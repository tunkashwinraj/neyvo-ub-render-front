// Visible reCAPTCHA v2 "I'm not a robot" checkbox (web only; no-op on other platforms).
import 'package:flutter/material.dart';

import 'recaptcha_v2_checkbox_stub.dart'
    if (dart.library.html) 'recaptcha_v2_checkbox_web.dart' as impl;

Widget buildRecaptchaV2Checkbox({
  required String siteKey,
  required void Function(String token) onVerified,
  Key? key,
}) =>
    impl.buildRecaptchaV2Checkbox(
      siteKey: siteKey,
      onVerified: onVerified,
      key: key,
    );
