#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { InstructorStack } from '../lib/instructor-stack';

const app = new cdk.App();

// ── Environment resolution ────────────────────────────────────────────────────
// Pass --context env=prod  (or set CDK_DEFAULT_ACCOUNT / CDK_DEFAULT_REGION).
const envName = app.node.tryGetContext('env') ?? 'dev';

new InstructorStack(app, `InstructorStack-${envName}`, {
  envName,
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION ?? 'ap-south-1',
  },
  description: `Instructor app infrastructure (S3 + IAM) — ${envName}`,
});

app.synth();
