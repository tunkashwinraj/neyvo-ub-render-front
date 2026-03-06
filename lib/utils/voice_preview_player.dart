// Shared utility to play voice preview audio in-app (URL or base64).
// Uses audioplayers so samples play directly in the app instead of opening a new tab.

import 'package:audioplayers/audioplayers.dart';

final AudioPlayer _sharedPlayer = AudioPlayer();

/// Play voice preview from API response.
/// Supports { audio_url } or { audio_base64, content_type }.
/// Stops any current playback before starting a new one.
Future<void> playVoicePreview(Map<String, dynamic> res) async {
  await _sharedPlayer.stop();
  final url = (res['audio_url'] ?? '').toString().trim();
  if (url.isNotEmpty) {
    await _sharedPlayer.play(UrlSource(url));
    return;
  }
  final base64 = (res['audio_base64'] ?? '').toString().trim();
  final contentType = (res['content_type'] ?? 'audio/mpeg').toString().trim();
  if (base64.isNotEmpty) {
    final dataUrl = 'data:$contentType;base64,$base64';
    await _sharedPlayer.play(UrlSource(dataUrl));
  }
}

/// Stop playback.
Future<void> stopVoicePreview() async {
  await _sharedPlayer.stop();
}
