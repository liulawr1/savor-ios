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

## Kitchen equipment — September 12, 2026

- Profiles store an explicit selection of microwave, stovetop, oven, and kettle. Missing profile data stays unset during migration; an explicitly saved empty list means no heating equipment. Profile edits do not remove pantry items or saved recipes, and sample transitions preserve the profile.
- All **26 backend tests passed**, including unknown/duplicate/missing profile validation, required equipment declarations, subset checks, No oven conflicts, empty and kettle-only profiles, and adjustments constrained by the current profile rather than historical recipe requirements or conflicting free text.
- The standalone check using the **real Swift models and store** passed: an older pantry file without equipment fields loads intact; existing recipe progress survives saving and reopening a profile; an empty profile persists distinctly from unset; sample reset/exit retains the profile. All test files were temporary.
- **Two live Gemini calls passed through the HTTP routes:** a microwave-only profile produced a meal declaring only microwave; revising it with an empty profile produced a cold salad declaring no heating equipment. [Full request and responses](equipment-live-validation.json).
- Eight distinct simulator workflows passed across the full run and a targeted retest: the six existing workflows, plus profile persistence/current-profile revision/empty-profile persistence, and explicit setup with sample reset preservation. Test interactions were corrected to tap switch controls and distinguish the preview equipment label from the original behind the sheet.
- Debug simulator and unsigned Release iPhone builds passed. Release still excludes local connection credentials. Visually inspected [the equipment profile screen](equipment-profile.png).
- Required-equipment validation checks the model's structured declaration. It does not prove that every appliance in the natural-language instructions was declared, or guarantee cooking feasibility. The instructions require complete declarations and appropriate vessels; users still review the steps.


## Post-cooking pantry review — September 12, 2026

- Replaced the completion toggles with explicit **Used it all**, **Some left**, and **Didn’t use** choices. Some left requires a manually entered, nonblank amount of up to 60 characters. Drafts are local to the completion sheet, and no arithmetic or Gemini call is involved.
- The real Swift-store completion checks passed: mixed outcomes persist across reload; manual text replaces only the selected item's quantity; Use soon and other metadata, unrelated items, equipment, and recipe instructions are preserved. Duplicate completion, blank/oversized quantities, missing choices, duplicate/incomplete reviews, and unrelated-item edits are rejected without partial writes.
- Stale reviews are rejected when their pantry items change or disappear. A simulated filesystem write failure left the in-memory pantry and cooked history unchanged. Recipes whose pantry references have all been removed still complete without creating water or shopping items.
- The older-data migration/profile persistence check passed again. Debug simulator and unsigned Release iPhone builds passed. Visually inspected [the review screen](post-cooking-review.png) using sample kitchen data.
- Three focused simulator workflows passed across the initial run and a targeted retest: mixed outcomes with persisted amounts/removal/meal history, blank-amount validation and cancellation, and the existing completed-sample workflow. The history check was isolated from the pantry-search keyboard by relaunching before switching tabs. Xcode emitted its existing simulator diagnostics-collection warning after tests; the targeted test command succeeded.
