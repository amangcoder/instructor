#!/usr/bin/env python3
import subprocess
import sys

dart = '/opt/homebrew/share/flutter/bin/dart'
cwd = '/Users/amangupta/Projects/instructor/app'
args = [dart, 'run', 'build_runner', 'build', '--delete-conflicting-outputs']

print(f"Running: {' '.join(args)}")
print(f"Working dir: {cwd}")
print("=" * 60)

result = subprocess.run(args, cwd=cwd, capture_output=False, timeout=300)
sys.exit(result.returncode)
