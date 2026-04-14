#!/bin/bash
set -e
cd /Users/amangupta/Projects/instructor/app
dart run build_runner build --delete-conflicting-outputs
echo "EXIT_CODE: $?"
