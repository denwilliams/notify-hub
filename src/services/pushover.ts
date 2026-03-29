const PUSHOVER_API = "https://api.pushover.net/1/messages.json";

export async function sendPushover(
  token: string,
  user: string,
  title: string,
  message: string,
  priority: number = 0,
  url?: string
): Promise<boolean> {
  const body: Record<string, string> = {
    token,
    user,
    title,
    message,
    priority: String(priority),
  };
  if (url) {
    body.url = url;
  }

  const res = await fetch(PUSHOVER_API, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(body).toString(),
  });

  return res.ok;
}
