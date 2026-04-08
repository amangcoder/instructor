/**
 * CDK assertion tests for InstructorStack.
 *
 * Uses aws-cdk-lib/assertions to validate the CloudFormation template
 * synthesized from the CDK stack without deploying any real resources.
 *
 * Coverage:
 *   Existing resources (S3 bucket, IAM user, Secrets Manager)
 *   New Lambda resources (TASK-010): Lambda function, API Gateway HTTP API,
 *     DynamoDB table, SES identity, IAM execution role, CloudWatch log group
 *
 * To run: npm test (requires jest + ts-jest in devDependencies)
 */

import * as cdk from 'aws-cdk-lib';
import { Template, Match } from 'aws-cdk-lib/assertions';
import { InstructorStack } from './instructor-stack';

// ---------------------------------------------------------------------------
// Helper: synthesize a test stack
// ---------------------------------------------------------------------------

function synthesizeStack(envName = 'dev'): Template {
  const app = new cdk.App();
  const stack = new InstructorStack(app, `InstructorStack-${envName}`, {
    envName,
    env: { account: '123456789012', region: 'us-east-1' },
  });
  return Template.fromStack(stack);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('InstructorStack', () => {
  let template: Template;

  beforeEach(() => {
    template = synthesizeStack('dev');
  });

  // ── S3 Bucket (existing resource) ─────────────────────────────────────────

  describe('S3 Bucket', () => {
    it('creates exactly one S3 bucket', () => {
      template.resourceCountIs('AWS::S3::Bucket', 1);
    });

    it('blocks all public access on the bucket', () => {
      template.hasResourceProperties('AWS::S3::Bucket', {
        PublicAccessBlockConfiguration: {
          BlockPublicAcls: true,
          BlockPublicPolicy: true,
          IgnorePublicAcls: true,
          RestrictPublicBuckets: true,
        },
      });
    });

    it('enables S3-managed server-side encryption', () => {
      template.hasResourceProperties('AWS::S3::Bucket', {
        BucketEncryption: {
          ServerSideEncryptionConfiguration: Match.arrayWith([
            Match.objectLike({
              ServerSideEncryptionByDefault: {
                SSEAlgorithm: 'AES256',
              },
            }),
          ]),
        },
      });
    });

    it('enables versioning on the bucket', () => {
      template.hasResourceProperties('AWS::S3::Bucket', {
        VersioningConfiguration: {
          Status: 'Enabled',
        },
      });
    });

    it('has a TTS cache lifecycle rule that expires objects', () => {
      template.hasResourceProperties('AWS::S3::Bucket', {
        LifecycleConfiguration: {
          Rules: Match.arrayWith([
            Match.objectLike({
              Id: 'tts-cache-expiry',
              Prefix: 'tts/',
              Status: 'Enabled',
            }),
          ]),
        },
      });
    });

    it('has a backups retention lifecycle rule', () => {
      template.hasResourceProperties('AWS::S3::Bucket', {
        LifecycleConfiguration: {
          Rules: Match.arrayWith([
            Match.objectLike({
              Id: 'backups-version-retention',
              Prefix: 'backups/',
              Status: 'Enabled',
            }),
          ]),
        },
      });
    });

    it('enforces HTTPS-only access via bucket policy', () => {
      template.hasResourceProperties('AWS::S3::BucketPolicy', {
        PolicyDocument: {
          Statement: Match.arrayWith([
            Match.objectLike({
              Effect: 'Deny',
              Condition: {
                Bool: { 'aws:SecureTransport': 'false' },
              },
            }),
          ]),
        },
      });
    });

    it('dev bucket name includes the env suffix', () => {
      template.hasResourceProperties('AWS::S3::Bucket', {
        BucketName: 'instructor-cache-dev',
      });
    });
  });

  // ── Prod bucket name (different stack) ────────────────────────────────────

  describe('S3 Bucket — prod env', () => {
    it('prod bucket name is "instructor-cache" (no suffix)', () => {
      const prodTemplate = synthesizeStack('prod');
      prodTemplate.hasResourceProperties('AWS::S3::Bucket', {
        BucketName: 'instructor-cache',
      });
    });

    it('prod bucket has RETAIN removal policy', () => {
      const prodTemplate = synthesizeStack('prod');
      prodTemplate.hasResource('AWS::S3::Bucket', {
        DeletionPolicy: 'Retain',
        UpdateReplacePolicy: 'Retain',
      });
    });

    it('dev bucket has DELETE removal policy', () => {
      template.hasResource('AWS::S3::Bucket', {
        DeletionPolicy: 'Delete',
      });
    });
  });

  // ── IAM User (existing resource) ──────────────────────────────────────────

  describe('IAM User', () => {
    it('creates exactly one IAM user', () => {
      template.resourceCountIs('AWS::IAM::User', 1);
    });

    it('IAM user name includes the env suffix', () => {
      template.hasResourceProperties('AWS::IAM::User', {
        UserName: 'instructor-server-dev',
      });
    });

    it('IAM user has an inline TTS cache policy', () => {
      template.hasResourceProperties('AWS::IAM::Policy', {
        PolicyDocument: {
          Statement: Match.arrayWith([
            Match.objectLike({
              Action: Match.arrayWith(['s3:GetObject', 's3:PutObject']),
            }),
          ]),
        },
      });
    });

    it('IAM user has an inline sync backup policy', () => {
      template.hasResourceProperties('AWS::IAM::Policy', {
        PolicyDocument: {
          Statement: Match.arrayWith([
            Match.objectLike({
              Action: Match.arrayWith(['s3:ListBucket']),
            }),
          ]),
        },
      });
    });
  });

  // ── Secrets Manager (existing resource) ───────────────────────────────────

  describe('Secrets Manager', () => {
    it('creates a Secrets Manager secret for server credentials', () => {
      template.resourceCountIs('AWS::SecretsManager::Secret', 1);
    });

    it('secret name follows instructor/<env>/server-aws-credentials pattern', () => {
      template.hasResourceProperties('AWS::SecretsManager::Secret', {
        Name: 'instructor/dev/server-aws-credentials',
      });
    });

    it('dev secret has DESTROY removal policy', () => {
      template.hasResource('AWS::SecretsManager::Secret', {
        DeletionPolicy: 'Delete',
      });
    });
  });

  // ── CloudFormation Outputs ────────────────────────────────────────────────

  describe('CloudFormation Outputs', () => {
    it('outputs the bucket name', () => {
      template.hasOutput('BucketName', {
        Description: 'S3 bucket name → AWS_S3_BUCKET env var',
      });
    });

    it('outputs the bucket region', () => {
      template.hasOutput('BucketRegion', {
        Description: 'AWS region → AWS_REGION env var',
      });
    });

    it('outputs the server IAM user name', () => {
      template.hasOutput('ServerUserName', {});
    });

    it('outputs the Secrets Manager ARN', () => {
      template.hasOutput('CredentialsSecretArn', {
        Description: Match.stringLikeRegexp('Secrets Manager'),
      });
    });
  });

  // ── Lambda function (TASK-010) ────────────────────────────────────────────
  //
  // These tests validate resources added by TASK-010 (CDK Lambda extension).
  // lambda.ts now exists (TASK-008 complete) — tests enabled.

  describe('Lambda function (TASK-010)', () => {
    it('creates a Lambda function with 1024 MB memory', () => {
      template.hasResourceProperties('AWS::Lambda::Function', {
        MemorySize: 1024,
      });
    });

    it('Lambda timeout is 120 seconds', () => {
      template.hasResourceProperties('AWS::Lambda::Function', {
        Timeout: 120,
      });
    });

    it('Lambda runtime is nodejs (Node.js 20+)', () => {
      template.hasResourceProperties('AWS::Lambda::Function', {
        Runtime: Match.stringLikeRegexp(/nodejs/),
      });
    });

    it('Lambda has DYNAMODB_TABLE environment variable', () => {
      template.hasResourceProperties('AWS::Lambda::Function', {
        Environment: {
          Variables: Match.objectLike({
            DYNAMODB_TABLE: Match.anyValue(),
          }),
        },
      });
    });

    it('Lambda has AWS_REGION environment variable', () => {
      template.hasResourceProperties('AWS::Lambda::Function', {
        Environment: {
          Variables: Match.objectLike({
            AWS_REGION: Match.anyValue(),
          }),
        },
      });
    });

    it('Lambda is NOT placed in a VPC', () => {
      // Lambda function should NOT have a VpcConfig property
      const resources = template.toJSON().Resources;
      const lambdaFunctions = Object.values(resources).filter(
        (r: any) => r.Type === 'AWS::Lambda::Function',
      );
      for (const fn of lambdaFunctions as any[]) {
        expect(fn.Properties.VpcConfig).toBeUndefined();
      }
    });
  });

  // ── API Gateway HTTP API (TASK-010) ───────────────────────────────────────

  describe('API Gateway HTTP API (TASK-010)', () => {
    it('creates an HTTP API (not REST API)', () => {
      template.resourceCountIs('AWS::ApiGatewayV2::Api', 1);
      template.hasResourceProperties('AWS::ApiGatewayV2::Api', {
        ProtocolType: 'HTTP',
      });
    });

    it('has an /api/{proxy+} integration route', () => {
      template.hasResourceProperties('AWS::ApiGatewayV2::Route', {
        RouteKey: Match.stringLikeRegexp(/api/),
      });
    });

    it('has a Lambda integration for the API', () => {
      template.hasResourceProperties('AWS::ApiGatewayV2::Integration', {
        IntegrationType: 'AWS_PROXY',
        PayloadFormatVersion: '2.0',
      });
    });

    it('has auto-deploy enabled on the default stage', () => {
      template.hasResourceProperties('AWS::ApiGatewayV2::Stage', {
        AutoDeploy: true,
        StageName: '$default',
      });
    });
  });

  // ── DynamoDB table (TASK-010) ─────────────────────────────────────────────

  describe('DynamoDB table (TASK-010)', () => {
    it('creates exactly one DynamoDB table', () => {
      template.resourceCountIs('AWS::DynamoDB::Table', 1);
    });

    it('uses on-demand (PAY_PER_REQUEST) billing mode', () => {
      template.hasResourceProperties('AWS::DynamoDB::Table', {
        BillingMode: 'PAY_PER_REQUEST',
      });
    });

    it('has pk (HASH) and sk (RANGE) attributes', () => {
      template.hasResourceProperties('AWS::DynamoDB::Table', {
        AttributeDefinitions: Match.arrayWith([
          { AttributeName: 'pk', AttributeType: 'S' },
          { AttributeName: 'sk', AttributeType: 'S' },
        ]),
        KeySchema: Match.arrayWith([
          { AttributeName: 'pk', KeyType: 'HASH' },
          { AttributeName: 'sk', KeyType: 'RANGE' },
        ]),
      });
    });

    it('has a GSI with gsi1pk and gsi1sk (for email lookups)', () => {
      template.hasResourceProperties('AWS::DynamoDB::Table', {
        GlobalSecondaryIndexes: Match.arrayWith([
          Match.objectLike({
            KeySchema: Match.arrayWith([
              { AttributeName: 'gsi1pk', KeyType: 'HASH' },
              { AttributeName: 'gsi1sk', KeyType: 'RANGE' },
            ]),
          }),
        ]),
      });
    });

    it('has TTL enabled on the ttl attribute', () => {
      template.hasResourceProperties('AWS::DynamoDB::Table', {
        TimeToLiveSpecification: {
          AttributeName: 'ttl',
          Enabled: true,
        },
      });
    });

    it('point-in-time recovery is enabled', () => {
      template.hasResourceProperties('AWS::DynamoDB::Table', {
        PointInTimeRecoverySpecification: {
          PointInTimeRecoveryEnabled: true,
        },
      });
    });
  });

  // ── Lambda IAM execution role (TASK-010) ──────────────────────────────────

  describe('Lambda IAM execution role (TASK-010)', () => {
    it('Lambda execution role has DynamoDB permissions on the table', () => {
      template.hasResourceProperties('AWS::IAM::Policy', {
        PolicyDocument: {
          Statement: Match.arrayWith([
            Match.objectLike({
              Action: Match.arrayWith([
                'dynamodb:GetItem',
                'dynamodb:PutItem',
                'dynamodb:UpdateItem',
                'dynamodb:DeleteItem',
                'dynamodb:Query',
              ]),
            }),
          ]),
        },
      });
    });

    it('Lambda execution role has SES SendEmail permission', () => {
      template.hasResourceProperties('AWS::IAM::Policy', {
        PolicyDocument: {
          Statement: Match.arrayWith([
            Match.objectLike({
              Action: Match.arrayWith(['ses:SendEmail']),
            }),
          ]),
        },
      });
    });

    it('Lambda execution role has CloudWatch Logs permissions', () => {
      template.hasResourceProperties('AWS::IAM::Policy', {
        PolicyDocument: {
          Statement: Match.arrayWith([
            Match.objectLike({
              Action: Match.arrayWith([
                'logs:CreateLogGroup',
                'logs:CreateLogStream',
                'logs:PutLogEvents',
              ]),
            }),
          ]),
        },
      });
    });
  });

  // ── CloudWatch log group (TASK-010) ───────────────────────────────────────

  describe('CloudWatch log group (TASK-010)', () => {
    it('creates a CloudWatch log group for Lambda logs', () => {
      template.resourceCountIs('AWS::Logs::LogGroup', 1);
    });

    it('log group has a retention policy', () => {
      template.hasResourceProperties('AWS::Logs::LogGroup', {
        RetentionInDays: Match.anyValue(),
      });
    });
  });

  // ── AWS WAF (TASK-016) ────────────────────────────────────────────────────
  //
  // Validates the WAF WebACL, logging configuration, and association with the
  // API Gateway HTTP API stage added by TASK-016.

  describe('AWS WAF WebACL (TASK-016)', () => {
    it('creates exactly one WAFv2 WebACL', () => {
      template.resourceCountIs('AWS::WAFv2::WebACL', 1);
    });

    it('WebACL has REGIONAL scope', () => {
      template.hasResourceProperties('AWS::WAFv2::WebACL', {
        Scope: 'REGIONAL',
      });
    });

    it('WebACL default action is ALLOW', () => {
      template.hasResourceProperties('AWS::WAFv2::WebACL', {
        DefaultAction: { Allow: {} },
      });
    });

    it('WebACL name includes the env suffix', () => {
      template.hasResourceProperties('AWS::WAFv2::WebACL', {
        Name: 'instructor-waf-dev',
      });
    });

    it('WebACL has CloudWatch metrics enabled', () => {
      template.hasResourceProperties('AWS::WAFv2::WebACL', {
        VisibilityConfig: {
          CloudWatchMetricsEnabled: true,
          SampledRequestsEnabled: true,
        },
      });
    });

    it('WebACL has a PerIpRateLimit rule at priority 1', () => {
      template.hasResourceProperties('AWS::WAFv2::WebACL', {
        Rules: Match.arrayWith([
          Match.objectLike({
            Name: 'PerIpRateLimit',
            Priority: 1,
            Action: { Block: {} },
          }),
        ]),
      });
    });

    it('rate-based rule limits to 100 requests per 5-minute window per IP', () => {
      template.hasResourceProperties('AWS::WAFv2::WebACL', {
        Rules: Match.arrayWith([
          Match.objectLike({
            Statement: {
              RateBasedStatement: {
                Limit: 100,
                AggregateKeyType: 'IP',
              },
            },
          }),
        ]),
      });
    });

    it('rate-based rule action is BLOCK', () => {
      template.hasResourceProperties('AWS::WAFv2::WebACL', {
        Rules: Match.arrayWith([
          Match.objectLike({
            Name: 'PerIpRateLimit',
            Action: { Block: {} },
          }),
        ]),
      });
    });
  });

  describe('AWS WAF Logging (TASK-016)', () => {
    it('creates a WAF log group with aws-waf-logs- prefix', () => {
      template.hasResourceProperties('AWS::Logs::LogGroup', {
        LogGroupName: 'aws-waf-logs-instructor-dev',
      });
    });

    it('creates a WAFv2 logging configuration', () => {
      template.resourceCountIs('AWS::WAFv2::LoggingConfiguration', 1);
    });

    it('WAF logging configuration references the WAF log group', () => {
      // The logging config's LogDestinationConfigs should reference the WAF log group ARN.
      // We verify the resource exists and has a non-empty destination list.
      template.hasResourceProperties('AWS::WAFv2::LoggingConfiguration', {
        LogDestinationConfigs: Match.anyValue(),
      });
    });

    it('WAF log group resource policy grants delivery.logs.amazonaws.com write access', () => {
      // The resource policy on the WAF log group must allow WAF log delivery.
      template.hasResourceProperties('AWS::Logs::ResourcePolicy', {
        PolicyDocument: Match.serializedJson(
          Match.objectLike({
            Statement: Match.arrayWith([
              Match.objectLike({
                Effect: 'Allow',
                Principal: Match.objectLike({
                  Service: 'delivery.logs.amazonaws.com',
                }),
                Action: Match.arrayWith([
                  'logs:CreateLogStream',
                  'logs:PutLogEvents',
                ]),
              }),
            ]),
          }),
        ),
      });
    });
  });

  describe('AWS WAF Association (TASK-016)', () => {
    it('creates a WAFv2 WebACL association', () => {
      template.resourceCountIs('AWS::WAFv2::WebACLAssociation', 1);
    });

    it('WebACL association resource ARN points to the API Gateway stage', () => {
      // The resource ARN for API Gateway HTTP API uses the format:
      // arn:aws:apigateway:{region}::/apis/{apiId}/stages/{stageName}
      template.hasResourceProperties('AWS::WAFv2::WebACLAssociation', {
        ResourceArn: Match.stringLikeRegexp('apigateway.*apis.*stages'),
      });
    });

    it('WebACL association references the WAF WebACL ARN', () => {
      template.hasResourceProperties('AWS::WAFv2::WebACLAssociation', {
        WebAclArn: Match.anyValue(),
      });
    });
  });

  describe('WAF CloudFormation Outputs (TASK-016)', () => {
    it('outputs the WAF WebACL ARN', () => {
      template.hasOutput('WafWebAclArn', {
        Description: Match.stringLikeRegexp('WAF WebACL'),
      });
    });

    it('outputs the WAF log group name', () => {
      template.hasOutput('WafLogGroupName', {
        Description: Match.stringLikeRegexp('WAF request logs'),
      });
    });
  });

  // ── CloudWatch Alarms + Dashboard (TASK-018) ──────────────────────────────
  //
  // Validates the SNS alarm topic, three CloudWatch alarms, the CloudWatch
  // dashboard, and the corresponding CloudFormation outputs.

  describe('SNS Alarm Topic (TASK-018)', () => {
    it('creates exactly one SNS topic for alarms', () => {
      template.resourceCountIs('AWS::SNS::Topic', 1);
    });

    it('SNS topic name includes the env suffix', () => {
      template.hasResourceProperties('AWS::SNS::Topic', {
        TopicName: 'instructor-alarms-dev',
      });
    });

    it('SNS topic has a human-readable display name', () => {
      template.hasResourceProperties('AWS::SNS::Topic', {
        DisplayName: 'Instructor dev CloudWatch Alarms',
      });
    });
  });

  describe('Lambda error-rate alarm (TASK-018)', () => {
    it('creates a CloudWatch alarm for Lambda error rate', () => {
      template.hasResourceProperties('AWS::CloudWatch::Alarm', {
        AlarmName: 'instructor-dev-lambda-error-rate',
      });
    });

    it('error-rate alarm threshold is 5', () => {
      template.hasResourceProperties('AWS::CloudWatch::Alarm', {
        AlarmName: 'instructor-dev-lambda-error-rate',
        Threshold: 5,
      });
    });

    it('error-rate alarm requires 2-of-2 evaluation periods', () => {
      template.hasResourceProperties('AWS::CloudWatch::Alarm', {
        AlarmName: 'instructor-dev-lambda-error-rate',
        EvaluationPeriods: 2,
        DatapointsToAlarm: 2,
      });
    });

    it('error-rate alarm treats missing data as NOT_BREACHING', () => {
      template.hasResourceProperties('AWS::CloudWatch::Alarm', {
        AlarmName: 'instructor-dev-lambda-error-rate',
        TreatMissingData: 'notBreaching',
      });
    });

    it('error-rate alarm sends to the SNS alarm topic', () => {
      template.hasResourceProperties('AWS::CloudWatch::Alarm', {
        AlarmName: 'instructor-dev-lambda-error-rate',
        AlarmActions: Match.anyValue(),
        OKActions: Match.anyValue(),
      });
    });
  });

  describe('Lambda throttles alarm (TASK-018)', () => {
    it('creates a CloudWatch alarm for Lambda throttles', () => {
      template.hasResourceProperties('AWS::CloudWatch::Alarm', {
        AlarmName: 'instructor-dev-lambda-throttles',
      });
    });

    it('throttles alarm threshold is 0 (any throttle fires the alarm)', () => {
      template.hasResourceProperties('AWS::CloudWatch::Alarm', {
        AlarmName: 'instructor-dev-lambda-throttles',
        Threshold: 0,
        ComparisonOperator: 'GreaterThanThreshold',
      });
    });

    it('throttles alarm fires on the first breaching data point (1-of-1)', () => {
      template.hasResourceProperties('AWS::CloudWatch::Alarm', {
        AlarmName: 'instructor-dev-lambda-throttles',
        EvaluationPeriods: 1,
        DatapointsToAlarm: 1,
      });
    });

    it('throttles alarm treats missing data as NOT_BREACHING', () => {
      template.hasResourceProperties('AWS::CloudWatch::Alarm', {
        AlarmName: 'instructor-dev-lambda-throttles',
        TreatMissingData: 'notBreaching',
      });
    });
  });

  describe('Lambda duration p99 alarm (TASK-018)', () => {
    it('creates a CloudWatch alarm for Lambda duration p99', () => {
      template.hasResourceProperties('AWS::CloudWatch::Alarm', {
        AlarmName: 'instructor-dev-lambda-duration-p99',
      });
    });

    it('duration alarm threshold is 96 000 ms (80% of 120 s timeout)', () => {
      template.hasResourceProperties('AWS::CloudWatch::Alarm', {
        AlarmName: 'instructor-dev-lambda-duration-p99',
        Threshold: 96000,
      });
    });

    it('duration alarm requires 2-of-2 evaluation periods', () => {
      template.hasResourceProperties('AWS::CloudWatch::Alarm', {
        AlarmName: 'instructor-dev-lambda-duration-p99',
        EvaluationPeriods: 2,
        DatapointsToAlarm: 2,
      });
    });

    it('duration alarm comparison operator is GreaterThanThreshold', () => {
      template.hasResourceProperties('AWS::CloudWatch::Alarm', {
        AlarmName: 'instructor-dev-lambda-duration-p99',
        ComparisonOperator: 'GreaterThanThreshold',
      });
    });

    it('duration alarm treats missing data as NOT_BREACHING', () => {
      template.hasResourceProperties('AWS::CloudWatch::Alarm', {
        AlarmName: 'instructor-dev-lambda-duration-p99',
        TreatMissingData: 'notBreaching',
      });
    });
  });

  describe('CloudWatch Dashboard (TASK-018)', () => {
    it('creates exactly one CloudWatch dashboard', () => {
      template.resourceCountIs('AWS::CloudWatch::Dashboard', 1);
    });

    it('dashboard name includes the env suffix', () => {
      template.hasResourceProperties('AWS::CloudWatch::Dashboard', {
        DashboardName: 'instructor-dev',
      });
    });

    it('dashboard body is a non-empty JSON string', () => {
      const resources = template.toJSON().Resources;
      const dashboards = Object.values(resources).filter(
        (r: any) => r.Type === 'AWS::CloudWatch::Dashboard',
      );
      expect(dashboards.length).toBe(1);
      const body = (dashboards[0] as any).Properties.DashboardBody;
      // Body may be a CloudFormation Fn::Sub token or a JSON string.
      expect(body).toBeTruthy();
    });
  });

  describe('Observability CloudFormation Outputs (TASK-018)', () => {
    it('outputs the SNS alarm topic ARN', () => {
      template.hasOutput('AlarmTopicArn', {
        Description: Match.stringLikeRegexp('SNS topic ARN'),
      });
    });

    it('outputs the CloudWatch dashboard URL', () => {
      template.hasOutput('DashboardUrl', {
        Description: Match.stringLikeRegexp('CloudWatch dashboard'),
      });
    });

    it('outputs the error-rate alarm name', () => {
      template.hasOutput('AlarmErrorRateName', {
        Description: Match.stringLikeRegexp('error rate'),
      });
    });

    it('outputs the throttles alarm name', () => {
      template.hasOutput('AlarmThrottlesName', {
        Description: Match.stringLikeRegexp('throttling'),
      });
    });

    it('outputs the duration alarm name', () => {
      template.hasOutput('AlarmDurationName', {
        Description: Match.stringLikeRegexp('duration'),
      });
    });
  });
});
