import type { Bindings, EventRow } from "./types";
import { sendPushover } from "./services/pushover";

const MAX_MESSAGE_LENGTH = 900;

function isQuietHours(env: Bindings): boolean {
  const offset = parseInt(env.TZ_OFFSET, 10);
  const now = new Date();
  const localHour = (now.getUTCHours() + offset) % 24;

  const start = parseInt(env.QUIET_START, 10);
  const end = parseInt(env.QUIET_END, 10);

  // Handles wrapping (e.g., 22:00 -> 07:00)
  if (start > end) {
    return localHour >= start || localHour < end;
  }
  return localHour >= start && localHour < end;
}

function formatDigest(events: EventRow[]): string {
  const grouped = new Map<string, EventRow[]>();
  for (const event of events) {
    const list = grouped.get(event.source) ?? [];
    list.push(event);
    grouped.set(event.source, list);
  }

  const lines: string[] = [];
  let length = 0;
  let included = 0;

  for (const [source, sourceEvents] of grouped) {
    const header = `[${source}] ${sourceEvents.length} event${sourceEvents.length > 1 ? "s" : ""}`;

    if (length + header.length + 1 > MAX_MESSAGE_LENGTH) break;
    lines.push(header);
    length += header.length + 1;

    for (const event of sourceEvents) {
      const line = `  • ${event.title}`;
      if (length + line.length + 1 > MAX_MESSAGE_LENGTH) break;
      lines.push(line);
      length += line.length + 1;
      included++;
    }
  }

  if (included < events.length) {
    lines.push(`… and ${events.length - included} more`);
  }

  return lines.join("\n");
}

export async function handleCron(env: Bindings): Promise<void> {
  if (isQuietHours(env)) {
    return;
  }

  const { results: events } = await env.DB.prepare(
    `SELECT * FROM events WHERE pushed = 0 ORDER BY created_at ASC`
  ).all<EventRow>();

  if (events.length === 0) {
    return;
  }

  const digest = formatDigest(events);
  const title = `NotifyHub: ${events.length} new event${events.length > 1 ? "s" : ""}`;

  await sendPushover(env.PUSHOVER_TOKEN, env.PUSHOVER_USER, title, digest);

  const ids = events.map((e) => e.id);
  const placeholders = ids.map(() => "?").join(",");
  await env.DB.prepare(`UPDATE events SET pushed = 1 WHERE id IN (${placeholders})`)
    .bind(...ids)
    .run();
}
