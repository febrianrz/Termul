import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/sso_config.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// Handles login against the Alter Indonesia OAuth2 SSO
/// (`{baseUrl}/oauth/authorize` + `/oauth/token`) and stores the resulting
/// tokens in secure storage.
class AuthService {
  static const _kAccessToken = 'sso_access_token';
  static const _kRefreshToken = 'sso_refresh_token';

  final _secureStorage = const FlutterSecureStorage();

  Future<bool> isLoggedIn() async {
    return await _secureStorage.read(key: _kAccessToken) != null;
  }

  Future<void> login() async {
    final state = const Uuid().v4();
    final authorizeUrl = Uri.parse('${SsoConfig.baseUrl}/oauth/authorize')
        .replace(
          queryParameters: {
            'client_id': SsoConfig.clientId,
            'redirect_uri': SsoConfig.redirectUri,
            'response_type': 'code',
            'state': state,
          },
        );

    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: authorizeUrl.toString(),
        callbackUrlScheme: SsoConfig.callbackUrlScheme,
      );
    } catch (_) {
      throw AuthException('Login dibatalkan');
    }

    final callbackUri = Uri.parse(result);
    final code = callbackUri.queryParameters['code'];
    final returnedState = callbackUri.queryParameters['state'];

    if (code == null) {
      throw AuthException('Login gagal: kode otorisasi tidak diterima');
    }
    if (returnedState != state) {
      throw AuthException('Login gagal: state tidak cocok');
    }

    await _exchangeCode(code);
  }

  Future<void> _exchangeCode(String code) async {
    final response = await http.post(
      Uri.parse('${SsoConfig.baseUrl}/oauth/token'),
      headers: {'Accept': 'application/json'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': SsoConfig.clientId,
        'client_secret': SsoConfig.clientSecret,
        'redirect_uri': SsoConfig.redirectUri,
        'code': code,
      },
    );

    if (response.statusCode != 200) {
      throw AuthException('Gagal menukar kode login (${response.statusCode})');
    }

    await _storeTokens(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> _storeTokens(Map<String, dynamic> data) async {
    await _secureStorage.write(
      key: _kAccessToken,
      value: data['access_token'] as String,
    );
    final refreshToken = data['refresh_token'] as String?;
    if (refreshToken != null) {
      await _secureStorage.write(key: _kRefreshToken, value: refreshToken);
    }
  }

  Future<bool> _refresh() async {
    final refreshToken = await _secureStorage.read(key: _kRefreshToken);
    if (refreshToken == null) return false;

    final response = await http.post(
      Uri.parse('${SsoConfig.baseUrl}/oauth/token'),
      headers: {'Accept': 'application/json'},
      body: {
        'grant_type': 'refresh_token',
        'client_id': SsoConfig.clientId,
        'client_secret': SsoConfig.clientSecret,
        'refresh_token': refreshToken,
      },
    );

    if (response.statusCode != 200) return false;
    await _storeTokens(jsonDecode(response.body) as Map<String, dynamic>);
    return true;
  }

  Future<http.Response> _getUser(String token) {
    return http.get(
      Uri.parse('${SsoConfig.baseUrl}/api/user'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
  }

  /// Returns the logged-in user's profile (per Alter Indonesia's `/api/user`
  /// schema), or null if not logged in / the session could not be refreshed.
  Future<Map<String, dynamic>?> fetchUser() async {
    var token = await _secureStorage.read(key: _kAccessToken);
    if (token == null) return null;

    var response = await _getUser(token);
    if (response.statusCode == 401) {
      if (!await _refresh()) return null;
      token = await _secureStorage.read(key: _kAccessToken);
      response = await _getUser(token!);
    }

    if (response.statusCode != 200) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> logout() async {
    final token = await _secureStorage.read(key: _kAccessToken);
    if (token != null) {
      try {
        await http.post(
          Uri.parse('${SsoConfig.baseUrl}/api/logout'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
      } catch (_) {
        // Best-effort revoke; still clear the local session below.
      }
    }
    await _secureStorage.delete(key: _kAccessToken);
    await _secureStorage.delete(key: _kRefreshToken);
  }
}
