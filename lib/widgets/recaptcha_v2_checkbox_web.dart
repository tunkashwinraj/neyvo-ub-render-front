// Web: visible reCAPTCHA v2 "I'm not a robot" checkbox.
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// reCAPTCHA v2 site key.
/// In production, pass a real key via:
///   flutter build web --dart-define=RECAPTCHA_V2_SITE_KEY=your_site_key
/// For local dev, this falls back to Google's public test key.
const String _kDefaultV2SiteKey = String.fromEnvironment(
  'RECAPTCHA_V2_SITE_KEY',
  defaultValue: '6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI',
);
const String _kCallbackName = 'recaptchaV2Success';

void _onRecaptchaSuccess(String token) {
  _currentCallback?.call(token);
}

void Function(String)? _currentCallback;
String _currentSiteKey = _kDefaultV2SiteKey;
bool _viewFactoryRegistered = false;

void _registerViewFactory() {
  if (_viewFactoryRegistered) return;
  _viewFactoryRegistered = true;
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(
    'recaptcha-v2-checkbox',
    (int viewId) {
      final div = html.DivElement()
        ..className = 'g-recaptcha'
        ..setAttribute('data-sitekey', _currentSiteKey)
        ..setAttribute('data-callback', _kCallbackName)
        ..style.height = '78px'
        ..style.width = '304px';
      // Render after the element is in the DOM; reCAPTCHA script may load async.
      Future.microtask(() {
        _renderRecaptcha(div);
      });
      return div;
    },
  );
}

void _renderRecaptcha(html.Element div) {
  try {
    final grecaptcha = js_util.getProperty(html.window, 'grecaptcha');
    if (grecaptcha == null) {
      _scheduleRender(div);
      return;
    }
    js_util.callMethod(grecaptcha, 'render', [div]);
  } catch (_) {
    _scheduleRender(div);
  }
}

void _scheduleRender(html.Element div) {
  Future.delayed(const Duration(milliseconds: 300), () {
    if (div.ownerDocument == null) return;
    _renderRecaptcha(div);
  });
}

Widget buildRecaptchaV2Checkbox({
  required String siteKey,
  required void Function(String token) onVerified,
  Key? key,
}) {
  _currentSiteKey = siteKey.isNotEmpty ? siteKey : _kDefaultV2SiteKey;
  _registerViewFactory();
  _currentCallback = onVerified;
  // Expose callback for reCAPTCHA to call when user checks the box.
  js_util.setProperty(
    js_util.globalThis,
    _kCallbackName,
    js_util.allowInterop(_onRecaptchaSuccess),
  );
  return SizedBox(
    key: key,
    height: 78,
    width: 304,
    child: HtmlElementView(viewType: 'recaptcha-v2-checkbox'),
  );
}
