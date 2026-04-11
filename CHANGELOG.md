# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2026-04-11

### Added

- AI-powered plan generation via backend API
- Docker Compose setup with Kokoro TTS, NestJS API, and Redis
- AWS CDK infrastructure (Lambda, WAFv2, SES email)
- Production deploy script (`deploy.sh`)
- Local dev launcher (`start-backend.sh`)
- Redis-backed distributed rate limiting
- Health checks for all services

### Changed

- Default backend URL switched from local IP to production (`instructor.api.layersiq.com`)
- Expanded `.gitignore` with IDE, build, secrets, Flutter, and OS patterns
- Made `deploy.sh` executable
- Added `dist/` to infra TypeScript exclude list

### Fixed

- REST API routing with WAFv2
- App voice crashing issue
- Removed debug breakpoints from plan generation client

### Removed

- Checked-in IDE config files (`.idea/`, `.vscode/`)

## [0.1.0] - 2026-04-06

### Added

- Flutter cross-platform app (Android, iOS, macOS, Linux, Windows, Web)
- Plan-based workout/routine timer with voice guidance (TTS)
- Plan editor with step types: exercise, rest, instruction, repeat blocks
- Plan library with category filtering and starter plans
- Now Playing screen with countdown timer and session controls
- Onboarding flow with template picker
- Audio engine for chimes, countdowns, and background audio
- Text-to-Speech service with caching
- Background execution and notification support
- Phone call detection for auto-pause
- Drift-based local database with execution state persistence
- Riverpod state management
- Dark/light theme support
- Settings screen with TTS voice, speed, and battery optimization
- Comprehensive test suite (unit, widget, and repository tests)
- Project documentation (PRD, idea doc, plan schema research)
