#!/bin/bash
/opt/homebrew/share/flutter/bin/dart run build_runner build --delete-conflicting-outputs
echo "BUILD_RUNNER_EXIT: $?"
/opt/homebrew/share/flutter/bin/flutter analyze
echo "FLUTTER_ANALYZE_EXIT: $?"
