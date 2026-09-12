// Opt-in: one real Gemini request through the local HTTP adjustment endpoint.
import { readFile, writeFile } from 'node:fs/promises';
import { once } from 'node:events';
import { randomBytes } from 'node:crypto';
import assert from 'node:assert/strict';
import { makeServer } from '../server/app.mjs';
import { DEFAULT_MODEL } from '../server/ai.mjs';
const previous = JSON.parse(await readFile(new URL('../docs/live-validation.json', import.meta.url), 'utf8'));
const request = { ...previous.input, original: previous.result.recipes[0], adjustment: "I only have a microwave and I am out of lemon. Adapt this recipe without lemon, using microwave-safe equipment.", excludedIDs: [], equipment: ['microwave'] };
const token = randomBytes(32).toString('hex');
const model = process.env.GEMINI_MODEL || DEFAULT_MODEL;
const server = makeServer({ apiKey: process.env.GEMINI_API_KEY, clientToken: token, model });
server.listen(0, '127.0.0.1'); await once(server, 'listening');
try {
 const response = await fetch(`http://127.0.0.1:${server.address().port}/v1/adjust`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` }, body: JSON.stringify(request) });
 const result = await response.json();
 if (!response.ok) throw new Error(`HTTP ${response.status}: ${result.error}`);
 assert.ok(result.recipe.adjustmentSummary);
 assert.ok(result.recipe.steps.some(step => /microwave/i.test(step)));
 assert.ok(!result.recipe.ingredients.some(item => /lemon/i.test(item.name)));
 assert.equal(result.recipe.originalRecipeID, request.original.id);
 assert.ok(result.recipe.minutes <= request.minutes);
 assert.equal(result.recipe.servings, request.servings);
 await writeFile(new URL('../docs/adjustment-live-validation.json', import.meta.url), JSON.stringify({ checkedAt: new Date().toISOString(), model, request, result }, null, 2) + '\n');
 console.log(JSON.stringify({ title: result.recipe.title, minutes: result.recipe.minutes, changes: result.recipe.adjustmentSummary, ingredientNames: result.recipe.ingredients.map(i => i.name), steps: result.recipe.steps }, null, 2));
} finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
