# Instructor — AWS Infrastructure

AWS CDK TypeScript stack that provisions the S3 bucket and IAM resources required by the Instructor backend.

## What it provisions

| Resource | Purpose |
|---|---|
| **S3 Bucket** `instructor-cache` | TTS audio L2 cache (`tts/`) and per-user SQLite backups (`backups/`) |
| **IAM User** `instructor-server-<env>` | NestJS backend identity for S3 operations |
| **IAM Policy** (inline) | Least-privilege: `s3:GetObject`, `s3:PutObject` on `tts/*` and `backups/*` |
| **Secrets Manager Secret** `instructor/<env>/server-aws-credentials` | Stores `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` |

## S3 Bucket Layout

```
instructor-cache/
  tts/
    {sha256-hash}.wav          ← TTS audio L2 cache (Gemini + Kokoro)
  backups/
    {userId}/
      instructor.db            ← Per-user SQLite database backup
```

### Security configuration

- **Block all public access** — no objects are publicly readable
- **HTTPS-only** — bucket policy denies all HTTP requests (`aws:SecureTransport`)
- **SSE-S3 encryption at rest** — server-side encryption with managed keys
- **CORS for pre-signed URL uploads** — Flutter client uploads directly to S3 (no proxy through NestJS)
- **Versioning** — enabled globally; tts/ objects keep 1 version (old versions expire in 1 day); backups/ keeps 5 non-current versions for 30 days

### Lifecycle rules

| Prefix | Rule | Retention |
|---|---|---|
| `tts/` | Expire current version | 90 days (prod) / 30 days (dev) |
| `tts/` | Expire non-current versions | 1 day |
| `backups/` | Retain non-current versions | 30 days, max 5 versions |

## Prerequisites

1. [AWS CLI](https://aws.amazon.com/cli/) configured with admin credentials
2. [Node.js 22+](https://nodejs.org/)
3. CDK bootstrapped in your target account/region (one-time setup):

```bash
npx aws-cdk bootstrap aws://ACCOUNT_ID/ap-south-1
```

## Deploy

```bash
cd infra
npm install

# Preview changes
npm run diff -- --context env=prod

# Deploy to production
npm run deploy -- --context env=prod

# Deploy to dev (bucket suffix: instructor-cache-dev)
npm run deploy -- --context env=dev
```

After deployment, CloudFormation outputs the bucket name, region, IAM user name, and the Secrets Manager ARN.

## Retrieve credentials after deploy

```bash
aws secretsmanager get-secret-value \
  --secret-id instructor/prod/server-aws-credentials \
  --region ap-south-1 \
  --query SecretString \
  --output text
```

This returns JSON:
```json
{
  "AWS_ACCESS_KEY_ID": "AKIA...",
  "AWS_SECRET_ACCESS_KEY": "..."
}
```

Copy these values into `server/.env`:
```
AWS_S3_BUCKET=instructor-cache
AWS_REGION=ap-south-1
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
```

**Never commit `.env` to git.** The `.gitignore` in `server/` already excludes it.

## Production deployment (EC2/ECS)

If running the NestJS server on AWS infrastructure, attach an **IAM role** to the compute resource instead of using a static IAM user key:

1. Create an IAM role for your EC2/ECS task
2. Attach the same policies from `InstructorStack` (`TtsCachePolicy`, `SyncBackupPolicy`)
3. Remove `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from the environment — the AWS SDK will automatically use the instance metadata service (IMDS)

## Cost estimate

At small scale (< 1000 users, < 10k TTS requests/day):

| Resource | Monthly cost (ap-south-1) |
|---|---|
| S3 Standard storage (10 GB) | ~$0.25 |
| S3 PUT requests (10k/day) | ~$1.50 |
| S3 GET requests (50k/day) | ~$0.25 |
| Data transfer out (5 GB) | ~$0.60 |
| Secrets Manager (1 secret) | ~$0.40 |
| **Total** | **~$3/month** |

At 10k users the S3 costs scale linearly. Consider S3 Intelligent-Tiering for backups if the user base grows significantly.

## Tear down

```bash
# Dev only — prod bucket has RETAIN policy
npm run destroy -- --context env=dev
```
