# Termul

SSH client / terminal multiplexer for Android (Termius-like), built with Flutter.

## Download

[**⬇ Download latest APK**](https://github.com/febrianrz/Termul/releases/latest/download/app-release.apk)

The APK is built automatically by GitHub Actions on every push, so the link above always points to the latest build. Build history is in the [Actions](https://github.com/febrianrz/Termul/actions) tab.

## Features

- Save multiple SSH hosts (name, address, port, username, password or private key)
- Passwords/private keys are stored in the device's secure storage (Keychain/Keystore), never in plaintext
- Interactive terminal per host (xterm + dartssh2)
- SSO login via Alter Indonesia (OAuth2 Authorization Code Grant)

## Project structure

- `lib/` — the Flutter app (Android & iOS)
- `backend/` — backend skeleton (Express + TypeScript) for future cross-device sync, not yet wired into the app

## Running locally

```bash
flutter pub get
cp dart_define.example.json dart_define.json   # fill in ALTER_CLIENT_ID & ALTER_CLIENT_SECRET, never commit this file
flutter run --dart-define-from-file=dart_define.json
```

## CI configuration (automatic APK builds)

The `.github/workflows/build-apk.yml` workflow needs two repository secrets so the built APK can actually log in:

- `ALTER_CLIENT_ID`
- `ALTER_CLIENT_SECRET`

Add them under **Settings → Secrets and variables → Actions → New repository secret**. Without these, the APK still builds, but SSO login won't work.
