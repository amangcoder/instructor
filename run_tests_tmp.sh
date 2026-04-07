#!/bin/bash
echo "=== NestJS Server Tests ==="
cd /Users/amangupta/Projects/instructor/server
node node_modules/.bin/jest --forceExit --passWithNoTests 2>&1
echo ""
echo "=== Kokoro Python Tests ==="
cd /Users/amangupta/Projects/instructor/kokoro-server
python3 -m pytest tests/ -v 2>&1
echo ""
echo "=== Flutter App Tests ==="
cd /Users/amangupta/Projects/instructor/app
flutter test 2>&1
