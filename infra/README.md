# Instructor — AWS Infrastructure

AWS CDK TypeScript stack that provisions all backend infrastructure for the Instructor app.

## What it provisions

### Existing resources (unchanged)

| Resource | Purpose |
|---|---|
| **S3 Bucket** `instructor-cache[-<env>]` | TTS audio L2 cache (`tts/`) and per-user SQLite backups (`backups/`) |
| **IAM User** `instructor-server-<env>` | NestJS backend identity for S3 operations (Docker / local dev) |
| **IAM Policies** (inline) | Least-privilege `s3:GetObject`/`PutObject` on `tts/*` and `backups/*` |
| **Secrets Manager** `instructor/<env>/server-aws-credentials` | `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` for Docker deployments |

### New Lambda resources

| Resource | Purpose |
|---|---|
| **DynamoDB Table** `instructor-<env>` | Single-table design — users, OTPs, refresh tokens, sync metadata, rate-limit counters |
| **Secrets Manager** `instructor/<env>/app-secrets` | JWT secrets, API keys, Gemini API key — read by Lambda via Parameters & Secrets Extension |
| **CloudWatch Log Group** `/aws/lambda/instructor-<env>` | Explicit log group with retention (1 week dev / 3 months prod) |
| **IAM Role** `instructor-lambda-<env>` | Least-privilege execution role for the Lambda function |
| **Lambda Layer** `AWS-Parameters-and-Secrets-Lambda-Extension` | Caches Secrets Manager values in-process; zero latency on warm calls |
| **Lambda Function** `instructor-<env>` | NestJS app via `@codegenie/serverless-express`; 1024 MB / 120 s / Node 22 / no VPC |
| **API Gateway HTTP API v2** | `ANY /api/{proxy+}` → Lambda; HTTP API (not REST) for lower cost and latency |
| **SES Email Identity** | Verified sender address for OTP emails |

## S3 Bucket Layout

```
instructor-cache/
  tts/
    {sha256-hash}.wav          ← TTS audio L2 cache (Gemini + Kokoro)
  backups/
    {userId}/
      instructor.db            ← Per-user SQLite database backup
```

## DynamoDB Key Schema (single-table)

| Entity | pk | sk | gsi1pk | gsi1sk | ttl |
|---|---|---|---|---|---|
| User | `USER#<id>` | `PROFILE` | `<email>` | `USER` | — |
| OTP | `OTP#<email>` | `<timestamp>#<id>` | — | — | ✓ |
| Refresh Token | `TOKEN#<hash>` | `TOKEN` | `USER#<userId>` | `TOKEN` | ✓ |
| Sync Metadata | `USER#<userId>` | `SYNC` | — | — | — |
| Rate Limit | `RATELIMIT#<ns>#<key>` | `COUNTER` | — | — | ✓ |

- **GSI name**: `gsi1` (partition: `gsi1pk`, sort: `gsi1sk`, projection: ALL)
- **TTL**: enabled on the `ttl` attribute (Unix epoch seconds); best-effort, up to 48h lag

## Prerequisites

