const { execSync } = require('child_process');
try {
  const out = execSync(
    'node_modules/.bin/jest src/admin-analytics/admin-analytics.service.spec.ts src/admin-analytics/admin-analytics.controller.spec.ts --no-coverage --verbose',
    { cwd: '/Users/amangupta/Projects/instructor/server', encoding: 'utf8', stdio: ['pipe','pipe','pipe'] }
  );
  process.stdout.write(out);
} catch(e) {
  process.stdout.write(e.stdout || '');
  process.stderr.write(e.stderr || '');
  process.exit(e.status || 1);
}
