/**
 * AWS Lambda entry point — Instructor NestJS backend.
 *
 * Design decisions (see architecture.json for full rationale):
 *
 *  1. App caching — the NestJS application instance is bootstrapped exactly
 *     ONCE per Lambda execution environment (cold start) and cached in module
 *     scope. Warm invocations reuse the cached handler at near-zero overhead.
 *
 *  2. CORS — NOT enabled here. CORS is configured on the API Gateway HTTP API
 *     (CorsConfiguration in CDK). Enabling CORS in both places produces
 *     duplicate Access-Control-Allow-Origin headers, which browsers reject.
 *     CORS is still enabled in main.ts for local development.
 *
 *  3. Secrets — loaded from the AWS Parameters and Secrets Lambda Extension
 *     (http://localhost:2773) before NestJS boots, so all NestJS modules see
 *     the correct process.env values from the first DI scan.
 *
 *  4. Binary media — binarySettings.contentTypes causes serverless-express to
 *     base64-encode audio/wav responses and set isBase64Encoded=true. API Gateway
 *     REST API (v1) decodes this base64 before sending to the client, but ONLY
 *     when binaryMediaTypes is set on the RestApi (see infra/lib/instructor-stack.ts).
 *     Without that CDK setting, API Gateway forwards the raw base64 string and the
 *     client receives text instead of binary audio bytes (ExoPlayer WavExtractor fail).
 *
 *  5. VPC — Lambda is NOT placed in a VPC. Redis and SMTP are removed, so
 *     there are no VPC-internal dependencies. Non-VPC Lambda has native internet
 *     access for outbound HTTPS to S3, SES, Kokoro, and Gemini.
 *
 * ⚠ Express 5 compatibility check:
 *  NestJS 11 ships @nestjs/platform-express which depends on Express 5.
 *  @codegenie/serverless-express was authored for Express 4. Before production:
 *    1. Deploy to dev and verify GET /api/health returns 200.
 *    2. Send a TTS request and verify binary WAV response has valid RIFF header.
 *  If incompatible, alternatives: Lambda Function URLs (no adapter needed),
 *  downgrade to Express 4 via NestJS ExpressAdapter override.
 *
 * @see https://docs.aws.amazon.com/secretsmanager/latest/userguide/retrieving-secrets_lambda.html
 * @see https://github.com/CodeGenieApp/serverless-express
 */

// reflect-metadata MUST be imported before any NestJS decorator code is
// evaluated. esbuild banner injects this for bundled output; importing here
// is the belt-and-suspenders safety net.
import 'reflect-metadata';

import type { Handler, Context } from 'aws-lambda';
import { configure } from '@codegenie/serverless-express';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';

import { AppModule } from './app.module';
import { JsonLoggerService } from './common/json-logger.service';
import { SESEmailService } from './email/ses-email.service';

// ── Background task types ─────────────────────────────────────────────────────

export interface SendOtpEmailTask {
  task: 'sendOtpEmail';
  to: string;
  code: string;
}

// ── Module-level handler cache ────────────────────────────────────────────────
// Persists for the lifetime of the Lambda execution environment.
// On cold start: undefined → triggers bootstrap().
// On warm invocations: reused directly, skipping NestJS re-init.
let cachedHandler: Handler | undefined;

// ── Secrets loading ───────────────────────────────────────────────────────────

/**
 * Loads the application secrets JSON from the AWS Parameters and Secrets
 * Lambda Extension and writes each key into process.env.
 *
 * The extension pre-fetches the secret on cold start, caches it for
 * SECRETS_MANAGER_TTL seconds (configured via Lambda env var), and serves
 * subsequent requests from its in-process cache — zero latency on warm calls.
 *
 * Behaviour:
 *  - If APP_SECRETS_ID is not set, returns immediately (useful for local dev).
 *  - If the extension responds with an error, logs a warning and returns —
 *    the app will still boot; modules that need secrets will fail with clear errors.
 *  - Existing process.env values take precedence (supports local dev overrides
 *    set in .env or shell environment without touching the Lambda env vars).
 *
 * Endpoint: GET http://localhost:2773/secretsmanager/get?secretId=<id>
 * Auth header: X-Aws-Parameters-Secrets-Token: <AWS_SESSION_TOKEN>
 */
