# Termul

SSH client / terminal multiplexer for Android (Termius-like), built with Flutter.

## Download

[**⬇ Download latest APK**](https://github.com/febrianrz/Termul/releases/latest/download/app-release.apk)

The APK is built automatically by GitHub Actions on every push, so the link above always points to the latest build. Build history is in the [Actions](https://github.com/febrianrz/Termul/actions) tab.

## Features

- Save multiple SSH hosts (name, address, port, username, password or private key)
- Passwords/private keys are stored in the device's secure storage (Keychain/Keystore), never in plaintext
- Interactive terminal per host (xterm + dartssh2)
- SSO login via Alter Indonesia (OAuth2 Authorization Code Grant) — the app never holds the OAuth client_secret; `backend/` performs the `/oauth/token` exchange on its behalf

## Project structure

- `lib/` — the Flutter app (Android & iOS)
- `backend/` — Express + TypeScript service that brokers the SSO token exchange; will also host cross-device sync in the future

## Running the app locally

```bash
flutter pub get
cp dart_define.example.json dart_define.json   # fill in ALTER_CLIENT_ID and point BACKEND_BASE_URL at your backend
flutter run --dart-define-from-file=dart_define.json
```

## Running the backend locally

See [`backend/README.md`](backend/README.md).

## CI/CD

- **`build-apk.yml`** — builds the release APK on every push and publishes it to the `latest` GitHub Release (the download link above). Needs repository secret `ALTER_CLIENT_ID` and, once the backend is deployed, repository **variable** `BACKEND_BASE_URL` (Settings → Secrets and variables → Actions).
- **`backend-docker.yml`** — builds `backend/`'s Docker image and pushes it to Docker Hub as `<DOCKERHUB_USERNAME>/termul-backend:latest` whenever `backend/**` changes. Needs repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` (a Docker Hub [access token](https://hub.docker.com/settings/security), not your password).

Add secrets/variables under **Settings → Secrets and variables → Actions**.
