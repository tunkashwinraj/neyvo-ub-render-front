// Fallback for non-web: copy CSV to clipboard
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> downloadCsv(String filename, String csvContent, BuildContext context) async {
  await Clipboard.setData(ClipboardData(text: csvContent));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV copied to clipboard. Paste into Excel or save as $filename')),
    );
  }
}