async function loadSecrets(): Promise<void> {
  const secretId = process.env.APP_SECRETS_ID;
  if (!secretId) {
    console.warn(
      '[Lambda] APP_SECRETS_ID is not set — skipping Secrets Manager load. ' +
        'This is expected for local development; ensure all required env vars are set manually.',
    );
    return;
  }

  const port = process.env.PARAMETERS_SECRETS_EXTENSION_HTTP_PORT ?? '2773';
  const url = `http://localhost:${port}/secretsmanager/get?secretId=${encodeURIComponent(secretId)}`;

  try {
    // AWS_SESSION_TOKEN is injected automatically by the Lambda runtime.
    const response = await fetch(url, {
      headers: {
        'X-Aws-Parameters-Secrets-Token': process.env.AWS_SESSION_TOKEN ?? '',
      },
    });

    if (!response.ok) {
      console.error(
        `[Lambda] Secrets extension returned HTTP ${response.status} for secret "${secretId}". ` +
          'Proceeding without loaded secrets — check IAM role has secretsmanager:GetSecretValue.',
      );
      return;
    }

    const body = (await response.json()) as { SecretString?: string };
    if (!body.SecretString) {
      console.warn('[Lambda] Secrets extension returned an empty SecretString.');
      return;
    }

    const secrets = JSON.parse(body.SecretString) as Record<string, string>;
    let injected = 0;

    for (const [key, value] of Object.entries(secrets)) {
      // Explicit Lambda environment variables take precedence over Secrets Manager
      // so that per-environment overrides (set in CDK) are never clobbered.
      if (process.env[key] === undefined) {
        process.env[key] = value;
        injected++;
      }
    }

    console.log(
      `[Lambda] Injected ${injected} secret(s) from "${secretId}" into process.env.`,
    );
  } catch (err) {
    // Non-fatal — app boots and fails at first use of a missing secret, which
    // produces a more informative error than crashing here during cold start.
    console.error('[Lambda] Failed to load secrets from extension:', err);
  }
}

// ── NestJS bootstrap ──────────────────────────────────────────────────────────

/**
 * Creates and initialises the NestJS application, then wraps it with
 * @codegenie/serverless-express so the Lambda handler can forward API Gateway
 * HTTP API v2 events into the Express-based NestJS router.
 *
 * Key differences from main.ts (long-running HTTP server mode):
 *  - No `app.listen()` — serverless-express routes requests through the event.
 *  - No `app.enableCors()` — CORS is owned by API Gateway HTTP API.
 *  - No `import 'dotenv/config'` — env vars come from Lambda config + Secrets Manager.
 *
 * @returns A Lambda Handler that forwards events to the NestJS Express app.
 */
