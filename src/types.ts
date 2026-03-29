export type Bindings = {
  DB: D1Database;
  API_KEY: string;
  PUSHOVER_TOKEN: string;
  PUSHOVER_USER: string;
  QUIET_START: string;
  QUIET_END: string;
  TZ_OFFSET: string;
};

export interface EventRow {
  id: number;
  title: string;
  message: string;
  source: string;
  level: string;
  urgent: number;
  url: string | null;
  pushed: number;
  read_at: string | null;
  created_at: string;
}
