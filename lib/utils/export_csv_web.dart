// Web: trigger CSV file download
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';

Future<void> downloadCsv(String filename, String csvContent, BuildContext context) async {
  final bytes = utf8.encode(csvContent);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)..setAttribute('download', filename);
  anchor.click();
  html.Url.revokeObjectUrl(url);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloaded $filename')),
    );
  }
}
