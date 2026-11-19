import 'package:flutter_test/flutter_test.dart';
import 'package:the_yogini_journey/src/certificate_client.dart';
import 'package:the_yogini_journey/src/certificate_pdf.dart';

void main() {
  testWidgets(
    'renders a PDF with the public verification URL for a saved certificate',
    (tester) async {
      final certificate = CourseCertificate(
        id: '81c10a04-ef55-4438-b65c-b023d6bed103',
        courseId: 'morning-yoga',
        learnerName: 'प्रियंका Sharma',
        courseTitle: 'Morning Yoga',
        completedAt: DateTime.utc(2026, 11, 18),
        shareEnabled: true,
      );
      final uri = certificate.verificationUri(
        Uri.parse('https://yogini-certificates.example.workers.dev'),
      );
      expect(uri.path, '/verify');
      expect(uri.queryParameters['code'], certificate.id);
      await tester.runAsync(() async {
        final pdf = await renderCertificatePdf(
          certificate,
          uri,
          '18 November 2026',
        );
        expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
        expect(pdf.length, greaterThan(2000));
      });
    },
  );
}
