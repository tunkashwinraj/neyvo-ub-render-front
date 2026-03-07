// Web: open Stripe in same window so redirect returns with session.
import 'dart:html' as html;

Future<void> openStripeUrl(String url) async {
  html.window.location.assign(url);
}
