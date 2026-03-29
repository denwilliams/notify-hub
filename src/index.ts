import { Hono } from "hono";
import type { Bindings } from "./types";
import { auth } from "./middleware/auth";
import notify from "./routes/notify";
import timeline from "./routes/timeline";
import read from "./routes/read";
import { handleCron } from "./cron";

const app = new Hono<{ Bindings: Bindings }>();

app.use("*", auth);

app.route("/notify", notify);
app.route("/timeline", timeline);
app.route("/events", read);

export default {
  fetch: app.fetch,
  async scheduled(event: ScheduledEvent, env: Bindings, ctx: ExecutionContext) {
    ctx.waitUntil(handleCron(env));
  },
};
