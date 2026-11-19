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
    expect(find.text('Bhramari'), findsOneWidget);

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
}
