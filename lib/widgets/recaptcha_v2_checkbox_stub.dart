// Stub for non-web: no visible reCAPTCHA checkbox.
import 'package:flutter/material.dart';

Widget buildRecaptchaV2Checkbox({
  required String siteKey,
  required void Function(String token) onVerified,
  Key? key,
}) =>
    const SizedBox.shrink();
