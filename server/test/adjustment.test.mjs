import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { makeServer } from '../app.mjs';
import { validateAdjustment, adjustmentRequest, validateAdjustmentOutput, analyze } from '../ai.mjs';

const peas = { id: 'peas', name: 'Canned chickpeas', quantity: '1 can', category: 'Protein', useSoon: true };
const lemon = { id: 'lemon', name: 'Lemon', quantity: '1', category: 'Fruit', useSoon: false };
const original = { id: 'original', isSample: false, title: 'Lemon chickpeas', description: 'A quick warm bowl.', minutes: 10, servings: 2, ingredients: [{ pantryID: 'peas', name: peas.name, quantity: '1 can' }, { pantryID: 'lemon', name: 'Lemon', quantity: '1' }], steps: ['Drain the chickpeas.', 'Warm with lemon juice.'], why: 'Uses the pantry.' };
const input = { items: [peas, lemon], minutes: 15, servings: 2, style: 'Vegetarian', allowShopping: false, original, adjustment: 'I am out of lemon. Use a microwave.', excludedIDs: ['lemon'], equipment: ['stovetop', 'microwave'] };
const revised = { ...original, requiredEquipment: ['microwave'], title: 'Microwave chickpeas', ingredients: [original.ingredients[0]], steps: ['Drain and rinse the chickpeas into a microwave-safe bowl.', 'Add water, cover loosely and heat in short intervals, stirring until hot.'] };
const output = { recipes: [revised], adjustmentSummary: 'Removed lemon and replaced the stovetop method with microwave heating.' };

test('adjustments use current pantry, remove exclusions, and strip historical persistence fields', () => {
 const request = validateAdjustment({ ...input, original: { ...original, cookedAt: 'yesterday', preferences: { minutes: 500 } } });
 assert.deepEqual(request.items, [peas]); assert.deepEqual(request.excludedNames, ['Lemon']);
 assert.equal(request.original.cookedAt, undefined); assert.equal(request.original.preferences, undefined);
 // Old recipe references remain historical context even when the item has been removed.
 assert.ok(validateAdjustment({ ...input, items: [peas], excludedIDs: [] }));
 const spec = adjustmentRequest(request);
 assert.deepEqual(JSON.parse(spec.parts[0].text), request);
 assert.deepEqual(spec.schema.properties.recipes.items.properties.ingredients.items.properties.pantryID.enum, ['peas', 'water']);
 assert.equal(spec.schema.properties.recipes.maxItems, 1);
 assert.match(spec.instruction, /microwave/);
});
test('invalid revision requests stop before the provider', () => {
 for (const v of [{ ...input, adjustment: ' ' }, { ...input, adjustment: 'x'.repeat(601) }, { ...input, excludedIDs: ['unknown'] }, { ...input, excludedIDs: ['lemon', 'lemon'] }, { ...input, original: { ...original, isSample: true } }, { ...input, original: { ...original, steps: ['x'.repeat(701)] } }, { ...input, original: { ...original, ingredients: null } }, { ...input, minutes: 100 }]) assert.throws(() => validateAdjustment(v), e => e.status === 400);
 assert.throws(() => validateAdjustment({ ...input, excludedIDs: ['peas', 'lemon'] }), e => e.status === 422);
});
test('one fresh revision carries server-owned ancestry, explanation and preferences', () => {
 const recipe = validateAdjustmentOutput({ ...output, recipes: [{ ...revised, id: original.id, completedSteps: [0, 1], cookedAt: 'today', originalRecipeID: 'forged' }] }, validateAdjustment(input)).recipe;
 assert.notEqual(recipe.id, original.id); assert.equal(recipe.originalRecipeID, original.id);
 assert.equal(recipe.completedSteps, undefined); assert.equal(recipe.cookedAt, undefined); assert.equal(recipe.isSample, false);
 assert.equal(recipe.adjustmentSummary, output.adjustmentSummary);
 assert.deepEqual(recipe.preferences, { minutes: 15, servings: 2, style: 'Vegetarian', allowShopping: false });
});
test('revisions reject unavailable ingredients, extras without opt-in, wrong limits and bad summaries', () => {
 const context = validateAdjustment(input);
 for (const v of [{ ...output, adjustmentSummary: '' }, { ...output, adjustmentSummary: 'x'.repeat(601) }, { ...output, recipes: [revised, revised] }, { ...output, recipes: [original] }, { ...output, recipes: [{ ...revised, minutes: 30 }] }, { ...output, recipes: [{ ...revised, servings: 4 }] }, { ...output, recipes: [{ ...revised, ingredients: [...revised.ingredients, { pantryID: 'missing', name: 'Oil', quantity: '1 tbsp' }] }] }]) assert.throws(() => validateAdjustmentOutput(v, context), e => e.status === 502);
 assert.throws(() => validateAdjustmentOutput({ recipes: [], adjustmentSummary: 'Not feasible.' }, context), e => e.status === 422 && /original recipe is unchanged/.test(e.message));
 // Excluded food cannot be added back as a shopping item even with shopping enabled.
 const shopping = validateAdjustment({ ...input, allowShopping: true });
 assert.throws(() => validateAdjustmentOutput({ ...output, recipes: [{ ...revised, ingredients: [...revised.ingredients, { pantryID: 'missing', name: 'LEMON', quantity: '1' }] }] }, shopping), e => e.status === 502);
});
test('adjustment endpoint authenticates, validates and returns a generated revision through the full pipeline', async t => {
 let calls = 0;
 const server = makeServer({ apiKey: 'test-key', clientToken: 'test-only-adjustment-token-32-characters', limit: 1,
  analyzeImpl: (kind, data, options) => analyze(kind, data, { ...options, fetchImpl: async (url, request) => {
   calls++; const body = JSON.parse(request.body);
   assert.match(url, /:generateContent$/); assert.equal(request.headers['x-goog-api-key'], 'test-key');
   const context = JSON.parse(body.contents[0].parts[0].text);
   assert.equal(context.adjustment, input.adjustment); assert.deepEqual(context.items, [peas]);
   return Response.json({ candidates: [{ finishReason: 'STOP', content: { parts: [{ text: JSON.stringify(output) }] } }] });
  } }) });
 server.listen(0, '127.0.0.1'); await once(server, 'listening');
 t.after(() => new Promise(resolve => { server.closeAllConnections(); server.close(resolve); }));
 const send = (body, token = 'test-only-adjustment-token-32-characters') => fetch(`http://127.0.0.1:${server.address().port}/v1/adjust`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` }, body: JSON.stringify(body) });
 assert.equal((await send(input, 'bad')).status, 401);
 assert.equal((await send({ ...input, adjustment: '' })).status, 400); assert.equal(calls, 0);
 const response = await send(input); assert.equal(response.status, 200); const result = await response.json();
 assert.equal(result.recipe.originalRecipeID, original.id); assert.equal(result.recipe.title, revised.title);
 assert.equal((await send(input)).status, 429); assert.equal(calls, 1);
});
