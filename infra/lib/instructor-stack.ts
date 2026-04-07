import * as cdk from 'aws-cdk-lib';
import {
  aws_s3 as s3,
  aws_iam as iam,
  aws_secretsmanager as secretsmanager,
  CfnOutput,
  Duration,
  RemovalPolicy,
} from 'aws-cdk-lib';
import { Construct } from 'constructs';

// ── Stack props ────────────────────────────────────────────────────────────────

export interface InstructorStackProps extends cdk.StackProps {
  /** 'dev' | 'staging' | 'prod' — controls removal policy and lifecycle rules */
  readonly envName: string;
}

// ── Instructor S3 + IAM Stack ─────────────────────────────────────────────────
//
// Provisions:
//   1. S3 bucket  — stores TTS audio cache and per-user SQLite backups.
//   2. IAM user   — used by the NestJS backend to sign S3 requests and write
//                   the TTS L2 cache.  Access key is stored in Secrets Manager.
//   3. IAM policy — least-privilege: scoped to the two prefixes used by the app.
//
// Bucket layout:
//   tts/{sha256}.wav                — TTS audio L2 cache (Gemini + Kokoro)
//   backups/{userId}/instructor.db  — per-user SQLite database backup
//
// Security posture:
//   • Block all public access.
//   • HTTPS-only bucket policy (deny non-TLS requests).
//   • SSE-S3 encryption at rest (no KMS dependency for simplicity; upgrade to
//     SSE-KMS for PCI/HIPAA workloads).
//   • IAM user key stored in Secrets Manager — never in env vars directly.
//   • Lifecycle rule: expire TTS cache entries after 90 days (prod) / 30 days
//     (dev/staging) to control storage costs.
//   • Object versioning enabled only on the backups/ prefix workaround: CDK
//     cannot scope versioning per-prefix, so versioning is enabled globally with
//     a lifecycle rule that expires old non-current versions of tts/ objects
//     quickly to avoid cost blowup.
// ──────────────────────────────────────────────────────────────────────────────

export class InstructorStack extends cdk.Stack {
  /** The single bucket shared by TTS cache and user backups. */
  public readonly bucket: s3.Bucket;

  /** IAM user whose credentials the NestJS server uses. */
  public readonly serverUser: iam.User;

