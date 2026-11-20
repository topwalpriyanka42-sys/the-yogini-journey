import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_yogini_journey/src/app.dart';

void main() {
  testWidgets('demo opens on a narrow screen and navigation works offline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ProviderScope(child: YoginiApp()));
    await tester.pumpAndSettle();

    expect(find.text('The Yogini Journey'), findsOneWidget);
    expect(find.text('Morning Yoga'), findsOneWidget);
    await tester.tap(find.text('Browse courses'));
    await tester.pumpAndSettle();
    expect(find.text('Introduction to Yoga'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Pranayama'));
    await tester.pumpAndSettle();
    for (final practice in [
      'Deep Breathing',
      'Bhramari',
      'Anulom Vilom',
      'Nadi Shodhana',
      'Ujjayi',
      'Kapalbhati',
    ]) {
      final card = find.text(practice);
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, practice), findsOneWidget);
      expect(find.text('अभ्यास के निर्देश'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }

    await tester.tap(
      find.widgetWithText(NavigationDestination, 'Certificates'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your certificates'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest can switch to dark appearance', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: YoginiApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Guest profile'))).brightness,
      Brightness.dark,
    );
  });
  testWidgets(
    'welcome tour opens registration and creates a temporary profile',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: YoginiApp()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take the welcome tour'));
      await tester.pumpAndSettle();
      expect(find.text('Find your starting point'), findsOneWidget);

      for (var step = 0; step < 2; step++) {
        await tester.ensureVisible(find.text('Next'));
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Create demo account'));
      await tester.tap(find.text('Create demo account'));
      await tester.pumpAndSettle();

      final submit = find.widgetWithText(FilledButton, 'Create profile');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Enter a name.'), findsOneWidget);
      expect(find.text('Enter a valid sample email.'), findsOneWidget);
      expect(find.text('Enter at least 8 characters.'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Demo Student');
      await tester.enterText(fields.at(1), 'student@example.com');
      await tester.enterText(fields.at(2), 'sample123');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Demo Student'), findsOneWidget);

      await tester.tap(find.text('End demo session'));
      await tester.pumpAndSettle();
      expect(find.text('Guest profile'), findsOneWidget);
    },
  );

  testWidgets('guest can open sign in and use sample credentials', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: YoginiApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demo sign in'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'learner@example.com');
    await tester.enterText(fields.at(1), 'sample123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Demo learner'), findsOneWidget);
  });

  testWidgets('course cards open the matching detail page', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: YoginiApp()));
    await tester.pumpAndSettle();
    final course = find.text('Morning Yoga');
    await tester.ensureVisible(course);
    await tester.tap(course);
    await tester.pumpAndSettle();
    expect(find.text('Course details'), findsOneWidget);
    expect(find.text('Morning Yoga'), findsOneWidget);
    expect(find.text('Watch sample lesson'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('The Yogini Journey'), findsOneWidget);
  });
}
