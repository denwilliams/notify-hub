# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

NotifyHub is a personal (single-user) notification aggregation system. Cloud systems POST events to a Cloudflare Worker, which stores them in D1 and optionally pushes urgent ones via Pushover. Native Apple apps (iPhone, iPad, Mac) display the event timeline. See `REQUIREMENTS_ARCHITECTURE.md` for the full spec.

## Architecture

Two main components share this repo:

### 1. Cloudflare Worker (TypeScript + Hono)

- **Runtime:** Cloudflare Workers with Hono router
- **Database:** Cloudflare D1 (SQLite) — single `events` table
- **Endpoints:** `POST /notify` (ingest), `GET /timeline` (paginated, cursor-based), `PUT /events/:id/read` (mark read), `DELETE /events/:id/read` (mark unread)
- **Auth:** Static API key via `x-api-key` header on all endpoints
- **Cron:** Hourly trigger batches unpushed non-urgent events into a Pushover digest, respecting configurable quiet hours (default 22:00–07:00 Melbourne time)
- **Urgent flow:** Immediate Pushover push + `pushed=1` on insert
- **Non-urgent flow:** Insert with `pushed=0`, batch at next cron tick outside quiet hours

### 2. SwiftUI App (NotifyHub.app — multiplatform)

- **Single Xcode target** for iPhone, iPad, macOS (iOS 17+ / macOS 14+)
- **Shared code:** timeline UI, HTTP client (`WorkerClient`), models, iCloud KV sync
- **iOS-specific:** background app refresh, `UNUserNotificationCenter` badge
- **macOS-specific:** floating `NSPanel` (always-on-top, draggable, collapsible), dock badge + bounce, launch-at-login via `SMAppService`, no menubar icon
- **Read state:** server-side on D1 (`read_at` column), via `PUT /events/:id/read` and `DELETE /events/:id/read`
- **Config:** build-time secrets via `Secrets.xcconfig` (gitignored), values injected into Info.plist
- **Polling:** macOS uses `DispatchSourceTimer` (60s); iOS uses Background App Refresh; all platforms refresh immediately on foreground

### Key environment variables (Worker)

`API_KEY`, `PUSHOVER_TOKEN`, `PUSHOVER_USER` (secrets); `QUIET_START`, `QUIET_END`, `TZ_OFFSET` (vars).

## Build & Dev Commands

### Worker

```bash
npm install                  # install dependencies
npx wrangler dev             # local dev server
npx wrangler deploy          # deploy to Cloudflare
npx wrangler d1 execute notify-hub-db --local --file=schema.sql  # apply schema locally
```

### Swift App

```bash
xcodebuild -scheme NotifyHub -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme NotifyHub -destination 'platform=macOS' build
open NotifyHub.xcodeproj     # or .xcworkspace if one exists
```

## Design Constraints

- Single-user system — no multi-tenancy, no user management
- Must stay within Cloudflare free tier (100k req/day, 5M D1 reads/day)
- Worker must handle cold starts gracefully (no warm state)
- iOS/Mac apps must not drain battery — minimum 60s poll interval
- Pushover is the only push delivery channel (no APNs direct, no email)
