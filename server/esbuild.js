const esbuild = require('esbuild');
const esbuildPluginTsc = require('esbuild-plugin-tsc');

esbuild
  .build({
    entryPoints: ['src/main.ts', 'src/lambda.ts'],
    bundle: true,
    outdir: 'dist',
    platform: 'node',
    target: 'ES2023',
    sourcemap: true,
    format: 'cjs',
    minify: true,
    external: [
      '@nestjs/websockets',
      '@nestjs/websockets/socket-module',
      '@nestjs/microservices',
      '@nestjs/microservices/microservices-module',
    ],
    plugins: [esbuildPluginTsc({ force: true })],
  })
  .catch(() => process.exit(1));
