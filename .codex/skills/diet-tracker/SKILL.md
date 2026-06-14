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

## Rules

- Keep Cloudflare Access, Worker API, web, and iOS behavior aligned.
- Do not commit secrets, local env files, D1 exports, auth cookies, or generated build output.
- If the iOS `API_BASE_URL`, Access callback URL, or Worker `/auth/ios-callback` behavior changes, update `docs/runbooks/cloudflare-access.md`.
- If D1 schema or seed data changes, update `apps/worker/migrations` and `docs/runbooks/d1.md`.
- If app icons are replaced, update both the source master and derived platform sizes.

## Common Checks

```bash
npm run typecheck
npm run lint
npm test
npm run test:worker
npm run test:web
npm run test:e2e
```

For iOS, prefer XcodeBuildMCP. If using CLI:

```bash
cd apps/ios
xcodegen generate --spec project.yml
xcodebuild test -project NutritionTracker.xcodeproj -scheme NutritionTracker -destination 'platform=iOS Simulator,name=iPhone 17'
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
