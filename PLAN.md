# /goal plan: diet.banghaochi.com nutrition tracker

Generated: 2026-06-14

## 0. Confirmed decisions

- Domain: `diet.banghaochi.com`
- Scope: personal use only, not a public multi-user product
- Web stack: Cloudflare-based app and API
- iOS stack: native SwiftUI app syncing with the Cloudflare backend
- Food logging v1: manual input for calories, carbs, protein, fat, and water
- Recommended auth: Cloudflare Access with One-time PIN, allowlisting only your email
- Primary goal: track daily intake, macros, water, exercise day type, and calorie deficit against a fixed fat-loss plan

## 1. Product goal

Build a private nutrition tracker that lets you quickly answer these questions every day:

- How many kcal have I eaten today?
- How many grams of carbs, protein, and fat have I eaten today?
- How much water have I consumed today?
- Is today a training day or rest day?
- How much planned calorie deficit remains today?
- Am I following the weekly fat-loss plan consistently?

The app should be boring in the best way: fast, private, easy to update from phone or browser, and hard to accidentally mis-enter.

## 2. Current nutrition baseline

Use the plan you already got as the initial default profile.

### Assumptions

- Weight: 70 kg, clothed
- Height: 170 cm
- Age: 25
- Sex: male
- Lifestyle outside training: mostly sedentary
- Formula: Mifflin-St Jeor
- Estimated BMR: 1640 kcal/day
- Estimated non-exercise daily expenditure: 1970 kcal/day
- Training day exercise estimate: 650 kcal net extra burn

### Daily targets

| Day type | Total burn estimate | Intake target | Deficit target | Carbs | Protein | Fat | Water target |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Training day | 2620 kcal | 2100 kcal | 520 kcal | 250 g | 140 g | 60 g | 3000 ml |
| Rest day | 1970 kcal | 1700 kcal | 270 kcal | 160 g | 140 g | 55 g | 2300 ml |

Water targets should be editable. The v1 defaults above are practical placeholders, not medical advice.

### Weekly template

| Day | Default type | Intake | Deficit | Macros |
| --- | --- | ---: | ---: | --- |
| Monday | Training | 2100 kcal | 520 kcal | 250 C / 140 P / 60 F |
| Tuesday | Rest | 1700 kcal | 270 kcal | 160 C / 140 P / 55 F |
| Wednesday | Training | 2100 kcal | 520 kcal | 250 C / 140 P / 60 F |
| Thursday | Rest | 1700 kcal | 270 kcal | 160 C / 140 P / 55 F |
| Friday | Training | 2100 kcal | 520 kcal | 250 C / 140 P / 60 F |
| Saturday | Training | 2100 kcal | 520 kcal | 250 C / 140 P / 60 F |
| Sunday | Rest | 1700 kcal | 270 kcal | 160 C / 140 P / 55 F |

The app must let you override any day type manually, because real training weeks shift.

## 3. MVP behavior

### Today screen

Show today's status first, with no landing page.

Required cards or sections:

- Day type toggle: Training / Rest
- Calorie progress: eaten kcal, target kcal, remaining kcal
- Deficit estimate: total burn estimate minus consumed kcal
- Macro progress:
  - Carbs: consumed g / target g
  - Protein: consumed g / target g
  - Fat: consumed g / target g
- Water progress: consumed ml / target ml
- Today's entries list
- Quick add button
- Body weight quick log, optional but visible

### Manual food entry

Fields:

- Time
- Meal slot: breakfast, lunch, dinner, snack, drink, supplement, other
- Name or note
- Calories
- Carbs in grams
- Protein in grams
- Fat in grams
- Water in ml

Validation:

- Calories must be non-negative
- Macro grams must be non-negative
- Water must be non-negative
- Warn, but do not block, when macro-derived calories differ strongly from entered calories
- Macro kcal formula:
  - carbs kcal = carbs_g * 4
  - protein kcal = protein_g * 4
  - fat kcal = fat_g * 9

### History screen

Required:

