#!/usr/bin/env node
/**
 * Replace Material Design token class names with dark-slate/indigo Tailwind classes
 * TASK-001: Replace placeholder design tokens
 */

const fs = require('fs');
const path = require('path');

const REPLACEMENTS = [
  ['bg-surface-container', 'bg-slate-800/50'],
  ['bg-surface\\b', 'bg-slate-900'],
  ['text-on-surface\\b', 'text-white'],
  ['text-on-surface-variant', 'text-slate-400'],
  ['border-outline-variant', 'border-white/8'],
  ['bg-primary/10', 'bg-indigo-600/15'],
  ['text-primary', 'text-indigo-400'],
  ['bg-error-container', 'bg-red-950/80'],
  ['text-on-error-container', 'text-red-400'],
  ['text-success', 'text-emerald-400'],
  ['text-error\\b', 'text-red-400'],
  ['text-on-primary', 'text-white'],
  ['bg-primary/5', 'bg-white/5'],
  ['hover:bg-primary/5', 'hover:bg-white/5'],
];

function processFile(filePath) {
  try {
    let content = fs.readFileSync(filePath, 'utf-8');
    let original = content;

    for (const [from, to] of REPLACEMENTS) {
      const regex = new RegExp(`\\b${from}\\b`, 'g');
      content = content.replace(regex, to);
    }

    if (content !== original) {
      fs.writeFileSync(filePath, content, 'utf-8');
      console.log(`✓ ${filePath}`);
      return true;
    }
  } catch (error) {
    console.error(`✗ ${filePath}: ${error.message}`);
  }
  return false;
}

function walkDir(dir) {
  const files = fs.readdirSync(dir);
  let count = 0;

  for (const file of files) {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory() && !file.startsWith('.') && file !== 'node_modules') {
      count += walkDir(filePath);
    } else if (file.endsWith('.tsx') || file.endsWith('.ts')) {
      if (processFile(filePath)) count++;
    }
  }

  return count;
}

const webDir = path.join(__dirname, 'web');
console.log('Starting token replacements...\n');
const updated = walkDir(webDir);
console.log(`\n✓ Updated ${updated} files`);
