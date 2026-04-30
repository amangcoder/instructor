const { execSync } = require('child_process');
try {
  const out = execSync(
    'node_modules/.bin/jest src/auth/admin-role.guard.spec.ts src/auth/auth.service.spec.ts --no-coverage',
    { cwd: '/Users/amangupta/Projects/instructor/server', encoding: 'utf8', stdio: ['pipe','pipe','pipe'] }
  );
  process.stdout.write(out);
} catch(e) {
  process.stdout.write(e.stdout || '');
  process.stderr.write(e.stderr || '');
  process.exit(e.status || 1);
}
