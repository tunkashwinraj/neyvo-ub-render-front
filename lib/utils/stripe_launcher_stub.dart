// Stub: open Stripe in external browser (mobile/desktop).
import 'package:url_launcher/url_launcher.dart';

Future<void> openStripeUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
