# Instructor Server — Setup & Deployment Guide

This document covers everything needed to go from a fresh AWS account to a running
production deployment of the Instructor NestJS backend on AWS Lambda.

**Stack overview:**
| Layer | Service | Free-tier limit |
|---|---|---|
| Database | [Neon PostgreSQL](https://neon.tech) | 0.5 GB storage, 191.9 compute-hours/month |
| Cache / Rate-limit | [Upstash Redis](https://upstash.com) | 10 000 commands/day (serverless, per-request billing) |
| Compute | AWS Lambda (Node.js 22) | 1M requests / 400 000 GB-s per month |
| API layer | AWS API Gateway HTTP API v2 | 1M requests/month |
| Email | AWS SES | 62 000 outbound emails/month (from Lambda) |
| Storage | AWS S3 | 5 GB / 20 000 GET / 2 000 PUT |
| Secrets | AWS Secrets Manager | First 30 days free; < $0.50/month thereafter |

---

## Prerequisites

- **Node.js ≥ 18** and **npm** installed locally
- **AWS CLI v2** installed and configured:
  ```bash
  aws configure
  # AWS Access Key ID: <your key>
  # AWS Secret Access Key: <your secret>
  # Default region name: ap-south-1   (or your preferred region)
  # Default output format: json
  ```
- **AWS CDK v2** (installed automatically via `npx cdk` — no global install required)

---

## Step 1 — Create a Neon PostgreSQL Project

1. Sign up / log in at <https://console.neon.tech>.
2. Click **New Project**.
3. Choose a region close to your Lambda region (e.g. **AWS / ap-south-1** for Mumbai).
4. Name the project `instructor-prod`.
5. After creation, open the project → **Connection Details** tab.
6. Select **Pooled connection** (uses PgBouncer; required for Lambda):
   ```
   postgresql://neondb_owner:<password>@<pooler-host>.neon.tech/neondb?sslmode=require
   ```
   Copy and save this as **`DATABASE_URL`**.
7. Also copy the **Direct connection** string (needed for Drizzle migrations):
   ```
   postgresql://neondb_owner:<password>@<direct-host>.neon.tech/neondb?sslmode=require
   ```
   Save this as **`DATABASE_DIRECT_URL`** for local migration runs only
   (it is NOT stored in Secrets Manager).

### Run Drizzle Migrations (first time and after schema changes)

```bash
cd server
# Use the direct connection string — pooler does not support DDL reliably
DATABASE_URL="postgresql://neondb_owner:..." npm run db:migrate
```

> The `db:migrate` script is defined in `server/package.json` and runs
> `drizzle-kit migrate` against the direct connection.

---

## Step 2 — Create an Upstash Redis Database

1. Sign up / log in at <https://console.upstash.com>.
2. Click **Create Database**.
3. Select type: **Redis**.
4. Name: `instructor-prod`.
5. Region: pick the same AWS region as your Lambda (e.g. `ap-south-1`).
6. **Enable REST API** (this is the default for Upstash serverless Redis — no TCP needed).
7. After creation, open the database → **Details** tab:
   - Copy **REST URL** → save as **`UPSTASH_REDIS_REST_URL`**
     (format: `https://<db-name>.upstash.io`)
   - Copy **REST Token** → save as **`UPSTASH_REDIS_REST_TOKEN`**
     (a long Base64 string starting with `AX...`)

> Upstash Redis is used for fixed-window rate limiting on authentication endpoints.
> The free tier allows 10 000 commands/day, which is sufficient for ~1 000 DAU.

---

## Step 3 — Configure SES Domain Verification (DNS Records)

AWS SES must verify that you own the **layersiq.com** domain before it will send email
from `instructor.app@layersiq.com`.

### 3a. Deploy the CDK stack (first pass — generates DNS token outputs)

Run the CDK deploy **once** to create the SES identity and get the verification tokens:

```bash
./deploy.sh
```

After the deploy completes, note the CloudFormation outputs in your terminal.
You can also view them in the AWS Console:

```
CloudFormation → InstructorStack-prod → Outputs tab
```

### 3b. Add DNS records to layersiq.com

You need to add **four DNS records** to your domain registrar or DNS provider
(e.g. Route 53, Cloudflare, Namecheap).

#### TXT Record — Domain Ownership Verification

| Type | Name / Host | Value |
|------|-------------|-------|
| TXT | `_amazonses.layersiq.com` | `<token from SES console>` |

To find this token:
1. AWS Console → **SES** → **Verified Identities** → `layersiq.com`
2. **Domain verification** section → copy the TXT record value.

#### CNAME Records — DKIM Signing (3 records)

DKIM lets receiving servers verify that emails were signed by AWS SES.
SES generates three CNAME records; all three must be added.

| Type | Name / Host | Value |
|------|-------------|-------|
| CNAME | `<token1>._domainkey.layersiq.com` | `<token1>.dkim.amazonses.com` |
| CNAME | `<token2>._domainkey.layersiq.com` | `<token2>.dkim.amazonses.com` |
| CNAME | `<token3>._domainkey.layersiq.com` | `<token3>.dkim.amazonses.com` |

To find these tokens:
1. AWS Console → **SES** → **Verified Identities** → `layersiq.com`
2. **DKIM configuration** section → **DKIM signing** → copy the 3 CNAME records.

> **Note:** DNS propagation typically takes 5–30 minutes but can take up to 72 hours.
> SES will automatically detect the records and change the identity status to **Verified**.

### 3c. Verify DNS propagation

```bash
# Check TXT record
dig TXT _amazonses.layersiq.com +short

# Check one of the DKIM CNAME records
dig CNAME <token1>._domainkey.layersiq.com +short
```

---

## Step 4 — Request SES Production Access

New AWS accounts are in the **SES Sandbox** by default.
The sandbox only allows sending to manually verified email addresses.
You must request production access to send to arbitrary users.

**Estimated approval time: 24–48 hours.**

1. AWS Console → **SES** → **Account dashboard** → **Request production access**.
2. Fill in the form:
   - **Mail type:** Transactional
   - **Website URL:** your app's URL
   - **Use case:** OTP one-time-password authentication emails for the Instructor app
   - **Additional contacts:** your email for AWS support correspondence
3. Submit. AWS will reply by email once approved.

While waiting for approval, you can test by adding verified email addresses in
**SES → Verified Identities → Add email address**.

---

## Step 5 — Populate Secrets Manager

Before the Lambda function can start, all `REPLACE_ME` values in the app secrets
must be replaced with real values.

### Generate cryptographic secrets

```bash
# Generate JWT_SECRET (256-bit hex)
openssl rand -hex 32

# Generate JWT_REFRESH_SECRET (256-bit hex)
openssl rand -hex 32

# Generate API_KEY (256-bit hex)
openssl rand -hex 32

# Generate OTP_SALT (256-bit hex)
openssl rand -hex 32
```

### Get Gemini API key

1. Visit <https://aistudio.google.com/app/apikey>
2. Create an API key for the `instructor-prod` project.

### Update the secret

```bash
aws secretsmanager put-secret-value \
  --secret-id instructor/prod/app-secrets \
  --secret-string '{
    "JWT_SECRET":                "<openssl rand -hex 32 output>",
    "JWT_REFRESH_SECRET":        "<openssl rand -hex 32 output>",
    "API_KEY":                   "<openssl rand -hex 32 output>",
    "OTP_SALT":                  "<openssl rand -hex 32 output>",
    "GEMINI_API_KEY":            "<from aistudio.google.com>",
    "KOKORO_SERVER_URL":         "<Modal deployment URL or empty string>",
    "DATABASE_URL":              "<Neon pooled connection string from Step 1>",
    "UPSTASH_REDIS_REST_URL":    "<Upstash REST URL from Step 2>",
    "UPSTASH_REDIS_REST_TOKEN":  "<Upstash REST token from Step 2>"
  }'
```

> **Important:** Use the **pooled** Neon connection string for `DATABASE_URL`
> (not the direct connection string). Lambda uses @neondatabase/serverless which
> works over HTTP, and the pooler handles connection limits.

Verify the secret was updated:

```bash
aws secretsmanager get-secret-value \
  --secret-id instructor/prod/app-secrets \
  --query SecretString \
  --output text | jq .
```

---

## Step 6 — Bootstrap CDK (First Time Only)

If this is the first CDK deployment in this AWS account/region:

```bash
cd infra
npx cdk bootstrap aws://<ACCOUNT_ID>/<REGION>
# Example: npx cdk bootstrap aws://123456789012/ap-south-1
```

This creates the CDK staging bucket and IAM roles needed for deployment.
Only needs to be done once per account/region combination.

---

## Step 7 — Deploy

```bash
# From the project root:
./deploy.sh
```

Alternatively, using the npm script:

```bash
cd infra
npm run deploy:prod
```

Both commands run:
```
cdk deploy --all \
  --context env=prod \
  --context sesFromEmail=instructor.app@layersiq.com \
  --require-approval broadening
```

### After deploy — note the outputs

| Output | Description |
|--------|-------------|
| `ApiUrl` | HTTPS invoke URL — set as `BACKEND_URL` in Flutter app |
| `LambdaFunctionName` | Name for `aws lambda invoke` or CloudWatch logs |
| `AppSecretsArn` | Secrets Manager ARN (confirm secrets are populated) |
| `AlarmTopicArn` | Subscribe your ops email for CloudWatch alerts |
| `DashboardUrl` | CloudWatch metrics dashboard link |

### Subscribe to alerts (optional but recommended)

```bash
aws sns subscribe \
  --topic-arn <AlarmTopicArn from outputs> \
  --protocol email \
  --notification-endpoint your-ops-email@example.com
```

Confirm the subscription by clicking the link in the confirmation email.

---

## Step 8 — Verify the Deployment

```bash
# Health check
curl -s https://<ApiUrl>/api/health | jq .

# Expected response:
# { "status": "ok" }
```

```bash
# Tail Lambda logs (requires AWS CLI v2)
aws logs tail /aws/lambda/instructor-prod --follow
```

---

## Updating the Lambda (Redeployment)

```bash
# Rebuild server TypeScript (if you haven't already)
cd server && npm run build

# Redeploy
cd ..
./deploy.sh
```

CDK only redeploys resources that have changed.
Lambda code changes trigger a new function version automatically.

---

## Environment Variables Reference

The Lambda function receives the following environment variables at runtime:

| Variable | Source | Description |
|----------|--------|-------------|
| `NODE_ENV` | CDK stack | Always `production` |
| `AWS_S3_BUCKET` | CDK stack | S3 bucket name for TTS cache and backups |
| `SES_FROM_EMAIL` | CDK stack | `instructor.app@layersiq.com` |
| `APP_SECRETS_ID` | CDK stack | Secrets Manager secret name |
| `PARAMETERS_SECRETS_EXTENSION_HTTP_PORT` | CDK stack | `2773` — Lambda extension port |
| `SECRETS_MANAGER_TTL` | CDK stack | `300` — secret cache TTL in seconds |
| `AWS_NODEJS_CONNECTION_REUSE_ENABLED` | CDK stack | `1` — HTTP keep-alive for AWS SDK |
| `JWT_SECRET` | Secrets Manager | JWT signing key |
| `JWT_REFRESH_SECRET` | Secrets Manager | JWT refresh token signing key |
| `API_KEY` | Secrets Manager | `x-api-key` header for mobile clients |
| `OTP_SALT` | Secrets Manager | Salt for OTP hashing |
| `GEMINI_API_KEY` | Secrets Manager | Google Gemini 2.0 Flash API key |
| `KOKORO_SERVER_URL` | Secrets Manager | Modal Kokoro TTS server URL (optional) |
| `DATABASE_URL` | Secrets Manager | Neon PostgreSQL pooled connection string |
| `UPSTASH_REDIS_REST_URL` | Secrets Manager | Upstash Redis REST API URL |
| `UPSTASH_REDIS_REST_TOKEN` | Secrets Manager | Upstash Redis REST API token |

---

## Monthly Database Maintenance

PostgreSQL does not automatically purge expired records from `otp_records` or
`refresh_tokens`. Run these cleanup queries **once per month** to prevent table bloat:

```sql
-- Remove expired OTP records older than 7 days
-- (7-day grace period preserves audit trail for recent events)
DELETE FROM otp_records
WHERE expires_at < NOW() - INTERVAL '7 days';

-- Remove expired refresh tokens
-- (expired tokens cannot be used; deleting them frees storage)
DELETE FROM refresh_tokens
WHERE expires_at < NOW();
```

### Run via psql (using the direct Neon connection string)

```bash
psql "postgresql://neondb_owner:<password>@<direct-host>.neon.tech/neondb?sslmode=require" \
  -c "DELETE FROM otp_records WHERE expires_at < NOW() - INTERVAL '7 days';"

psql "postgresql://neondb_owner:<password>@<direct-host>.neon.tech/neondb?sslmode=require" \
  -c "DELETE FROM refresh_tokens WHERE expires_at < NOW();"
```

### Run via Neon SQL Editor

1. Open <https://console.neon.tech> → your project → **SQL Editor**.
2. Paste and run each query separately.

> **Tip:** Neon's free tier includes 0.5 GB of storage.
> Monthly cleanup ensures you stay well within that limit at launch scale.

---

## Troubleshooting

### Lambda cold starts are slow (> 5 seconds)

- The Lambda has 1 024 MB memory and no VPC attachment.
  Cold starts typically take 2–4 seconds (NestJS bootstrap + secrets fetch).
- If cold starts are unacceptable, enable **Provisioned Concurrency** (small cost):
  ```bash
  aws lambda put-provisioned-concurrency-config \
    --function-name instructor-prod \
    --qualifier <version-or-alias> \
    --provisioned-concurrent-executions 1
  ```

### SES emails are not delivered

1. Check SES identity status: **SES → Verified Identities → layersiq.com** — must show **Verified**.
2. Check if the account is still in sandbox mode: **SES → Account dashboard**.
3. Check Lambda logs for SES errors: `aws logs tail /aws/lambda/instructor-prod --follow`.
4. Verify the `SES_FROM_EMAIL` output equals `instructor.app@layersiq.com`.

### Database connection errors from Lambda

1. Confirm `DATABASE_URL` in Secrets Manager is the **pooled** connection string (contains `pooler` in hostname).
2. Check Neon project status at <https://console.neon.tech> — free tier projects auto-suspend after 5 minutes of inactivity.
   The first query after suspension will take ~1–2 seconds (wake-up time).
3. Inspect Lambda logs for `NeonDbError` or `ECONNREFUSED`.

### Upstash Redis rate limit errors

1. Confirm `UPSTASH_REDIS_REST_URL` and `UPSTASH_REDIS_REST_TOKEN` are set correctly.
2. Check the Upstash console for daily command usage — free tier is 10 000 commands/day.
3. If commands are exhausted, the `RateLimitService` will throw and the Lambda will return 429.

### CDK deploy fails with "Bucket already exists"

The S3 bucket name `instructor-cache` is globally unique. If another AWS account
already owns it, change the bucket name in `infra/lib/instructor-stack.ts`:
```typescript
const bucketName = isProd ? 'instructor-cache-<your-suffix>' : `instructor-cache-${envName}`;
```

### WAF returns 403 on legitimate requests

The WAF rate limit is set to **100 requests per 5-minute window per source IP**.
During development or load testing, you may hit this limit.
To temporarily bypass, use `aws wafv2` to update the rate limit or disable the rule:
```bash
# View current WebACL config
aws wafv2 get-web-acl \
  --name instructor-waf-prod \
  --scope REGIONAL \
  --id <webacl-id>
```
