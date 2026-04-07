import type { Config } from 'drizzle-kit';
import { join } from 'path';

/**
 * Drizzle Kit configuration for generating and running migrations.
 *
 * Usage:
 *   npx drizzle-kit generate   — generate SQL migration files from schema changes
 *   npx drizzle-kit migrate    — apply pending migrations to the database
 *   npx drizzle-kit studio     — open the Drizzle Studio UI
 *
 * The database file location honours the DATABASE_DIR env variable so that
 * local dev, Docker, and CI all point to the right file without code changes.
 */
const dataDir = process.env.DATABASE_DIR ?? join(process.cwd(), 'data');
const dbUrl = join(dataDir, 'server.db');

export default {
  schema: './src/database/schema.ts',
  out: './src/database/migrations',
  dialect: 'sqlite',
  dbCredentials: {
    url: dbUrl,
  },
  verbose: true,
  strict: true,
} satisfies Config;
