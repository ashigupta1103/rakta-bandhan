// Rakta Bandhan edge Worker. Cloudflare's free plan, so it works while Firebase
// is still on Spark. See docs/launch/SPARK_NOW.md.
//
//   GET  /health                       liveness, no sign-in
//   PUT|GET|DELETE /media/{kind}/{uid}/{name}   photos on R2 (media.ts)
//   POST /ice                          call-relay credentials (ice.ts)

import { handleIce } from './ice.js';
import { handleMedia, isPublic, parseMediaPath } from './media.js';
import { Env, HttpError } from './types.js';

const METHODS = 'GET, HEAD, PUT, DELETE, POST, OPTIONS';

/** Public photos may be read from anywhere (the link is the secret); everything else only from the allowed origins. */
function corsHeaders(request: Request, env: Env): Headers {
  const h = new Headers();
  const origin = request.headers.get('origin');
  const media = parseMediaPath(new URL(request.url).pathname);
  const publicRead = media !== null && isPublic(media.kind) && (request.method === 'GET' || request.method === 'HEAD');
  if (publicRead) {
    h.set('access-control-allow-origin', '*');
  } else if (origin && (env.ALLOWED_ORIGINS ?? '').split(',').some((o) => o.trim() === origin)) {
    h.set('access-control-allow-origin', origin);
    h.set('vary', 'Origin');
  }
  return h;
}

async function route(request: Request, env: Env): Promise<Response> {
  const { pathname } = new URL(request.url);
  if (pathname === '/health') return Response.json({ ok: true });
  if (pathname === '/ice') return handleIce(request, env);
  const media = parseMediaPath(pathname);
  if (media) return handleMedia(request, env, media);
  throw new HttpError(404, 'Not found.');
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const cors = corsHeaders(request, env);
    if (request.method === 'OPTIONS') {
      cors.set('access-control-allow-methods', METHODS);
      cors.set('access-control-allow-headers', 'authorization, content-type');
      cors.set('access-control-max-age', '86400');
      return new Response(null, { status: 204, headers: cors });
    }
    let res: Response;
    try {
      res = await route(request, env);
    } catch (e) {
      if (e instanceof HttpError) {
        res = Response.json({ error: e.message }, { status: e.status });
      } else {
        console.error('unhandled', String(e));
        res = Response.json({ error: 'Something went wrong. Try again.' }, { status: 500 });
      }
    }
    // Responses from R2 or fetch() have immutable headers: copy before adding.
    const headers = new Headers(res.headers);
    cors.forEach((value, key) => headers.set(key, value));
    return new Response(res.body, { status: res.status, headers });
  },
} satisfies ExportedHandler<Env>;
