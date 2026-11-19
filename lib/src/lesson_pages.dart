import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import 'catalog.dart';
import 'pages.dart';

class CourseDetailPage extends StatelessWidget {
  const CourseDetailPage({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Course details'),
      leading: BackButton(
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/courses');
          }
        },
      ),
    ),
    body: SafeArea(
      child: PageContent(
        maxWidth: 620,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 2,
              child: Image.asset(
                'assets/${course.image}.jpg',
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(course.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('${course.level.label} · ${course.minutes} min · Free'),
          const SizedBox(height: 12),
          Text(course.description),
          const SizedBox(height: 24),
          Text('Lesson preview', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Play a short sample clip to try the lesson player.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push('/courses/${course.id}/preview'),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Watch sample lesson'),
          ),
        ],
      ),
    ),
  );
}

class LessonPreviewPage extends StatefulWidget {
  const LessonPreviewPage({super.key, required this.course});

  final Course course;

  @override
  State<LessonPreviewPage> createState() => _LessonPreviewPageState();
}

class _LessonPreviewPageState extends State<LessonPreviewPage> {
  late VideoPlayerController _controller;
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _controller = VideoPlayerController.asset('assets/lesson-preview.mp4');
    _initialization = _controller.initialize();
  }

  void _retry() {
    _controller.dispose();
    setState(_load);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
        return;
      }
      if (controller.value.isCompleted) {
        await controller.seekTo(Duration.zero);
      }
      if (mounted && identical(controller, _controller)) {
        await controller.play();
      }
    } catch (_) {
      if (!mounted || !identical(controller, _controller)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playback failed. Please try again.')),
      );
    }
  }

  Widget _error() => Column(
    children: [
      const Text('The sample video could not be loaded.'),
      TextButton(onPressed: _retry, child: const Text('Retry')),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sample lesson'),
      leading: BackButton(
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/courses/${widget.course.id}');
          }
        },
      ),
    ),
    body: SafeArea(
      child: PageContent(
        maxWidth: 720,
        children: [
          Text(
            widget.course.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Bundled sample video · 8 seconds'),
          const SizedBox(height: 20),
          FutureBuilder<void>(
            future: _initialization,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading sample video',
                  ),
                );
              }
              if (snapshot.hasError) return _error();
              return ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller,
                builder: (context, value, child) {
                  if (value.hasError) return _error();
                  final label = value.isPlaying
                      ? 'Pause'
                      : value.isCompleted
                      ? 'Replay'
                      : 'Play';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: value.aspectRatio,
                          child: child,
                        ),
                      ),
                      const SizedBox(height: 12),
                      VideoProgressIndicator(
                        _controller,
                        allowScrubbing: false,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _togglePlayback,
                        icon: Icon(
                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                        label: Text(label),
                      ),
                    ],
                  );
                },
                child: VideoPlayer(_controller),
              );
            },
          ),
        ],
      ),
    ),
  );
}
