// lib/api/spearia_api.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as ul;

import '../core/pulse_request_cancelled.dart';

/// Thrown by the HTTP client on non-2xx or invalid responses.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Uri? uri;
  final dynamic payload;

  ApiException(this.message, {this.statusCode, this.uri, this.payload});

  @override
  String toString() =>
      'ApiException(${statusCode ?? '-'} ${uri?.toString() ?? ''}): $message';
}

/// Optional global hook so UI can show SnackBars, Sentry, etc.
typedef ApiErrorHook = void Function(ApiException e);

enum ApiTimeoutClass { fast, medium, heavy }

/// Centralized HTTP/URL utility for the Flutter app.
///
/// Configure once (usually in main()):
///   NeyvoApi.setBaseUrl("http://127.0.0.1:8000");
///   NeyvoApi.setSessionToken("...");                 // <- user session (Bearer)
///   NeyvoApi.setAdminToken("...");                   // optional admin header
///   NeyvoApi.setDefaultAccountId("demo-biz-001");   // optional convenience
///   NeyvoApi.setGlobalErrorHook((e) { ... });        // optional
class SpeariaApi {
  static String _baseUrl = "";
  static String? _sessionToken; // <— NEW: user session (Bearer)
  static String? _adminToken; // optional X-Admin-Token for admin routes
  static String? _userId; // optional X-User-Id for Pulse RBAC
  static String? _defaultAccountId; // auto-injected if a call forgets it
  static Duration _defaultTimeout = const Duration(seconds: 20);
  static bool _sendNgrokSkipHeader = false;
  static bool _autoAdminForAdminPaths = true; // add X-Admin-Token for /admin/*
  static ApiErrorHook? _errorHook;

  static Dio? _dio;
  static String _dioBaseUrl = "";

  /// Cancels in-flight tab-scoped GETs (see [getJsonMapTabScoped]). Call when the
  /// user selects a different main Pulse sidebar tab so the previous screen stops
  /// competing for bandwidth with the new one.
  static CancelToken? _pulseTabCancelToken;

  static void bumpPulseTabCancelToken() {
    try {
      _pulseTabCancelToken?.cancel('pulse tab switched');
    } catch (_) {}
    _pulseTabCancelToken = CancelToken();
  }

  /// Dio client mirroring the behavior of the Neyvo HTTP helpers.
  /// This is used by some Riverpod providers (e.g. billing) that call
  /// `api.dio.get(...)` per feature spec.
  Dio get dio {
    _ensureBaseUrlOrThrow();
    if (_dio == null || _dioBaseUrl != _baseUrl) {
      _dioBaseUrl = _baseUrl;
      _dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: _defaultTimeout,
          receiveTimeout: _defaultTimeout,
        ),
      );
      _dio!.interceptors.clear();
      _dio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            // Inject default account_id (same behavior as _withAccountId in HTTP helpers).
            if (_defaultAccountId != null && _defaultAccountId!.isNotEmpty) {
              options.queryParameters.putIfAbsent('account_id', () => _defaultAccountId!);
            }

            // Inject headers (Authorization, X-Admin-Token, X-User-Id, Accept, CORS helper header).
            final h = _headers(
              headers: null,
              adminAuth: false,
              path: options.path,
              includeJsonContentType: false,
            );
            options.headers.addAll(h);

