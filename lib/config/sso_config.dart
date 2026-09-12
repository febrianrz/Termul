/// SSO / backend configuration, supplied at build time via `--dart-define`
/// (or `--dart-define-from-file`).
///
/// Local dev: copy `dart_define.example.json` to `dart_define.json`
/// (gitignored) and run `flutter run --dart-define-from-file=dart_define.json`.
///
/// The OAuth2 `client_secret` never appears here — it lives only in the
/// `backend/` service, which performs the `/oauth/token` exchange on the
/// app's behalf so the secret never ships inside the APK/IPA.
class SsoConfig {
  static const baseUrl = String.fromEnvironment(
    'ALTER_SSO_BASE_URL',
    defaultValue: 'https://one.alterindonesia.com',
  );
  static const clientId = String.fromEnvironment('ALTER_CLIENT_ID');
  static const redirectUri = 'com.febrianrz.termul://callback';
  static const callbackUrlScheme = 'com.febrianrz.termul';

  /// Base URL of the Termul backend (see `backend/`), which brokers the
  /// token exchange. Defaults to the Android emulator's alias for the
  /// host machine's localhost.
  static const backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}
