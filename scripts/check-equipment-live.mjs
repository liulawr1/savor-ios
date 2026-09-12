// Opt-in: two real Gemini calls, using canned ingredients rather than personal data.
import { readFile, writeFile } from 'node:fs/promises';
import { once } from 'node:events';
import { randomBytes } from 'node:crypto';
import assert from 'node:assert/strict';
import { makeServer } from '../server/app.mjs';
import { DEFAULT_MODEL } from '../server/ai.mjs';
const fixture = JSON.parse(await readFile(new URL('../docs/live-validation.json', import.meta.url), 'utf8'));
const mealInput = { ...fixture.input, equipment: ['microwave'] };
const token = randomBytes(32).toString('hex');
const model = process.env.GEMINI_MODEL || DEFAULT_MODEL;
const server = makeServer({ apiKey: process.env.GEMINI_API_KEY, clientToken: token, model });
server.listen(0, '127.0.0.1'); await once(server, 'listening');
const post = async (path, body) => {
 const response = await fetch(`http://127.0.0.1:${server.address().port}${path}`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` }, body: JSON.stringify(body) });
 const result = await response.json();
 if (!response.ok) throw new Error(`HTTP ${response.status}: ${result.error}`);
 return result;
};
try {
 const meals = await post('/v1/meals', mealInput);
 assert.ok(meals.recipes.every(r => r.requiredEquipment.every(e => e === 'microwave')));
 const adjustmentInput = { ...mealInput, equipment: [], original: meals.recipes[0], excludedIDs: [], adjustment: 'I no longer have any heating equipment. Adapt this to cold preparation only.' };
 const adjusted = await post('/v1/adjust', adjustmentInput);
 assert.deepEqual(adjusted.recipe.requiredEquipment, []);
 await writeFile(new URL('../docs/equipment-live-validation.json', import.meta.url), JSON.stringify({ checkedAt: new Date().toISOString(), model, mealInput, meals, adjustmentInput, adjusted }, null, 2) + '\n');
 console.log(JSON.stringify({ generated: meals.recipes.map(r => ({ title: r.title, equipment: r.requiredEquipment })), adjusted: { title: adjusted.recipe.title, equipment: adjusted.recipe.requiredEquipment, changes: adjusted.recipe.adjustmentSummary } }, null, 2));
} finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
