import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'catalog.dart';
import 'firebase_backend.dart';
import 'lesson_pages.dart';
import 'live_catalog.dart';
import 'pages.dart';

class LiveCourseLessons extends ConsumerStatefulWidget {
  const LiveCourseLessons({super.key, required this.course});

  final Course course;

  @override
  ConsumerState<LiveCourseLessons> createState() => _LiveCourseLessonsState();
}

class _LiveCourseLessonsState extends ConsumerState<LiveCourseLessons> {
  final _saving = <String>{};

  Future<void> _save(String uid, String lessonId, bool completed) async {
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
            if (lessons.isEmpty) {
              return const Text(
                'Lessons will appear here when they are published.',
              );
            }
            final count = lessons
                .where((lesson) => completed?.contains(lesson.id) ?? false)
                .length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Lessons', style: Theme.of(context).textTheme.titleLarge),
                if (user == null)
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
                                  ),
                          ),
                  ),
              ],
            );
          },
        );
  }
}

final _mediaUrlProvider = FutureProvider.autoDispose
    .family<Uri, ({String courseId, String lessonId})>((ref, key) async {
      final storage = ref.watch(storageProvider)!;
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
