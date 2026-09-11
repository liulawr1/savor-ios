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
- Explicit selection of ingredients used up; no guessed quantity deductions.
- A labeled offline sample kitchen with three prepared recipes. Samples are excluded from real meals-made counts.
- Custom native bowl illustration and app icon. Illustrations are not generated photos of the suggested meal.

Recipe suggestions are not guaranteed to be nutritionally balanced, allergen-free, safe, or feasible. Check ingredient labels, freshness, quantities, and cooking instructions. **Use soon** is an intention, not a shelf-life calculation. No expiry prediction, environmental-savings estimate, or nutrition estimate is made.

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

Backend tests use mocked upstream responses and do not call Gemini. In Xcode, **⌘U** runs simulator UI tests with an isolated test-data directory. See [the validation record](docs/VALIDATION.md) and [demo walkthrough](docs/DEMO.md).

The opt-in `scripts/check-live.mjs` makes a real Gemini request for the documented sample ingredient list and records the validated result in `docs/live-validation.json`:

```sh
node --env-file=server/.env scripts/check-live.mjs
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
