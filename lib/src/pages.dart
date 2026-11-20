import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'catalog.dart';
import 'firebase_backend.dart';
import 'live_catalog.dart';
import 'youtube_video.dart';

class PageContent extends StatelessWidget {
  const PageContent({super.key, required this.children, this.maxWidth = 1050});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageContent(
    children: [
      _HeroPanel(demo: ref.watch(firebaseAppProvider) == null),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.push('/welcome'),
          icon: const Icon(Icons.explore_outlined),
          label: const Text('Take the welcome tour'),
        ),
      ),
      const SizedBox(height: 26),
      _SectionHeader(
        title: 'Explore free courses',
        action: 'View all',
        onPressed: () => context.go('/courses'),
      ),
      const SizedBox(height: 10),
      _CatalogContent(
        builder: (courses) => _CourseGrid(courses: courses.take(3).toList()),
      ),
      const SizedBox(height: 26),
      _SectionHeader(
        title: 'Pranayama',
        action: 'View all',
        onPressed: () => context.go('/pranayama'),
      ),
      const SizedBox(height: 10),
      for (final practice in breathPractices.take(2))
        _PracticeTile(practice: practice),
    ],
  );
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.demo});

  final bool demo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/studio.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              excludeFromSemantics: true,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xff213526),
                    Color(0xe6213526),
                    Color(0x66213526),
                  ],
                  stops: [0, 0.58, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  demo
                      ? 'Welcome to the demo'
                      : 'Welcome to The Yogini Journey',
                  style: text.labelLarge?.copyWith(
                    color: const Color(0xfff1e6c9),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Make time for yoga',
                  style: text.displaySmall?.copyWith(
                    color: Colors.white,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Explore free yoga courses and breathing practices.',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xfff1e6c9),
                    foregroundColor: const Color(0xff263a2b),
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => context.go('/courses'),
                  child: const Text('Browse courses'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onPressed,
  });

  final String title;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      TextButton(onPressed: onPressed, child: Text(action)),
    ],
  );
}

class CoursePage extends StatelessWidget {
  const CoursePage({super.key});

  @override
  Widget build(BuildContext context) => PageContent(
    children: [
      const Text('All courses are free. Browse courses by level.'),
      _CatalogContent(
        builder: (courses) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final level in Level.values)
              if (courses.any((course) => course.level == level)) ...[
                const SizedBox(height: 22),
                Text(
                  level.label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                _CourseGrid(
                  courses: courses
                      .where((course) => course.level == level)
                      .toList(),
                ),
              ],
          ],
        ),
      ),
    ],
  );
}

class _CatalogContent extends ConsumerWidget {
  const _CatalogContent({required this.builder});

  final Widget Function(List<Course>) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(courseCatalogProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Column(
          children: [
            const Text('Could not load courses.'),
            TextButton(
              onPressed: () => ref.invalidate(courseCatalogProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
        data: (courses) => courses.isEmpty
            ? const Text('Courses will appear here when they are published.')
            : builder(courses),
      );
}

class _CourseGrid extends StatelessWidget {
  const _CourseGrid({required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = switch (width) {
        >= 830 => 3,
        >= 360 => 2,
        _ => 1,
      };
      const gap = 12.0;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final course in courses)
            SizedBox(
              width: (width - gap * (columns - 1)) / columns,
              child: CoursePreviewCard(course: course),
            ),
        ],
      );
    },
  );
}

class CoursePreviewCard extends StatelessWidget {
  const CoursePreviewCard({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () => context.push('/courses/${course.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 2,
              child: Image.asset(
                'assets/${course.image}.jpg',
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.level.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(course.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${course.minutes} min · Free',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(course.description, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PranayamaPage extends StatelessWidget {
  const PranayamaPage({super.key});

  @override
  Widget build(BuildContext context) => PageContent(
    children: [
      Text(
        'Breathing practices',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text('Open a practice for instructions and video lessons.'),
      const SizedBox(height: 16),
      for (final practice in breathPractices) _PracticeTile(practice: practice),
    ],
  );
}

class _PracticeTile extends StatelessWidget {
  const _PracticeTile({required this.practice});

  final BreathPractice practice;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: colors.secondaryContainer,
      child: ListTile(
        textColor: colors.onSecondaryContainer,
        iconColor: colors.onSecondaryContainer,
        leading: const Icon(Icons.air),
        title: Text(practice.name),
        subtitle: Text(practice.description),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => _PracticePage(practice: practice)),
        ),
      ),
    );
  }
}

class _PracticePage extends StatelessWidget {
  const _PracticePage({required this.practice});

  final BreathPractice practice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(practice.name)),
      body: SafeArea(
        child: PageContent(
          maxWidth: 640,
          children: [
            Text(
              'अभ्यास के निर्देश',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            for (final (index, step) in practice.instructions.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('${index + 1}. $step'),
              ),
            const Text(
              'साँस पर ज़ोर न डालें। चक्कर आए या असहज लगे तो रुकें और सामान्य साँस लें।',
            ),
            const SizedBox(height: 24),
            _PracticeVideos(courseId: practice.courseId),
          ],
        ),
      ),
    );
  }
}

class _PracticeVideos extends ConsumerWidget {
  const _PracticeVideos({required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const unavailable = Text('वीडियो लेसन अभी उपलब्ध नहीं है।');
    const loading = Text('वीडियो लेसन लोड हो रहे हैं…');
    const error = Text('वीडियो लेसन लोड नहीं हो सके। कनेक्शन जाँचें।');

    if (ref.watch(firestoreProvider) == null) return unavailable;
    return ref
        .watch(courseCatalogProvider)
        .when(
          loading: () => loading,
          error: (_, _) => error,
          data: (courses) {
            if (!courses.any((course) => course.id == courseId))
              return unavailable;
            return ref
                .watch(lessonsProvider(courseId))
                .when(
                  loading: () => loading,
                  error: (_, _) => error,
                  data: (lessons) {
                    final videos = lessons
                        .where(
                          (lesson) => isYoutubeVideoId(lesson.youtubeVideoId),
                        )
                        .toList();
                    if (videos.isEmpty) return unavailable;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'YouTube वीडियो लेसन',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final lesson in videos)
                          OutlinedButton.icon(
                            onPressed: () => openYoutubeVideo(
                              context,
                              lesson.youtubeVideoId!,
                            ),
                            icon: const Icon(Icons.play_circle_outline),
                            label: Text(lesson.title),
                          ),
                      ],
                    );
                  },
                );
          },
        );
  }
}

class EmptyPage extends StatelessWidget {
  const EmptyPage({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => PageContent(
    children: [
      const SizedBox(height: 32),
      Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 12),
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text(description, textAlign: TextAlign.center),
    ],
  );
}