- Daily table or list for the last 14/30 days
- Weekly summary:
  - average kcal
  - average protein
  - training/rest day count
  - estimated weekly deficit
  - average water
- Simple trend chart for kcal and weight

### Settings screen

Required:

- Profile assumptions: sex, age, height, current weight
- BMR formula result
- Activity factor for non-exercise days
- Training-day exercise kcal estimate
- Training and rest day macro targets
- Water targets
- Timezone
- Export data button

## 4. Deliberately out of scope for v1

Do not build these in v1 unless the core tracker is already complete and tested:

- AI natural-language meal parsing
- Barcode scanner
- Food database search
- Social or multi-user accounts
- Meal photos
- Coach/admin dashboard
- Apple Health integration
- Widgets and Live Activities
- Nutrition recommendations beyond the fixed targets
- Complex periodization or adaptive diet coaching

These are good v2+ features, but they will slow down the first usable version.

## 5. Recommended architecture

### Repository layout

Suggested monorepo:

```text
nutrition-tracker/
  apps/
    web/
    worker/
    ios/
  packages/
    shared/
      schema/
      calculations/
      api-client/
  docs/
    product/
    api/
    runbooks/
```

### Cloudflare components

Use:

- Cloudflare DNS for `diet.banghaochi.com`
- Cloudflare Access to protect the private app
- Cloudflare Workers for the API
- Cloudflare D1 for relational storage
- Cloudflare Workers static assets or Cloudflare Pages for the web frontend
- Wrangler for local development, D1 migrations, and deployment
- Workers Logs / Cloudflare dashboard for runtime observability

Do not use in v1:

- Durable Objects: no real-time multi-user coordination needed
- R2: no file uploads needed
- KV: D1 is enough unless config caching is needed later
- Queues: no async pipeline needed yet
- Workers AI: manual entry only in v1

### Web frontend

Recommended:

- Vite + React + TypeScript
- Small component system, no marketing landing page
- Use form components optimized for repeated daily entry
- Keep dashboard dense and readable
- Use shared calculation code from `packages/shared/calculations`

The web app should be installable as a PWA later, but the main iOS target is native SwiftUI.

### Worker API

Recommended:

- TypeScript Worker
- Hono or a similarly small router
- Zod or Valibot for request validation
- OpenAPI spec generated or maintained from schemas
- D1 binding named `DB`
- All date boundaries computed in the user's configured timezone

## 6. Auth plan

Use Cloudflare Access with One-time PIN for v1.

### Web auth

- Create an Access application for `https://diet.banghaochi.com/*`
- Enable One-time PIN identity provider
- Add an Access policy allowing only your email
- Set a reasonable session duration
- Keep the entire app private, including API routes

### iOS auth

Use the same Access-protected origin if possible:

- Open Cloudflare Access login through `ASWebAuthenticationSession`
- Complete OTP login in the system browser session
- Store only the resulting session material/cookies that the platform allows
- Use `URLSession` for authenticated API calls
- Store sensitive auth state in Keychain when applicable

Important caveat: Cloudflare Access is excellent for a personal private web app, but native mobile auth can be more awkward than normal app-level OAuth. If native Access login becomes brittle, switch only the mobile API auth to a simple app-level login later. Do not start there for v1 unless Access blocks development.

### Automated test access

For CI/e2e tests against protected staging:

- Prefer a staging hostname such as `diet-staging.banghaochi.com`
- Use a Cloudflare Access service token only in CI secrets
- Never embed service token secrets in the iOS app bundle

## 7. Data model

Use D1 migrations from day one.

### `profile`

One row for your personal profile.

Fields:

- `id`
- `display_name`
- `email`
- `sex`
- `age`
- `height_cm`
- `current_weight_kg`
- `timezone`
- `activity_factor`
- `training_exercise_kcal`
- `created_at`
- `updated_at`

### `daily_targets`

Stores default target definitions.

Fields:

- `id`
- `day_type`: `training` or `rest`
- `burn_kcal`
- `intake_kcal`
- `deficit_kcal`
- `carbs_g`
- `protein_g`
- `fat_g`
- `water_ml`
- `created_at`
- `updated_at`

