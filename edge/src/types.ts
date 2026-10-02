export interface Env {
  /** R2 bucket holding every photo. */
  MEDIA: R2Bucket;
  FIREBASE_PROJECT_ID: string;
  /** Comma-separated browser origins allowed to call the private routes. */
  ALLOWED_ORIGINS?: string;
  /** Base URL for returned media links; defaults to the request's own origin. */
  PUBLIC_BASE_URL?: string;
  /** Cloudflare Realtime TURN key id and API token (secrets). */
  TURN_KEY_ID?: string;
  TURN_API_TOKEN?: string;
  /** Local development only (`wrangler dev --var AUTH_EMULATOR:true`): accept the Auth emulator's unsigned tokens. */
  AUTH_EMULATOR?: string;
  /** Local development only: host:port of the Firestore emulator. */
  FIRESTORE_EMULATOR_HOST?: string;
}

export class HttpError extends Error {
  constructor(
    public readonly status: number,
    message: string,
  ) {
    super(message);
  }
}
