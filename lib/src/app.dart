import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'account_pages.dart';
import 'catalog.dart';
import 'lesson_pages.dart';
import 'pages.dart';
import 'theme.dart';

const _tabs = [
  (path: '/', label: 'Home', icon: Icons.home_outlined),
  (path: '/courses', label: 'Courses', icon: Icons.menu_book_outlined),
  (path: '/pranayama', label: 'Pranayama', icon: Icons.air),
  (
    path: '/certificates',
    label: 'Certificates',
    icon: Icons.workspace_premium_outlined,
  ),
  (path: '/profile', label: 'Profile', icon: Icons.person_outline),
];

final themeModeProvider = NotifierProvider<ThemePreference, ThemeMode>(
  ThemePreference.new,
);

class ThemePreference extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void select(ThemeMode mode) => state = mode;
}

final _routerProvider = Provider<GoRouter>((ref) {
  const pages = <Widget>[
    HomePage(),
    CoursePage(),
    PranayamaPage(),
    EmptyPage(
      icon: Icons.workspace_premium_outlined,
      title: 'Your certificates',
      description: 'Course certificates will appear here when certificate issuing is available.',
    ),
    ProfilePage(),
  ];
  final router = GoRouter(
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const OnboardingPage()),
      GoRoute(
        path: '/login',
        builder: (_, _) => const AccountPage(register: false),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => const AccountPage(register: true),
      ),
      GoRoute(
        path: '/courses/:courseId',
        builder: (_, state) =>
            _CourseRoute(courseId: state.pathParameters['courseId']!),
        routes: [
          GoRoute(
            path: 'preview',
            builder: (_, state) => _CourseRoute(
              courseId: state.pathParameters['courseId']!,
              playPreview: true,
            ),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => _Shell(
          selectedIndex: _tabs.indexWhere((tab) => tab.path == state.uri.path),
          child: child,
        ),
        routes: [
          for (var index = 0; index < _tabs.length; index++)
            GoRoute(path: _tabs[index].path, builder: (_, _) => pages[index]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class YoginiApp extends ConsumerWidget {
  const YoginiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'The Yogini Journey',
    debugShowCheckedModeBanner: false,
    theme: yoginiTheme(Brightness.light),
    darkTheme: yoginiTheme(Brightness.dark),
    themeMode: ref.watch(themeModeProvider),
    routerConfig: ref.watch(_routerProvider),
  );
}

class _Shell extends StatelessWidget {
  const _Shell({required this.selectedIndex, required this.child});

  final int selectedIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Icon(
            Icons.spa_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              selectedIndex == 0
                  ? 'The Yogini Journey'
                  : _tabs[selectedIndex].label,
            ),
          ),
        ],
      ),
    ),
    body: SafeArea(top: false, child: child),
    bottomNavigationBar: NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => context.go(_tabs[index].path),
      destinations: [
        for (final tab in _tabs)
          NavigationDestination(icon: Icon(tab.icon), label: tab.label),
      ],
    ),
  );
}

class _CourseRoute extends ConsumerWidget {
  const _CourseRoute({required this.courseId, this.playPreview = false});

  final String courseId;
  final bool playPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref
        .watch(coursesProvider)
        .where((course) => course.id == courseId)
        .firstOrNull;
    if (course == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Course unavailable')),
        body: PageContent(
          children: [
            const Text('This course could not be found.'),
            TextButton(
              onPressed: () => context.go('/courses'),
              child: const Text('Browse courses'),
            ),
          ],
        ),
      );
    }
    return playPreview
        ? LessonPreviewPage(course: course)
        : CourseDetailPage(course: course);
  }
}

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageContent(
    children: [
      Text(
        ref.watch(demoProfileProvider) ?? 'Guest profile',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      const Text('You’re exploring The Yogini Journey in demo mode.'),
      const SizedBox(height: 24),
      DropdownButtonFormField<ThemeMode>(
        initialValue: ref.watch(themeModeProvider),
        decoration: const InputDecoration(
          labelText: 'Appearance',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(
            value: ThemeMode.system,
            child: Text('Use device setting'),
          ),
          DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
        ],
        onChanged: (mode) {
          if (mode != null) ref.read(themeModeProvider.notifier).select(mode);
        },
      ),
      const SizedBox(height: 20),
      if (ref.watch(demoProfileProvider) == null) ...[
        FilledButton(
          onPressed: () => context.push('/login'),
          child: const Text('Demo sign in'),
        ),
        OutlinedButton(
          onPressed: () => context.push('/register'),
          child: const Text('Create demo account'),
        ),
      ] else
        OutlinedButton(
          onPressed: () => ref.read(demoProfileProvider.notifier).end(),
          child: const Text('End demo session'),
        ),
    ],
  );
}