### `day_logs`

One row per local date.

Fields:

- `id`
- `local_date`
- `day_type`
- `burn_kcal`
- `intake_target_kcal`
- `deficit_target_kcal`
- `carbs_target_g`
- `protein_target_g`
- `fat_target_g`
- `water_target_ml`
- `notes`
- `created_at`
- `updated_at`

Store copied targets on each day so history remains stable even if settings change later.

### `entries`

One row per food/drink/manual log item.

Fields:

- `id`
- `day_log_id`
- `logged_at`
- `meal_slot`
- `name`
- `calories_kcal`
- `carbs_g`
- `protein_g`
- `fat_g`
- `water_ml`
- `notes`
- `created_at`
- `updated_at`
- `deleted_at`

Use soft delete so accidental deletion can be recovered.

### `body_weights`

Fields:

- `id`
- `local_date`
- `measured_at`
- `weight_kg`
- `notes`
- `created_at`
- `updated_at`

### `audit_events`

Optional but useful even for personal tools.

Fields:

- `id`
- `event_type`
- `entity_type`
- `entity_id`
- `summary`
- `created_at`

## 8. API design

Use `/api/v1`.

Required endpoints:

- `GET /api/v1/profile`
- `PATCH /api/v1/profile`
- `GET /api/v1/targets`
- `PATCH /api/v1/targets/:dayType`
- `GET /api/v1/days/:localDate`
- `PATCH /api/v1/days/:localDate`
- `GET /api/v1/days?start=YYYY-MM-DD&end=YYYY-MM-DD`
- `POST /api/v1/entries`
- `PATCH /api/v1/entries/:id`
- `DELETE /api/v1/entries/:id`
- `POST /api/v1/body-weights`
- `GET /api/v1/summary?start=YYYY-MM-DD&end=YYYY-MM-DD`
- `GET /api/v1/export.json`

Response rules:

- Always return ISO timestamps
- Always return local dates as `YYYY-MM-DD`
- Return numbers as numbers, not strings
- Return validation errors with machine-readable field names
- Include calculated totals on day and summary responses

## 9. Calculation rules

All calculations must be covered by unit tests.

### BMR

Use Mifflin-St Jeor:

```text
male_bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age + 5
female_bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age - 161
```

For the initial profile:

```text
10 * 70 + 6.25 * 170 - 5 * 25 + 5 = 1642.5
```

Round display to about 1640 kcal/day.

### Daily burn

```text
rest_burn = bmr * activity_factor
training_burn = rest_burn + training_exercise_kcal
```

Initial:

```text
rest_burn ~= 1640 * 1.2 = 1970
training_burn ~= 1970 + 650 = 2620
```

### Deficit

```text
planned_deficit = burn_kcal - intake_target_kcal
actual_deficit = burn_kcal - consumed_kcal
remaining_intake = intake_target_kcal - consumed_kcal
```

Do not show negative remaining intake as an error. Show it clearly as over target.

### Macro totals

```text
consumed_carbs_g = sum(entries.carbs_g)
consumed_protein_g = sum(entries.protein_g)
consumed_fat_g = sum(entries.fat_g)
consumed_water_ml = sum(entries.water_ml)
```

### Day creation

When a day is first opened:

1. Pick default day type from weekly template.
2. Copy that day type's targets into `day_logs`.
3. Allow manual override.
4. Preserve historical copied values if settings change later.

## 10. iOS app plan

### Minimum target

Recommended: iOS 17+.

Reason:

- Modern SwiftUI and Observation patterns are cleaner
- Async/await networking is standard
- SwiftData is available if local caching is needed

If you need older iOS later, downgrade deliberately and replace newer APIs.

### App structure

Use SwiftUI with small screens and explicit services.

Suggested modules:

- `NutritionApp`
- `TodayFeature`
- `EntryEditorFeature`
- `HistoryFeature`
- `SettingsFeature`
- `Networking`
- `Auth`
- `Models`
- `Calculations`
- `Persistence`

### Navigation

Use a `TabView`:

