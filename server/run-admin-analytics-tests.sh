#!/bin/sh
cd /Users/amangupta/Projects/instructor/server
./node_modules/.bin/jest src/admin-analytics/admin-analytics.service.spec.ts src/admin-analytics/admin-analytics.controller.spec.ts --no-coverage --verbose 2>&1
