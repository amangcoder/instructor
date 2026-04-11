# Instructor

A voice-guided plan execution app. Author timed routines — workouts, meditation, study sessions, cooking recipes — and let the app guide you through each step with voice instructions, chimes, and countdowns. No screen-watching required.

## Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Flutter App  │────▶│  NestJS API  │────▶│  Kokoro TTS  │
│  (mobile/web) │     │  (port 3071) │     │  (port 3070) │
└──────────────┘     └──────┬───────┘     └──────────────┘
                           │
                     ┌─────┴─────┐
                     │   Redis   │
                     │ (rate lim)│
                     └───────────┘
```

| Component | Stack | Location |
|-----------|-------|----------|
| **App** | Flutter/Dart, Riverpod, Drift | `app/` |
| **API Server** | NestJS, TypeScript | `server/` |
| **TTS Server** | FastAPI, Kokoro ONNX | `kokoro-server/` |
| **Infrastructure** | AWS CDK (Lambda, WAFv2, SES) | `infra/` |

## Features

- Plan-based timer with exercise, rest, instruction, and repeat-block steps
- Text-to-Speech voice guidance (Kokoro ONNX + platform TTS fallback)
- AI-powered plan generation
- Plan library with category filtering and starter templates
- Background execution with notification support
- Phone call detection for auto-pause
- Offline-capable with local database persistence
- Dark/light theme

## Getting Started

### Prerequisites

- Flutter SDK (stable channel)
- Node.js >= 18
- Python 3.10+ (for Kokoro TTS)

### Local Development

```bash
# Start backend services (Kokoro TTS + NestJS API)
./start-backend.sh

# Or start individually
./start-backend.sh kokoro   # TTS only (port 3070)
./start-backend.sh server   # API only (port 3071)
```

```bash
# Run the Flutter app
cd app
flutter run --dart-define=BACKEND_URL=http://localhost:3071
```

### Docker

```bash
cp server/.env.example server/.env
# Fill in real values in server/.env
docker compose up --build
```

### Deploy to AWS

```bash
# First time: bootstrap CDK
cd infra && npx cdk bootstrap

# Deploy all stacks
./deploy.sh
```

## Project Structure

```
instructor/
├── app/                  # Flutter client
│   ├── lib/
│   │   ├── models/       # Data models & plan schema
│   │   ├── providers/    # Riverpod providers
│   │   ├── screens/      # UI screens
│   │   ├── services/     # TTS, audio, API clients
│   │   └── database/     # Drift local database
│   └── ios/android/...   # Platform targets
├── server/               # NestJS API
│   └── src/
│       ├── tts/          # TTS synthesis endpoints
│       ├── plans/        # Plan CRUD & generation
│       ├── auth/         # Authentication
│       └── ratelimit/    # Redis-backed rate limiting
├── kokoro-server/        # Kokoro TTS (FastAPI + ONNX)
├── infra/                # AWS CDK infrastructure
├── Docs/                 # PRD, research, test cases
├── docker-compose.yml    # Local multi-service setup
├── deploy.sh             # Production deploy script
└── start-backend.sh      # Local dev launcher
```
