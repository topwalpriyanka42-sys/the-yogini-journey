# The Yogini Journey

Phase 1 is a Flutter demo for Android and iOS. It opens in guest mode using bundled course and breathing practice previews. After dependencies are installed, the app can run offline without Firebase configuration.

## Run the demo

Flutter 3.50.0 is the SDK used for this project. From the project root:

```sh
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <device-id>
```

For Android, install Android Studio and the Android SDK, accept the licenses with `flutter doctor --android-licenses`, and start an emulator from **Tools → Device Manager**. You can also connect an Android phone with USB debugging enabled. Use the ID printed by `flutter devices`, for example `flutter run -d emulator-5554`.

For iOS, use macOS with Xcode and an iOS Simulator. Start it with `open -a Simulator`, then select its ID from `flutter devices`.

## Project layout

- `lib/main.dart` starts the Flutter app and Riverpod.
- `lib/src/app.dart` configures the five GoRouter destinations and guest appearance setting.
- `lib/src/theme.dart` defines the light and dark Material themes.
- `lib/src/pages.dart` contains the responsive screens and shared preview widgets.
- `lib/src/catalog.dart` contains typed mock course and breathing practice data.
- `assets/` contains offline demo photos.
- `test/app_test.dart` checks narrow-screen navigation and the dark appearance setting.
- `android/` and `ios/` contain the generated platform projects. The development application ID is `com.example.the_yogini_journey`.

Demo photo sources: [Studio](https://images.unsplash.com/photo-1544367567-0f2fcb009e0b), [Morning](https://images.unsplash.com/photo-1575052814086-f385e2e2ad1b), [Balance](https://images.unsplash.com/photo-1506126613408-eca07ce68773). Photos are from [Unsplash](https://unsplash.com/license).

## Firebase setup for the backend phase

1. Choose the final Android application ID and iOS bundle ID. Register both apps in a Firebase development project. Keep production in a separate project.
2. Install the Firebase CLI, sign in with `firebase login`, and install FlutterFire CLI with `dart pub global activate flutterfire_cli`.
3. From the app root, run `flutter pub add firebase_core firebase_auth cloud_firestore firebase_storage cloud_functions`. Run `flutterfire configure --project=<development-project-id> --platforms=android,ios` to generate `lib/firebase_options.dart`. Initialize Firebase only for the configured backend mode and retain the offline guest entry point for demos.
4. In the Firebase console, enable Email/Password Authentication. Create Firestore and Storage with restrictive defaults. Initialize Functions, Firestore rules and indexes, Storage rules, and emulators with `firebase init`; test owner and administrator access with `firebase emulators:start` before deploying.
5. Assign administrator claims through a trusted Firebase Admin SDK process with narrowly scoped service permissions. Configure AI credentials with Functions Secret Manager when the chat backend is added. Keep service-account credentials and AI keys out of the Flutter app and source control.

## Next phase

Build the onboarding, sign-in and registration screens, course details, and sample lesson playback. The current catalog contains six course previews and six breathing practice previews. The Certificates tab is an empty state and Profile offers an in-session appearance setting.
