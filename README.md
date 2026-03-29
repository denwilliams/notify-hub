# NotifyHub

Personal notification aggregation system. Cloud systems push events to a Cloudflare Worker, which stores them in D1 and delivers urgent ones via Pushover. Native apps on Mac, iPhone, and iPad display the event timeline.

## Sending Events

```bash
curl -X POST https://your-worker.workers.dev/notify \
  -H "Content-Type: application/json" \
  -H "x-api-key: YOUR_API_KEY" \
  -d '{
    "title": "Deploy complete",
    "message": "v2.3.1 deployed to production",
    "source": "github",
    "urgent": false
  }'
```

### Required fields

| Field | Type | Description |
|---|---|---|
| `title` | string | Short summary |
| `message` | string | Detail text |
| `source` | string | System identifier (e.g. `github`, `aws`, `monitoring`) |
| `urgent` | boolean | `true` = immediate Pushover push, `false` = batched hourly |

### Optional fields

| Field | Type | Default | Description |
|---|---|---|---|
| `level` | string | `info` | `info`, `warn`, or `error` |
| `url` | string | `null` | Link to open on tap |

### Examples

```bash
# Urgent alert
curl -X POST https://your-worker.workers.dev/notify \
  -H "Content-Type: application/json" \
  -H "x-api-key: YOUR_API_KEY" \
  -d '{"title":"Server down","message":"prod-1 unreachable","source":"monitoring","urgent":true,"level":"error"}'

# Non-urgent with link
curl -X POST https://your-worker.workers.dev/notify \
  -H "Content-Type: application/json" \
  -H "x-api-key: YOUR_API_KEY" \
  -d '{"title":"PR merged","message":"#42 feature-x merged","source":"github","urgent":false,"url":"https://github.com/org/repo/pull/42"}'
```

## API

| Method | Path | Description |
|---|---|---|
| `POST` | `/notify` | Ingest a new event |
| `GET` | `/timeline?limit=50&cursor=ID` | Paginated event timeline |
| `PUT` | `/events/:id/read` | Mark event as read |
| `DELETE` | `/events/:id/read` | Mark event as unread |

All endpoints require `x-api-key` header.

## Development

### Prerequisites

- Node.js + npm
- Xcode (for native apps)
- Wrangler CLI (`npm install`)

### Setup

```bash
npm install
cp NotifyHub/Secrets.xcconfig.example NotifyHub/Secrets.xcconfig
# Edit Secrets.xcconfig with your WORKER_HOST and API_KEY
```

### Build & Run

| Command | Description |
|---|---|
| `make dev` | Local worker dev server |
| `make test` | Run backend tests |
| `make deploy` | Deploy worker to Cloudflare |
| `make build-mac` | Build macOS app → `build/NotifyHub.app` |
| `make run-mac` | Build + launch macOS app |
| `make install-mac` | Build + install to `/Applications` |
| `make build-ios` | Build iOS for simulator |
| `make run-ios` | Build + launch on iPhone simulator |
| `make install-iphone` | Build + install to connected iPhone |
| `make install-ipad` | Build + install to connected iPad |
| `make generate` | Regenerate Xcode project |
