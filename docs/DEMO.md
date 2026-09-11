# Savor demo walkthrough

Aim for 90–120 seconds. Use the actual iPhone simulator UI and clearly identify the sample kitchen when showing it.

1. **Problem (10s):** “Students buy ingredients, then struggle to turn what’s left into a meal. Savor starts with what’s already in your kitchen.” Show the pantry and Use soon flags.
2. **Capture (20s):** In your own pantry, photograph a few recognizable ingredients, tap Scan ingredients, correct any uncertain names or amounts, and add the reviewed items. If scanning fails or quota is unavailable, say so and use manual entry. Don’t represent prepared sample data as a live scan.
3. **AI value (25s):** Select a cooking time and servings. Leave extras off and find meals. Show how a recipe uses pantry ingredients and prioritizes Use soon items. Show that missing items are listed explicitly when extras are enabled.
4. **Complete the loop (25s):** Save a recipe, check off its cooking steps, and mark it made. Select only the ingredients completely used up. Return to the pantry and recipe box.
5. **Technical depth (15s):** SwiftUI iOS app; Gemini multimodal extraction and structured recipe generation; server-side validation of pantry references, time, servings, and shopping limits; local persistence; credentials kept off GitHub.
6. **Honest scope (5s):** “This is the working local MVP. Public hosting and per-user authentication are the next deployment step.”

Before recording, test a real food photo, an unclear photo, a non-food image, a limited pantry, and an ingredient marked Use soon. Review recipes before cooking. Never show keys, `.env`, `Local.xcconfig`, or a terminal that contains credentials.

The offline sample kitchen is a rehearsal tool. Reset it in Settings if you remove its ingredients. Its meals are explicitly excluded from the real meals-made count.
