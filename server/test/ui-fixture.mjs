// Local-only deterministic HTTP fixture for simulator tests. Never calls Gemini.
import { makeServer } from '../app.mjs';
import { APIError, validateMealOutput, validateAdjustmentOutput } from '../ai.mjs';
const server = makeServer({ apiKey: 'fixture-not-a-provider-key', clientToken: 'savor-ui-fixture-token-32-characters', limit: 500,
 analyzeImpl: async (kind, input) => {
  if (kind === 'scan') return { items: [], note: 'Use manual entry in this test.' };
  if (kind === 'adjust' && input.adjustment.includes('fail')) throw new APIError(503, 'The test AI is temporarily unavailable. Your original is unchanged.');
  if (kind === 'adjust' && input.adjustment.includes('slow')) await new Promise(resolve => setTimeout(resolve, 2500));
  const item = input.items[0];
  const recipe = { requiredEquipment: [kind === 'adjust' ? 'microwave' : 'stovetop'], title: kind === 'adjust' ? 'Microwave chickpea bowl' : 'Warm chickpea bowl', description: 'A simple meal using your pantry.', minutes: 10, servings: input.servings, ingredients: [{ pantryID: item.id, name: item.name, quantity: '1 can' }, { pantryID: 'water', name: 'Water', quantity: '1 tablespoon' }], steps: kind === 'adjust' ? ['Drain and rinse chickpeas into a microwave-safe bowl with water.', 'Cover loosely and heat in short intervals, stirring until hot.'] : ['Drain and rinse the canned chickpeas.', 'Warm the chickpeas with water on the stovetop.'], why: 'Uses the chickpeas already in your pantry.' };
  return kind === 'adjust' ? validateAdjustmentOutput({ recipes: [recipe], adjustmentSummary: 'Changed stovetop heating to microwave heating using the same pantry ingredients.' }, input) : validateMealOutput({ recipes: [recipe] }, input);
 } });
server.listen(8790, '127.0.0.1', () => console.log('Savor UI fixture ready on 8790; no Gemini calls.'));
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => { server.closeAllConnections(); server.close(); });
