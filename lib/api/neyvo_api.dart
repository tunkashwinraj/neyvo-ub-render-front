import 'package:flutter/widgets.dart';

import 'spearia_api.dart';

export 'spearia_api.dart' show ApiException, ApiTimeoutClass, SpeariaApi;

/// Canonical API facade for Neyvo runtime.
/// Static members are explicit forwards so call sites can use `NeyvoApi.*` like `SpeariaApi.*`.
class NeyvoApi extends SpeariaApi {
  static String get baseUrl => SpeariaApi.baseUrl;

  static String? get sessionToken => SpeariaApi.sessionToken;

  static void setBaseUrl(String url) => SpeariaApi.setBaseUrl(url);

  static void setSessionToken(String? token) => SpeariaApi.setSessionToken(token);

  static void setAdminToken(String? token) => SpeariaApi.setAdminToken(token);

  static void setUserId(String? uid) => SpeariaApi.setUserId(uid);

  static void setDefaultAccountId(String? id) => SpeariaApi.setDefaultAccountId(id);

  static void setDefaultTimeout(Duration d) => SpeariaApi.setDefaultTimeout(d);

  static Duration timeoutForClass(ApiTimeoutClass timeoutClass) =>
      SpeariaApi.timeoutForClass(timeoutClass);

  static void setNgrokSkipHeader(bool enabled) => SpeariaApi.setNgrokSkipHeader(enabled);

  static void setAutoAdminForAdminPaths(bool enabled) =>
      SpeariaApi.setAutoAdminForAdminPaths(enabled);

  static void setGlobalErrorHook(ApiErrorHook? hook) => SpeariaApi.setGlobalErrorHook(hook);

  static Future<Map<String, dynamic>> postJsonMap(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    Duration? timeout,
    bool adminAuth = false,
  }) =>
      SpeariaApi.postJsonMap(
        path,
        body: body,
        params: params,
        headers: headers,
        timeout: timeout,
        adminAuth: adminAuth,
      );

  static Future<dynamic> patchJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    Duration? timeout,
    bool adminAuth = false,
  }) =>
      SpeariaApi.patchJson(
        path,
        body: body,
        params: params,
        headers: headers,
        timeout: timeout,
        adminAuth: adminAuth,
      );

  static Future<dynamic> deleteJson(
    String path, {
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    Duration? timeout,
    bool adminAuth = false,
  }) =>
      SpeariaApi.deleteJson(
        path,
        params: params,
        headers: headers,
        timeout: timeout,
        adminAuth: adminAuth,
      );

  static Future<String> getText(
    String path, {
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    Duration? timeout,
    bool adminAuth = false,
  }) =>
      SpeariaApi.getText(
        path,
        params: params,
        headers: headers,
        timeout: timeout,
        adminAuth: adminAuth,
      );

  static Future<Map<String, dynamic>> getJsonMap(
    String path, {
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    Duration? timeout,
    bool adminAuth = false,
  }) =>
      SpeariaApi.getJsonMap(
        path,
        params: params,
        headers: headers,
        timeout: timeout,
        adminAuth: adminAuth,
      );

  static Future<bool> launchExternal(String url) => SpeariaApi.launchExternal(url);

  static Future<bool> launchInApp(String url) => SpeariaApi.launchInApp(url);

  static Future<T?> guardApi<T>(
    BuildContext context,
    Future<T> Function() op, {
    String? friendlyError,
  }) =>
      SpeariaApi.guardApi(context, op, friendlyError: friendlyError);
}
