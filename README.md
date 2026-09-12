# Savor

**Good food. Already here.** A native SwiftUI pantry-to-meal app for turning ingredients on hand into something worth cooking.

Savor is a separate project from Mend. It uses Xcode, Swift, Git, and a small Node server with Google Gemini. No third-party iOS packages or Node dependencies are required.

## Run on this Mac

1. In Terminal:

   ```sh
   cd "/Users/lawrence/Documents/Codex/2026-09-09/i-am/outputs/Savor/server"
   npm start
   ```

2. Open **Savor.xcodeproj** in Xcode.
3. Select the **Savor** scheme and **iPhone 17 Pro** simulator, then press **⌘R**.
4. Choose **Add my first ingredients**, or **Explore the sample kitchen** to try the offline workflow.

The existing Gemini key was copied locally with permission. Development pairing was generated automatically. There is no server address or token to enter in the app. Keep the Terminal server running for live AI. Savor uses port **8788**, so it can run alongside Mend.

If you change your local server settings, run `npm run setup` and rebuild the app. The app’s Settings screen can check the connection without making an AI call.

## What works

- Manual ingredient entry with quantities and categories.
- Camera and PhotosPicker input; images are re-encoded as JPEG and resized before upload.
- Gemini photo recognition followed by an editable review before ingredients enter the pantry.
- User-controlled **Use soon** flags, search, editing, and removal.
- Meal generation with time, servings, cooking style, and optional missing ingredients.
- Pantry-only requests include no presumed oil, salt, or seasonings. Water is allowed.
- Server-side validation of pantry IDs, serving counts, time limits, output bounds, and the maximum of three missing ingredients per recipe.
- Saved recipes, sharing, step checklists, persistent progress, and meal completion.
- **Kitchen equipment profile**: save microwave, stovetop, oven, and kettle availability; all generated meals and revisions declare required equipment and are checked against the current profile.
- **Make this work**: adjust a generated recipe for a missing ingredient or different equipment, review the changes and full revised recipe, then save both versions with separate progress.
- Explicit selection of ingredients used up; no guessed quantity deductions.
- A labeled offline sample kitchen with three prepared recipes. Samples are excluded from real meals-made counts.
- Custom native bowl illustration and app icon. Illustrations are not generated photos of the suggested meal.

Recipe suggestions are not guaranteed to be nutritionally balanced, allergen-free, safe, or feasible. Check ingredient labels, freshness, quantities, and cooking instructions. **Use soon** is an intention, not a shelf-life calculation. No expiry prediction, environmental-savings estimate, or nutrition estimate is made.

## Set up your kitchen equipment

Go to **Pantry → Settings (sliders icon) → Kitchen equipment → Edit equipment**, or tap **Your equipment** on Cook or the adjustment screen. Select microwave, stovetop, oven, and/or kettle, then tap **Save**. You only need to do this once unless your kitchen changes.

The profile starts unset, including when upgrading an existing pantry; no appliances are assumed. Save with all switches off for **No heating equipment**, which requests cold-preparation meals. The app assumes basic utensils and appropriate cookware; kettle means an electric kettle for boiling water only.

Every meal-generation and recipe-adjustment request includes the current profile. Gemini must return a `requiredEquipment` list for every recipe; the server rejects unknown, duplicate, unavailable, or style-incompatible entries (for example oven with No oven selected). Recipe details and revision previews show **Equipment needed**. Natural-language steps still need review: checking the declared list cannot prove that Gemini listed every appliance correctly.

Changing the profile preserves pantry items, saved recipes, and cooking progress. Existing suggestions remain available and show a warning if their listed equipment is outside the new profile. Older recipes without equipment data are labeled as not recorded; they are never assumed to need no equipment. Use **Make this work** to request a revision against your current kitchen. Sample recipes show their equipment for reference and remain offline; resetting or leaving the sample preserves your personal equipment profile. Photo scanning does not involve cooking equipment and is unchanged.

Restart the server and rebuild the app after this update. Older clients that omit equipment receive a setup error rather than unrestricted recipes.

## Adjust a recipe

Open a live AI recipe from **Cook** or **Recipe box**, then tap **Make this work** below its explanation.

1. Describe the change, such as “Can I use a microwave?” or “I’m out of lemon.” There is also a microwave shortcut.
2. Check your equipment profile, time limit, servings, cooking style, and extras setting. New recipes remember their generation preferences. Older recipes still open normally and ask you to review fallback preferences.
3. Optionally expand **Leave out ingredients** to explicitly exclude pantry items from this revision. This does not edit your pantry.
4. Tap **Adjust recipe**. This makes one Gemini request through `/v1/adjust`, sharing the current pantry, original recipe, preferences, and change request.
5. Review **What changed**, the ingredients, and the new steps. Choose **Use this version**, **Edit my request**, or **Keep original**.

Accepting saves the original and revised recipes together in Recipe box. The original keeps its progress; the revised recipe starts a fresh checklist. Closing, cancelling, or discarding does not save a revision. Failed requests leave the original unchanged. The server uses current pantry availability rather than assuming old recipe ingredients are still present. Ingredient references, exclusions, time, servings, and shopping limits are validated; cooking and dietary semantics still need user review. Sample recipes remain offline and cannot be adjusted.

After pulling this update, restart the Node server and rebuild the app in Xcode. Public Release networking remains disabled until hosting and authentication are implemented.

## Fresh setup after cloning

Requires Xcode with an installed iOS simulator and Node 22+.

