import * as path from 'path';
import * as cdk from 'aws-cdk-lib';
import {
  aws_s3 as s3,
  aws_iam as iam,
  aws_secretsmanager as secretsmanager,
  aws_lambda as lambda,
  aws_lambda_nodejs as nodejs,
  aws_logs as logs,
  aws_apigateway as apigw,
  aws_ses as ses,
  aws_wafv2 as wafv2,
  aws_cloudwatch as cloudwatch,
  aws_cloudwatch_actions as cw_actions,
  aws_sns as sns,
  CfnOutput,
  Duration,
  RemovalPolicy,
} from 'aws-cdk-lib';
import { Construct } from 'constructs';

// ── Stack props ────────────────────────────────────────────────────────────────

export interface InstructorStackProps extends cdk.StackProps {
  /** 'dev' | 'staging' | 'prod' — controls removal policy and lifecycle rules */
  readonly envName: string;
  /**
   * SES sender email address (e.g. "instructor.app@layersiq.com").
   * Falls back to CDK context key 'sesFromEmail', then 'instructor.app@layersiq.com'.
   * For production: layersiq.com domain must be verified in AWS SES before first deploy.
   */
  readonly sesFromEmail?: string;
}

// ── Instructor Infrastructure Stack ──────────────────────────────────────────
//
// Provisions (in order of creation):
//   1. S3 bucket          — TTS audio cache + per-user SQLite backups (EXISTING)
//   2. IAM user           — NestJS server S3 credentials for Docker/local (EXISTING)
//   3. IAM policies       — Least-privilege S3 access for IAM user (EXISTING)
//   4. Secrets Manager    — IAM user credentials (EXISTING)
//   5. App secrets        — JWT, API keys, Gemini key, DB/Redis URLs in Secrets Manager
//   6. CloudWatch log grp — Explicit log group with retention policy
//   7. Lambda exec role   — Least-privilege IAM role for Lambda function
//   8. Extension layer    — AWS Parameters & Secrets Lambda Extension (Secrets Manager cache)
//   9. Lambda function    — NodejsFunction with esbuild; 1024 MB / 120 s; no VPC
//  10. HTTP API v2        — API Gateway HTTP API; ANY /api/{proxy+} -> Lambda
//  11. SES identity       — layersiq.com domain identity (DKIM + TXT verification records)
//  12. WAF log group      — CloudWatch log group for WAF request logs (name: aws-waf-logs-*)
//  13. WAF WebACL         — REGIONAL WebACL; rate-based rule 100 req/5-min per source IP
//  14. WAF logging config — Connects WebACL to the WAF log group
//  15. WAF association    — Attaches WebACL to API Gateway HTTP API $default stage
//
// Key design decisions:
//   • Lambda is NOT placed in a VPC — eliminates NAT Gateway cost and ENI cold-start penalty.
//   • Neon PostgreSQL (free tier) and Upstash Redis (free tier) replace DynamoDB — no per-request data charges at launch scale (~1,000 DAU).
//   • HTTP API v2 (not REST API) — 70% cheaper, lower latency, sufficient feature set.
//   • Parameters & Secrets Lambda Extension — secrets cached in-process; zero latency on warm calls.
//   • IAM role (not IAM user) for Lambda — execution role grants temporary credentials automatically.
//   • WAF REGIONAL scope — required for API Gateway; CLOUDFRONT scope is only for CloudFront distros.
//   • WAF rate limit at 100/5-min per IP — blocks burst abuse while allowing legitimate traffic.
//   • WAF logs to CloudWatch — log group name MUST start with 'aws-waf-logs-' (AWS requirement).
// ──────────────────────────────────────────────────────────────────────────────

export class InstructorStack extends cdk.Stack {
  // ── Existing resources ─────────────────────────────────────────────────────

  /** The single bucket shared by TTS cache and user backups. */
  public readonly bucket: s3.IBucket;

  /** IAM user whose credentials the NestJS server uses (Docker / local dev). */
  public readonly serverUser: iam.User;

  // ── New Lambda resources ───────────────────────────────────────────────────

  /** Lambda function running the NestJS application. */
  public readonly lambdaFn: lambda.Function;

  /** Invoke URL for the HTTP API (no trailing slash). */
  public readonly apiUrl: string;