- Today
- History
- Settings

Use `NavigationStack` inside each tab.

### State and data flow

- Use `@State` for local UI state
- Use `@Observable` app state/services for shared session and data state
- Use async/await for API calls
- Use explicit loading, empty, error, and offline states
- Do not put network requests in SwiftUI `body`

### Local persistence

V1 can start online-first, but the app should not lose entered data if the network hiccups.

Recommended:

- Store draft entry form locally while editing
- Cache recent days locally
- Add a small pending-write queue if offline support is implemented
- Use Keychain for auth/session material

SwiftData is acceptable for local cache on iOS 17+. Keep D1 as the source of truth.

### iOS screens

Today:

- Training/rest segmented control
- Calories remaining
- Macro progress
- Water progress with quick buttons: +250 ml, +500 ml
- Today's entries
- Add entry sheet

Add Entry:

- Numeric fields optimized for fast entry
- Meal slot picker
- Save button disabled until numbers are valid
- Show macro kcal estimate

History:

- Last 14/30 days
- Weekly average
- Weight trend

Settings:

- Profile
- Targets
- Auth/session status
- Export button

### Accessibility

Add accessibility identifiers for UI tests:

- `today.dayType.training`
- `today.dayType.rest`
- `today.addEntry`
- `entry.calories`
- `entry.carbs`
- `entry.protein`
- `entry.fat`
- `entry.water`
- `entry.save`
- `history.summary`
- `settings.profile`

## 11. Web UI plan

### Layout

The first screen is the tracker, not a marketing page.

Desktop:

- Left/main: today's log and entry list
- Right/sidebar: targets, remaining numbers, weekly summary

Mobile:

- Today summary first
- Quick add sticky action
- Entries below
- History and settings in bottom navigation or simple tabs

### UI rules

- Make manual entry fast
- Use numeric inputs with clear units
- Use segmented controls for training/rest
- Use progress bars for macros and water
- Avoid decorative dashboards that slow down entry
- Preserve keyboard-friendly input
- Warn before deleting entries

## 12. Cloudflare implementation plan

### Phase 1: Project setup

Tasks:

- Create monorepo
- Add TypeScript config
- Add shared calculation package
- Add Worker app
- Add web app
- Add D1 migration folder
- Add `.env.example`
- Add Wrangler config

Acceptance:

- `npm install` or chosen package-manager install succeeds
- TypeScript compiles
- Worker responds locally
- Web app renders locally

### Phase 2: D1 schema and seed data

Tasks:

- Create D1 database
- Write initial migrations
- Add seed script for profile and targets
- Add local D1 workflow

Acceptance:

- Migrations apply locally
- Profile row exists
- Training and rest targets exist
- `GET /api/v1/days/:date` creates or returns a day log

### Phase 3: API

Tasks:

- Implement validation
- Implement day target copy logic
- Implement CRUD for entries
- Implement body weight endpoints
- Implement summary endpoint
- Implement export endpoint

Acceptance:

- API tests pass
- Invalid payloads return structured 400 responses
- Date boundaries work in configured timezone
- Deleting an entry updates daily totals

### Phase 4: Web app

Tasks:

- Build Today screen
- Build Add Entry flow
- Build History screen
- Build Settings screen
- Connect to API
- Handle loading/error states

Acceptance:

- Manual entry can be added, edited, deleted
- Day type changes update targets
- Summary matches API totals
- UI works on desktop and mobile widths

### Phase 5: Cloudflare Access and domain

Tasks:

- Add DNS route for `diet.banghaochi.com`
- Configure Cloudflare Access app
- Enable One-time PIN
- Allowlist your email
- Protect web and API routes
- Add staging hostname if needed

Acceptance:

- Unauthenticated browser sees Access login
- Your email can log in
- Other emails cannot log in
- API is not publicly reachable without Access
- CI/e2e has a safe staging auth path

### Phase 6: Deploy

Tasks:

- Deploy Worker/API
- Deploy web frontend
- Bind D1 production database
- Apply production migrations
- Smoke test production

Acceptance:

