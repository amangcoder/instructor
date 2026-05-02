const { spawnSync } = require('child_process');
const result = spawnSync(
  'node_modules/.bin/jest',
  ['--passWithNoTests', '--forceExit', '--no-coverage'],
  { cwd: __dirname, encoding: 'utf8', stdio: 'pipe' }
);
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
process.exit(result.status || 0);
