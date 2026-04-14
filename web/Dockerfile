# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# Instructor Web — Next.js 15 marketing site
#
# Multi-stage build:
#   deps    → install production + dev dependencies with pnpm
#   builder → compile Next.js app
#   runner  → minimal production image
#
# Exposes port 3072 (aligns with project convention: frontend = 3072).
# ─────────────────────────────────────────────────────────────────────────────

# ── Stage 1: install dependencies ────────────────────────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app

# Install pnpm globally (matches lock file format)
RUN npm install -g pnpm@latest --quiet

# Copy lock file and manifest first for better layer caching
COPY package.json pnpm-lock.yaml ./

# Install all dependencies (including devDeps needed for build)
RUN pnpm install --frozen-lockfile

# ── Stage 2: build the Next.js application ───────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

RUN npm install -g pnpm@latest --quiet

# Copy installed node_modules from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy full source tree
COPY . .

# Build-time environment
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

# Build-time placeholder — the API route proxies at runtime via BACKEND_URL
ENV BACKEND_URL=http://localhost:3071

RUN pnpm run build

# ── Stage 3: lean production image ───────────────────────────────────────────
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
# Default port — can be overridden via docker-compose environment block
ENV PORT=3072
ENV HOSTNAME=0.0.0.0

RUN addgroup --system --gid 1001 nodejs && \
    adduser  --system --uid 1001 nextjs

# Copy only what next start needs
COPY --from=builder /app/public         ./public
COPY --from=builder /app/.next          ./.next
COPY --from=builder /app/node_modules   ./node_modules
COPY --from=builder /app/package.json   ./package.json

USER nextjs

EXPOSE 3072

# `next start` reads PORT from the environment
CMD ["node_modules/.bin/next", "start", "-p", "3072"]
