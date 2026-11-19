import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'firebase_backend.dart';

const _configuredUrl = String.fromEnvironment('CERTIFICATE_WORKER_URL');

final certificateServer = _serverUri(_configuredUrl);

Uri? _serverUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      (uri.hasPort && uri.port != 443)) {
    return null;
  }
  return uri;
}

class CourseCertificate {
  const CourseCertificate({
    required this.id,
    required this.courseId,
    required this.learnerName,
    required this.courseTitle,
    required this.completedAt,
    required this.shareEnabled,
  });

  factory CourseCertificate.fromJson(Map<String, dynamic> json) =>
      CourseCertificate(
        id: json['certificateId'] as String,
        courseId: json['courseId'] as String,
        learnerName: json['learnerName'] as String,
        courseTitle: json['courseTitle'] as String,
        completedAt: DateTime.parse(json['completedAt'] as String).toUtc(),
        shareEnabled: json['shareEnabled'] == true,
      );

  final String id;
  final String courseId;
  final String learnerName;
  final String courseTitle;
  final DateTime completedAt;
  final bool shareEnabled;

  Uri verificationUri(Uri server) =>
      server.replace(path: '/verify', queryParameters: {'code': id});
}

class CertificateRequestException implements Exception {
  const CertificateRequestException(this.message);
  final String message;
}

class CertificateClient {
  const CertificateClient(this.server, this.user, this.client);

  final Uri server;
  final User user;
  final http.Client client;

  Future<Map<String, dynamic>> _send(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final token = await user.getIdToken();
    if (token == null) {
      throw const CertificateRequestException('Sign in again to continue.');
    }
    final request =
        http.Request(data == null ? 'GET' : 'POST', server.replace(path: path))
          ..followRedirects = false
          ..headers['Authorization'] = 'Bearer $token';
    if (data != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(data);
    }
    final response = await client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 20));
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw CertificateRequestException(
        json['error'] as String? ?? 'Certificate request failed.',
      );
    }
    return json;
  }

  Future<List<CourseCertificate>> history() async {
    final result = await _send('/api/certificates');
    return (result['certificates'] as List)
        .map((item) => CourseCertificate.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> issue(String courseId) async {
    await _send('/api/certificates/issue', data: {'courseId': courseId});
  }

  Future<void> setSharing(String courseId, bool enabled) async {
    await _send(
      '/api/certificates/share',
      data: {'courseId': courseId, 'enabled': enabled},
    );
  }
}

final certificateClientProvider = Provider.autoDispose<CertificateClient?>((
  ref,
) {
  final user = ref.watch(authUserProvider).asData?.value;
  final server = certificateServer;
  if (user?.emailVerified != true || server == null) return null;
  final client = http.Client();
  ref.onDispose(client.close);
  return CertificateClient(server, user!, client);
});

final certificateHistoryProvider =
    FutureProvider.autoDispose<List<CourseCertificate>>((ref) async {
      return ref.watch(certificateClientProvider)?.history() ?? const [];
    });
