import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:the_yogini_journey/src/yoga_chat.dart';

void main() {
  test('demo responds in both languages and redirects urgent requests', () {
    expect(demoYogaReply('breathing', 'en'), contains('natural'));
    expect(demoYogaReply('ध्यान', 'hi'), contains('साँस'));
    expect(demoYogaReply('सीने में दर्द', 'hi'), contains('आपातकालीन'));
    expect(
      demoYogaReply('medicine dosage', 'en'),
      contains('health professional'),
    );
  });

  testWidgets(
    'guest chat can send a question and receive a labelled demo reply',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: YogaChatPage())),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'How can I meditate?');
      await tester.tap(find.byTooltip('Send question'));
      await tester.pumpAndSettle();
      expect(find.text('Demo reply'), findsOneWidget);
      expect(find.textContaining('attention wanders'), findsOneWidget);
    },
  );
}
