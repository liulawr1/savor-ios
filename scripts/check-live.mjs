import { analyze, validateMeals, DEFAULT_MODEL } from '../server/ai.mjs';
import { writeFileSync } from 'node:fs';
const input = validateMeals({items:[
 {id:'chickpeas',name:'Canned chickpeas',quantity:'1 can',category:'Protein',useSoon:false},
 {id:'spinach',name:'Spinach',quantity:'2 handfuls',category:'Vegetables',useSoon:true},
 {id:'tomatoes',name:'Cherry tomatoes',quantity:'1 cup',category:'Vegetables',useSoon:true},
 {id:'oil',name:'Olive oil',quantity:'1 tablespoon',category:'Other',useSoon:false},
 {id:'lemon',name:'Lemon',quantity:'1',category:'Fruit',useSoon:false}
],minutes:15,servings:2,style:'Vegetarian',allowShopping:false});
try {
 const result = await analyze('meals', input, {apiKey:process.env.GEMINI_API_KEY,model:process.env.GEMINI_MODEL || DEFAULT_MODEL,signal:AbortSignal.timeout(45000)});
 writeFileSync(new URL('../docs/live-validation.json',import.meta.url), JSON.stringify({checkedAt:new Date().toISOString(),model:process.env.GEMINI_MODEL || DEFAULT_MODEL,input,result},null,2)+'\n');
 console.log(JSON.stringify({success:true,recipes:result.recipes.map(r=>({title:r.title,minutes:r.minutes,ingredients:r.ingredients.length}))}));
} catch(error) { console.log(JSON.stringify({success:false,status:error.status,message:error.message})); process.exitCode=1; }
