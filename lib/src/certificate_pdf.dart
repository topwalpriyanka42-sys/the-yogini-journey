import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'certificate_client.dart';

// Flutter shapes the learner and course names with device fonts, including
// Devanagari. The rest of the PDF uses vector text and a vector QR code.
Future<Uint8List> _nameImage(String text, double size, double width) async {
  const scale = 3.0;
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 2,
    ellipsis: '…',
    text: TextSpan(
      text: text,
      style: TextStyle(color: const Color(0xff294839), fontSize: size),
    ),
  )..layout(minWidth: width, maxWidth: width);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  painter.paint(canvas, Offset.zero);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (width * scale).ceil(),
    (painter.height * scale).ceil(),
  );
  painter.dispose();
  picture.dispose();
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Could not render certificate text.');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}

Future<Uint8List> renderCertificatePdf(
  CourseCertificate certificate,
  Uri verificationUrl,
  String date,
) async {
  final names = await Future.wait([
    _nameImage(certificate.learnerName, 40, 660),
    _nameImage(certificate.courseTitle, 28, 660),
  ]);
  const green = PdfColor.fromInt(0xff294839);
  const gold = PdfColor.fromInt(0xffaa854d);
  const paper = PdfColor.fromInt(0xfffbf7ed);
  const logo = '''
<svg viewBox="0 0 64 48" xmlns="http://www.w3.org/2000/svg">
<path d="M32 44 Q4 40 3 19 Q23 15 32 44 Q41 15 61 19 Q60 40 32 44 M32 33 Q19 19 32 2 Q45 19 32 33" fill="none" stroke="#294839" stroke-width="2"/>
</svg>
''';
  final doc = pw.Document(
    title: 'The Yogini Journey Certificate',
    author: 'The Yogini Journey',
  );
  pw.Widget text(String value, double size) => pw.Text(
    value,
    textAlign: pw.TextAlign.center,
    style: const pw.TextStyle(color: green).copyWith(fontSize: size),
  );
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => pw.Container(
        decoration: pw.BoxDecoration(
          color: paper,
          border: pw.Border.all(color: green, width: 2),
        ),
        padding: const pw.EdgeInsets.all(7),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: gold, width: .7),
          ),
          padding: const pw.EdgeInsets.fromLTRB(28, 21, 28, 17),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SvgImage(svg: logo, width: 58, height: 43),
              pw.SizedBox(height: 9),
              text('THE YOGINI JOURNEY', 18),
              pw.SizedBox(height: 24),
              text('Certificate of Completion', 38),
              pw.SizedBox(height: 15),
              text('Presented to', 15),
              pw.Image(
                pw.MemoryImage(names[0]),
                width: 660,
                height: 78,
                fit: pw.BoxFit.contain,
              ),
              text('for completing', 15),
              pw.Image(
                pw.MemoryImage(names[1]),
                width: 660,
                height: 57,
                fit: pw.BoxFit.contain,
              ),
              text('Completed on $date', 14),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 82,
                    height: 82,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: gold),
                    ),
                    child: text('YOGINI\nISSUER SEAL', 9),
                  ),
                  text('Certificate ID  ${certificate.id}', 10),
                  pw.Container(
                    color: PdfColors.white,
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: verificationUrl.toString(),
                      width: 82,
                      height: 82,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return doc.save();
}
