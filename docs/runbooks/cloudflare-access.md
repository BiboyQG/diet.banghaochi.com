# Cloudflare Access Runbook

## Current setup

- Production application: `Diet Tracker Production` for `https://diet.banghaochi.com/*`
- Staging application: `Diet Tracker Staging` for `https://diet-staging.banghaochi.com/*`
- Identity provider: Cloudflare Access One-time PIN
- Allow policy: `m13971212844@gmail.com`
- App cookie setting: `http_only_cookie_attribute=false` so the native iOS login flow can read the application-domain `CF_Authorization` cookie

The Worker redirects `/auth/ios-callback` to `diettracker://access/callback` after Access login so `ASWebAuthenticationSession` can complete. When Access has issued `CF_Authorization`, the Worker appends it as `cf_authorization` with an optional `expires_at` value so iOS can persist a usable API session in Keychain.

Store CI service token values only in CI secrets. Do not embed service token secrets in the iOS app or web bundle.

iOS production config:

- `API_BASE_URL`: `https://diet.banghaochi.com/api/v1/`
- `ACCESS_LOGIN_URL`: `https://diet.banghaochi.com/auth/ios-callback`
- `ACCESS_CALLBACK_SCHEME`: `diettracker`

Smoke checks:

```bash
curl -I https://diet.banghaochi.com
curl -I https://diet.banghaochi.com/api/v1/health
curl -I https://diet.banghaochi.com/auth/ios-callback
```

Unauthenticated requests should be redirected to Cloudflare Access.

## Passkey note

Cloudflare Access One-time PIN is intentionally email-first. Native iOS passkeys are possible, but not as a direct replacement for the current Access OTP configuration. A passkey migration would require either:

1. A passkey-capable external IdP connected to Access through OIDC/SAML.
2. Replacing Access with app-owned WebAuthn/passkey auth, session cookies, and Worker-side session verification.

Do not start a passkey rewrite unless the auth ownership decision is explicit.

If local DNS is behind Cloudflare propagation, verify with a public resolver first:

```bash
dig +short @1.1.1.1 diet.banghaochi.com A
```
