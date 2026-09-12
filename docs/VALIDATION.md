# Validation record

Checked September 11, 2026 on this Mac using Xcode 26.1.1, the iPhone 17 Pro simulator with iOS 26.1, and Node 24.16.0.

## Builds and automated checks

- Debug simulator build: passed.
- Release iPhone build with code signing disabled: passed. This checks compilation, not installation or distribution.
- Compiled configuration: Debug contains local development pairing; Release contains neither the local server URL nor the pairing token. The Gemini key is stored only in the ignored server environment file.
- Backend: all 17 tests passed. Coverage includes request and response bounds, ingredient identity, optional shopping limits, malformed/refused/truncated provider responses, authentication, request size, rate limits, concurrency, missing configuration, and safe local setup. These tests mock Gemini and do not consume API quota.
- Three simulator UI workflows passed: manual pantry persistence; replacing the sample kitchen with a personal pantry; and saving step progress through cooking completion. The latter two passed after fixing ambiguous UI test selectors. Tests use a separate local data directory.
- The pantry screen was visually inspected in the simulator. [Screenshot](pantry.png).

## Live Gemini checks

The configured account rejected `gemini-2.5-flash` generation as unavailable to new users. The default was updated to `gemini-3.6-flash`, which successfully handled both checks below.

1. **Meal generation:** five pantry ingredients, a 15-minute limit, two servings, vegetarian, and no shopping. Gemini returned a validated 10-minute warm chickpea and spinach salad using only the listed ingredients and water. [Input and result](live-validation.json).
2. **Image recognition:** a public photo of a red apple returned one red apple in the Fruit category, with a reminder to confirm the result. The first attempt through the local HTTP route received an upstream service error. One manually initiated retry through the same Gemini request and validation code succeeded. This establishes live image recognition; it is not an end-to-end camera UI test. [Result](scan-validation.json).

The image test used [Red Apple by Abhijit Tembhekar](https://commons.wikimedia.org/wiki/File:Red_Apple.jpg), licensed under [CC BY 2.0](https://creativecommons.org/licenses/by/2.0/). The unmodified image was fetched into memory for the test and is not included in the app or repository.

## Remaining limits

- Physical iPhone camera capture, campus-network connectivity, signing, TestFlight, and App Store distribution have not been tested.
- Complex pantry photos and the quality of a broad range of generated meals have not been evaluated. Editable ingredient review and explicit error states remain essential.
- Recipe schema checks enforce structure and pantry references; they cannot prove cooking quality, dietary suitability, or safety.
- Public HTTPS hosting, individual user authentication, and persistent server quotas are not implemented. Live AI currently requires the development server on this Mac; Release live networking is disabled pending that work.
- Live service availability and free quota can change. The app has no automatic paid fallback or automatic retry.

## Recipe adjustments — September 12, 2026

- Added `POST /v1/adjust`, which uses the current pantry, bounded original-recipe context, a change request, optional explicit ingredient exclusions, and reviewed cooking preferences. It shares the existing authentication, concurrency, timeout, and hourly limits.
- All **22 backend tests passed**, including five new adjustment tests covering historical pantry references, excluded ingredients, bounded requests, single-recipe output, fresh server-owned identity, original ancestry, remembered preferences, and the authenticated HTTP-to-provider pipeline with Gemini mocked.
- Debug simulator and unsigned Release iPhone builds passed. Compiled Release configuration still excludes the development URL and token; UI fixture overrides are compiled only into Debug and require the isolated UI-test launch flag.
- Simulator checks passed for failure/retry/discard and acceptance with persistence after relaunch. The revised checklist starts empty while the original's completed step is preserved. The three existing pantry/sample workflows also passed. A cancellation check passed with a deliberately delayed response: closing the sheet prevented a late revision from being saved. Six distinct simulator workflows were verified across the full run and a targeted final run.
- Visually inspected [the adjustment editor](adjustment-editor.png) and [the revision preview](adjustment-preview.png). These screenshots use deterministic test recipes, not a live Gemini response. The preview opens at the change explanation. Xcode reported a simulator diagnostics-collection warning after the final tests; the tests themselves and the test command passed.
- **One live Gemini adjustment passed through the actual HTTP route:** requested microwave preparation and no lemon using only the free-text request (no explicit ingredient exclusion). Gemini returned microwave steps, omitted lemon, kept the 15-minute/two-serving limits, and explained both changes. [Full request and validated response](adjustment-live-validation.json).
- The revised meal has not been cooked or evaluated for taste. Structural validation cannot prove equipment feasibility, dietary suitability, or complete compliance with free-text requests; the app shows the full revision for user review before acceptance.