```sh
cd server
npm run setup
```

Open `server/.env` locally, add `GEMINI_API_KEY`, then run `npm start`. Create the key in [Google AI Studio](https://aistudio.google.com/apikey). Keep the project on **Free Tier with billing disabled**. The default is `gemini-3.6-flash`, tested with this account after Google rejected generation with Gemini 2.5 Flash for new users. A model being eligible for a free tier does not prevent charges on a paid project. [Pricing](https://ai.google.dev/gemini-api/docs/pricing#gemini-3.6-flash), [billing](https://ai.google.dev/gemini-api/docs/billing).

Setup also writes `Local.xcconfig`, which contains only the local server URL and a random development pairing token. **Both `.env` and `Local.xcconfig` are Git-ignored.** The Gemini key is never bundled in the app. Do not paste either credential into chat, screenshots, or a demo recording.

The app/server make no automatic retry or paid-provider fallback. Free quotas are shared across everyone using the same project. When quota runs out, users can wait for reset or use saved recipes and their pantry offline.

## On a real iPhone

Set up your signing team and a unique bundle identifier in Xcode, select your connected iPhone, and run. Physical camera testing requires a phone.

For development over a trusted local network:

1. Put your Mac and iPhone on the same network. Campus Wi-Fi may isolate devices.
2. In `server/.env`, set `HOST=0.0.0.0` and `SAVOR_APP_URL=http://YOUR-MAC-NAME.local:8788`. Find the name with `scutil --get LocalHostName`.
3. Run `npm run setup`, restart the server, and rebuild in Xcode.
4. Allow local-network access on the phone when asked.

The pairing token is shared **only for local development**. It is extractable from a Debug app bundle and is not public-app authentication.

## Deployment boundary

This is a working local MVP, **not a deployed public service**. Ordinary app users should not configure a server or supply their own Gemini key. To distribute a live version, host the API over HTTPS and replace shared development pairing with user sessions or verified app access and persistent quotas. Keep the provider key only on the hosted server.

Release builds exclude the local pairing configuration and disable live networking until public authentication and hosting are implemented. The pantry and sample kitchen still work. No hosting account, paid plan, TestFlight distribution, or App Store publication has been created.

## Privacy

Pantry records and recipes are atomically saved to this app’s Application Support directory with file protection. Images are re-encoded, stripping source metadata. Scanned photos are held for review but are not added to the persistent pantry or logged/stored by this server. Ingredients are sent to Gemini for meal generation; the selected photo is sent for scanning.

Google’s unpaid-service terms allow inputs and outputs to be used to improve its products, including human review. The app discloses this. Use non-sensitive food photos and ingredient lists. [Gemini data-use terms](https://ai.google.dev/gemini-api/terms). The privacy manifest is an MVP declaration; review all App Store privacy disclosures against the final provider configuration and distribution model.

## Verification and Git

```sh
cd server
npm test
```

Backend tests use mocked upstream responses and do not call Gemini. Run all simulator UI tests with:

```sh
./scripts/test-ios.sh
```

This starts a deterministic local HTTP fixture on port 8790, runs Xcode tests using an isolated data directory, and stops the fixture afterward. It never calls Gemini or changes your personal pantry. To use **⌘U** in Xcode instead, first run `node server/test/ui-fixture.mjs` in a separate Terminal. Only Debug UI-test launches can use the fixture connection override. See [the validation record](docs/VALIDATION.md) and [demo walkthrough](docs/DEMO.md).

The opt-in `scripts/check-live.mjs` makes a real Gemini request for the documented sample ingredient list and records the validated result in `docs/live-validation.json`:

```sh
node --env-file=server/.env scripts/check-live.mjs
```

To opt into one live adjustment test (microwave cooking without lemon), run:

```sh
node --env-file=server/.env scripts/check-adjustment-live.mjs
```

It uses a microwave-only profile and the canned ingredient list from the earlier live validation, exercises the actual HTTP adjustment route, and records `docs/adjustment-live-validation.json`. It does not read or modify your pantry.

Two opt-in live equipment checks (microwave-only generation, then a revision with no heating equipment):

```sh
node --env-file=server/.env scripts/check-equipment-live.mjs
```

To verify migration from the older on-disk pantry format using temporary data and the real Swift store:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse-as-library Savor/Models.swift Savor/PantryStore.swift scripts/check-persistence.swift -o /tmp/savor-check-persistence
/tmp/savor-check-persistence
```

To create a private GitHub repository after reviewing the local commit:

```sh
gh repo create savor-ios --private --source=. --remote=origin --push
```

Run that from the project root. If GitHub CLI needs authentication, run `gh auth login` first. No remote is created automatically.

## Structure

- `Savor/`: SwiftUI screens, local models/store, photo capture, and API client.
- `server/`: authenticated HTTP routes, Gemini requests, validators, and tests.
- `Shared/sample-recipes.json`: original prepared recipes for the offline sample kitchen.
- `scripts/generate-project.py`: regenerate the plain Xcode project after adding source files. Preserve any custom signing changes first.
- `Debug.xcconfig`: optional include for local development pairing; Release does not use it.

Implementation references: [Gemini generateContent API](https://ai.google.dev/api/generate-content), [image input](https://ai.google.dev/gemini-api/docs/image-understanding), [thinking configuration](https://ai.google.dev/gemini-api/docs/generate-content/thinking), [safe cooking temperatures](https://www.foodsafety.gov/food-safety-charts/safe-minimum-internal-temperatures).
