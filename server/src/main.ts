import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';
import { JsonLoggerService } from './common/json-logger.service';

async function bootstrap() {
  const logger = new JsonLoggerService();

  const app = await NestFactory.create(AppModule, { logger });

  // CORS: allow explicit origins (Flutter web dev + configured origins).
  const allowedOrigins = (process.env.CORS_ORIGINS ?? 'http://localhost:3072')
    .split(',')
    .map((o) => o.trim());

  app.enableCors({
    origin: allowedOrigins,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'x-api-key'],
    credentials: true,
  });

  // Validate and strip unknown fields from all request bodies.
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  // Global prefix is NOT set here because API Gateway already routes /api/* directly to this handler.
  // With REST API proxy integration, the proxy path doesn't include the /api resource prefix,
  // so NestJS routes are registered without it (e.g., /tts/synthesize instead of /api/tts/synthesize).

  const port = process.env.PORT ?? 3071;
  await app.listen(port);

  logger.log(
    { msg: 'Server running', port, logLevel: process.env.LOG_LEVEL ?? 'debug' },
    'Bootstrap',
  );
  logger.log(
    { msg: 'CORS allowed origins', origins: allowedOrigins },
    'Bootstrap',
  );
}
bootstrap();
