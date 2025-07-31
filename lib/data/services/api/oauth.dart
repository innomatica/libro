import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../../model/webdav.dart';

class PushedAuthResponse {
  PushedAuthResponse({
    required this.pkce,
    required this.nonce,
    required this.requestUri,
  });

  String pkce;
  String nonce;
  String requestUri;
}

// https://datatracker.ietf.org/doc/html/rfc6749#section-5.1
class TokenXchResponse {
  TokenXchResponse({
    required this.accessToken,
    required this.tokenType,
    this.refreshToken,
    this.expiresIn,
    this.scope,
  });

  String accessToken;
  String tokenType;
  String? refreshToken;
  int? expiresIn;
  String? scope;
}

// https://datatracker.ietf.org/doc/html/rfc6749#section-5.1
class RefreshTokenResponse {
  RefreshTokenResponse({
    required this.accessToken,
    required this.tokenType,
    this.expiresIn,
    this.refreshToken,
    this.scope,
  });

  String accessToken;
  String tokenType;
  int? expiresIn;
  String? refreshToken;
  String? scope;
}

enum OAuthExCause { parreq, parres, excreq, excres, refreq, refres }

class OAuthException implements Exception {
  OAuthException(this.cause, {this.statusCode, this.details});
  OAuthExCause cause;
  int? statusCode;
  String? details;

  @override
  String toString() => '${cause.name} - $statusCode: $details';
}

class OAuthService {
  static const refreshMargin = 600; // 10 minutes
  // ignore: unused_field
  final _logger = Logger("OAuthHandler");

