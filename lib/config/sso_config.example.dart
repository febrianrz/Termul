/// Template for `sso_config.dart` (gitignored — never commit real secrets).
/// Copy this file to `sso_config.dart` and fill in the real values from
/// the Alter Indonesia "Aplikasi Klien" admin panel.
class SsoConfig {
  static const baseUrl = 'https://one.alterindonesia.com';
  static const clientId = 'YOUR_CLIENT_ID';
  static const clientSecret = 'YOUR_CLIENT_SECRET';
  static const redirectUri = 'com.febrianrz.termul://callback';
  static const callbackUrlScheme = 'com.febrianrz.termul';
}
