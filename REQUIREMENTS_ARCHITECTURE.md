# NotifyHub — Requirements & Architecture

**Version:** 0.1  
**Status:** Draft  
**Author:** Dennis  
**Date:** March 2026

---

## 1. Overview

NotifyHub is a personal notification aggregation system. Cloud systems and automated processes push events to a central backend. Those events are stored in a timeline and surfaced to the owner across iPhone, iPad, and Mac via native apps. Urgent events trigger immediate push notifications via Pushover. Non-urgent events are batched and delivered on an hourly schedule with configurable quiet hours.

---

## 2. Goals

- Single ingest API for any cloud system to push events to
- Persistent timeline of all events, queryable by client apps
- Immediate delivery for urgent events via Pushover
- Batched hourly digest for non-urgent events
- No notification spam during quiet hours (except urgent)
- Native apps on iPhone, iPad, and Mac from a single Swift codebase
- Lightweight, low-cost infrastructure

## 3. Non-Goals

- Multi-user / multi-tenant support
- Updating or retracting sent notifications
- Complex alerting rules or routing logic
- Email delivery

---

## 4. Functional Requirements

### 4.1 Ingest API

| # | Requirement |
|---|---|
| F-01 | Any HTTP client can POST an event to a single endpoint |
| F-02 | Requests must authenticate with a static API key via `x-api-key` header |
| F-03 | Each event must carry: `title`, `message`, `source`, `urgent` |
| F-04 | Optional event fields: `level` (info / warn / error), `url` |
| F-05 | All events are persisted to the timeline regardless of urgency |
| F-06 | Urgent events (`urgent: true`) trigger an immediate Pushover notification |
| F-07 | Non-urgent events are stored with `pushed = false` for later batching |

### 4.2 Timeline API

| # | Requirement |
|---|---|
| F-08 | Client apps can retrieve the event timeline via an authenticated GET endpoint |
| F-09 | Timeline is returned in reverse chronological order |
| F-10 | Endpoint supports cursor-based pagination |
| F-11 | Response includes read/unread state per event |

### 4.3 Notification Delivery

| # | Requirement |
|---|---|
| F-12 | Urgent events are delivered via Pushover immediately, 24/7 |
| F-13 | Non-urgent events are batched and delivered via Pushover once per hour |
| F-14 | Batched delivery is suppressed during configured quiet hours |
| F-15 | If no unpushed events exist at batch time, no notification is sent |
| F-16 | Batch message groups events by source and summarises counts |
| F-17 | Quiet hours are configurable (default: 10pm–7am, Melbourne time) |

### 4.4 Mac App

| # | Requirement |
|---|---|
| F-18 | App runs persistently, launching at login with no menubar icon |
| F-19 | App displays a floating draggable panel (always on top) |
| F-20 | Panel is collapsible (collapsed: small tile, expanded: event list) |
| F-21 | Dock badge shows unread event count, clears when events are read |
| F-22 | Dock icon bounces on receipt of a new urgent event |

### 4.5 iPhone / iPad App

| # | Requirement |
|---|---|
| F-23 | App displays the full event timeline |
| F-24 | App badge shows unread count |
| F-25 | App performs background refresh to keep timeline current |
| F-26 | Pushover handles urgent push delivery (separate app) |

### 4.6 Read State Sync

| # | Requirement |
|---|---|
| F-27 | Read state is stored server-side in D1 (`read_at` column on `events`) |
| F-28 | Marking an event read on any device is reflected on all others via the timeline API |

---

## 5. Non-Functional Requirements

| # | Requirement |
|---|---|
| NF-01 | Ingest API must respond in < 300ms under normal load |
| NF-02 | Infrastructure cost must remain within Cloudflare / D1 free tier at personal scale |
| NF-03 | No sensitive credentials stored in source code; all via environment secrets |
| NF-04 | System must handle cold-start gracefully (Cloudflare Worker has no warm state) |
| NF-05 | iOS / Mac apps must not drain battery; poll interval minimum 60 seconds |

---

## 6. Architecture

### 6.1 System Diagram