            handler.next(options);
          },
        ),
      );
    }
    return _dio!;
  }

  /// Read-only getter (handy for building absolute links)
  static String get baseUrl => _baseUrl;

  /// Returns current session token (if any)
  static String? get sessionToken => _sessionToken;

  /// Configure once (on app start)
  /// When baseUrl is not ngrok, the ngrok-skip-browser-warning header is disabled
  /// to avoid CORS preflight rejections on production (e.g. Render).
  static void setBaseUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) {
      _baseUrl = "";
      return;
    }
    _baseUrl = u.replaceAll(RegExp(r'/+$'), '');
    _sendNgrokSkipHeader = u.contains('ngrok');
  }

  /// Set/clear the logged-in user's session token (sent as `Authorization: Bearer ...`)
  static void setSessionToken(String? token) {
    _sessionToken =
        (token == null || token.trim().isEmpty) ? null : token.trim();
  }

  /// Optional admin token (sent as X-Admin-Token)
  static void setAdminToken(String? token) {
    _adminToken = (token == null || token.trim().isEmpty) ? null : token.trim();
  }

  /// Optional user id for Pulse RBAC (sent as X-User-Id)
  static void setUserId(String? uid) {
    _userId = (uid == null || uid.trim().isEmpty) ? null : uid.trim();
  }

  /// Optional: default account id (will be injected if missing in params/body)
  static void setDefaultAccountId(String? id) {
    _defaultAccountId =
        (id == null || id.trim().isEmpty) ? null : id.trim();
  }

  /// Optional: adjust default request timeout
  static void setDefaultTimeout(Duration d) {
    _defaultTimeout = d;
    // Rebuild Dio so [connectTimeout]/[receiveTimeout] match (cached instance would keep old values).
    _dio = null;
  }

  /// Timeout buckets for endpoint classes.
  /// Keep these explicit so critical identity calls fail fast while
  /// heavy analytics/report endpoints can tolerate backend latency.
  static Duration timeoutForClass(ApiTimeoutClass timeoutClass) {
    switch (timeoutClass) {
      case ApiTimeoutClass.fast:
        return const Duration(seconds: 10);
      case ApiTimeoutClass.medium:
        return const Duration(seconds: 15);
      case ApiTimeoutClass.heavy:
        return const Duration(minutes: 3);
    }
  }

  /// Optional: ngrok HTML splash avoidance header
  static void setNgrokSkipHeader(bool enabled) {
    _sendNgrokSkipHeader = enabled;
  }

  /// Optional: auto-add admin token on /admin/* paths
  static void setAutoAdminForAdminPaths(bool enabled) {
    _autoAdminForAdminPaths = enabled;
  }

  /// Optional global error hook (SnackBar, logging, etc.)
  static void setGlobalErrorHook(ApiErrorHook? hook) {
    _errorHook = hook;
  }

  static void _ensureBaseUrlOrThrow() {
    if (_baseUrl.isEmpty) {
      throw ApiException(
        'Neyvo API baseUrl is empty. Did you call NeyvoApi.setBaseUrl(...) in main.dart?',
      );
    }
  }

  /// Compose absolute URL from a path like "/api/xyz".
  static Uri _uri(String path, {Map<String, dynamic>? params}) {
    _ensureBaseUrlOrThrow();

    final full = path.startsWith('http')
        ? path
        : '$_baseUrl${path.startsWith('/') ? '' : '/'}$path';

    final qp = <String, String>{};
    params?.forEach((k, v) {
      if (v != null) qp[k] = v.toString();
    });

    return Uri.parse(full).replace(queryParameters: qp.isEmpty ? null : qp);
  }

  /// Build headers. We only include Content-Type when sending a JSON body to
  /// avoid unnecessary CORS preflights for GET/DELETE on web.
  static Map<String, String> _headers({
    Map<String, String>? headers,
    required bool adminAuth,
    required String path,
    bool includeJsonContentType = false,
  }) {
    final h = <String, String>{
      'Accept': 'application/json',
      if (includeJsonContentType) 'Content-Type': 'application/json',
      if (kIsWeb && _sendNgrokSkipHeader) 'ngrok-skip-browser-warning': 'true',
      ...?headers,
    };

    // User session (Bearer)
    if (_sessionToken != null && _sessionToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_sessionToken';
    }

    // Admin header - always send if available (many API routes require it)
    // Previously only sent for /admin/* paths, but other routes also need it
    if (_adminToken != null && _adminToken!.isNotEmpty) {
      h['X-Admin-Token'] = _adminToken!;
    }
    // Pulse RBAC: send current user id when set
    if (_userId != null && _userId!.isNotEmpty) {
      h['X-User-Id'] = _userId!;
    }
    return h;
  }

  static bool _looksLikeHtml(String body) {
    final t = body.trimLeft();
    return t.startsWith('<!DOCTYPE') || t.startsWith('<html');
  }

  static bool _looksLikeXml(String body) {
    final t = body.trimLeft();
    // Typical Twilio / XML prologs
    return t.startsWith('<?xml') ||
        t.startsWith('<Response') ||
        t.startsWith('<Twilio') ||
        t.startsWith('<speak');
  }

  static Future<Map<String, dynamic>> postJsonMap(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    Duration? timeout,
    bool adminAuth = false,
  }) async {
    final v = await postJson(
      path,
      body: body,
      params: params,
      headers: headers,
      timeout: timeout,
      adminAuth: adminAuth,
    );

    if (v is Map) {
      return Map<String, dynamic>.from(v);
    }

    throw ApiException(
      'Expected JSON object but got ${v.runtimeType}',
      uri: _uri(path, params: params),
    );
  }

  /// POST JSON using Dio with explicit connect/send/receive timeouts.
  ///
  /// Use for very large bodies (e.g. student CSV import). On Flutter web, `package:http`
  /// plus [Future.timeout] has been observed to fail around ~30s even when a longer
  /// duration is passed; Dio applies the full timeout to the upload and response.
  static Future<Map<String, dynamic>> postJsonMapDio(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? params,
    required Duration timeout,
    bool adminAuth = false,
  }) async {
    _ensureBaseUrlOrThrow();
    final p = Map<String, dynamic>.from(_withAccountId(params) ?? {});
    final b = _withAccountId(body);
    final dioClient = SpeariaApi().dio;
    try {
      final resp = await dioClient.post<dynamic>(
        path,
        queryParameters: p.isEmpty ? null : p,
        data: b,
        options: Options(
          connectTimeout: timeout,
          sendTimeout: timeout,
          receiveTimeout: timeout,
          responseType: ResponseType.json,
          headers: _headers(
            headers: null,
            adminAuth: adminAuth,
            path: path,
            includeJsonContentType: true,
          ),
        ),
      );
      final data = resp.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw ApiException(
        'Expected JSON object but got ${data.runtimeType}',
        uri: _uri(path, params: params),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final respBody = e.response?.data;
      String msg = e.message ?? 'HTTP error';
      if (respBody is Map && respBody['error'] != null) {
        msg = respBody['error'].toString();
      } else if (respBody is String && respBody.isNotEmpty) {
        msg = respBody;
      }
      throw ApiException(
        msg,
        statusCode: status,
        uri: e.requestOptions.uri,
        payload: respBody,
      );
    }
  }

  static Future<dynamic> putJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    Duration? timeout,
    bool adminAuth = false,
  }) async {
    final p = _withAccountId(params);
    final b = _withAccountId(body);
    final uri = _uri(path, params: p);
    try {
      final resp = await http
          .put(
            uri,
            headers: _headers(
              headers: headers,
              adminAuth: adminAuth,
              path: path,
              includeJsonContentType: true,
            ),
            body: jsonEncode(b ?? {}),
          )
          .timeout(timeout ?? _defaultTimeout);
      return _decodeOrThrow(resp, uri);
    } on ApiException catch (e) {
      _errorHook?.call(e);
      rethrow;
    }
  }

  static dynamic _decodeOrThrow(http.Response resp, Uri uri) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return null;
      if (_looksLikeHtml(resp.body) || _looksLikeXml(resp.body)) {
        throw ApiException(
          'Server returned ${_looksLikeHtml(resp.body) ? 'HTML' : 'XML'} instead of JSON.\n'
          '• You probably called getJson() on a text/html or text/xml endpoint.\n'
          '• Use NeyvoApi.getText(...) for endpoints that return TwiML/XML (e.g., /incoming-call) or plain text.\n'
          'URI: $uri',
          statusCode: resp.statusCode,
          uri: uri,
          payload: resp.body,
        );
      }
      try {
        return jsonDecode(resp.body);
      } catch (e) {
        throw ApiException('Invalid JSON response: $e', statusCode: resp.statusCode, uri: uri, payload: resp.body);
      }
    } else {
      try {
        final obj = jsonDecode(resp.body);
        throw ApiException(
          obj['error']?.toString() ?? 'HTTP ${resp.statusCode}',
          statusCode: resp.statusCode,
          uri: uri,
          payload: obj,
        );
      } catch (_) {
        throw ApiException('HTTP ${resp.statusCode}: ${resp.body}', statusCode: resp.statusCode, uri: uri);
      }
    }
  }

  /// Injects default account_id if not provided.
  static Map<String, dynamic>? _withAccountId(Map<String, dynamic>? paramsOrBody) {
    if (_defaultAccountId == null) return paramsOrBody;
    final map = Map<String, dynamic>.from(paramsOrBody ?? {});
    map.putIfAbsent('account_id', () => _defaultAccountId);
    return map;
  }

  // --------------------------- URL Helpers ---------------------------------

  static Future<bool> launchExternal(String url) async {
    if (url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    try {
      return await ul.launchUrl(
        uri,
        mode: ul.LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> launchInApp(String url) async {
    if (url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    try {
      return await ul.launchUrl(
        uri,
        mode: ul.LaunchMode.inAppWebView,
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> dial(String e164) {
    final clean = e164.replaceAll(' ', '');
    final uri = Uri.tryParse('tel:$clean');
    if (uri == null) return Future.value(false);
    return ul.launchUrl(uri, mode: ul.LaunchMode.externalApplication);
  }

  /// Open WhatsApp chat with phone number (E.164 format, no +)
  static Future<bool> whatsApp(String e164) {
    final clean = e164.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.isEmpty) return Future.value(false);
    final uri = Uri.parse('https://wa.me/$clean');
    return ul.launchUrl(uri, mode: ul.LaunchMode.externalApplication);
  }

  static Future<bool> email(String to, {String? subject, String? body}) {
    final qp = <String, String>{};
    if (subject != null && subject.isNotEmpty) qp['subject'] = subject;
    if (body != null && body.isNotEmpty) qp['body'] = body;

    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: qp.isEmpty ? null : qp,
    );
    return ul.launchUrl(uri, mode: ul.LaunchMode.externalApplication);
  }

  // ---------- Authorized Numbers (admin) ----------
  static Future<List<Map<String, dynamic>>> adminListAuthorizedNumbers(String accountId) async {
    final res = await getJsonMap(
      '/admin/authorized-numbers',
      params: {'account_id': accountId},
      adminAuth: true,
    );
    final items = (res['items'] as List).cast<Map<String, dynamic>>();
    return items;
  }

  static Future<void> adminAddAuthorizedNumber({
    required String accountId,
    required String e164,
    String? label,
    String type = 'allow',
  }) async {
    await postJson(
      '/admin/authorized-numbers',
      adminAuth: true,
      body: {
        'account_id': accountId,
        'e164': e164,
        if (label != null) 'label': label,
        'type': type,
      },
    );
  }

  static Future<void> adminUpdateAuthorizedNumber({
    required String accountId,
    required String docId,
    String? label,
    String? type, // 'allow' | 'block'
  }) async {
    final body = <String, dynamic>{'account_id': accountId};
    if (label != null) body['label'] = label;
    if (type != null) body['type'] = type;
    await patchJson('/admin/authorized-numbers/$docId', adminAuth: true, body: body);
  }

  static Future<void> adminRemoveAuthorizedNumber({
    required String accountId,
    required String e164,
  }) async {
    await deleteJson(
      '/admin/authorized-numbers',
      adminAuth: true,
      params: {'account_id': accountId, 'e164': e164},
    );
  }

  // ---------- Training Admin ----------
  static Future<Map<String, dynamic>> adminTrainingInfo(String accountId) async {
    return await getJsonMap(
      '/admin/training/info',
      params: {'account_id': accountId},
      adminAuth: false,
    );
  }

  static Future<String> adminRotateTrainingPin(String accountId) async {
    final res = await postJson(
      '/admin/training/rotate-pin',
      body: {'account_id': accountId},
      adminAuth: true,
    );
    if (res is Map && res['pin'] is String) return res['pin'];
    throw ApiException('Unexpected rotate-pin response', payload: res);
  }

  // --------------------------- HTTP Helpers --------------------------------

  static Future<dynamic> getJson(
      String path, {
        Map<String, dynamic>? params,
        Map<String, String>? headers,
        Duration? timeout,
        bool adminAuth = false,
      }) async {
    final p = _withAccountId(params);
    final uri = _uri(path, params: p);
    try {
      final resp = await http
          .get(uri, headers: _headers(headers: headers, adminAuth: adminAuth, path: path))
          .timeout(timeout ?? _defaultTimeout);
      return _decodeOrThrow(resp, uri);
    } on ApiException catch (e) {
      _errorHook?.call(e);
      rethrow;
    }
  }

  static Future<dynamic> postJson(
      String path, {
        Map<String, dynamic>? body,
        Map<String, dynamic>? params,
        Map<String, String>? headers,
        Duration? timeout,
        bool adminAuth = false,
      }) async {
    final p = _withAccountId(params);
    final b = _withAccountId(body);
    final uri = _uri(path, params: p);
    try {
      final resp = await http
          .post(
        uri,
        headers: _headers(
          headers: headers,
          adminAuth: adminAuth,
          path: path,
          includeJsonContentType: true,
        ),
        body: jsonEncode(b ?? {}),
      )
          .timeout(timeout ?? _defaultTimeout);
      return _decodeOrThrow(resp, uri);
    } on ApiException catch (e) {
      _errorHook?.call(e);
      rethrow;
    }
  }

  static Future<dynamic> patchJson(
      String path, {
        Map<String, dynamic>? body,
        Map<String, dynamic>? params,
        Map<String, String>? headers,
        Duration? timeout,
        bool adminAuth = false,
      }) async {
    final p = _withAccountId(params);
    final b = _withAccountId(body);
    final uri = _uri(path, params: p);
    try {
      final resp = await http
          .patch(
        uri,
        headers: _headers(
          headers: headers,
          adminAuth: adminAuth,
          path: path,
          includeJsonContentType: true,
        ),
        body: jsonEncode(b ?? {}),
      )
          .timeout(timeout ?? _defaultTimeout);
      return _decodeOrThrow(resp, uri);
    } on ApiException catch (e) {
      _errorHook?.call(e);
      rethrow;
    }
  }

  static Future<dynamic> deleteJson(
      String path, {
        Map<String, dynamic>? params,
        Map<String, String>? headers,
        Duration? timeout,
        bool adminAuth = false,
      }) async {
    final p = _withAccountId(params);
    final uri = _uri(path, params: p);
    try {
      final resp = await http
          .delete(uri, headers: _headers(headers: headers, adminAuth: adminAuth, path: path))
          .timeout(timeout ?? _defaultTimeout);
      return _decodeOrThrow(resp, uri);
    } on ApiException catch (e) {
      _errorHook?.call(e);
      rethrow;
    }
  }

  static Future<String> getText(
      String path, {
        Map<String, dynamic>? params,
        Map<String, String>? headers,
        Duration? timeout,
        bool adminAuth = false,
      }) async {
    final p = _withAccountId(params);
    final uri = _uri(path, params: p);
    try {
      final resp = await http
          .get(uri, headers: _headers(headers: headers, adminAuth: adminAuth, path: path))
          .timeout(timeout ?? _defaultTimeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw ApiException('HTTP ${resp.statusCode}: ${resp.body}', statusCode: resp.statusCode, uri: uri);
      }
      return resp.body;
    } on ApiException catch (e) {
      _errorHook?.call(e);
      rethrow;
    }
  }

  // --------------------------- Typed helpers -------------------------------

  static Future<Map<String, dynamic>> getJsonMap(
      String path, {
        Map<String, dynamic>? params,
        Map<String, String>? headers,
        Duration? timeout,
        bool adminAuth = false,
      }) async {
    final v = await getJson(
      path,
      params: params,
      headers: headers,
      timeout: timeout,
      adminAuth: adminAuth,
    );
    if (v is Map) return Map<String, dynamic>.from(v);
    throw ApiException('Expected JSON object but got ${v.runtimeType}', uri: _uri(path, params: params));
  }

  /// Same as [getJsonMap] but uses Dio with a shared cancel token. [bumpPulseTabCancelToken]
  /// should be called when switching main Pulse tabs so stale reads stop immediately.
  static Future<Map<String, dynamic>> getJsonMapTabScoped(
    String path, {
    Map<String, dynamic>? params,
    Map<String, String>? extraHeaders,
    Duration? timeout,
    bool adminAuth = false,
  }) async {
    _ensureBaseUrlOrThrow();
    final p = Map<String, dynamic>.from(_withAccountId(params) ?? {});
    _pulseTabCancelToken ??= CancelToken();
    final token = _pulseTabCancelToken!;
    final dioClient = SpeariaApi().dio;
    // Dio applies BaseOptions.connectTimeout (~20–30s) unless overridden. Long-running
    // Pulse reads (e.g. campaign CSV export) must raise connect + receive or Dio throws
    // DioExceptionType.connectionTimeout before the server finishes.
    final effectiveTimeout = timeout ?? _defaultTimeout;
    try {
      final resp = await dioClient.get<dynamic>(
        path,
        queryParameters: p.isEmpty ? null : p,
        cancelToken: token,
        options: Options(
          connectTimeout: effectiveTimeout,
          sendTimeout: effectiveTimeout,
          receiveTimeout: effectiveTimeout,
          responseType: ResponseType.json,
          headers: extraHeaders,
        ),
      );
      final data = resp.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw ApiException(
        'Expected JSON object but got ${data.runtimeType}',
        uri: _uri(path, params: params),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw const PulseRequestCancelled();
      }
      final status = e.response?.statusCode;
      final body = e.response?.data;
      String msg = e.message ?? 'HTTP error';
      if (body is Map && body['error'] != null) {
        msg = body['error'].toString();
      } else if (body is String && body.isNotEmpty) {
        msg = body;
      }
      throw ApiException(
        msg,
        statusCode: status,
        uri: e.requestOptions.uri,
        payload: body,
      );
    }
  }

  static Future<List<dynamic>> getJsonList(
      String path, {
        Map<String, dynamic>? params,
        Map<String, String>? headers,
        Duration? timeout,
        bool adminAuth = false,
      }) async {
    final v = await getJson(
      path,
      params: params,
      headers: headers,
      timeout: timeout,
      adminAuth: adminAuth,
    );
    if (v is List) return List<dynamic>.from(v);
    throw ApiException('Expected JSON array but got ${v.runtimeType}', uri: _uri(path, params: params));
  }

  // --------------------------- Convenience ---------------------------------

  /// Guard pattern to reduce try/catch in widgets:
  /// await NeyvoApi.guardApi(context, () => NeyvoApi.getJsonMap('/api/...'));
  static Future<T?> guardApi<T>(
      BuildContext context,
      Future<T> Function() op, {
        String? friendlyError, // optional SnackBar copy
      }) async {
    try {
      return await op();
    } on PulseRequestCancelled {
      return null;
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError ?? e.message)),
      );
      return null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError ?? 'Something went wrong: $e')),
      );
      return null;
    }
  }

  /// Quick ping for dev.
  static Future<void> debugPing(BuildContext context) async {
    try {
      final txt = await getText('/healthz');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backend OK: ${txt.trim()}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ping failed: $e')),
      );
    }
  }

  /// Retries only on transient network failures (not [ApiException] 4xx/5xx).
  /// Handles [DioException] (tab-scoped Dio) and [TimeoutException] (http package paths).
  static Future<T> runWithRetry<T>(
    Future<T> Function() op, {
    int maxAttempts = 3,
    Duration delay = const Duration(milliseconds: 400),
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await op();
      } on DioException catch (e) {
        final retryable = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout;
        if (!retryable || attempt >= maxAttempts) rethrow;
        await Future<void>.delayed(delay * attempt);
      } on TimeoutException {
        if (attempt >= maxAttempts) rethrow;
        await Future<void>.delayed(delay * attempt);
      }
    }
    throw StateError('runWithRetry: exhausted after $maxAttempts attempts');
  }
}
