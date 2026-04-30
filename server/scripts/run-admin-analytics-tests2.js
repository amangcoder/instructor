const { spawnSync } = require('child_process');
const result = spawnSync(
  'node_modules/.bin/jest',
  [
    'src/admin-analytics/admin-analytics.service.spec.ts',
    'src/admin-analytics/admin-analytics.controller.spec.ts',
    '--no-coverage',
    '--verbose',
  ],
  {
    cwd: '/Users/amangupta/Projects/instructor/server',
    encoding: 'utf8',
  }
);
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
process.exit(result.status || 0);