async function bootstrap(): Promise<Handler> {
  // ── 1. Inject secrets before any NestJS modules initialise ────────────────
  // DatabaseService (Neon), UpstashRateLimitService, SESEmailService, and
  // JwtModule read process.env during NestJS provider construction; secrets
  // must be in place before NestFactory.create() scans providers.
  await loadSecrets();

  // ── 2. Create the NestJS application ──────────────────────────────────────
  const logger = new JsonLoggerService();

  const app = await NestFactory.create(AppModule, {
    logger,
    // Suppress the ASCII banner — reduces CloudWatch Logs ingestion noise.
    abortOnError: false,
  });

  // ── 3. Global pipes ────────────────────────────────────────────────────────
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,  // Strip request body properties not declared in DTOs.
      transform: true,  // Auto-coerce plain objects to DTO class instances.
    }),
  );

  // ── 4. Global prefix ───────────────────────────────────────────────────────
  // All routes are prefixed with /api (e.g., /api/auth/request-otp).
  // The REST API proxy at /{proxy+} forwards the full path including /api.
  app.setGlobalPrefix('api');

  // ── 5. Initialise (runs onModuleInit hooks) ────────────────────────────────
  // app.init() completes dependency injection without binding to a TCP port.
  // All NestJS onModuleInit hooks run here; they must avoid network I/O to
  // keep cold start under the 5-second target at 1024 MB Lambda memory.
  await app.init();

  // ── 6. Wrap with serverless-express ───────────────────────────────────────
  // configure() translates API Gateway REST API (v1) proxy events into
  // Express-compatible request/response objects and back again.
  //
  // binarySettings.contentTypes: responses with these Content-Type values are
  // base64-encoded by serverless-express and flagged with isBase64Encoded=true.
  // API Gateway REST API v1 then decodes the base64 body back to binary before
  // forwarding to the client — requires binaryMediaTypes on the RestApi CDK
  // construct (infra/lib/instructor-stack.ts) to work correctly.
  // API Gateway REST API payload limit: 10 MB (≈ 7.3 MB effective after base64).
  // Typical TTS audio: 50 KB – 2 MB → safely within limit.
  const expressInstance = app.getHttpAdapter().getInstance() as Express.Application;

  const handler = configure({
    app: expressInstance as unknown as import('http').RequestListener,
    binarySettings: {
      contentTypes: [
        'audio/wav',
        'audio/mpeg',
        'audio/mp3',
        'audio/ogg',
        'audio/webm',
        'application/octet-stream',
      ],
    },
  });

  logger.log(
    {
      msg: 'Lambda cold start complete — handler cached for warm reuse',
      nodeEnv: process.env.NODE_ENV,
      databaseUrl: process.env.DATABASE_URL ? 'configured' : 'NOT SET',
      upstashRedis: process.env.UPSTASH_REDIS_REST_URL ? 'configured' : 'NOT SET',
      s3Bucket: process.env.AWS_S3_BUCKET,
      sesFrom: process.env.SES_FROM_EMAIL,
      region: process.env.AWS_REGION,
    },
    'Lambda',
  );

  return handler as unknown as Handler;
}

// ── Lambda handler export ─────────────────────────────────────────────────────

/**
 * The AWS Lambda handler function.
 *
 * Entry point referenced by the CDK NodejsFunction:
 *   entry:   'server/src/lambda.ts'
 *   handler: 'handler'  ← must match this export name
 *
 * Cold start path  (cachedHandler === undefined):
 *   loadSecrets() → NestFactory.create() → app.init() → configure() → cache → handle
 *
 * Warm invocation path (cachedHandler is set):
 *   cached handler → Express router → NestJS controller → response
 *
 * The Lambda timeout is 120 s (set in CDK). API Gateway HTTP API v2 has a
 * hard 30-second integration timeout — requests longer than 29 s receive a
 * 503 Gateway Timeout from API Gateway regardless of the Lambda timeout.
 */
export const handler: Handler = async (
  event: unknown,
  context: Context,
): Promise<unknown> => {
  // ── Background task routing ───────────────────────────────────────────────
  // When this Lambda invokes itself asynchronously (InvocationType: 'Event'),
  // the event contains a `task` field instead of an API Gateway HTTP payload.
  // Handle these tasks directly without going through the HTTP adapter.
  if (event && typeof event === 'object' && 'task' in event) {
    const taskEvent = event as SendOtpEmailTask;
    if (taskEvent.task === 'sendOtpEmail') {
      const emailService = new SESEmailService();
      await emailService.sendOtpEmail(taskEvent.to, taskEvent.code);
      return { success: true };
    }
    console.error('[Lambda] Unknown background task:', taskEvent.task);
    return { success: false };
  }

  // ── HTTP request routing ──────────────────────────────────────────────────
  if (!cachedHandler) {
    cachedHandler = await bootstrap();
  }

  return cachedHandler(event, context, () => {
    // Callback form — not used by serverless-express v4+ which is Promise-based.
    // Included for type compatibility with the Handler signature.
  });
};
