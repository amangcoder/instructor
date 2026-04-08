#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { InstructorStack } from '../lib/instructor-stack';

const app = new cdk.App();

// ── Environment resolution ────────────────────────────────────────────────────
// Usage examples:
//   cdk deploy --context env=dev
//   cdk deploy --context env=prod --context sesFromEmail=noreply@instructor.app
//
// Required context keys:
//   env           — 'dev' | 'staging' | 'prod'  (default: 'dev')
//   sesFromEmail  — SES sender address           (default: 'noreply@instructor.app')
//
// Environment variables consumed by CDK:
//   CDK_DEFAULT_ACCOUNT — AWS account ID (set by `aws configure` or CI/CD)
//   CDK_DEFAULT_REGION  — AWS region     (default: 'ap-south-1')

const envName = (app.node.tryGetContext('env') as string | undefined) ?? 'dev';

new InstructorStack(app, `InstructorStack-${envName}`, {
  envName,
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION ?? 'ap-south-1',
  },
  description: `Instructor app infrastructure (S3, IAM, DynamoDB, Lambda, API Gateway) — ${envName}`,
  // sesFromEmail can also be supplied via CDK context: --context sesFromEmail=<email>
  // Stack constructor reads it from context if not supplied here.
});

app.synth();
