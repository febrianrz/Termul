# Termul

SSH client / terminal multiplexer for Android (Termius-like), built with Flutter.

## Download

[**⬇ Download latest APK**](https://github.com/febrianrz/Termul/releases/latest/download/app-release.apk)

The APK is built automatically by GitHub Actions on every push, so the link above always points to the latest build. Build history is in the [Actions](https://github.com/febrianrz/Termul/actions) tab.

## Features

- Save multiple SSH hosts (name, address, port, username, password or private key)
- Passwords/private keys are stored in the device's secure storage (Keychain/Keystore), never in plaintext
- Interactive terminal per host (xterm + dartssh2)
- SSO login (OAuth2 Authorization Code Grant, e.g. Laravel Passport) — the app never holds the client_secret; `backend/` performs the `/oauth/token` exchange on its behalf

## Project structure

- `lib/` — the Flutter app (Android & iOS)
- `backend/` — Express + TypeScript service that brokers the SSO token exchange; will also host cross-device sync in the future

## Running the app locally

```bash
flutter pub get
cp dart_define.example.json dart_define.json   # fill in your SSO client_id, point BACKEND_BASE_URL at your backend
flutter run --dart-define-from-file=dart_define.json
```

## Running the backend locally

See [`backend/README.md`](backend/README.md).

## CI/CD

- **`build-apk.yml`** — builds the release APK on every push and publishes it to the `latest` GitHub Release (the download link above). Needs repository secret `SSO_CLIENT_ID`, plus optional repository **variables** `SSO_BASE_URL`, `SSO_REDIRECT_URI` and `BACKEND_BASE_URL` if you're not using this repo's defaults.
- **`backend-docker.yml`** — builds `backend/`'s Docker image and pushes it whenever `backend/**` changes. Pushes to Docker Hub by default; see `backend/README.md` for pushing to your own registry instead. Needs repository secrets `DOCKER_USERNAME` and `DOCKER_PASSWORD` (a Docker Hub [access token](https://hub.docker.com/settings/security), not your password, if using Docker Hub).

Add secrets/variables under **Settings → Secrets and variables → Actions**.

## Forking (bring your own SSO)

Nothing SSO-specific is hardcoded — the app and backend read the SSO server URL, client ID, secret and redirect URI entirely from config. Your SSO server just needs to speak the same OAuth2 Authorization Code Grant shape as Laravel Passport: `/oauth/authorize`, `/oauth/token`, `/api/user`, `/api/logout`.

To point a fork at your own SSO client:

1. Register a client with your SSO provider and note its `client_id` and `client_secret`.
2. Pick your app's package/bundle ID (e.g. `com.yourcompany.yourapp`) and a redirect URI using it as the scheme, e.g. `com.yourcompany.yourapp://callback`.
3. Update `android/app/build.gradle.kts` (`namespace` / `applicationId`) and the `CallbackActivity` intent-filter's `android:scheme` in `android/app/src/main/AndroidManifest.xml` to match your new scheme.
4. Set these locally (`dart_define.json`) and in CI (repo secrets/variables):
   - `SSO_BASE_URL` — your SSO server's base URL
   - `SSO_CLIENT_ID` — your client ID
   - `SSO_REDIRECT_URI` — the redirect URI from step 2
   - `BACKEND_BASE_URL` — where you're running `backend/`
5. Set `SSO_CLIENT_ID`, `SSO_CLIENT_SECRET`, `SSO_BASE_URL` (if different) and `SSO_REDIRECT_URI` in the backend's `.env` (or as Docker Hub / host env vars) — see `backend/README.md`.

No code changes needed beyond the Android package/scheme in steps 2–3.