  constructor(scope: Construct, id: string, props: InstructorStackProps) {
    super(scope, id, props);

    const { envName } = props;
    const isProd = envName === 'prod';

    const sesFromEmail =
      props.sesFromEmail ??
      (this.node.tryGetContext('sesFromEmail') as string | undefined) ??
      'instructor.app@layersiq.com';

    // ── 1. S3 Bucket ──────────────────────────────────────────────────────────

    const bucketName = isProd ? 'instructor-cache' : `instructor-cache-${envName}`;

    if (isProd) {
      // In prod, the bucket already exists (created before the stack was managed by CDK).
      // Import it by name so CDK can reference its ARN without trying to create it.
      this.bucket = s3.Bucket.fromBucketName(this, 'InstructorBucket', bucketName);
    } else {
      this.bucket = new s3.Bucket(this, 'InstructorBucket', {
        bucketName,
        blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
        encryption: s3.BucketEncryption.S3_MANAGED,
        enforceSSL: true,
        versioned: true,
        removalPolicy: RemovalPolicy.DESTROY,
        autoDeleteObjects: true,

        lifecycleRules: [
          {
            id: 'tts-cache-expiry',
            prefix: 'tts/',
            enabled: true,
            expiration: Duration.days(30),
            noncurrentVersionExpiration: Duration.days(1),
            abortIncompleteMultipartUploadAfter: Duration.days(1),
          },
          {
            id: 'backups-version-retention',
            prefix: 'backups/',
            enabled: true,
            noncurrentVersionExpiration: Duration.days(30),
            noncurrentVersionsToRetain: 5,
          },
        ],

        cors: [
          {
            id: 'flutter-presigned-uploads',
            allowedMethods: [s3.HttpMethods.PUT, s3.HttpMethods.GET, s3.HttpMethods.HEAD],
            allowedOrigins: ['*'],
            allowedHeaders: [
              'Content-Type',
              'Content-Disposition',
              'Content-Length',
              'x-amz-*',
              'Authorization',
            ],
            maxAge: 3000,
            exposedHeaders: ['ETag'],
          },
        ],
      });
    }

    // ── 2. IAM User (NestJS backend — Docker / local dev) ─────────────────────
    // NOTE: Lambda uses its execution role (not this IAM user).
    // This user is retained for docker-compose and non-Lambda deployments.

    this.serverUser = new iam.User(this, 'InstructorServerUser', {
      userName: `instructor-server-${envName}`,
    });

    // ── 3. Least-privilege S3 Policy for IAM user ─────────────────────────────

    const ttsPolicy = new iam.Policy(this, 'TtsCachePolicy', {
      statements: [
        new iam.PolicyStatement({
          sid: 'TtsCacheReadWrite',
          effect: iam.Effect.ALLOW,
          actions: ['s3:GetObject', 's3:PutObject', 's3:GetObjectAttributes'],
          resources: [this.bucket.arnForObjects('tts/*')],
        }),
      ],
    });

    const syncPolicy = new iam.Policy(this, 'SyncBackupPolicy', {
      statements: [
        new iam.PolicyStatement({
          sid: 'SyncBackupPresignedUrls',
          effect: iam.Effect.ALLOW,
          actions: [
            's3:GetObject',
            's3:PutObject',
            's3:GetObjectAttributes',
            's3:ListBucket',
          ],
          resources: [this.bucket.arnForObjects('backups/*'), this.bucket.bucketArn],
          conditions: {
            StringLike: { 's3:prefix': ['backups/*'] },
          },
        }),
      ],
    });

    this.serverUser.attachInlinePolicy(ttsPolicy);
    this.serverUser.attachInlinePolicy(syncPolicy);

    // ── 4. IAM User Access Key -> Secrets Manager ──────────────────────────────

    const secretName = `instructor/${envName}/server-aws-credentials`;
    let credentialsSecret: secretsmanager.ISecret;
    let accessKey: iam.CfnAccessKey | null = null;

    if (isProd) {
      // In prod, import the existing secret to avoid recreating it
      credentialsSecret = secretsmanager.Secret.fromSecretNameV2(
        this,
        'ServerCredentialsSecret',
        secretName
      );
    } else {
      // In non-prod, create a new secret with fresh access key
      accessKey = new iam.CfnAccessKey(this, 'ServerAccessKey', {
        userName: this.serverUser.userName,
      });

      credentialsSecret = new secretsmanager.Secret(this, 'ServerCredentialsSecret', {
        secretName,
        description: 'AWS access key for the Instructor NestJS server (S3 TTS cache + sync)',
        secretStringValue: cdk.SecretValue.unsafePlainText(
          JSON.stringify({
            AWS_ACCESS_KEY_ID: accessKey.ref,
            AWS_SECRET_ACCESS_KEY: accessKey.attrSecretAccessKey,
          }),
        ),
        removalPolicy: RemovalPolicy.DESTROY,
      });
    }

    // ── 5. CloudFormation Outputs — existing resources ────────────────────────

    new CfnOutput(this, 'BucketName', {
      value: this.bucket.bucketName,
      description: 'S3 bucket name -> AWS_S3_BUCKET env var',
      exportName: `InstructorBucketName-${envName}`,
    });

    new CfnOutput(this, 'BucketRegion', {
      value: this.region,
      description: 'AWS region -> AWS_REGION env var',
      exportName: `InstructorBucketRegion-${envName}`,
    });

    new CfnOutput(this, 'ServerUserName', {
      value: this.serverUser.userName,
      description: 'IAM user name for the NestJS backend (Docker/local)',
    });

    new CfnOutput(this, 'CredentialsSecretArn', {
      value: credentialsSecret.secretArn,
      description: 'Secrets Manager ARN: AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY',
      exportName: `InstructorCredentialsSecretArn-${envName}`,
    });

    if (accessKey) {
      new CfnOutput(this, 'AccessKeyId', {
        value: accessKey.ref,
        description: 'AWS_ACCESS_KEY_ID for the NestJS server (also in Secrets Manager)',
      });
    }

    // ══════════════════════════════════════════════════════════════════════════
    // NEW RESOURCES — Lambda, API Gateway, SES
    // ══════════════════════════════════════════════════════════════════════════

    // ── 5. App Secrets (JWT, API keys, Gemini key, DB/Redis URLs) ────────────
    // These are consumed by the Lambda function via the Parameters & Secrets
    // Lambda Extension (localhost:2773).  Populate all REPLACE_ME values before
    // running `cdk deploy` for the first time:
    //   aws secretsmanager put-secret-value \
    //     --secret-id instructor/<env>/app-secrets \
    //     --secret-string '{"JWT_SECRET":"...","JWT_REFRESH_SECRET":"...","API_KEY":"...","OTP_SALT":"...","GEMINI_API_KEY":"..."}'

    const appSecretsName = `instructor/${envName}/app-secrets`;
    let appSecrets: secretsmanager.ISecret;

    if (isProd) {
      // Secret already exists (created before stack was managed by CDK).
      appSecrets = secretsmanager.Secret.fromSecretNameV2(this, 'AppSecrets', appSecretsName);
    } else {
      appSecrets = new secretsmanager.Secret(this, 'AppSecrets', {
        secretName: appSecretsName,
        description: [
          'Application secrets for Instructor Lambda.',
          'Keys: JWT_SECRET, JWT_REFRESH_SECRET, API_KEY, OTP_SALT, GEMINI_API_KEY, KOKORO_SERVER_URL,',
          'DATABASE_URL, UPSTASH_REDIS_REST_URL, UPSTASH_REDIS_REST_TOKEN.',
          'MUST be populated before first deploy - replace all REPLACE_ME values.',
        ].join(' '),
        secretStringValue: cdk.SecretValue.unsafePlainText(
          JSON.stringify({
            JWT_SECRET: 'REPLACE_ME',              // openssl rand -hex 32
            JWT_REFRESH_SECRET: 'REPLACE_ME',      // openssl rand -hex 32
            API_KEY: 'REPLACE_ME',                 // openssl rand -hex 32
            OTP_SALT: 'REPLACE_ME',                // openssl rand -hex 32
            GEMINI_API_KEY: 'REPLACE_ME',          // https://aistudio.google.com/app/apikey
            KOKORO_SERVER_URL: '',                 // Optional: URL of standalone Kokoro server
            DATABASE_URL: 'REPLACE_ME',            // Neon pooler connection string
            UPSTASH_REDIS_REST_URL: 'REPLACE_ME',  // Upstash Redis REST URL
            UPSTASH_REDIS_REST_TOKEN: 'REPLACE_ME',// Upstash Redis REST token
          }),
        ),
        removalPolicy: RemovalPolicy.DESTROY,
      });
    }

    // ── 8. CloudWatch Log Group ───────────────────────────────────────────────
    // Import existing log group if prod, otherwise create a new one for non-prod
    // (non-prod logs are cleaned up on stack destroy)

    const logGroupName = `/aws/lambda/instructor-${envName}`;
    const logGroup = isProd
      ? logs.LogGroup.fromLogGroupName(this, 'LambdaLogGroup', logGroupName)
      : new logs.LogGroup(this, 'LambdaLogGroup', {
          logGroupName,
          retention: logs.RetentionDays.ONE_WEEK,
          removalPolicy: RemovalPolicy.DESTROY,
        });

    // ── 9. Lambda IAM Execution Role ─────────────────────────────────────────
    // Principle of least privilege — each sid is scoped to the exact resources
    // and actions needed.  No wildcard resources or actions.

    const lambdaRole = new iam.Role(this, 'LambdaExecutionRole', {
      roleName: `instructor-lambda-${envName}`,
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      description: 'Execution role for Instructor Lambda - S3, SES, Secrets Manager, CloudWatch',
    });

    // 9a. CloudWatch Logs — write to the explicit log group only.
    lambdaRole.addToPolicy(
      new iam.PolicyStatement({
        sid: 'CloudWatchLogs',
        effect: iam.Effect.ALLOW,
        actions: ['logs:CreateLogStream', 'logs:PutLogEvents'],
        // Log group ARN + ":*" to cover log streams within the group.
        resources: [`${logGroup.logGroupArn}:*`],
      }),
    );

    // 9b. S3 — TTS cache: read + write audio files.
    lambdaRole.addToPolicy(
      new iam.PolicyStatement({
        sid: 'S3TtsCache',
        effect: iam.Effect.ALLOW,
        actions: ['s3:GetObject', 's3:PutObject', 's3:GetObjectAttributes'],
        resources: [this.bucket.arnForObjects('tts/*')],
      }),
    );

    // 9d. S3 — User backups: generate pre-signed PUT/GET URLs; read size for /sync/status.
    //     ListBucket is scoped to backups/ prefix via condition.
    lambdaRole.addToPolicy(
      new iam.PolicyStatement({
        sid: 'S3SyncBackups',
        effect: iam.Effect.ALLOW,
        actions: [
          's3:GetObject',
          's3:PutObject',
          's3:GetObjectAttributes',
          's3:ListBucket',
        ],
        resources: [
          this.bucket.arnForObjects('backups/*'),
          this.bucket.bucketArn,
        ],
        conditions: {
          // Restrict ListBucket to backups/ prefix; prevents TTS key enumeration.
          StringLike: { 's3:prefix': ['backups/*'] },
        },
      }),
    );

    // 9e. SES — send OTP verification emails.
    //     Scoped to the layersiq.com domain identity.
    const sesIdentityArn = `arn:aws:ses:${this.region}:${this.account}:identity/layersiq.com`;
    lambdaRole.addToPolicy(
      new iam.PolicyStatement({
        sid: 'SESSendEmail',
        effect: iam.Effect.ALLOW,
        actions: ['ses:SendEmail', 'ses:SendRawEmail'],
        resources: [sesIdentityArn],
      }),
    );

    // 9f. Secrets Manager — read app secrets via the Lambda extension.
    //     GetSecretValue is the only action needed; scoped to the app-secrets.
    //     AWS Secrets Manager appends a random suffix to secret ARNs (e.g., -4du3Fk),
    //     so we use a wildcard to match the actual ARN at runtime.
    lambdaRole.addToPolicy(
      new iam.PolicyStatement({
        sid: 'SecretsManagerRead',
        effect: iam.Effect.ALLOW,
        actions: ['secretsmanager:GetSecretValue'],
        resources: [
          cdk.Arn.format(
            {
              service: 'secretsmanager',
              resource: `secret:${appSecretsName}-*`,
            },
            cdk.Stack.of(this),
          ),
        ],
      }),
    );

    // ── 10. AWS Parameters and Secrets Lambda Extension layer ─────────────────
    // This extension pre-caches secrets from Secrets Manager in the execution
    // environment and exposes them at http://localhost:2773/secretsmanager/get.
    // Warm invocations pay zero latency cost (no SDK calls in application code).
    //
    // Layer account IDs are region-specific (AWS-owned, not customer-owned).
    // Source: https://docs.aws.amazon.com/secretsmanager/latest/userguide/retrieving-secrets_lambda.html
    // Layer version 12 supports Node.js 18/20/22 and arm64/x86_64.

    const extensionLayerAccounts = new cdk.CfnMapping(this, 'ExtensionLayerAccounts', {
      mapping: {
        'us-east-1':      { accountId: '177933569100' },
        'us-east-2':      { accountId: '590474943231' },
        'us-west-1':      { accountId: '997803712105' },
        'us-west-2':      { accountId: '345057560386' },
        'ap-south-1':     { accountId: '176022468876' },
        'ap-northeast-1': { accountId: '133490724326' },
        'ap-northeast-2': { accountId: '738900069198' },
        'ap-southeast-1': { accountId: '044395824272' },
        'ap-southeast-2': { accountId: '665172237481' },
        'eu-west-1':      { accountId: '015030872274' },
        'eu-west-2':      { accountId: '133256977650' },
        'eu-central-1':   { accountId: '187925254637' },
        'ca-central-1':   { accountId: '200266452380' },
      },
    });

    // Construct the layer ARN using Fn::Sub + Fn::FindInMap so it resolves
    // correctly at CloudFormation deploy time regardless of the target region.
    const extensionLayerArn = cdk.Fn.sub(
      'arn:aws:lambda:${AWS::Region}:${AccountId}:layer:AWS-Parameters-and-Secrets-Lambda-Extension:12',
      { AccountId: extensionLayerAccounts.findInMap(cdk.Aws.REGION, 'accountId') },
    );

    const extensionLayer = lambda.LayerVersion.fromLayerVersionArn(
      this,
      'ParametersSecretsExtension',
      extensionLayerArn,
    );

    // ── 11. Lambda Function ───────────────────────────────────────────────────
    // Entry point: server/src/lambda.ts  (created by TASK-008)
    // Bundled with esbuild via NodejsFunction:
    //   • keepNames: true     — preserves class/function names for NestJS DI
    //   • externalModules     — excludes native addons and legacy deps not used in Lambda
    //   • server tsconfig     — provides emitDecoratorMetadata + paths config to esbuild
    //
    // NOT in a VPC: eliminates NAT Gateway cost (~$32/month) and
    //               ENI cold-start penalty (100–400 ms per cold start).

    this.lambdaFn = new nodejs.NodejsFunction(this, 'ApiHandler', {
      functionName: `instructor-${envName}`,
      // Prerequisite: server/src/lambda.ts must exist (created by TASK-008).
      entry: path.join(__dirname, '../../server/src/lambda.ts'),
      handler: 'handler',
      runtime: lambda.Runtime.NODEJS_22_X,
      memorySize: 1024,
      // 120 s — well under API Gateway HTTP API's 30 s integration timeout.
      // TTS synthesis peaks at ~15 s; keep room for cold starts.
      timeout: Duration.seconds(120),
      role: lambdaRole,
      // Attach the explicitly-created log group (controls retention + removal policy).
      logGroup,
      // Attach the Parameters & Secrets Lambda Extension.
      layers: [extensionLayer],
      environment: {
        NODE_ENV: 'production',
        // Enable HTTP keep-alive on the AWS SDK HTTP agent for connection reuse
        // (reduces per-request latency on warm invocations by ~10–30 ms).
        AWS_NODEJS_CONNECTION_REUSE_ENABLED: '1',
        // Application config — non-secret values passed directly.
        AWS_S3_BUCKET: this.bucket.bucketName,
        SES_FROM_EMAIL: sesFromEmail,
        // Lambda extension config — the extension listens on this port.
        PARAMETERS_SECRETS_EXTENSION_HTTP_PORT: '2773',
        // Cache TTL for secrets (seconds). 300 s = 5 minutes.
        SECRETS_MANAGER_TTL: '300',
        // The secret ID that the Lambda code fetches from the extension.
        APP_SECRETS_ID: appSecrets.secretName,
      },
      bundling: {
        // Do not minify — preserves stack traces in CloudWatch logs.
        minify: false,
        // REQUIRED for NestJS: esbuild must not mangle class/function names
        // because NestJS DI resolves providers by constructor name at runtime.
        keepNames: true,
        sourceMap: true,
        sourceMapMode: nodejs.SourceMapMode.INLINE,
        target: 'node22',
        // CommonJS format for Node.js Lambda runtime.
        format: nodejs.OutputFormat.CJS,
        // Use the server's tsconfig — gives esbuild paths config and decorator flags.
        // Note: esbuild ignores emitDecoratorMetadata; keepNames is the compensating control.
        tsconfig: path.join(__dirname, '../../server/tsconfig.json'),
        // Externalized modules — NOT bundled and NOT installed in the Lambda zip.
        // These are either:
        //   (a) Native addons that cannot be bundled (better-sqlite3), or
        //   (b) Legacy modules removed from the build that must not be imported at runtime.
        // If the Lambda handler still imports these at runtime, it will throw.
        // Ensure server/src/lambda.ts does NOT import these modules.
        externalModules: [
          'better-sqlite3',               // Native addon — removed; Neon HTTP driver used instead
          'ioredis',                       // TCP Redis client — removed; Upstash HTTP client used instead
          '@nestjs/websockets',            // Optional NestJS peer dep — not used
          '@nestjs/microservices',         // Optional NestJS peer dep — not used
          '@nestjs/platform-socket.io',    // Optional NestJS peer dep — not used
          'class-transformer/storage',     // Optional — dynamically required by NestJS
        ],
      },
    });

    // ── 12. API Gateway REST API ──────────────────────────────────────────────────
    // REST API (required for WAFv2 support):
    //   • Required for WAFv2 association (HTTP API v2 not supported by WAFv2)
    //   • Higher cost (~$3.50/million) but enables security features
    //   • Built-in CORS + throttling; sufficient for this project

    const restApi = new apigw.RestApi(this, 'RestApi', {
      restApiName: `instructor-api-${envName}`,
      description: `Instructor backend API - ${envName}`,
      defaultCorsPreflightOptions: {
        allowOrigins: apigw.Cors.ALL_ORIGINS,
        allowMethods: apigw.Cors.ALL_METHODS,
        allowHeaders: [
          'Content-Type',
          'Authorization',
          'x-api-key',
          'x-amz-date',
          'x-amz-security-token',
        ],
        maxAge: Duration.minutes(5),
      },
      deploy: false,
    });

    // Lambda proxy integration
    const lambdaIntegration = new apigw.LambdaIntegration(this.lambdaFn, {
      proxy: true,
      // 29 s — just under API Gateway's 30 s hard limit.
      // Lambda timeout is 120 s, but clients will get a 503 after 29 s anyway.
      timeout: Duration.seconds(29),
    });

    // Single catch-all proxy at root: /{proxy+}
    // Captures all NestJS routes including /api/*
    // REST API will forward the full path to Lambda (e.g., /api/tts/synthesize)
    restApi.root.addResource('{proxy+}').addMethod('ANY', lambdaIntegration);

    // Deploy with default stage
    const deployment = new apigw.Deployment(this, 'ApiDeployment', { api: restApi });
    const defaultStage = new apigw.Stage(this, 'DefaultStage', {
      deployment,
      stageName: 'default',
    });

    // Grant API Gateway permission to invoke the Lambda function.
    // sourceArn scoped to this API only — prevents confused-deputy attacks.
    this.lambdaFn.addPermission('ApiGatewayInvoke', {
      principal: new iam.ServicePrincipal('apigateway.amazonaws.com'),
      action: 'lambda:InvokeFunction',
      sourceArn: `arn:aws:execute-api:${this.region}:${this.account}:${restApi.restApiId}/*/*`,
    });

    // ── 11. SES Domain Identity — layersiq.com ────────────────────────────────
    // Registers the layersiq.com domain with AWS SES for DKIM-signed sending.
    //
    // Domain verification generates:
    //   - Three CNAME records for DKIM (DkimDnsTokenName1/2/3 outputs)
    //   - A TXT record for domain verification
    // Add these DNS records in your registrar / Route 53 hosted zone.
    //
    // Sender email instructor.app@layersiq.com is authorised once the domain is verified.
    //
    // IMPORTANT: New AWS accounts start in the SES sandbox (can only send to
    //   verified addresses). Request SES production access before going live:
    //   https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html

    // In prod, the layersiq.com SES identity is managed by the LayersIq-Production stack.
    // Only create it in non-prod environments.
    if (!isProd) {
      new ses.CfnEmailIdentity(this, 'SesFromIdentity', {
        emailIdentity: 'layersiq.com',
      });
    }

    // ── 14. CloudFormation Outputs — new resources ────────────────────────────

    // API URL: https://<apiId>.execute-api.<region>.amazonaws.com/<stage>
    this.apiUrl = `https://${restApi.restApiId}.execute-api.${this.region}.amazonaws.com/${defaultStage.stageName}`;

    new CfnOutput(this, 'ApiUrl', {
      value: this.apiUrl,
      description: 'REST API invoke URL - set as BACKEND_URL in Flutter app',
      exportName: `InstructorApiUrl-${envName}`,
    });

    new CfnOutput(this, 'LambdaFunctionName', {
      value: this.lambdaFn.functionName,
      description: 'Lambda function name (for aws lambda invoke, CloudWatch)',
    });

    new CfnOutput(this, 'LambdaFunctionArn', {
      value: this.lambdaFn.functionArn,
      description: 'Lambda function ARN',
      exportName: `InstructorLambdaArn-${envName}`,
    });

    new CfnOutput(this, 'AppSecretsArn', {
      value: appSecrets.secretArn,
      description: 'Secrets Manager ARN for app secrets - populate all REPLACE_ME values before deploy',
      exportName: `InstructorAppSecretsArn-${envName}`,
    });

    new CfnOutput(this, 'LogGroupName', {
      value: logGroup.logGroupName,
      description: 'CloudWatch log group for Lambda function',
    });

    new CfnOutput(this, 'SesFromEmail', {
      value: sesFromEmail,
      description: 'SES sender identity - must be verified before sending emails',
    });

    // ══════════════════════════════════════════════════════════════════════════
    // WAF — Web Application Firewall (TASK-016)
    // ══════════════════════════════════════════════════════════════════════════

    // ── 13. WAF CloudWatch Log Group ──────────────────────────────────────────
    // AWS WAF requires the destination log group name to START WITH 'aws-waf-logs-'.
    // Import existing log group if prod, otherwise create a new one for non-prod.

    const wafLogGroupName = `aws-waf-logs-instructor-${envName}`;
    const wafLogGroup = isProd
      ? logs.LogGroup.fromLogGroupName(this, 'WafLogGroup', wafLogGroupName)
      : new logs.LogGroup(this, 'WafLogGroup', {
          logGroupName: wafLogGroupName,
          retention: logs.RetentionDays.ONE_WEEK,
          removalPolicy: RemovalPolicy.DESTROY,
        });

    // Grant WAF log delivery service permission to write to the log group.
    // WAF uses the 'delivery.logs.amazonaws.com' service principal for CloudWatch delivery.
    // The resource policy is mandatory — without it WAF silently drops logs.
    wafLogGroup.addToResourcePolicy(
      new iam.PolicyStatement({
        sid: 'WafLogDelivery',
        effect: iam.Effect.ALLOW,
        principals: [new iam.ServicePrincipal('delivery.logs.amazonaws.com')],
        actions: ['logs:CreateLogStream', 'logs:PutLogEvents'],
        resources: [`${wafLogGroup.logGroupArn}:log-stream:*`],
        conditions: {
          // Scope the permission to WAF log delivery for this account only.
          StringEquals: { 'aws:SourceAccount': this.account },
          ArnLike: {
            'aws:SourceArn': `arn:aws:logs:${this.region}:${this.account}:*`,
          },
        },
      }),
    );

    // ── 14. WAF WebACL ────────────────────────────────────────────────────────
    // REGIONAL scope — mandatory for API Gateway; CLOUDFRONT scope is only for
    // CloudFront distributions and must be deployed in us-east-1.
    //
    // Rules:
    //   Priority 1 — PerIpRateLimit:
    //     Rate-based rule counting per unique source IP.
    //     Limit: 100 requests per 5-minute window (AWS WAF fixed window, not sliding).
    //     Action: BLOCK — returns HTTP 403 to the throttled client.
    //     Effect: prevents a single client from consuming the API Gateway stage quota
    //             (200 burst / 100 RPS) and from executing brute-force attacks.
    //
    // Default action: ALLOW — all requests not matched by a rule pass through.

    const webAcl = new wafv2.CfnWebACL(this, 'WafWebAcl', {
      name: `instructor-waf-${envName}`,
      description: `WAF WebACL for Instructor API ${envName} - per-IP rate limiting`,
      scope: 'REGIONAL',
      // Allow traffic that does not match any rule.
      defaultAction: { allow: {} },
      visibilityConfig: {
        cloudWatchMetricsEnabled: true,
        metricName: `instructor-waf-${envName}`,
        sampledRequestsEnabled: true,
      },
      rules: [
        {
          name: 'PerIpRateLimit',
          priority: 1,
          // BLOCK the request that exceeds the threshold.
          action: { block: {} },
          visibilityConfig: {
            cloudWatchMetricsEnabled: true,
            metricName: `PerIpRateLimit-${envName}`,
            sampledRequestsEnabled: true,
          },
          statement: {
            rateBasedStatement: {
              // 100 requests per 5-minute window — AWS WAF minimum allowed value.
              // Window is always 5 minutes (AWS-fixed); no config knob needed.
              limit: 100,
              // Aggregate by the source IP of the request.
              aggregateKeyType: 'IP',
            },
          },
        },
      ],
    });

    // ── 15. WAF Logging Configuration ─────────────────────────────────────────
    // Sends sampled and full request logs (allowed + blocked) to CloudWatch.
    // The destination ARN must reference a log group whose name starts with
    // 'aws-waf-logs-' — any other name is rejected by the WAF control plane.

    const wafLoggingConfig = new wafv2.CfnLoggingConfiguration(this, 'WafLoggingConfig', {
      resourceArn: webAcl.attrArn,
      logDestinationConfigs: [
        // CloudWatch Logs destination: use the log group ARN (not a stream ARN).
        wafLogGroup.logGroupArn,
      ],
    });

    // Ensure the log group resource policy is in place before WAF tries to write.
    wafLoggingConfig.node.addDependency(wafLogGroup);

    // ── 16. WAF WebACL Association — API Gateway REST API ─────────────────────
    // Associates the WebACL with the API Gateway REST API default stage.
    //
    // Resource ARN format for REST API stage:
    //   arn:aws:apigateway:{region}::/restapis/{apiId}/stages/{stageName}
    //
    // Note: The leading '//' (double slash) after 'apigateway' is intentional and required.

    const apiStageArn = `arn:aws:apigateway:${this.region}::/restapis/${restApi.restApiId}/stages/${defaultStage.stageName}`;

    const wafAssociation = new wafv2.CfnWebACLAssociation(this, 'WafWebAclAssociation', {
      resourceArn: apiStageArn,
      webAclArn: webAcl.attrArn,
    });

    // The association requires the stage to exist first.
    wafAssociation.node.addDependency(defaultStage);

    // ── 17. CloudFormation Outputs — WAF resources ────────────────────────────

    new CfnOutput(this, 'WafWebAclArn', {
      value: webAcl.attrArn,
      description: 'WAF WebACL ARN - rate-limited to 100 req/5-min per source IP',
      exportName: `InstructorWafWebAclArn-${envName}`,
    });

    new CfnOutput(this, 'WafLogGroupName', {
      value: wafLogGroup.logGroupName,
      description: 'CloudWatch log group for WAF request logs',
    });

    // ══════════════════════════════════════════════════════════════════════════
    // OBSERVABILITY — CloudWatch Alarms + Dashboard (TASK-018)
    //
    // Alarms:
    //   1. Lambda error rate > 5%   (2-of-2 five-minute periods)
    //   2. Lambda throttles > 0     (any throttle in a 5-minute period)
    //   3. Lambda duration p99 > 96 s (80% of 120 s timeout, 2-of-2 periods)
    //
    // All alarms publish to an SNS topic.  Subscribe your ops email after deploy:
    //   aws sns subscribe \
    //     --topic-arn <AlarmTopicArn> \
    //     --protocol email \
    //     --notification-endpoint ops@instructor.app
    //
    // Dashboard: instructor-<env>
    //   Row 1 — Lambda invocations, errors, error rate %, throttles
    //   Row 2 — Lambda duration p50/p99, alarm status widget
    // ══════════════════════════════════════════════════════════════════════════

    // ── SNS topic for alarm notifications ─────────────────────────────────────

    const alarmTopic = new sns.Topic(this, 'AlarmTopic', {
      topicName: `instructor-alarms-${envName}`,
      displayName: `Instructor ${envName} CloudWatch Alarms`,
    });

    const snsAlarmAction = new cw_actions.SnsAction(alarmTopic);

    // ── Lambda metric definitions ──────────────────────────────────────────────
    //
    // All metrics use a 5-minute period — short enough to surface issues quickly,
    // long enough to smooth transient single-invocation spikes.

    const evalPeriod = Duration.minutes(5);
    const lambdaDimensions = { FunctionName: this.lambdaFn.functionName };

    const mErrors = new cloudwatch.Metric({
      namespace: 'AWS/Lambda',
      metricName: 'Errors',
      dimensionsMap: lambdaDimensions,
      statistic: 'Sum',
      period: evalPeriod,
      label: 'Errors',
    });

    const mInvocations = new cloudwatch.Metric({
      namespace: 'AWS/Lambda',
      metricName: 'Invocations',
      dimensionsMap: lambdaDimensions,
      statistic: 'Sum',
      period: evalPeriod,
      label: 'Invocations',
    });

    const mThrottles = new cloudwatch.Metric({
      namespace: 'AWS/Lambda',
      metricName: 'Throttles',
      dimensionsMap: lambdaDimensions,
      statistic: 'Sum',
      period: evalPeriod,
      label: 'Throttles',
    });

    const mDurationP50 = new cloudwatch.Metric({
      namespace: 'AWS/Lambda',
      metricName: 'Duration',
      dimensionsMap: lambdaDimensions,
      statistic: 'p50',
      period: evalPeriod,
      label: 'Duration p50 (ms)',
    });

    const mDurationP99 = new cloudwatch.Metric({
      namespace: 'AWS/Lambda',
      metricName: 'Duration',
      dimensionsMap: lambdaDimensions,
      statistic: 'p99',
      period: evalPeriod,
      label: 'Duration p99 (ms)',
    });

    // Error rate — MathExpression avoids division-by-zero when invocations = 0.
    // IF() returns 0 (not breaching) when there is no traffic.
    const mErrorRate = new cloudwatch.MathExpression({
      expression: 'IF(invocations > 0, 100 * errors / invocations, 0)',
      usingMetrics: { errors: mErrors, invocations: mInvocations },
      period: evalPeriod,
      label: 'Error Rate (%)',
    });

    // ── Alarm 1: Error rate > 5% ───────────────────────────────────────────────
    // Requires 2-of-2 consecutive 5-minute periods to fire, reducing alert noise
    // from isolated transient failures that self-resolve.

    const alarmErrorRate = new cloudwatch.Alarm(this, 'AlarmLambdaErrorRate', {
      alarmName: `instructor-${envName}-lambda-error-rate`,
      alarmDescription:
        'Lambda error rate exceeded 5% over two consecutive 5-minute windows. ' +
        'Check CloudWatch Logs for stack traces: ' +
        `/aws/lambda/instructor-${envName}`,
      metric: mErrorRate,
      threshold: 5,
      evaluationPeriods: 2,
      datapointsToAlarm: 2,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      // Missing data = no invocations = not an error condition.
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    alarmErrorRate.addAlarmAction(snsAlarmAction);
    alarmErrorRate.addOkAction(snsAlarmAction);

    // ── Alarm 2: Lambda throttles > 0 ─────────────────────────────────────────
    // Any throttle means we are hitting the reserved or account concurrency limit.
    // Fires on the first occurrence (1-of-1) so the team can raise the limit
    // before it impacts user traffic.

    const alarmThrottles = new cloudwatch.Alarm(this, 'AlarmLambdaThrottles', {
      alarmName: `instructor-${envName}-lambda-throttles`,
      alarmDescription:
        'Lambda throttling detected - concurrent execution limit may need raising. ' +
        'Check Lambda -> Configuration -> Concurrency in the AWS console.',
      metric: mThrottles,
      // Threshold = 0: trigger on ANY throttle event (> 0).
      threshold: 0,
      evaluationPeriods: 1,
      datapointsToAlarm: 1,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    alarmThrottles.addAlarmAction(snsAlarmAction);
    alarmThrottles.addOkAction(snsAlarmAction);

    // ── Alarm 3: Duration p99 > 96 s (80 % of 120 s Lambda timeout) ───────────
    // CloudWatch Duration metric is in milliseconds.
    // 80% of 120,000 ms = 96,000 ms.
    // Fires after 2 consecutive breaching periods — one slow invocation
    // (e.g. a single cold start) should not page on-call.

    const alarmDuration = new cloudwatch.Alarm(this, 'AlarmLambdaDuration', {
      alarmName: `instructor-${envName}-lambda-duration-p99`,
      alarmDescription:
        'Lambda p99 duration exceeded 96 s (80 % of 120 s timeout). ' +
        'TTS synthesis or cold-start latency may be approaching the API Gateway 30 s limit. ' +
        'Investigate slow invocations in the Duration dashboard widget.',
      metric: mDurationP99,
      // 96,000 ms = 96 seconds = 80 % of Lambda timeout.
      threshold: 96_000,
      evaluationPeriods: 2,
      datapointsToAlarm: 2,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    alarmDuration.addAlarmAction(snsAlarmAction);
    alarmDuration.addOkAction(snsAlarmAction);

    // ── CloudWatch Dashboard ───────────────────────────────────────────────────
    //
    // Open: https://<region>.console.aws.amazon.com/cloudwatch/home#dashboards:name=instructor-<env>
    // Or use the DashboardUrl CloudFormation output below.

    const dashboard = new cloudwatch.Dashboard(this, 'InstructorDashboard', {
      dashboardName: `instructor-${envName}`,
    });

    // Row 1 — Lambda traffic and error signals
    dashboard.addWidgets(
      new cloudwatch.GraphWidget({
        title: 'Lambda - Invocations & Errors',
        left: [mInvocations],
        right: [mErrors],
        leftYAxis: { label: 'Invocations', showUnits: false },
        rightYAxis: { label: 'Errors', showUnits: false },
        width: 8,
        height: 6,
      }),
      new cloudwatch.GraphWidget({
        title: 'Lambda - Error Rate (%)',
        left: [mErrorRate],
        leftYAxis: { label: 'Error Rate (%)', showUnits: false },
        leftAnnotations: [
          { value: 5, label: '5 % alarm threshold', color: '#d62728' },
        ],
        width: 8,
        height: 6,
      }),
      new cloudwatch.GraphWidget({
        title: 'Lambda - Throttles',
        left: [mThrottles],
        leftYAxis: { label: 'Count', showUnits: false },
        width: 8,
        height: 6,
      }),
    );

    // Row 2 — Lambda duration and alarm status overview
    dashboard.addWidgets(
      new cloudwatch.GraphWidget({
        title: 'Lambda - Duration p50 / p99 (ms)',
        left: [mDurationP50, mDurationP99],
        leftYAxis: { label: 'Milliseconds', showUnits: false },
        leftAnnotations: [
          { value: 96_000, label: '96 s (80 % of timeout)', color: '#ff7f0e' },
          { value: 30_000, label: '30 s (API GW limit)',    color: '#d62728' },
        ],
        width: 12,
        height: 6,
      }),
      new cloudwatch.AlarmStatusWidget({
        title: 'Alarm Status',
        alarms: [alarmErrorRate, alarmThrottles, alarmDuration],
        width: 12,
        height: 6,
      }),
    );

    // ── CloudFormation Outputs — observability resources ───────────────────────

    new CfnOutput(this, 'AlarmTopicArn', {
      value: alarmTopic.topicArn,
      description:
        'SNS topic ARN for CloudWatch alarm notifications. ' +
        'Subscribe ops email: aws sns subscribe --topic-arn <arn> --protocol email --notification-endpoint ops@instructor.app',
      exportName: `InstructorAlarmTopicArn-${envName}`,
    });

    new CfnOutput(this, 'DashboardUrl', {
      value: `https://${this.region}.console.aws.amazon.com/cloudwatch/home#dashboards:name=instructor-${envName}`,
      description: 'CloudWatch dashboard - Lambda operational metrics',
    });

    new CfnOutput(this, 'AlarmErrorRateName', {
      value: alarmErrorRate.alarmName,
      description: 'CloudWatch alarm: Lambda error rate > 5%',
    });

    new CfnOutput(this, 'AlarmThrottlesName', {
      value: alarmThrottles.alarmName,
      description: 'CloudWatch alarm: Lambda throttling events',
    });

    new CfnOutput(this, 'AlarmDurationName', {
      value: alarmDuration.alarmName,
      description: 'CloudWatch alarm: Lambda duration p99 > 96 s (80% of 120 s timeout)',
    });
  }
}
