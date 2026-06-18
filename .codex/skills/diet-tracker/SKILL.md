---
name: diet-tracker
description: Work on the diet.banghaochi.com monorepo across Cloudflare Workers/D1, Vite web, SwiftUI iOS, auth, deployment, and cross-platform smoke tests.
---

# Diet Tracker Skill

Use this skill when changing the private nutrition tracker in this repository.

## Orientation

- Web app: `apps/web`
- Worker/API: `apps/worker`
- Shared schemas/calculations: `packages/shared`
- iOS app: `apps/ios`
- Runbooks: `docs/runbooks`
- Reusable food templates: D1 `food_templates`, shared schemas, Worker routes, web API/types, and iOS models/client/store

## Rules

- Keep Cloudflare Access, Worker API, web, and iOS behavior aligned.
- Do not commit secrets, local env files, D1 exports, auth cookies, or generated build output.
- If the iOS `API_BASE_URL`, Access callback URL, or Worker `/auth/ios-callback` behavior changes, update `docs/runbooks/cloudflare-access.md`.
- If D1 schema or seed data changes, update `apps/worker/migrations`, `docs/runbooks/d1.md`, and any cross-platform clients that depend on the schema.
- If app icons are replaced, update both the source master and derived platform sizes.
- If the iOS Foundation Models food-entry flow changes, keep it iOS 27+ availability-gated, review-before-save, and covered by parser/draft tests.

## Common Checks

```bash
npm run typecheck
npm run lint
npm test
npm run test:worker
npm run test:web
npm run test:e2e
```

## Deployment

Apply D1 migrations before deploying each environment:

```bash
cd apps/worker
npx wrangler d1 migrations apply DB --env staging --remote
npx wrangler deploy --env staging
npx wrangler d1 migrations apply DB --env production --remote
npx wrangler deploy --env production
```

For iOS, prefer XcodeBuildMCP. If using CLI:

```bash
cd apps/ios
xcodegen generate --spec project.yml
xcodebuild test -project NutritionTracker.xcodeproj -scheme NutritionTracker -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Physical iPhone Install

Keep Personal Team signing and device-specific provisioning local unless the user explicitly asks to share those changes. When Xcode beta is required for the connected iPhone/iOS version, use `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl list devices
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project apps/ios/NutritionTracker.xcodeproj -scheme NutritionTracker -configuration Debug -destination 'id=<device-id>' -derivedDataPath /tmp/NutritionTrackerDeviceBuild -allowProvisioningUpdates build
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl device install app --device <device-id> /tmp/NutritionTrackerDeviceBuild/Build/Products/Debug-iphoneos/NutritionTracker.app
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun devicectl device process launch --device <device-id> com.banghaochi.diet
```

## Cross-Platform Smoke

Before calling production v1 done:

1. Log in on web.
2. Add a web entry and verify it persists in production D1.
3. Open the iOS app against `https://diet.banghaochi.com/api/v1/`.
4. Confirm iOS reads the web entry.
5. Add water from iOS.
6. Refresh web and confirm the water total updates.
7. Open `/api/v1/export.json` in an authenticated session and confirm it returns JSON.
