/// SSO / backend configuration, supplied at build time via `--dart-define`
/// (or `--dart-define-from-file`) — nothing provider-specific is hardcoded,
/// so forks can point this at their own OAuth2 SSO server and backend
/// without touching app code. See the root README's "Forking" section for
/// exactly what to change.
///
/// Local dev: copy `dart_define.example.json` to `dart_define.json`
/// (gitignored) and run `flutter run --dart-define-from-file=dart_define.json`.
///
/// The OAuth2 `client_secret` never appears here — it lives only in the
/// `backend/` service, which performs the `/oauth/token` exchange on the
/// app's behalf so the secret never ships inside the APK/IPA.
class SsoConfig {
  /// Base URL of the OAuth2 SSO server. The app expects it to expose a
  /// Laravel-Passport-style Authorization Code Grant: `/oauth/authorize`,
  /// `/oauth/token`, `/api/user`, `/api/logout`.
  static const baseUrl = String.fromEnvironment(
    'SSO_BASE_URL',
    defaultValue: 'https://one.alterindonesia.com',
  );
  static const clientId = String.fromEnvironment('SSO_CLIENT_ID');

  /// Must exactly match the redirect URI registered with the SSO client,
  /// and its scheme must match an intent-filter in AndroidManifest.xml
  /// (see android/app/src/main/AndroidManifest.xml).
  static const redirectUri = String.fromEnvironment(
    'SSO_REDIRECT_URI',
    defaultValue: 'com.febrianrz.termul://callback',
  );

  static String get callbackUrlScheme => Uri.parse(redirectUri).scheme;

  /// Base URL of the Termul backend (see `backend/`), which brokers the
  /// token exchange. Defaults to the Android emulator's alias for the
  /// host machine's localhost.
  static const backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}
