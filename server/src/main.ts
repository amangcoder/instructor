import 'dotenv/config';
import './instrument';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';
import { JsonLoggerService } from './common/json-logger.service';
import { AllExceptionsFilter } from './common/all-exceptions.filter';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { JwtService } from '@nestjs/jwt';

async function bootstrap() {
  const logger = new JsonLoggerService();

  const app = await NestFactory.create(AppModule, { logger });

  // CORS: allow explicit origins (Flutter web dev + configured origins).
  const allowedOrigins = (process.env.CORS_ORIGINS ?? 'http://localhost:3072')
    .split(',')
    .map((o) => o.trim());

  app.enableCors({
    origin: allowedOrigins,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'x-api-key'],
    credentials: true,
  });

  // Validate and strip unknown fields from all request bodies.
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  // Standardise all error responses into { statusCode, error, message, requestId }.
  // Must be registered AFTER ValidationPipe so the filter sees HttpExceptions
  // raised by the pipe. The filter reads requestId set by ApiLoggerInterceptor.
  app.useGlobalFilters(new AllExceptionsFilter());

  // Global prefix — matches lambda.ts so local dev URLs are identical to production.
  app.setGlobalPrefix('api');

  // ── OpenAPI / Swagger ──────────────────────────────────────────────────────
  // Served at /api/docs. In production, requires a valid admin Bearer token.
  const swaggerConfig = new DocumentBuilder()
    .setTitle('Instructor API')
    .setDescription(
      'REST API for the Instructor coaching-plan app. ' +
      'All endpoints (except /api/auth/request-otp and /api/auth/verify-otp) ' +
      'require a valid JWT Bearer token.',
    )
    .setVersion(process.env.npm_package_version ?? '1.0.0')
    .addBearerAuth(
      { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      'access-token',
    )
    .addServer(`http://localhost:${process.env.PORT ?? 3071}`, 'Local dev')
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);

  // In production, guard the docs behind admin JWT verification.
  // In dev/test, the docs are publicly accessible at /api/docs.
  if (process.env.NODE_ENV === 'production') {
    const jwtService = app.get(JwtService);
    // Express middleware to verify admin JWT before serving Swagger UI.
    const httpAdapter = app.getHttpAdapter();
    httpAdapter.use('/api/docs', (req: any, res: any, next: any) => {
      const forbidden = (message: string) =>
        res.status(403).json({ statusCode: 403, message, error: 'forbidden', requestId: req.requestId ?? 'unknown' });

      const authHeader: string | undefined = req.headers['authorization'];
      if (!authHeader?.startsWith('Bearer ')) {
        return forbidden('Forbidden');
      }

      const token = authHeader.slice(7);
      try {
        const decoded = jwtService.verify(token) as any;
        if (decoded?.role !== 'admin') {
          return forbidden('Admin access required');
        }
        next();
      } catch {
        return forbidden('Invalid or expired token');
      }
    });
  }

  SwaggerModule.setup('api/docs', app, document, {
    swaggerOptions: {
      persistAuthorization: true,
      tagsSorter: 'alpha',
      operationsSorter: 'alpha',
    },
  });

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
  logger.log(
    { msg: 'Swagger docs', url: `http://localhost:${port}/api/docs` },
    'Bootstrap',
  );
}
bootstrap();
