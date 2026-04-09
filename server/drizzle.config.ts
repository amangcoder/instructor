import { defineConfig } from 'drizzle-kit';

/**
 * Drizzle Kit configuration for Neon PostgreSQL.
 *
 * Used by `drizzle-kit generate` to produce migration SQL files and by
 * `drizzle-kit migrate` to apply them against the Neon database.
 *
 * Database connection is read from DATABASE_URL — set it in .env for local
 * development or export it before running drizzle-kit commands:
 *
 *   DATABASE_URL="postgres://..." npx drizzle-kit generate
 *   DATABASE_URL="postgres://..." npx drizzle-kit migrate
 *
 * In Lambda, DATABASE_URL is injected by the AWS Parameters and Secrets
 * Lambda Extension from Secrets Manager — migrations are run locally before
 * each deployment, not at runtime.
 */
export default defineConfig({
  dialect: 'postgresql',
  schema: './src/database/schema.ts',
  out: './drizzle',
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
});