- `https://diet.banghaochi.com` loads after Access login
- Today screen reads production D1 data
- New entry persists after reload
- Export endpoint returns valid JSON

## 13. iOS implementation plan

### Phase 1: Xcode project

Tasks:

- Create SwiftUI iOS app under `apps/ios`
- Set bundle identifier
- Add app icon later
- Add Today, History, Settings tabs
- Add basic models and calculation tests

Acceptance:

- App builds in Debug
- App launches in Simulator
- Unit tests pass
- Preview states render for main screens

### Phase 2: API client

Tasks:

- Add typed API client
- Add request/response models
- Add mock API implementation for previews/tests
- Add error handling

Acceptance:

- API client tests pass with mocked responses
- Today screen can load fixture data
- Error state is visible and recoverable

### Phase 3: Auth

Tasks:

- Implement Cloudflare Access login with `ASWebAuthenticationSession`
- Persist usable session state safely
- Add logout/reset session
- Add token/cookie expiry handling

Acceptance:

- Fresh install can authenticate
- App can call protected API after login
- Logout removes local auth state
- Expired session sends user back to login

### Phase 4: Today and entry editing

Tasks:

- Build Today dashboard
- Build Add Entry sheet
- Build Edit Entry flow
- Add water quick buttons
- Add optimistic update or clear loading state

Acceptance:

- Add entry from iOS, see it on web after refresh
- Add entry from web, see it on iOS after refresh
- Invalid input is blocked
- Delete confirmation works

### Phase 5: History and settings

Tasks:

- Build daily history list
- Build weekly summary
- Build editable targets/profile
- Add export action

Acceptance:

- History matches backend summary
- Settings changes affect new days, not old copied day logs
- Profile updates persist

## 14. Testing strategy

Testing is a required deliverable, not an optional cleanup step.

### Shared calculation tests

Cover:

- BMR formula
- Rest day burn
- Training day burn
- Planned deficit
- Actual deficit
- Macro kcal estimate
- Day creation from weekly template
- Target copy behavior

Required command:

```bash
npm test
```

or equivalent package-manager command.

### Cloudflare Worker tests

Use Cloudflare's Workers Vitest integration so tests run against Worker runtime APIs and bindings locally.

Cover:

- API route success cases
- API validation failures
- D1 read/write paths
- Entry create/edit/delete
- Summary aggregation
- Export JSON
- Access/JWT handling where testable

Required commands:

```bash
npm run test:worker
npx wrangler d1 migrations apply <DB_NAME> --local
npx wrangler dev
```

If using a preview/staging database, also verify remote migrations against staging before production.

### Web tests

Use:

- Component tests for important form behavior
- Playwright e2e tests for real user flows

Cover:

- Load Today screen
- Add manual entry
- Edit manual entry
- Delete manual entry
- Toggle training/rest
- Add water
- View history
- Update settings
- Mobile viewport layout
- Desktop viewport layout

Required commands:

```bash
npm run typecheck
npm run lint
npm run test:web
npm run test:e2e
```

Browser verification:

- Open local app
- Confirm no blank screen
- Confirm no overlapping text
- Confirm mobile and desktop layouts work
- Confirm production domain requires Access login

### iOS tests

Use Swift Testing or XCTest for model/service tests. Use XCTest UI tests for workflows.

Cover:

- Calculation parity with shared web/backend values
- API client decoding
- API error handling
- Auth state transitions
- Add entry flow
- Edit entry flow
- Delete entry flow
- Training/rest toggle
- Water quick-add
- History rendering

Required commands:

```bash
xcodebuild test -scheme <AppScheme> -destination 'platform=iOS Simulator,name=<Simulator Name>'
```

Also verify with Build iOS Apps / XcodeBuildMCP workflow:

1. Show session defaults.
2. Build and run the app on Simulator.
3. Capture UI description or screenshot after launch.
4. Perform one add-entry UI flow.
5. Capture logs and summarize any errors.

Manual simulator acceptance:

- Fresh install shows login
- Login works
- Today screen loads
- Add entry persists
- Relaunch preserves session and data
- Offline or failed-network state is understandable

