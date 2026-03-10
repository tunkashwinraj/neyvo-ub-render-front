// Web: update the browser address bar to [path] without reloading.
import 'dart:html' as html;

void updateBrowserUrl(String path) {
  html.window.history.replaceState(null, '', path);
}