```
 Cloud Systems
 (GitHub Actions, AWS Lambda,
  Cloudflare Workers, scripts, etc.)
          │
          │  POST /notify
          │  x-api-key: <secret>
          ▼
  ┌───────────────────────┐
  │   Cloudflare Worker   │  ← Hono router, TypeScript
  │   notify-hub          │
  └──────────┬────────────┘
             │
     ┌───────┴────────┐
     │                │
     ▼                ▼
  Cloudflare D1    Pushover API
  (SQLite)         (urgent only)
  events table          │
     │                  ▼
     │           iPhone / iPad
     │           (Pushover app)
     │
     │  GET /timeline
     │  PUT /events/:id/read
     │  DELETE /events/:id/read
     │  x-api-key: <secret>
     ▼
  ┌─────────────────────────────┐
  │   NotifyHub.app (SwiftUI)   │
  │   iPhone / iPad / Mac       │
  └─────────────────────────────┘
```

### 6.2 Cloudflare Worker

**Runtime:** Cloudflare Workers (TypeScript)  
**Router:** Hono  
**Database:** Cloudflare D1 (SQLite)  
**Cron:** Cloudflare Workers Cron Trigger  

#### Endpoints

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/notify` | API key | Ingest a new event |
| `GET` | `/timeline` | API key | Retrieve paginated event timeline |
| `PUT` | `/events/:id/read` | API key | Mark an event as read (no body) |
| `DELETE` | `/events/:id/read` | API key | Mark an event as unread (no body) |

#### Cron Schedule

```
0 * * * *    ← top of every hour, UTC
```

Cron handler checks local time against quiet window before dispatching the batch. If within quiet hours, exits immediately without sending.

#### Environment Variables

| Variable | Type | Description |
|---|---|---|
| `API_KEY` | Secret | Shared key for ingest and timeline auth |
| `PUSHOVER_TOKEN` | Secret | Pushover application token |
| `PUSHOVER_USER` | Secret | Pushover user key |
| `QUIET_START` | Var | Quiet hours start (24h, local time). Default: `22` |
| `QUIET_END` | Var | Quiet hours end (24h, local time). Default: `7` |
| `TZ_OFFSET` | Var | UTC offset for quiet hour calculation. Default: `11` (AEDT) |

### 6.3 D1 Database Schema

```sql
CREATE TABLE events (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  title       TEXT    NOT NULL,
  message     TEXT    NOT NULL,
  source      TEXT    NOT NULL,
  level       TEXT    NOT NULL DEFAULT 'info',   -- info | warn | error
  urgent      INTEGER NOT NULL DEFAULT 0,         -- 0 | 1
  url         TEXT,
  pushed      INTEGER NOT NULL DEFAULT 0,         -- 0 = pending batch, 1 = sent
  read_at     TEXT,                               -- null = unread, ISO 8601 timestamp = read
  created_at  TEXT    NOT NULL
);

CREATE INDEX idx_events_id_desc   ON events(id DESC);
CREATE INDEX idx_events_pushed    ON events(pushed, created_at);
CREATE INDEX idx_events_source    ON events(source);
```

### 6.4 Swift App (NotifyHub.app)

**Target:** SwiftUI Multiplatform (single Xcode target)  
**Destinations:** iPhone, iPad, macOS  
**Min OS:** iOS 17 / macOS 14  
**Read state sync:** `NSUbiquitousKeyValueStore` (iCloud KV)  

#### Module Structure

```
NotifyHub/
├── Shared/
│   ├── NotifyHubApp.swift          @main, platform branching
│   ├── ContentView.swift           Timeline list, event rows
│   ├── EventDetailView.swift       Expanded event, URL action
│   ├── NotificationStore.swift     @Observable state, polling, read tracking
│   ├── WorkerClient.swift          /timeline HTTP client
│   └── Models.swift                NotifyEvent, EventLevel
│
├── iOS/
│   ├── iOSApp.swift                UIApplicationDelegate, background fetch
│   └── AppBadge.swift              UNUserNotificationCenter badge management
│
└── macOS/
    ├── macOSApp.swift              NSApplicationDelegate, login item
    ├── FloatingPanel.swift         NSPanel subclass, always-on-top host
    ├── FloatingPanelController.swift  Collapse/expand, drag behaviour
    └── DockBadge.swift             NSApp.dockTile badge + bounce
