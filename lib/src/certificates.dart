import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_backend.dart';
import 'pages.dart';

final _certificateFunctions = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instanceFor(
    app: ref.watch(firebaseAppProvider)!,
    region: 'us-central1',
  );
});

final _certificatesProvider = StreamProvider.autoDispose
    .family<List<QueryDocumentSnapshot<Map<String, dynamic>>>, String>(
      (ref, uid) => ref
          .watch(firestoreProvider)!
          .collection('users')
          .doc(uid)
          .collection('certificates')
          .orderBy('issuedAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs),
    );

String _certificateError(Object error) {
  if (error is FirebaseFunctionsException &&
      const {
        'failed-precondition',
        'unauthenticated',
        'invalid-argument',
      }.contains(error.code)) {
    return error.message ?? 'Could not check certificate eligibility.';
  }
  return 'Could not complete the certificate request. Check your connection and try again.';
}

class CertificateRequestButton extends ConsumerStatefulWidget {
  const CertificateRequestButton({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<CertificateRequestButton> createState() =>
      _CertificateRequestButtonState();
}

class _CertificateRequestButtonState
    extends ConsumerState<CertificateRequestButton> {
  bool _busy = false;

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(_certificateFunctions)
          .httpsCallable('issueCertificate')
          .call({'courseId': widget.courseId});
      if (mounted) context.go('/certificates');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_certificateError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _busy ? null : _request,
    icon: const Icon(Icons.workspace_premium_outlined),
    label: Text(_busy ? 'Checking completion…' : 'Get certificate'),
  );
}

class CertificatesPage extends ConsumerWidget {
  const CertificatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(firebaseAppProvider) == null) {
      return const EmptyPage(
        icon: Icons.workspace_premium_outlined,
        title: 'Your certificates',
        description: 'Sign in to the Firebase app to earn course certificates.',
      );
    }
    return ref
        .watch(authUserProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const PageContent(
            children: [Text('Could not check your account.')],
          ),
          data: (user) {
            if (user == null || !user.emailVerified) {
              return PageContent(
                children: [
                  Text(
                    user == null
                        ? 'Sign in to see your certificates.'
                        : 'Verify your email to see your certificates.',
                  ),
                  TextButton(
                    onPressed: () => context.go('/profile'),
                    child: const Text('Open Profile'),
                  ),
                ],
              );
            }
            final history = _certificatesProvider(user.uid);
            return PageContent(
              children: [
                Text(
                  'Your certificates',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                ref
                    .watch(history)
                    .when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => Column(
                        children: [
                          const Text('Could not load your certificates.'),
                          TextButton(
                            onPressed: () => ref.invalidate(history),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                      data: (records) => records.isEmpty
                          ? const Text(
                              'Complete all published lessons in a course to earn a certificate.',
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final record in records)
                                  _CertificateCard(
                                    key: ValueKey(record.reference.path),
                                    record: record,
                                  ),
                              ],
                            ),
                    ),
              ],
            );
          },
        );
  }
}

class _CertificateCard extends ConsumerStatefulWidget {
  const _CertificateCard({super.key, required this.record});

  final QueryDocumentSnapshot<Map<String, dynamic>> record;

  @override
  ConsumerState<_CertificateCard> createState() => _CertificateCardState();
}

class _CertificateCardState extends ConsumerState<_CertificateCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_certificateError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enableVerification() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable QR verification?'),
        content: const Text(
          'Anyone with the certificate link or QR code can see your name, course and completion date, and download this PDF.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(_certificateFunctions)
        .httpsCallable('issueCertificate')
        .call({'courseId': widget.record.id, 'shareConsent': true});
  }

  Future<void> _disableVerification() async {
    await ref
        .read(_certificateFunctions)
        .httpsCallable('issueCertificate')
        .call({'courseId': widget.record.id, 'shareConsent': false});
  }

  Future<void> _pdf({required bool share}) async {
    final functions = ref.read(_certificateFunctions);
    final id = widget.record.data()['certificateId'] as String;
    final result = await functions.httpsCallable('downloadCertificate').call({
      'courseId': widget.record.id,
    });
    final data = result.data as Map;
    final bytes = base64Decode(data['pdfBase64'] as String);
    if (!mounted) return;
    final filename = 'Yogini-$id.pdf';
    if (share) {
      final renderBox = context.findRenderObject() as RenderBox?;
      final bounds = renderBox == null || !renderBox.hasSize
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      await Printing.sharePdf(bytes: bytes, filename: filename, bounds: bounds);
    } else {
      final saved = await FilePicker.saveFile(
        fileName: filename,
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('PDF saved.')));
      }
    }
  }

  Future<void> _openVerification(String id) async {
    final project = ref.read(firebaseAppProvider)!.options.projectId;
    final uri = Uri.https(
      'us-central1-$project.cloudfunctions.net',
      '/verifyCertificate',
      {'code': id},
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open verification');
    }
  }

  @override
  Widget build(BuildContext context) {
    final certificate = widget.record.data();
    final id = certificate['certificateId'] as String;
    final course = certificate['courseTitle'] as String;
    final date = (certificate['completedAt'] as Timestamp).toDate().toUtc();
    final sharing = certificate['shareEnabled'] == true;
    final formattedDate = MaterialLocalizations.of(context)
        .formatMediumDate(date);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(course, style: Theme.of(context).textTheme.titleLarge),
            Text('Completed $formattedDate'),
            Text(sharing ? 'QR verification enabled' : 'Private certificate'),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => _pdf(share: false)),
                  child: const Text('Download PDF'),
                ),
                if (sharing) ...[
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => _pdf(share: true)),
                    child: const Text('Share PDF'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => _openVerification(id)),
                    child: const Text('Verify online'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _run(_disableVerification),
                    child: const Text('Disable QR verification'),
                  ),
                ] else
                  TextButton(
                    onPressed: _busy ? null : () => _run(_enableVerification),
                    child: const Text('Enable QR verification'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