  constructor(scope: Construct, id: string, props: InstructorStackProps) {
    super(scope, id, props);

    const { envName } = props;
    const isProd = envName === 'prod';

    // ── 1. S3 Bucket ──────────────────────────────────────────────────────────

    // Bucket name follows the convention already used in the project.
    // Suffix with env for multi-env deployments.
    const bucketName = isProd ? 'instructor-cache' : `instructor-cache-${envName}`;

    this.bucket = new s3.Bucket(this, 'InstructorBucket', {
      bucketName,
      // Block every form of public access.
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      // SSE-S3 managed encryption at rest.
      encryption: s3.BucketEncryption.S3_MANAGED,
      // Enforce HTTPS-only access (enforced by bucket policy below).
      enforceSSL: true,
      // Enable versioning so SQLite backups have a recovery window.
      versioned: true,
      // Keep bucket on stack destroy in prod; destroy in dev for cost hygiene.
      removalPolicy: isProd ? RemovalPolicy.RETAIN : RemovalPolicy.DESTROY,
      autoDeleteObjects: !isProd,

      // ── Lifecycle rules ────────────────────────────────────────────────────
      lifecycleRules: [
        // Rule 1: Expire TTS cache objects after N days (current version).
        //   tts/  prefix — these are re-generatable audio files.
        {
          id: 'tts-cache-expiry',
          prefix: 'tts/',
          enabled: true,
          expiration: Duration.days(isProd ? 90 : 30),
          // Also clean up previous versions quickly — TTS files don't need history.
          noncurrentVersionExpiration: Duration.days(1),
          // Clean up incomplete multipart uploads (shouldn't happen for small
          // WAV files, but good housekeeping).
          abortIncompleteMultipartUploadAfter: Duration.days(1),
        },
        // Rule 2: Retain only the latest 5 backup versions per user prefix.
        //   backups/  prefix — keep non-current versions for 30 days for safety.
        {
          id: 'backups-version-retention',
          prefix: 'backups/',
          enabled: true,
          noncurrentVersionExpiration: Duration.days(30),
          // CDK NoncurrentVersionsToRetain: keep the last 5 backup snapshots
          // (protects against accidental overwrites while bounding storage cost).
          noncurrentVersionsToRetain: 5,
        },
      ],

      // ── CORS ──────────────────────────────────────────────────────────────
      // Flutter client uploads/downloads directly to S3 using pre-signed URLs.
      // CORS must allow PUT (upload) and GET (download) from any origin because:
      //   • The Flutter mobile app has no origin (no browser context).
      //   • The Flutter web build may be served from varying origins.
      // Pre-signed URL expiry (5 minutes) is the real security boundary here.
      cors: [
        {
          id: 'flutter-presigned-uploads',
          allowedMethods: [
            s3.HttpMethods.PUT,
            s3.HttpMethods.GET,
            s3.HttpMethods.HEAD,
          ],
          // Wildcard is acceptable: pre-signed URLs are time-limited, HMAC-signed,
          // and scoped to a specific S3 object key.
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

    // ── 2. IAM User (NestJS backend) ──────────────────────────────────────────
    // A dedicated IAM user (not root credentials) for the NestJS backend.
    // In production workloads running on EC2/ECS/Lambda, prefer an IAM role
    // over a user — but the project deploys via Docker on arbitrary hosts,
    // so an IAM user with a stored access key is the right choice here.

    this.serverUser = new iam.User(this, 'InstructorServerUser', {
      userName: `instructor-server-${envName}`,
    });

    // ── 3. Least-privilege S3 Policy ─────────────────────────────────────────

    // 3a. TTS cache (L2) — NestJS reads/writes audio files it generated.
    const ttsPolicy = new iam.Policy(this, 'TtsCachePolicy', {
      statements: [
        new iam.PolicyStatement({
          sid: 'TtsCacheReadWrite',
          effect: iam.Effect.ALLOW,
          actions: [
            's3:GetObject',
            's3:PutObject',
            // HeadObject is used to check if a key exists (cache miss detection).
            's3:GetObjectAttributes',
          ],
          resources: [this.bucket.arnForObjects('tts/*')],
        }),
      ],
    });

    // 3b. User backups — NestJS generates pre-signed PUT (upload) and GET
    //     (download) URLs.  The actual file transfer happens client-to-S3.
    //     HeadObject is used to check backup size for the /sync/status endpoint.
    const syncPolicy = new iam.Policy(this, 'SyncBackupPolicy', {
      statements: [
        new iam.PolicyStatement({
          sid: 'SyncBackupPresignedUrls',
          effect: iam.Effect.ALLOW,
          actions: [
            's3:GetObject',
            's3:PutObject',
            's3:GetObjectAttributes',
            // Allow server to generate presigned PUT and GET URLs for any
            // user's backup path: backups/{userId}/instructor.db
            's3:ListBucket',
          ],
          resources: [
            this.bucket.arnForObjects('backups/*'),
            // ListBucket requires the bucket ARN (not object ARN).
            this.bucket.bucketArn,
          ],
          conditions: {
            // Restrict ListBucket to the backups/ prefix to prevent enumeration
            // of TTS keys.
            StringLike: {
              's3:prefix': ['backups/*'],
            },
          },
        }),
      ],
    });

    this.serverUser.attachInlinePolicy(ttsPolicy);
    this.serverUser.attachInlinePolicy(syncPolicy);

    // ── 4. Access Key → Secrets Manager ──────────────────────────────────────
    // Generate an access key and store it in Secrets Manager.
    // The NestJS server should read credentials from Secrets Manager at startup
    // (or inject via env in docker-compose for local dev).
    // NEVER embed the key in environment variables in VCS.

    const accessKey = new iam.CfnAccessKey(this, 'ServerAccessKey', {
      userName: this.serverUser.userName,
    });

    // Store both key ID and secret in a single Secrets Manager secret.
    const credentialsSecret = new secretsmanager.Secret(
      this,
      'ServerCredentialsSecret',
      {
        secretName: `instructor/${envName}/server-aws-credentials`,
        description:
          'AWS access key for the Instructor NestJS server (S3 TTS cache + sync)',
        secretStringValue: cdk.SecretValue.unsafePlainText(
          JSON.stringify({
            AWS_ACCESS_KEY_ID: accessKey.ref,
            // CloudFormation resolves this at deploy time.
            AWS_SECRET_ACCESS_KEY: accessKey.attrSecretAccessKey,
          }),
        ),
        removalPolicy: isProd ? RemovalPolicy.RETAIN : RemovalPolicy.DESTROY,
      },
    );

    // ── 5. CloudFormation Outputs ─────────────────────────────────────────────
    // These values are used to populate server/.env (local dev) or to wire up
    // the Docker Compose / ECS task environment variables.

    new CfnOutput(this, 'BucketName', {
      value: this.bucket.bucketName,
      description: 'S3 bucket name → AWS_S3_BUCKET env var',
      exportName: `InstructorBucketName-${envName}`,
    });

    new CfnOutput(this, 'BucketRegion', {
      value: this.region,
      description: 'AWS region → AWS_REGION env var',
      exportName: `InstructorBucketRegion-${envName}`,
    });

    new CfnOutput(this, 'ServerUserName', {
      value: this.serverUser.userName,
      description: 'IAM user name for the NestJS backend',
    });

    new CfnOutput(this, 'CredentialsSecretArn', {
      value: credentialsSecret.secretArn,
      description:
        'Secrets Manager ARN containing AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY',
      exportName: `InstructorCredentialsSecretArn-${envName}`,
    });

    new CfnOutput(this, 'AccessKeyId', {
      value: accessKey.ref,
      description: 'AWS_ACCESS_KEY_ID for the NestJS server (also in Secrets Manager)',
    });

    // Note: SecretAccessKey is intentionally NOT output to CloudFormation console.
    // Retrieve via: aws secretsmanager get-secret-value --secret-id instructor/<env>/server-aws-credentials
  }
}
