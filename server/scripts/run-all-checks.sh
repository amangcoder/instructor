#!/bin/bash
set -e
cd /Users/amangupta/Projects/instructor/server

echo "=== JEST TESTS ==="
./node_modules/.bin/jest --forceExit 2>&1
JEST_EXIT=$?

echo ""
echo "=== ESLINT ==="
./node_modules/.bin/eslint src/admin-analytics/ src/app-version/ --max-warnings=0 2>&1
ESLINT_EXIT=$?

echo ""
echo "=== TYPESCRIPT ==="
./node_modules/.bin/tsc --noEmit 2>&1
TSC_EXIT=$?

echo ""
echo "=== SUMMARY ==="
echo "Jest exit: $JEST_EXIT"
echo "ESLint exit: $ESLINT_EXIT"
echo "TypeScript exit: $TSC_EXIT"
