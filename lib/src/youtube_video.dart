import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

final _videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

bool isYoutubeVideoId(String? value) =>
    value != null && value.length == 11 && _videoIdPattern.hasMatch(value);

Uri youtubeWatchUri(String videoId) =>
    Uri.https('www.youtube.com', '/watch', {'v': videoId});

String? youtubeIdFromLink(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443)) {
    return null;
  }
  final segments = uri.pathSegments;
  final id = switch (uri.host.toLowerCase()) {
    'youtu.be' when segments.length == 1 => segments.first,
    'youtube.com' ||
    'www.youtube.com' ||
    'm.youtube.com' when uri.path == '/watch' => uri.queryParameters['v'],
    'youtube.com' || 'www.youtube.com' || 'm.youtube.com'
        when segments.length == 2 &&
            const {'shorts', 'live', 'embed'}.contains(segments.first) =>
      segments.last,
    _ => null,
  };
  return isYoutubeVideoId(id) ? id : null;
}

Future<void> openYoutubeVideo(BuildContext context, String videoId) async {
  try {
    if (await launchUrl(
      youtubeWatchUri(videoId),
      mode: LaunchMode.externalApplication,
    )) {
      return;
    }
  } catch (_) {
    // The launcher can throw if the device has no compatible activity.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open YouTube on this device.')),
    );
  }
}
