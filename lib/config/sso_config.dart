/// SSO credentials, supplied at build time via `--dart-define` (or
/// `--dart-define-from-file`) — never hardcoded here, so this file is safe
/// to commit.
///
/// Local dev: copy `dart_define.example.json` to `dart_define.json`
/// (gitignored) and run `flutter run --dart-define-from-file=dart_define.json`.
///
/// TEMPORARY: the client_secret ends up embedded in the compiled app because
/// there is no backend deployed yet to broker the token exchange. This is
/// not safe for a production release (it can be extracted from the
/// APK/IPA) — once the Termul backend is deployed, move the `/oauth/token`
/// exchange server-side and drop `clientSecret` from the app entirely.
class SsoConfig {
  static const baseUrl = String.fromEnvironment(
    'ALTER_SSO_BASE_URL',
    defaultValue: 'https://one.alterindonesia.com',
  );
  static const clientId = String.fromEnvironment('ALTER_CLIENT_ID');
  static const clientSecret = String.fromEnvironment('ALTER_CLIENT_SECRET');
  static const redirectUri = 'com.febrianrz.termul://callback';
  static const callbackUrlScheme = 'com.febrianrz.termul';
}
