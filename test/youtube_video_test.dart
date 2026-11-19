import 'package:flutter_test/flutter_test.dart';
import 'package:the_yogini_journey/src/youtube_video.dart';

void main() {
  const videoId = 'aBcd-Ef_G12';

  test(
    'accepts standard YouTube video links and normalizes the destination',
    () {
      for (final link in [
        'https://youtu.be/$videoId?si=tracking',
        'https://www.youtube.com/watch?v=$videoId&t=12',
        'https://m.youtube.com/shorts/$videoId',
        'https://youtube.com/live/$videoId',
        'https://www.youtube.com/embed/$videoId',
      ]) {
        expect(youtubeIdFromLink(link), videoId);
      }
      expect(
        youtubeWatchUri(videoId).toString(),
        'https://www.youtube.com/watch?v=$videoId',
      );
    },
  );

  test('rejects non-video, lookalike, and non-HTTPS links', () {
    for (final link in [
      'https://www.youtube.com.evil.example/watch?v=$videoId',
      'https://youtube.com@evil.example/watch?v=$videoId',
      'https://example@youtube.com/watch?v=$videoId',
      'https://youtube.com:1234/watch?v=$videoId',
      'http://youtu.be/$videoId',
      'https://youtu.be/$videoId/extra',
      'https://youtube.com/playlist?list=$videoId',
      'https://youtube.com/watch?v=short',
    ]) {
      expect(youtubeIdFromLink(link), isNull, reason: link);
    }
  });
}