### End-to-end cross-platform test

Required before calling v1 done:

1. Log in on web.
2. Create today's day log.
3. Add entry on web.
4. Open iOS app.
5. Confirm same entry appears.
6. Add water on iOS.
7. Refresh web.
8. Confirm water total updated.
9. Change day type on web.
10. Confirm iOS reflects new targets.
11. Export JSON.
12. Confirm exported totals match UI.

## 15. Deployment and operations

### Environments

Use at least:

- Local
- Staging
- Production

Suggested hostnames:

- Production: `diet.banghaochi.com`
- Staging: `diet-staging.banghaochi.com`

### Secrets and config

Do not commit:

- Cloudflare API tokens
- Access service token secrets
- Production D1 database IDs if the repo is public
- iOS signing credentials

Use:

- Wrangler secrets for Worker secrets
- GitHub Actions or local environment secrets for CI
- Keychain for iOS local auth state

### Backups and export

Minimum:

- In-app JSON export
- Manual D1 export runbook

Better:

- Scheduled backup job later
- Store encrypted backup outside D1 later if the data becomes important

### Observability

Track:

- Worker errors
- API latency
- D1 query failures
- 4xx validation rates
- 5xx server errors
- iOS networking errors during manual QA

Add a simple `/api/v1/health` endpoint returning service status without exposing private data.

## 16. CI plan

Recommended checks for every PR or local release branch:

```bash
npm run typecheck
npm run lint
npm test
npm run test:worker
npm run test:web
npm run test:e2e
xcodebuild test -scheme <AppScheme> -destination 'platform=iOS Simulator,name=<Simulator Name>'
```

Production deploy should require:

- All tests passing
- D1 migrations reviewed
- Staging smoke test complete
- Access protection verified
- Production smoke test complete

## 17. Definition of done for v1

V1 is done only when all of these are true:

- `diet.banghaochi.com` is protected by Cloudflare Access
- You can log food manually from web
- You can log water manually from web
- You can toggle training/rest days from web
- You can view daily and weekly summaries from web
- iOS app can log in
- iOS app can read the same backend data
- iOS app can add/edit/delete entries
- iOS and web stay consistent after refresh/relaunch
- Export works
- Local, staging, and production D1 migrations are documented
- Worker tests pass
- Web tests pass
- iOS tests pass
- Manual cross-platform smoke test passes
- No service tokens or secrets are embedded in the iOS app or committed to git

## 18. Suggested implementation order

1. Write shared calculation tests first.
2. Build D1 schema and seed targets.
3. Build Worker API.
4. Build web Today screen.
5. Add Cloudflare Access to staging.
6. Deploy web/API to `diet.banghaochi.com`.
7. Create SwiftUI app shell.
8. Add iOS API client and auth.
9. Add iOS Today/Add Entry flows.
10. Add History and Settings.
11. Run full cross-platform test.
12. Only then consider v2 features.

## 19. Open decisions to revisit later

These are intentionally deferred:

- Whether to add AI meal parsing
- Whether to add food templates
- Whether to integrate Apple Health body weight or water
- Whether to support offline-first sync fully
- Whether to submit to App Store or keep personal/TestFlight/local install
- Whether to add adaptive calorie recommendations after 2 weeks of real data

## 20. Official references used

- Cloudflare Workers Vitest integration: https://developers.cloudflare.com/workers/testing/vitest-integration/
- Cloudflare D1 local development: https://developers.cloudflare.com/d1/best-practices/local-development/
- Cloudflare D1 migrations: https://developers.cloudflare.com/d1/reference/migrations/
- Cloudflare Access One-time PIN: https://developers.cloudflare.com/cloudflare-one/integrations/identity-providers/one-time-pin/
- Cloudflare Access policies: https://developers.cloudflare.com/cloudflare-one/access-controls/policies/
- Apple running tests and interpreting results: https://developer.apple.com/documentation/xcode/running-tests-and-interpreting-results
- Apple Swift Testing: https://developer.apple.com/xcode/swift-testing/
