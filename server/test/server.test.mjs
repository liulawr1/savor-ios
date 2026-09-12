import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { makeServer } from '../app.mjs';

const token = 'test-only-pairing-token-32-characters';
const input = { items: [{ id: 'peas', name: 'Chickpeas', quantity: '1 can', category: 'Protein', useSoon: true }], minutes: 15, servings: 2, style: 'Anything', allowShopping: false, equipment: ['stovetop', 'microwave'] };
const assessment = { recipes: [] };

async function fixture(t, options = {}) {
  const server = makeServer({ clientToken: token, apiKey: 'test-key', analyzeImpl: async () => assessment, ...options });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise(resolve => { server.closeAllConnections(); server.close(resolve); }));
  const base = `http://127.0.0.1:${server.address().port}`;
  return (path = '/v1/meals', body = input, extra = {}) => fetch(base + path, {
    method: path === '/health' ? 'GET' : 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    ...(path === '/health' ? {} : { body: JSON.stringify(body) }), ...extra
  });
}

test('requires pairing for health and analysis before any provider call', async t => {
  let calls = 0;
  const request = await fixture(t, { analyzeImpl: async () => { calls++; return assessment; } });
  for (const path of ['/health', '/v1/meals']) {
    const response = await request(path, input, { headers: {} });
    assert.equal(response.status, 401);
  }
  assert.equal(calls, 0);
});

test('healthy server and complete analysis serialize the app contract', async t => {
  const request = await fixture(t);
  assert.deepEqual(await (await request('/health')).json(), { status: 'ok', aiConfigured: true, model: 'gemini-3.6-flash' });
  const result = await request();
  assert.equal(result.status, 200);
  assert.equal(result.headers.get('cache-control'), 'no-store');
  assert.deepEqual(await result.json(), assessment);
});

test('missing provider key fails honestly instead of returning a practice result', async t => {
  const request = await fixture(t, { apiKey: '' });
  assert.equal((await (await request('/health')).json()).aiConfigured, false);
  const response = await request();
  assert.equal(response.status, 503);
  assert.match((await response.json()).error, /GEMINI_API_KEY/);
});

test('rejects malformed JSON and large requests before calling the AI', async t => {
  let calls = 0;
  const request = await fixture(t, { analyzeImpl: async () => { calls++; return assessment; } });
  assert.equal((await request('/v1/meals', input, { body: '{' })).status, 400);
  assert.equal((await request('/v1/meals', { ...input, notes: 'x'.repeat(3_100_001) })).status, 413);
  assert.equal(calls, 0);
});

test('enforces per-process hourly spend limit', async t => {
  let calls = 0;
  const request = await fixture(t, { limit: 1, analyzeImpl: async () => { calls++; return assessment; } });
  assert.equal((await request()).status, 200);
  assert.equal((await request()).status, 429);
  assert.equal(calls, 1);
});

test('limits concurrent analyses and frees slots when calls finish', async t => {
  const pending = [];
  const request = await fixture(t, { analyzeImpl: () => new Promise(resolve => pending.push(resolve)) });
  const first = request(); const second = request();
  for (let attempt = 0; pending.length < 2 && attempt < 100; attempt++) await new Promise(resolve => setTimeout(resolve, 5));
  assert.equal(pending.length, 2);
  assert.equal((await request()).status, 429);
  pending.forEach(resolve => resolve(assessment));
  assert.equal((await first).status, 200);
  assert.equal((await second).status, 200);
});

test('rejects weak pairing configuration at startup', () => {
  assert.throws(() => makeServer({ clientToken: 'short' }), /at least 32/);
  assert.throws(() => makeServer({ clientToken: token, limit: -1 }), /between 1 and 500/);
});
