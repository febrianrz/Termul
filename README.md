# Termul

SSH client / terminal multiplexer for Android (Termius-like), built with Flutter.

## Download

[**⬇ Download latest APK**](https://github.com/febrianrz/Termul/releases/latest/download/app-release.apk)

The APK is built automatically by GitHub Actions on every push, so the link above always points to the latest build. Build history is in the [Actions](https://github.com/febrianrz/Termul/actions) tab.

Built for 64-bit ARM (`arm64-v8a`) only, which is virtually every Android device sold since ~2017 - this keeps the APK much smaller than a universal build. If you need 32-bit or x86 support, drop `--target-platform android-arm64` from `build-apk.yml`'s build step (or use `--split-per-abi` to get one small APK per architecture instead of one big one).

## Features

- Save multiple SSH hosts (name, address, port, username, password or private key)
- Passwords/private keys are stored in the device's secure storage (Keychain/Keystore), never in plaintext
- Interactive terminal per host (xterm + dartssh2)
- SSO login (OAuth2 Authorization Code Grant, e.g. Laravel Passport) — the app never holds the client_secret; `backend/` performs the `/oauth/token` exchange on its behalf
- Tag hosts and search/filter the host list by name, address, username or tag
- Optional biometric/PIN app lock, re-armed whenever the app is backgrounded
- Broadcast a command to several open terminal sessions at once
- Terminal sessions auto-reconnect (with backoff) if the connection drops unexpectedly
- SSH port forwarding (local `-L` and remote `-R` tunnels) per host

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

- **`build-apk.yml`** — two jobs on every push: `build-android` builds the release APK and publishes it to the `latest` GitHub Release (the download link above); `build-ios` builds an unsigned iOS build to validate it compiles (no installable IPA yet - that needs an Apple Developer account, a signing certificate, and a provisioning profile, none of which are set up). Both need repository secret `ALTER_CLIENT_ID` (the SSO client ID, passed to the app as `--dart-define=SSO_CLIENT_ID`), plus optional repository **variables** `SSO_BASE_URL`, `SSO_REDIRECT_URI` and `BACKEND_BASE_URL` if you're not using this repo's defaults. `build-android` also accepts the release-signing secrets described below - without them it falls back to the debug key (with a build warning) so the workflow still runs.
- **`backend-docker.yml`** — builds `backend/`'s Docker image and pushes it whenever `backend/**` changes. Pushes to Docker Hub by default; see `backend/README.md` for pushing to your own registry instead. Needs repository secrets `DOCKER_USERNAME` and `DOCKER_PASSWORD` (a Docker Hub [access token](https://hub.docker.com/settings/security), not your password, if using Docker Hub).

Add secrets/variables under **Settings → Secrets and variables → Actions**.

## Android release signing

The release APK is signed with a real key rather than the Flutter template's
debug key, and R8 minification + resource shrinking are on (`android/app/build.gradle.kts`)
— both shrink the APK and make it harder to decompile. `android/key.properties`
(gitignored) holds the keystore path and passwords locally; in CI, the "Set up
Android release signing" step in `build-apk.yml` writes it from repository
secrets before the build.

To set up your own signing key (only needs doing once):

```bash
keytool -genkeypair -v -storetype PKCS12 \
  -keystore release-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Keep `release-keystore.jks` and its passwords somewhere safe outside the repo
(losing it means you can never publish an update under the same signature).
Then either:

- **Locally**: put the `.jks` file under `android/` and create
  `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`,
  `keyPassword` (see the keytool command above for the alias).
- **In CI**: add repository secrets `ANDROID_KEYSTORE_BASE64` (the `.jks`
  file, base64-encoded: `base64 -i release-keystore.jks`),
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`.

## Forking (bring your own SSO)

Nothing SSO-specific is hardcoded — the app and backend read the SSO server URL, client ID, secret and redirect URI entirely from config. Your SSO server just needs to speak the same OAuth2 Authorization Code Grant shape as Laravel Passport: `/oauth/authorize`, `/oauth/token`, `/api/user`, `/api/logout`.

To point a fork at your own SSO client:

1. Register a client with your SSO provider and note its `client_id` and `client_secret`.
2. Pick your app's package/bundle ID (e.g. `com.yourcompany.yourapp`) and a redirect URI using it as the scheme, e.g. `com.yourcompany.yourapp://callback`.
3. Update `android/app/build.gradle.kts` (`namespace` / `applicationId`) and the `CallbackActivity` intent-filter's `android:scheme` in `android/app/src/main/AndroidManifest.xml` to match your new scheme.
4. Set these locally in `dart_define.json` as-is:
   - `SSO_BASE_URL` — your SSO server's base URL
   - `SSO_CLIENT_ID` — your client ID
   - `SSO_REDIRECT_URI` — the redirect URI from step 2
   - `BACKEND_BASE_URL` — where you're running `backend/`

   In CI, set repository **variables** `SSO_BASE_URL`, `SSO_REDIRECT_URI` and
   `BACKEND_BASE_URL`, but the client ID goes in repository **secret**
   `ALTER_CLIENT_ID` (see `build-apk.yml`, which maps it to
   `--dart-define=SSO_CLIENT_ID` at build time) — rename that secret to
   match your own provider if you'd rather it not say "alter".
5. Set `SSO_CLIENT_ID`, `SSO_CLIENT_SECRET`, `SSO_BASE_URL` (if different) and `SSO_REDIRECT_URI` in the backend's `.env` (or as Docker Hub / host env vars) — see `backend/README.md`.

No code changes needed beyond the Android package/scheme in steps 2–3.
