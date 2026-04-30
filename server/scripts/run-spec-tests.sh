#!/bin/bash
cd /Users/amangupta/Projects/instructor/server
./node_modules/.bin/jest src/auth/admin-role.guard.spec.ts src/auth/auth.service.spec.ts --no-coverage 2>&1
