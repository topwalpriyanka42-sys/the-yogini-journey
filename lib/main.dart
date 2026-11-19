import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/firebase_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final app = await initializeBackend();
    runApp(
      ProviderScope(
        overrides: [firebaseAppProvider.overrideWithValue(app)],
        child: const YoginiApp(),
      ),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Firebase could not start. Check the app configuration and reopen the app.',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
