// Web: expose current origin so we only send debug logs when on localhost.
import 'dart:html' as html;

String? get currentWebOrigin => html.window.location.origin;
