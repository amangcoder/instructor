#!/bin/sh
cd /Users/amangupta/Projects/instructor/server
node node_modules/.bin/jest --testPathPattern="upstash-ratelimit" --no-coverage --forceExit
