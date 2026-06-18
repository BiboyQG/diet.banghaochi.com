# Diet Tracker

Private nutrition tracker for `diet.banghaochi.com`.

## Features

- Daily nutrition, water, weight, and target tracking.
- Reusable food templates for common meals across web and iOS.
- Cloudflare Access-protected web app and API, with iOS login through `/auth/ios-callback`.

## Local Setup

```bash
npm install
npm run wrangler:types
npm run db:migrate:local
npm run dev
```

The web app runs on `http://127.0.0.1:5173` and proxies `/api` to the local Worker on `http://127.0.0.1:8787`.

D1 migrations include seed data for reusable food templates, including the default Chipotle bowl.

## Checks

```bash
npm run typecheck
npm run lint
npm test
npm run test:worker
npm run test:web
npm run test:e2e
```

Web tests cover the common-food quick-log feedback state and the reduced-motion stylesheet guard. SwiftUI visual polish is verified through iOS simulator tests unless it changes data flow or API behavior.

## iOS

The native app lives in `apps/ios` and uses XcodeGen for the project file.

```bash
cd apps/ios
xcodegen generate --spec project.yml
xcodebuild test -project NutritionTracker.xcodeproj -scheme NutritionTracker -destination 'platform=iOS Simulator,name=iPhone 17'
```

The checked-in iOS app targets `https://diet.banghaochi.com/api/v1/` and requires Cloudflare Access login through `/auth/ios-callback`. For local-only simulator work, set `API_BASE_URL` in `apps/ios/project.yml` back to `http://localhost:8787/api/v1/` and regenerate the Xcode project.

## Production Notes

The web app is deployed as static assets from the Worker, so `diet.banghaochi.com`, `/api/*`, and `/auth/ios-callback` share one Cloudflare Access-protected origin.

```bash
npm run build --workspace @diet/web
cd apps/worker
npx wrangler d1 migrations apply DB --env staging --remote
npx wrangler deploy --env staging
npx wrangler d1 migrations apply DB --env production --remote
npx wrangler deploy --env production
```

Keep Cloudflare API tokens, Access service tokens, and production secrets out of the repo.