```

#### Platform Behaviour Matrix

| Feature | iPhone | iPad | macOS |
|---|---|---|---|
| Timeline UI | SwiftUI list | SwiftUI list | SwiftUI list in NSPanel |
| Window style | Full screen / sheet | Split view | Floating NSPanel |
| Badge | `UNUserNotificationCenter` | `UNUserNotificationCenter` | `NSApp.dockTile` |
| Background updates | Background App Refresh | Background App Refresh | `DispatchSourceTimer` (60s) |
| Urgent attention | Pushover app (separate) | Pushover app (separate) | Dock bounce |
| Launch at login | Standard | Standard | `SMAppService.mainApp` |
| Menubar icon | N/A | N/A | None |

#### Polling Strategy

- **macOS:** `DispatchSourceTimer` fires every 60 seconds while app is running
- **iOS/iPad:** Background App Refresh, system-scheduled, minimum 60 second interval requested
- On foreground: immediate refresh on `scenePhase` change to `.active`

---

## 7. Data Flow

### 7.1 Urgent Event

```
1. Cloud system POSTs { urgent: true, ... } to /notify
2. Worker validates API key
3. Worker INSERTs event with pushed = 1 (immediately marked)
4. Worker POSTs to Pushover API with high priority
5. Pushover delivers to iPhone/iPad via APNs
6. Next time NotifyHub.app polls /timeline, event appears in list
```

### 7.2 Non-Urgent Event

```
1. Cloud system POSTs { urgent: false, ... } to /notify
2. Worker validates API key
3. Worker INSERTs event with pushed = 0
4. At next hourly cron tick:
   a. Check local time against quiet window — exit if quiet
   b. Query all events WHERE pushed = 0
   c. Group by source, format digest message
   d. POST digest to Pushover
   e. UPDATE events SET pushed = 1 for all included IDs
```

### 7.3 Read State Sync

```
1. User opens NotifyHub.app on any device
2. App fetches timeline from Worker — each event includes read_at
3. Unread count = events where read_at is null
4. User taps event → app sends PUT /events/:id/read
5. Other devices see updated read_at on next timeline poll
```

---

## 8. Event Payload Reference

### POST /notify

```jsonc
{
  "title": "Deploy complete",       // required — short summary
  "message": "v2.3.1 to prod",     // required — detail
  "source": "github",               // required — system identifier
  "urgent": false,                  // required — immediate push if true
  "level": "info",                  // optional — info | warn | error
  "url": "https://..."             // optional — opens on tap
}
```

### GET /timeline Response

```jsonc
{
  "events": [
    {
      "id": 42,
      "title": "Deploy complete",
      "message": "v2.3.1 to prod",
      "source": "github",
      "level": "info",
      "urgent": false,
      "url": "https://...",
      "created_at": "2026-03-29T10:00:00Z",
      "read_at": null
    }
  ],
  "next_cursor": 41   // null if no more pages
}
```

---

## 9. Infrastructure & Cost

| Component | Service | Tier | Est. Cost |
|---|---|---|---|
| Ingest + cron + timeline API | Cloudflare Workers | Free (100k req/day) | $0 |
| Event storage | Cloudflare D1 | Free (5M reads, 100k writes/day) | $0 |
| Push delivery | Pushover | One-time licence | ~$5 |
| Read state sync | Cloudflare D1 | Included in event storage | $0 |
| App distribution | Direct install / TestFlight | Free | $0 |
| **Total recurring** | | | **$0/month** |

---

## 10. Open Questions

| # | Question | Notes |
|---|---|---|
| OQ-01 | Should the timeline API require the same API key as ingest, or a separate read key? | Single key is simpler; separate keys allow revocation without changing senders |
| OQ-02 | ~~Should read state live in iCloud KV or be server-side on D1?~~ | **Resolved: server-side D1 with `read_at` column** |
| OQ-03 | Quiet hours: should urgent events ever respect quiet hours? | Current design: urgent always delivers. Could add `urgent_quiet` flag later |
| OQ-04 | Event retention: how long to keep events in D1? | No TTL defined yet — could add a cleanup cron after 30/90 days |
| OQ-05 | Mac floating panel default position: remember last drag position? | Should persist to `UserDefaults` across relaunches |

---

## 11. Milestones

| Phase | Deliverable |
|---|---|
| 1 | Cloudflare Worker: `/notify` ingest, D1 schema, Pushover urgent delivery |
| 2 | Cloudflare Worker: `/timeline` endpoint, hourly cron batch with quiet hours |
| 3 | SwiftUI shared timeline view + WorkerClient + iCloud read sync |
| 4 | iOS/iPad app: badge, background refresh, App Store / TestFlight |
| 5 | macOS app: floating NSPanel, dock badge + bounce, launch at login |
| 6 | End-to-end test: GitHub Action → Worker → Pushover → app |