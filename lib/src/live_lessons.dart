import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'catalog.dart';
import 'certificate_client.dart';
import 'certificates.dart';
import 'firebase_backend.dart';
import 'lesson_pages.dart';
import 'live_catalog.dart';
import 'pages.dart';
import 'youtube_video.dart';

class LiveCourseLessons extends ConsumerStatefulWidget {
  const LiveCourseLessons({super.key, required this.course});

  final Course course;

  @override
  ConsumerState<LiveCourseLessons> createState() => _LiveCourseLessonsState();
}

class _LiveCourseLessonsState extends ConsumerState<LiveCourseLessons> {
  final _saving = <String>{};
  bool _savingEnrollment = false;

  Future<void> _enroll(String uid) async {
    setState(() => _savingEnrollment = true);
    try {
      final database = ref.read(firestoreProvider)!;
      final document = _enrollment(database, uid, widget.course.id);
      await database.runTransaction((transaction) async {
        if (!(await transaction.get(document)).exists) {
          transaction.set(document, {
            'enrolledAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not enroll. Check your connection and Firebase rules.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingEnrollment = false);
    }
  }

  Future<void> _save(
    String uid,
    String lessonId,
    bool completed, {
    required bool finalLesson,
  }) async {
    if (!_saving.add(lessonId)) return;
    setState(() {});
    try {
      final database = ref.read(firestoreProvider)!;
      final document = progressCollection(
        database,
        uid,
        widget.course.id,
      ).doc(lessonId);
      if (completed) {
        await document.set({'completedAt': FieldValue.serverTimestamp()});
      } else {
        await document.delete();
      }
      if (mounted && finalLesson && completed) {
        try {
          final client = ref.read(certificateClientProvider);
          if (client != null) {
            await client.issue(widget.course.id);
            if (mounted) ref.invalidate(certificateHistoryProvider);
          }
        } catch (_) {
          // Progress is saved. The learner can retry from Get certificate.
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save lesson progress. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(lessonId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (certificateServer != null) ref.watch(certificateClientProvider);
    final id = widget.course.id;
    final user = ref.watch(authUserProvider).asData?.value;
    final progress = user?.emailVerified == true
        ? ref.watch(lessonProgressProvider((uid: user!.uid, courseId: id)))
        : null;
    final completed = progress?.asData?.value;
    return ref
        .watch(lessonsProvider(id))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Column(
            children: [
              const Text('Could not load lessons.'),
              TextButton(
                onPressed: () => ref.invalidate(lessonsProvider(id)),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (lessons) {
            final count = lessons
                .where((lesson) => completed?.contains(lesson.id) ?? false)
                .length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (user?.emailVerified == true)
                  ref
                      .watch(
                        _enrollmentProvider((uid: user!.uid, courseId: id)),
                      )
                      .when(
                        loading: () => const Text('Checking enrollment…'),
                        error: (_, _) => TextButton(
                          onPressed: () => ref.invalidate(
                            _enrollmentProvider((uid: user.uid, courseId: id)),
                          ),
                          child: const Text('Retry enrollment status'),
                        ),
                        data: (enrolled) => enrolled
                            ? const Text('Enrolled')
                            : FilledButton(
                                onPressed: _savingEnrollment
                                    ? null
                                    : () => _enroll(user.uid),
                                child: Text(
                                  _savingEnrollment
                                      ? 'Enrolling…'
                                      : 'Enroll for free',
                                ),
                              ),
                      ),
                Text('Lessons', style: Theme.of(context).textTheme.titleLarge),
                if (lessons.isEmpty)
                  const Text(
                    'Lessons will appear here when they are published.',
                  )
                else if (user == null)
                  const Text('Sign in to save your progress.')
                else if (!user.emailVerified)
                  const Text('Verify your email in Profile to save progress.')
                else if (progress?.hasError == true) ...[
                  const Text('Could not load your progress.'),
                  TextButton(
                    onPressed: () => ref.invalidate(
                      lessonProgressProvider((uid: user.uid, courseId: id)),
                    ),
                    child: const Text('Retry progress'),
                  ),
                ] else if (completed == null)
                  const Text('Loading progress…')
                else ...[
                  Text('$count of ${lessons.length} lessons marked complete'),
                  LinearProgressIndicator(value: count / lessons.length),
                  if (count == lessons.length && certificateServer != null)
                    CertificateRequestButton(courseId: id),
                ],
                for (final lesson in lessons)
                  ListTile(
                    title: Text(lesson.title),
                    leading: const Icon(Icons.play_circle_outline),
                    onTap: () =>
                        context.push('/courses/$id/lessons/${lesson.id}'),
                    trailing: completed == null
                        ? null
                        : Checkbox(
                            semanticLabel: 'Mark ${lesson.title} complete',
                            value: completed.contains(lesson.id),
                            onChanged: _saving.contains(lesson.id)
                                ? null
                                : (value) => _save(
                                    user!.uid,
                                    lesson.id,
                                    value == true,
                                    finalLesson:
                                        count == lessons.length - 1 &&
                                        !completed.contains(lesson.id),
                                  ),
                          ),
                  ),
              ],
            );
          },
        );
  }
}

DocumentReference<Map<String, dynamic>> _enrollment(
  FirebaseFirestore db,
  String uid,
  String courseId,
) => db.collection('users').doc(uid).collection('enrollments').doc(courseId);

final _enrollmentProvider = StreamProvider.autoDispose
    .family<bool, ({String uid, String courseId})>(
      (ref, key) => _enrollment(
        ref.watch(firestoreProvider)!,
        key.uid,
        key.courseId,
      ).snapshots().map((snapshot) => snapshot.exists),
    );

final _mediaUrlProvider = FutureProvider.autoDispose
    .family<Uri, ({String courseId, String lessonId})>((ref, key) async {
      final storage = ref.watch(storageProvider);
      if (storage == null) {
        throw StateError('Firebase Storage is unavailable.');
      }
      final url = await storage
          .ref('courses/${key.courseId}/${key.lessonId}/video.mp4')
          .getDownloadURL();
      return Uri.parse(url);
    });

class LiveLessonPage extends ConsumerWidget {
  const LiveLessonPage({
    super.key,
    required this.course,
    required this.lessonId,
  });

  final Course course;
  final String lessonId;

  Widget _status(Widget child) => Scaffold(
    appBar: AppBar(title: const Text('Lesson')),
    body: SafeArea(child: PageContent(children: [child])),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(lessonsProvider(course.id))
      .when(
        loading: () =>
            _status(const Center(child: CircularProgressIndicator())),
        error: (_, _) => _status(
          TextButton(
            onPressed: () => ref.invalidate(lessonsProvider(course.id)),
            child: const Text('Could not load lesson. Retry'),
          ),
        ),
        data: (lessons) {
          final lesson = lessons
              .where((lesson) => lesson.id == lessonId)
              .firstOrNull;
          if (lesson == null) {
            return _status(const Text('This lesson is unavailable.'));
          }
          final youtubeId = lesson.youtubeVideoId;
          if (isYoutubeVideoId(youtubeId)) {
            return _status(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    lesson.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Watch on YouTube'),
                    onPressed: () => openYoutubeVideo(context, youtubeId!),
                  ),
                ],
              ),
            );
          }
          final media = _mediaUrlProvider((
            courseId: course.id,
            lessonId: lessonId,
          ));
          return ref
              .watch(media)
              .when(
                loading: () =>
                    _status(const Center(child: CircularProgressIndicator())),
                error: (_, _) => _status(
                  TextButton(
                    onPressed: () => ref.invalidate(media),
                    child: const Text('Could not open lesson video. Retry'),
                  ),
                ),
                data: (url) => LessonPreviewPage(
                  key: ValueKey(url),
                  course: course,
                  lessonTitle: lesson.title,
                  videoUrl: url,
                ),
              );
        },
      );
}
