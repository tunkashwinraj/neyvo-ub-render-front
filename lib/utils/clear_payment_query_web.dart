// Web: remove ?payment=... from URL so refresh doesn't re-show the dialog.
import 'dart:html' as html;

void clearPaymentQueryFromUrl() {
  final loc = html.window.location;
  final search = loc.search;
  if (search == null || search.isEmpty) return;
  html.window.history.replaceState(null, '', loc.pathname);
}
