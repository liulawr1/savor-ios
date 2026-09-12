import test from 'node:test';
import assert from 'node:assert/strict';
import { validateMeals, validateMealOutput, mealRequest, validateAdjustment, validateAdjustmentOutput } from '../ai.mjs';
const input = { items: [{ id: 'peas', name: 'Canned chickpeas', quantity: '1 can', category: 'Protein', useSoon: false }], minutes: 15, servings: 2, style: 'Anything', allowShopping: false, equipment: ['microwave'] };
const cold = { title: 'Chickpea salad', description: 'A simple cold bowl.', minutes: 5, servings: 2, ingredients: [{ pantryID: 'peas', name: 'Canned chickpeas', quantity: '1 can' }], steps: ['Drain and rinse the canned chickpeas.', 'Transfer to a bowl and serve.'], requiredEquipment: [], why: 'Uses ready-to-eat pantry food.' };
test('profile must be explicit and bounded; empty means no heating appliances', () => {
 for(const equipment of [undefined, null, 'microwave', ['toaster'], ['microwave', 'microwave'], ['microwave','stovetop','oven','kettle','blender']]) assert.throws(() => validateMeals({ ...input, equipment }), e => e.status === 400);
 assert.deepEqual(validateMeals({ ...input, equipment: [] }).equipment, []);
 assert.deepEqual(validateMeals(input).equipment, ['microwave']);
});
test('every recipe declares equipment, which must be a subset of the profile and style', () => {
 for(const requiredEquipment of [undefined, null, 'microwave', ['oven'], ['stovetop'], ['kettle'], ['blender'], ['microwave','microwave']]) assert.throws(() => validateMealOutput({ recipes: [{ ...cold, requiredEquipment }] }, input), e => e.status === 502);
 assert.deepEqual(validateMealOutput({ recipes: [{ ...cold, requiredEquipment: ['microwave'] }] }, input).recipes[0].requiredEquipment, ['microwave']);
 assert.throws(() => validateMealOutput({ recipes: [{ ...cold, requiredEquipment: ['oven'] }] }, { ...input, equipment: ['oven'], style: 'No oven' }), e => e.status === 502);
});
test('no-appliance and kettle-only profiles cannot silently acquire a heat source', () => {
 assert.deepEqual(validateMealOutput({ recipes: [cold] }, { ...input, equipment: [] }).recipes[0].requiredEquipment, []);
 assert.throws(() => validateMealOutput({ recipes: [{ ...cold, requiredEquipment: ['microwave'] }] }, { ...input, equipment: [] }), e => e.status === 502);
 assert.ok(validateMealOutput({ recipes: [{ ...cold, requiredEquipment: ['kettle'] }] }, { ...input, equipment: ['kettle'] }));
 const spec = mealRequest({ ...input, equipment: ['kettle'] });
 assert.deepEqual(JSON.parse(spec.parts[0].text).equipment, ['kettle']);
 assert.match(spec.instruction, /water-only kettle/);
 assert.ok(spec.schema.properties.recipes.items.required.includes('requiredEquipment'));
});
test('adjustments use the CURRENT profile even if the old recipe or free text wants an oven', () => {
 const context = validateAdjustment({ ...input, original: { ...cold, id: 'original', isSample: false, requiredEquipment: ['oven'], steps: ['Preheat the oven.', 'Bake the chickpeas.'] }, adjustment: 'Use the oven anyway.', excludedIDs: [] });
 assert.deepEqual(context.equipment, ['microwave']);
 assert.throws(() => validateAdjustmentOutput({ recipes: [{ ...cold, requiredEquipment: ['oven'] }], adjustmentSummary: 'Kept the oven.' }, context), e => e.status === 502);
 assert.ok(validateAdjustmentOutput({ recipes: [cold], adjustmentSummary: 'Switched to cold preparation.' }, context));
});
