import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAppProvider = Provider<FirebaseApp?>((ref) => null);
final authProvider = Provider<FirebaseAuth?>((ref) {
  final app = ref.watch(firebaseAppProvider);
  return app == null ? null : FirebaseAuth.instanceFor(app: app);
});
final authUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authProvider)?.userChanges() ?? Stream.value(null);
});
final firestoreProvider = Provider<FirebaseFirestore?>((ref) {
  final app = ref.watch(firebaseAppProvider);
  return app == null ? null : FirebaseFirestore.instanceFor(app: app);
});
final storageProvider = Provider<FirebaseStorage?>((ref) {
  final app = ref.watch(firebaseAppProvider);
  return app == null || app.options.storageBucket?.isNotEmpty != true
      ? null
      : FirebaseStorage.instanceFor(app: app);
});

Future<FirebaseApp?> initializeBackend() async {
  if (!const bool.fromEnvironment('FIREBASE_ENABLED')) return null;
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const bucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  if ([apiKey, appId, sender, project].any((value) => value.isEmpty)) {
    throw StateError('Firebase platform configuration is incomplete.');
  }
  return Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: sender,
      projectId: project,
      storageBucket: bucket == '' ? null : bucket,
    ),
  );
}

String authError(Object error) {
  if (error is! FirebaseAuthException) {
    return 'Something went wrong. Please try again.';
  }
  return switch (error.code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Check your email and password and try again.',
    'email-already-in-use' =>
      'This email is already registered. Try signing in.',
    'weak-password' => 'Choose a stronger password.',
    'invalid-email' => 'Enter a valid email address.',
    'network-request-failed' => 'Check your internet connection and try again.',
    'too-many-requests' => 'Too many attempts. Please try again later.',
    'requires-recent-login' =>
      'Sign out and sign back in before deleting your account.',
    _ => 'Firebase could not complete the request. Please try again.',
  };
}
