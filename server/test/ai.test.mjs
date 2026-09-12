import test from 'node:test';
import assert from 'node:assert/strict';
import { validateMeals, validateScan, validateMealOutput, validateScanOutput, generate, mealRequest, scanRequest } from '../ai.mjs';
export const input = { items: [{ id: 'peas', name: 'Canned chickpeas', quantity: '1 can', category: 'Protein', useSoon: true }], minutes: 15, servings: 2, style: 'Anything', allowShopping: false, equipment: ['stovetop', 'microwave'] };
const recipe = { requiredEquipment: ['stovetop'], title: 'Warm chickpeas', description: 'A simple pantry bowl.', minutes: 10, servings: 2, ingredients: [{ pantryID: 'peas', name: 'Canned chickpeas', quantity: '1 can' }], steps: ['Drain and rinse the chickpeas.', 'Warm gently with a splash of water and serve.'], why: 'Uses your chickpeas.' };
const clone = v => structuredClone(v);
test('input bounds reject unbounded data, invalid categories, duplicate and reserved IDs', () => {
 assert.deepEqual(validateMeals(input), input);
 for (const i of [{ ...input, items: [] }, { ...input, items: [input.items[0], input.items[0]] }, { ...input, minutes: 500 }, { ...input, servings: 10 }, { ...input, allowShopping: 'yes' }, { ...input, items: [{ ...input.items[0], id: 'water' }] }, { ...input, items: [{ ...input.items[0], name: 'x'.repeat(61) }] }]) assert.throws(() => validateMeals(i), e => e.status === 400);
});
test('scan only accepts bounded, canonical JPEG input', () => {
 assert.deepEqual(validateScan({ imageBase64: '/9j/2Q==' }), { imageBase64: '/9j/2Q==' });
 for (const imageBase64 of ['', 'notimage', 'data:image/jpeg;base64,abc', 'A'.repeat(3_000_001)]) assert.throws(() => validateScan({ imageBase64 }), e => e.status === 400);
});
test('scan results contain only reviewed fields and bounded familiar categories', () => {
 assert.deepEqual(validateScanOutput({ items: [], note: 'Try a food photo.' }), { items: [], note: 'Try a food photo.' });
 assert.throws(() => validateScanOutput({ items: [{ name: 'Apple', quantity: '1', category: 'Secret' }], note: 'Check it.' }), e => e.status === 502);
});
test('recipes preserve real IDs and canonical pantry names, never model-added persistence fields', () => {
 const r = clone(recipe); r.ingredients[0].name = 'Imagined substitute'; r.isSample = true; r.cookedAt = 'tomorrow';
 const result = validateMealOutput({ recipes: [r] }, input).recipes[0];
 assert.equal(result.ingredients[0].name, 'Canned chickpeas'); assert.equal(result.isSample, false); assert.equal(result.cookedAt, undefined);
});
test('pantry-only validation rejects missing and invented ingredients', () => {
 for (const pantryID of ['missing', 'invented']) { const r = clone(recipe); r.ingredients.push({ pantryID, name: 'Oil', quantity: '1 tbsp' }); assert.throws(() => validateMealOutput({ recipes: [r] }, input), e => e.status === 502); }
});
test('extras require opt-in and are capped at three; water is allowed', () => {
 const r = clone(recipe); r.ingredients.push({ pantryID: 'water', name: 'Tap water', quantity: '1 tbsp' });
 assert.equal(validateMealOutput({ recipes: [r] }, input).recipes[0].ingredients[1].name, 'Water');
 for (let i = 0; i < 3; i++) r.ingredients.push({ pantryID: 'missing', name: 'Extra '+i, quantity: '1' });
 assert.ok(validateMealOutput({ recipes: [r] }, { ...input, allowShopping: true }));
 r.ingredients.push({ pantryID: 'missing', name: 'Too many', quantity: '1' });
 assert.throws(() => validateMealOutput({ recipes: [r] }, { ...input, allowShopping: true }), e => e.status === 502);
});
test('impossible, oversized and off-constraint recipes fail without fabricated results', () => {
 assert.throws(() => validateMealOutput({ recipes: [] }, input), e => e.status === 422);
 for (const r of [{ ...recipe, minutes: 99 }, { ...recipe, servings: 1 }, { ...recipe, steps: ['Only one'] }, { ...recipe, ingredients: [{ pantryID: 'water', name: 'Water', quantity: '1 cup' }] }]) assert.throws(() => validateMealOutput({ recipes: [r] }, input), e => e.status === 502);
});
test('Gemini requests carry image bytes or pantry context, schema, and header-only credentials', async () => {
 const scan = scanRequest({ imageBase64: '/9j/2Q==' }); assert.equal(scan.parts[0].inlineData.data, '/9j/2Q==');
 const spec = mealRequest(input); assert.deepEqual(JSON.parse(spec.parts[0].text), input);
 const result = await generate(spec, { apiKey: 'test-key', fetchImpl: async (url, options) => {
  assert.equal(new URL(url).hostname, 'generativelanguage.googleapis.com'); assert.equal(new URL(url).search, ''); assert.equal(options.headers['x-goog-api-key'], 'test-key');
  const body = JSON.parse(options.body); assert.equal(body.generationConfig.responseMimeType, 'application/json'); assert.equal(body.generationConfig.thinkingConfig.thinkingLevel, 'minimal');
  return Response.json({ candidates: [{ finishReason: 'STOP', content: { parts: [{ thought: true, text: 'ignore' }, { text: '{"recipes":[]}' }] } }] });
 } }); assert.deepEqual(result, { recipes: [] });
});
test('provider refusals, truncation, malformed responses, and quota failures are recoverable', async () => {
 for (const envelope of [{ promptFeedback: { blockReason: 'SAFETY' } }, { candidates: [{ finishReason: 'MAX_TOKENS' }] }, null, { candidates: [{ finishReason: 'STOP', content: { parts: [{ text: '{' }] } }] }]) await assert.rejects(generate(mealRequest(input), { apiKey: 'test-key', fetchImpl: async () => Response.json(envelope) }), e => e.status >= 400);
 await assert.rejects(generate(mealRequest(input), { apiKey: 'test-key', fetchImpl: async () => new Response('secret upstream detail', { status: 429 }) }), e => e.status === 503 && !e.message.includes('secret') && !e.message.includes('billing'));
 const controller = new AbortController(); controller.abort();
 await assert.rejects(generate(mealRequest(input), { apiKey: 'test-key', signal: controller.signal, fetchImpl: async () => { throw new Error('private details'); } }), e => e.status === 504);
});