  Future<PushedAuthResponse> pushedAuthRequest(WebDavAuth auth) async {
    // check OIDC parameters
    final authEp = auth.extra!["authEp"];
    final parEp = auth.extra!["parEp"];
    final redirectUri = auth.redirectUri;
    final scope = auth.scope;
    final audience = auth.audience;
    if ([authEp, parEp, redirectUri, scope, audience].any((e) => e == null)) {
      throw OAuthException(
        OAuthExCause.parreq,
        details:
            "invalid parameters: authEp:$authEp,parEp:$parEp"
            "redirectUri:$redirectUri, scope:$scope, audience:$audience",
      );
    }
    // check credential
    final clientId = auth.username;
    final clientSecret = auth.password;
    if (clientId == null || clientSecret == null) {
      throw OAuthException(
        OAuthExCause.parreq,
        details: "invalid credentials: id:$clientId, secret:$clientSecret",
      );
    }
    // create credentials and nonce
    final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
    final nonce = _getRandomString();
    // create pkce and challenge
    // https://datatracker.ietf.org/doc/html/rfc7636/#section-4.1
    final pkce = _getRandomString(32).substring(0, 43); // remove padding
    // https://datatracker.ietf.org/doc/html/rfc7636/#section-4.2
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(pkce)).bytes)
        .substring(0, 43); // remove padding
    //
    // Pushed Authorization Requests (RFC 9129:2.1)
    //
    // https://datatracker.ietf.org/doc/html/rfc9126#name-request
    // with PKCE
    // https://datatracker.ietf.org/doc/html/rfc7636/#section-4.3
    //
    final parReqResp = await http.post(
      Uri.parse(parEp),
      headers: {'Authorization': 'Basic $credentials'},
      // Map format body will be turned into x-ww-form-urlencoded
      body: {
        "response_type": "code",
        "state": nonce,
        "client_id": clientId,
        "redirect_uri": redirectUri,
        "scope": scope,
        "code_challenge": challenge,
        "code_challenge_method": "S256",
        "audience": audience,
      },
    );
    // https://datatracker.ietf.org/doc/html/rfc9126#section-2.2
    _logger.fine('PAR response: ${parReqResp.body}');
    if (parReqResp.statusCode == 201) {
      // final lifetime = jsonDecode(res.body)['expires_in'];
      final requestUri = jsonDecode(parReqResp.body)['request_uri'];
      return PushedAuthResponse(
        pkce: pkce,
        nonce: nonce,
        requestUri: requestUri,
      );
    } else {
      throw OAuthException(
        OAuthExCause.parres,
        statusCode: parReqResp.statusCode,
        details: parReqResp.body,
      );
    }
  }

  Future<TokenXchResponse> exchangeToken({
    required WebDavAuth auth,
    required String code,
    required String pkce,
  }) async {
    // check auth parameters
    final tokenEp = auth.extra!["tokenEp"];
    final redirectUri = auth.redirectUri;
    final audience = auth.audience;
    if ([tokenEp, redirectUri, audience].any((e) => e == null)) {
      throw OAuthException(
        OAuthExCause.excreq,
        details:
            "invalid parameters:tokenEp:$tokenEp,"
            "redirectUri:$redirectUri, audience:$audience",
      );
    }
    // check credential
    final clientId = auth.username;
    final clientSecret = auth.password;
    if (clientId == null || clientSecret == null) {
      throw OAuthException(
        OAuthExCause.excreq,
        details: "invalid credentials: id:$clientId, secret:$clientSecret",
      );
    }
    // create credentials and nonce
    final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
    //
    // Access Token Exchange
    //
    // https://datatracker.ietf.org/doc/html/rfc6749#section-4.1.3
    // with PKCE
    // https://datatracker.ietf.org/doc/html/rfc7636/#section-4.5
    //
    final tokenExcRes = await http.post(
      // Uri(scheme: 'https', host: authHost, path: tokenPath),
      Uri.parse(tokenEp),
      headers: {'Authorization': 'Basic $credentials'},
      body: {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirectUri,
        "client_id": clientId,
        "code_verifier": pkce,
        "audience": audience,
      },
    );
    // https://datatracker.ietf.org/doc/html/rfc6749#section-4.1.4
    // {
    //   "access_token":"authelia_at_...",
    //   "expires_in": 3599,
    //   "refresh_token":"authelia_rt_...",
    //   "scope": "offline_access authelia.bearer.authz",
    //   "token_type": "bearer"
    // }
    _logger.fine('token response:${tokenExcRes.body}');
    if (tokenExcRes.statusCode == 200) {
      // save token data
      final tokenData = (jsonDecode(tokenExcRes.body) as Map);
      return TokenXchResponse(
        accessToken: tokenData["access_token"],
        tokenType: tokenData['token_type'],
        refreshToken: tokenData['refresh_token'],
        expiresIn: tokenData["expires_in"],
        scope: tokenData["scope"],
      );
    } else {
      throw OAuthException(
        OAuthExCause.excres,
        statusCode: tokenExcRes.statusCode,
        details: tokenExcRes.body,
      );
    }
  }

  Future<RefreshTokenResponse> refreshToken(WebDavAuth auth) async {
    // check auth parameters
    if (auth.extra?['tokenEp'] == null ||
        auth.refreshToken == null ||
        auth.expiresAt == null) {
      _logger.warning(
        'necessary auth parameters (tokenEp, refreshToken or '
        'expiresAt) missing:$auth',
      );
      throw OAuthException(
        OAuthExCause.refreq,
        details:
            "invalid paramters: tokenEp:${auth.extra?['tokenEp']}, "
            "refreshToken:${auth.refreshToken}, expiresAt:${auth.expiresAt}",
      );
    }
    // check credentials
    final clientId = auth.username;
    final clientSecret = auth.password;
    if (clientId == null || clientSecret == null) {
      throw OAuthException(
        OAuthExCause.refreq,
        details: "invalid credentials: id:$clientId, secret:$clientSecret",
      );
    }
    //
    // Refresh Token
    // https://datatracker.ietf.org/doc/html/rfc6749#section-6
    //
    final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
    final tokenRefRes = await http.post(
      Uri.parse(auth.extra!['tokenEp']),
      headers: {'Authorization': 'Basic $credentials'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': auth.refreshToken,
        "scope": auth.scope,
      },
    );
    // https://datatracker.ietf.org/doc/html/rfc6749#section-5.1
    // {
    //   "access_token":"authelia_at_...",
    //   "expires_in": 3599,
    //   "refresh_token":"authelia_rt_...",
    //   "scope": "offline_access authelia.bearer.authz",
    //   "tokey_type": "bearer"
    // }
    _logger.fine(
      'refresh response:${tokenRefRes.statusCode} -${tokenRefRes.body}',
    );
    if (tokenRefRes.statusCode == 200) {
      final tokenData = (jsonDecode(tokenRefRes.body) as Map);
      // update token data
      // auth.accessToken = tokenData["access_token"];
      // auth.refreshToken = tokenData["refresh_token"];
      // auth.expiresAt = tokenData["expires_in"] +
      //     DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // _logger.fine('updated: $auth');
      return RefreshTokenResponse(
        accessToken: tokenData["access_token"],
        tokenType: tokenData["token_type"],
        expiresIn: tokenData["expires_in"],
        refreshToken: tokenData["refresh_token"],
        scope: tokenData["scope"],
      );
    } else {
      throw OAuthException(
        OAuthExCause.refres,
        statusCode: tokenRefRes.statusCode,
        details: tokenRefRes.body,
      );
    }
  }

  String _getRandomString([int size = 16]) {
    return base64Url
        .encode(List<int>.generate(size, (_) => Random.secure().nextInt(256)))
        .replaceAll("=", "");
  }
}
