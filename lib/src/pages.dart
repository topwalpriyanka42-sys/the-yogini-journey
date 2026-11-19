import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'catalog.dart';

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
      const _HeroPanel(),
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
      _CourseGrid(courses: ref.watch(coursesProvider).take(3).toList()),
      const SizedBox(height: 26),
      _SectionHeader(
        title: 'Pranayama',
        action: 'View all',
        onPressed: () => context.go('/pranayama'),
      ),
      const SizedBox(height: 10),
      for (final practice in ref.watch(breathPracticesProvider).take(2))
        _PracticeTile(practice: practice),
    ],
  );
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

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
                  'Welcome to the demo',
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

class CoursePage extends ConsumerWidget {
  const CoursePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(coursesProvider);
    return PageContent(
      children: [
        const Text('All courses are free. Browse sample courses by level.'),
        for (final level in Level.values) ...[
          const SizedBox(height: 22),
          Text(level.label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          _CourseGrid(
            courses: courses.where((course) => course.level == level).toList(),
          ),
        ],
      ],
    );
  }
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

class PranayamaPage extends ConsumerWidget {
  const PranayamaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageContent(
    children: [
      Text(
        'Breathing practices',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text('Browse the practice previews.'),
      const SizedBox(height: 16),
      for (final practice in ref.watch(breathPracticesProvider))
        _PracticeTile(practice: practice),
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
      ),
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