1. [AWS CLI](https://aws.amazon.com/cli/) configured with admin credentials
2. [Node.js 22+](https://nodejs.org/)
3. CDK bootstrapped in your target account/region (one-time setup):

```bash
npx aws-cdk bootstrap aws://ACCOUNT_ID/ap-south-1
```

## Deploy

### Step 1 — Install dependencies

```bash
cd infra
npm install
```

### Step 2 — Populate app secrets (first deploy only)

The CDK stack creates `instructor/<env>/app-secrets` with placeholder values.
**Replace them before deploying the Lambda:**

```bash
aws secretsmanager put-secret-value \
  --secret-id instructor/dev/app-secrets \
  --region ap-south-1 \
  --secret-string '{
    "JWT_SECRET": "<openssl rand -hex 32>",
    "JWT_REFRESH_SECRET": "<openssl rand -hex 32>",
    "API_KEY": "<openssl rand -hex 32>",
    "OTP_SALT": "<openssl rand -hex 32>",
    "GEMINI_API_KEY": "<from https://aistudio.google.com/app/apikey>",
    "KOKORO_SERVER_URL": ""
  }'
```

### Step 3 — Verify SES sender email

The CDK stack creates an SES email identity. AWS sends a verification email.
Click the link in that email before OTP sending will work.

For production (domain identity), add the DKIM DNS records shown in the SES console.
Also [request SES production access](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html) to send to non-verified addresses.

### Step 4 — Deploy

```bash
# Preview changes (no AWS writes)
npm run diff -- --context env=dev

# Deploy to dev
npm run deploy:dev

# Deploy to prod with custom SES email
npm run deploy:prod -- --context sesFromEmail=noreply@instructor.app
```

After deployment, CloudFormation outputs include:
- `ApiUrl` — set as `BACKEND_URL` in the Flutter app
- `DynamoTableName` — `instructor-<env>`
- `LambdaFunctionName` — for `aws lambda invoke` and CloudWatch
- `AppSecretsArn` — Secrets Manager ARN for app secrets
- `LogGroupName` — CloudWatch log group path

## How the Lambda reads secrets

The [AWS Parameters and Secrets Lambda Extension](https://docs.aws.amazon.com/secretsmanager/latest/userguide/retrieving-secrets_lambda.html) is attached as a layer. It caches secrets locally and exposes them at `http://localhost:2773`. The NestJS application calls this endpoint at startup:

```typescript
const response = await fetch(
  `http://localhost:2773/secretsmanager/get?secretId=${process.env.APP_SECRETS_ID}`,
  { headers: { 'X-Aws-Parameters-Secrets-Token': process.env.AWS_SESSION_TOKEN! } }
);
const secrets = await response.json();
```

Warm invocations pay **zero latency** — the extension holds the secret in memory.

## Cost estimate

At small scale (~1,000 DAU, ~10k TTS requests/day):

| Resource | Monthly cost (ap-south-1) |
|---|---|
| S3 Standard (10 GB) | ~$0.25 |
| S3 PUT/GET requests | ~$1.75 |
| Data transfer out (5 GB) | ~$0.60 |
| DynamoDB (on-demand, ~50k writes/day) | ~$0.15 |
| DynamoDB (on-demand, ~200k reads/day) | ~$0.06 |
| Lambda (1024 MB, ~200k req/month @ 500ms avg) | ~$0.80 |
| API Gateway HTTP API (200k req/month) | ~$0.20 |
| Secrets Manager (2 secrets) | ~$0.80 |
| CloudWatch Logs (1 GB/month) | ~$0.55 |
| SES (1k emails/month) | ~$0.10 |
| **Total** | **~$5.25/month** |

**NAT Gateway savings**: No VPC → no NAT Gateway → saves **~$32/month** vs VPC-based architecture.

## IAM Role Permissions (Lambda execution role)

| Service | Actions | Scope |
|---|---|---|
| CloudWatch Logs | `CreateLogStream`, `PutLogEvents` | `/aws/lambda/instructor-<env>` log group only |
| DynamoDB | `GetItem`, `PutItem`, `UpdateItem`, `DeleteItem`, `Query` | `instructor-<env>` table + `gsi1` index |
| S3 | `GetObject`, `PutObject`, `GetObjectAttributes` | `tts/*` prefix only |
| S3 | `GetObject`, `PutObject`, `GetObjectAttributes`, `ListBucket` | `backups/*` prefix (ListBucket scoped by condition) |
| SES | `SendEmail`, `SendRawEmail` | Sender identity ARN only |
| Secrets Manager | `GetSecretValue` | `instructor/<env>/app-secrets` ARN only |

No wildcard resources. No wildcard actions.

## Retrieve Docker/local dev credentials

```bash
aws secretsmanager get-secret-value \
  --secret-id instructor/dev/server-aws-credentials \
  --region ap-south-1 \
  --query SecretString \
  --output text
```

Copy into `server/.env`:
```
AWS_S3_BUCKET=instructor-cache-dev
AWS_REGION=ap-south-1
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
```

**Never commit `.env` to git.**

## Tear down

```bash
# Dev only — prod resources have RETAIN policy
npm run destroy -- --context env=dev
```
