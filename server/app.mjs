import { createServer } from 'node:http';
import { timingSafeEqual } from 'node:crypto';
import { APIError, analyze, validateScan, validateMeals, validateAdjustment, DEFAULT_MODEL } from './ai.mjs';

const MAX_BODY = 3_100_000;
function authorized(header, token) {
  const candidate = Buffer.from(header ?? '');
  const expected = Buffer.from(`Bearer ${token}`);
  return candidate.length === expected.length && timingSafeEqual(candidate, expected);
}
async function readJSON(request) {
  if (!request.headers['content-type']?.toLowerCase().startsWith('application/json')) throw new APIError(415, 'Send JSON.');
  if (Number(request.headers['content-length'] ?? 0) > MAX_BODY) throw new APIError(413, 'This photo is too large. Try a smaller photo.');
  let size = 0;
  const chunks = [];
  for await (const chunk of request) {
    size += chunk.length;
    if (size > MAX_BODY) throw new APIError(413, 'This photo is too large. Try a smaller photo.');
    chunks.push(chunk);
  }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { throw new APIError(400, 'The request was not valid JSON.'); }
}

export function makeServer({ apiKey, clientToken, model = DEFAULT_MODEL, limit = 20, timeoutMs = 45_000, analyzeImpl = analyze }) {
  if (!clientToken || clientToken.length < 32) throw new Error('Set SAVOR_CLIENT_TOKEN to a random token of at least 32 characters. Run npm run setup.');
  if (!Number.isInteger(limit) || limit < 1 || limit > 500) throw new Error('SAVOR_REQUESTS_PER_HOUR must be between 1 and 500.');
  let requestTimes = [];
  let active = 0;
  const server = createServer(async (request, response) => {
    const send = (status, body) => {
      if (response.destroyed || response.writableEnded) return;
      response.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
      response.end(JSON.stringify(body));
    };
    try {
      const path = new URL(request.url, 'http://localhost').pathname;
      if (!authorized(request.headers.authorization, clientToken)) throw new APIError(401, 'The development connection needs attention. Run the server setup script and rebuild the app.');
      if (request.method === 'GET' && path === '/health') {
        return send(200, { status: 'ok', aiConfigured: Boolean(apiKey), model });
      }
      if (request.method !== 'POST' || !['/v1/scan', '/v1/meals', '/v1/adjust'].includes(path)) throw new APIError(404, 'Endpoint not found.');
      if (!apiKey) throw new APIError(503, 'Add GEMINI_API_KEY to the server’s .env file and restart it.');
      requestTimes = requestTimes.filter(time => time > Date.now() - 3_600_000);
      if (requestTimes.length >= limit) throw new APIError(429, 'This demo has reached its hourly analysis limit. Try again later.');
      if (active >= 2) throw new APIError(429, 'Two requests are already in progress. Please wait.');
      active++;
      const controller = new AbortController();
      const deadline = setTimeout(() => controller.abort(), timeoutMs);
      const onClose = () => { if (!response.writableEnded) controller.abort(); };
      response.on('close', onClose);
      try {
        const kind = path === '/v1/scan' ? 'scan' : path === '/v1/adjust' ? 'adjust' : 'meals';
        const input = (kind === 'scan' ? validateScan : kind === 'adjust' ? validateAdjustment : validateMeals)(await readJSON(request));
        // Reserve the quota synchronously after body validation, before any API call.
        if (requestTimes.length >= limit) throw new APIError(429, 'This demo has reached its hourly analysis limit. Try again later.');
        requestTimes.push(Date.now());
        const result = await analyzeImpl(kind, input, { apiKey, model, signal: controller.signal });
        send(200, result);
      } finally {
        clearTimeout(deadline); response.removeListener('close', onClose); active--;
      }
    } catch (error) {
      // Never log photos, user notes, provider response bodies, or credentials.
      send(error instanceof APIError ? error.status : 500, { error: error instanceof APIError ? error.message : 'Something went wrong. Please try again.' });
    }
  });
  server.requestTimeout = 60_000;
  server.headersTimeout = 10_000;
  server.keepAliveTimeout = 5000;
  return server;
}
