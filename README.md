# Termul

SSH client / terminal multiplexer untuk Android (mirip Termius), dibangun dengan Flutter.

## Download

[**⬇ Download APK terbaru**](https://github.com/febrianrz/Termul/releases/latest/download/app-release.apk)

APK dibuild otomatis oleh GitHub Actions setiap ada push, jadi link di atas selalu mengarah ke build terbaru. Riwayat build ada di tab [Actions](https://github.com/febrianrz/Termul/actions).

## Fitur

- Simpan banyak host SSH (nama, alamat, port, username, password atau private key)
- Password/private key disimpan di secure storage perangkat (Keychain/Keystore), bukan plaintext
- Terminal interaktif per host (xterm + dartssh2)
- Login SSO lewat Alter Indonesia (OAuth2 Authorization Code Grant)

## Struktur proyek

- `lib/` — aplikasi Flutter (Android & iOS)
- `backend/` — skeleton backend (Express + TypeScript) untuk fitur sync lintas device di masa depan, belum terhubung ke app

## Menjalankan secara lokal

```bash
flutter pub get
cp dart_define.example.json dart_define.json   # isi ALTER_CLIENT_ID & ALTER_CLIENT_SECRET, jangan di-commit
flutter run --dart-define-from-file=dart_define.json
```

## Konfigurasi CI (build APK otomatis)

Workflow `.github/workflows/build-apk.yml` butuh dua repository secret supaya APK hasil build bisa login:

- `ALTER_CLIENT_ID`
- `ALTER_CLIENT_SECRET`

Tambahkan di **Settings → Secrets and variables → Actions → New repository secret**. Tanpa ini, APK tetap ter-build tapi fitur login SSO tidak akan berfungsi.
