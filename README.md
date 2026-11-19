# The Yogini Journey

The Yogini Journey is a Flutter app for Android and iOS with an offline demo and an optional Firebase backend. It opens in guest mode using bundled course and breathing practice previews. After dependencies are installed, the app can run offline without Firebase configuration.

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

## Try the offline demo

- On Home, tap **Take the welcome tour** for the three onboarding screens, or browse the app immediately as a guest.
- Open **Profile** for **Demo sign in** or **Create demo account**. Use a sample email such as `learner@example.com` and a sample password of at least eight characters. The forms create an in-memory demo profile and discard the email and password. Registration does not create a Firebase account.
- Tap any course card, then tap **Watch sample lesson** to play the bundled eight-second placeholder MP4 on a supported Android or iOS device. The same clearly labeled sample is used across the catalog.
- Browse six pranayama previews from the **Pranayama** tab.

## Project layout

- `lib/main.dart` starts the Flutter app and Riverpod.
- `lib/src/app.dart` configures the five GoRouter destinations and guest appearance setting.
- `lib/src/theme.dart` defines the light and dark Material themes.
- `lib/src/pages.dart` contains the responsive screens and shared preview widgets.
- `lib/src/account_pages.dart` contains onboarding, account forms, and the temporary demo profile.
- `lib/src/lesson_pages.dart` contains course details and the sample player.
- `lib/src/catalog.dart` contains typed mock course and breathing practice data.
- `assets/` contains offline demo photos and a sample MP4.
- `test/app_test.dart` checks narrow-screen navigation, the dark appearance setting, onboarding, demo account forms, and course details.
- `android/` and `ios/` contain the generated platform projects. The development application ID is `com.example.the_yogini_journey`.

Demo photo sources: [Studio](https://images.unsplash.com/photo-1544367567-0f2fcb009e0b), [Morning](https://images.unsplash.com/photo-1575052814086-f385e2e2ad1b), [Balance](https://images.unsplash.com/photo-1506126613408-eca07ce68773). Photos are from [Unsplash](https://unsplash.com/license).

## Firebase setup for Phase 3

1. In a Firebase development project, enable the **Email/Password** sign-in provider, create the default Cloud Firestore database, and optionally provision Cloud Storage for direct MP4 uploads. Cloud Storage for Firebase requires a Blaze billing plan. YouTube lessons need only Authentication and Firestore. Register Android application ID `com.example.the_yogini_journey` and iOS bundle ID `com.example.theYoginiJourney`, or change the app IDs before registering.
2. Install the Firebase CLI and run `firebase login`. Deploy this repository's deny-by-default policies to the development project with `firebase deploy --only firestore:rules,firestore:indexes,storage --project <project-id>`.
3. If enabling account deletion, install the official [Delete User Data extension](https://extensions.dev/extensions/firebase/delete-user-data) with Firestore paths set to `users/{UID}` and Firestore delete mode **recursive**. Test with a disposable account and confirm that its nested progress documents are removed. Set `FIREBASE_ACCOUNT_DELETION_ENABLED` to `true` in the platform configuration only after this is active.
4. Copy `firebase.config.example.json` to `firebase.android.local.json` and fill it with the **Android** Firebase configuration. Use the `api_key[].current_key`, `mobilesdk_app_id`, `project_number`, `project_id`, and `storage_bucket` from the selected app in `google-services.json`. For iOS, create `firebase.ios.local.json` using the corresponding `API_KEY`, `GOOGLE_APP_ID`, `GCM_SENDER_ID`, `PROJECT_ID`, and `STORAGE_BUCKET` from `GoogleService-Info.plist`. These are client app identifiers. Keep administrator credentials out of these files and out of the app. The platform-specific local JSON files are gitignored. Leave `FIREBASE_STORAGE_BUCKET` blank to build a YouTube-only app that does not initialize Firebase Storage.
5. Run `flutter run -d <device-id> --dart-define-from-file=firebase.android.local.json` on Android, or pass the iOS JSON on iOS. Use the same build argument with `flutter build apk --release` to produce a configured Android APK. Omitting the build argument starts the offline demo.

### First administrator

Create an account from the Firebase build and verify its email. In the Firebase console, copy the matching **UID** from **Authentication → Users**. An authorized project operator on a trusted machine can then use Application Default Credentials with permission to get and update Firebase Auth users in the development project.

```sh
npm --prefix backend ci
gcloud auth application-default login
npm --prefix backend run grant-admin -- <project-id> <verified-user-uid>
```

Open **Profile → Administrator access** and sign in again to pick up the new claim. The app checks the verified email and custom claim, then confirms access with a server-only Firestore read. The Firestore rules enforce the same requirements. Only the trusted Admin SDK can assign claims. A verified administrator can then open the course editor in the same screen.

### Firestore and Storage schema

A trusted project operator can also seed a course and lesson in the Firebase console. Use URL-safe document IDs made from letters, digits and hyphens.

| Path | Fields and access |
| --- | --- |
| `courses/{courseId}` | `title`, `description`, `level` (`beginner`, `intermediate` or `advanced`), `minutes` (integer), optional `thumbnail` (`morning`, `balance` or `studio`), `published` (boolean). Guests query published courses. |
| `courses/{courseId}/lessons/{lessonId}` | `title`, `order` (integer), `published` (boolean), and optional `youtubeVideoId` (11-character YouTube video ID). Guests can list published lessons when the parent course is published. |
| `users/{uid}/courses/{courseId}/lesson_progress/{lessonId}` | `completedAt` (server timestamp). Only the verified owner can read it or mark an existing published lesson complete. This is self-reported learning progress. Certificate eligibility will require separate server validation. |
| `users/{uid}/enrollments/{courseId}` | `enrolledAt` (server timestamp). A verified learner can enroll in a published course and read their own enrollment. |
| `admin_audit_logs/{entryId}` | Read access requires a verified administrator token. Only trusted server processes can write. |

Upload the matching public MP4 with content type `video/mp4` to `courses/{courseId}/{lessonId}/video.mp4` using a trusted operator account. Create the object through Firebase Storage so the SDK can obtain its download URL. Set the object’s custom metadata key `published` to the string `true` only when the media is ready for public viewing. The Storage rule checks this trusted metadata independently of the Firestore catalog. To withdraw a video, unpublish the Firestore lesson, remove the Storage publication metadata, and delete the object or revoke its download token to invalidate previously shared URLs. Only a verified administrator can write catalog entries or upload a draft MP4 from the app. Published-content filters use the default single-field indexes.

### Test

```sh
flutter analyze
flutter test
npm --prefix backend ci
firebase emulators:exec --project demo-yogini --only firestore,storage 'npm --prefix backend test'
```

The emulator tests use a disposable demo project ID and cover published content, private progress, administrator claims and Storage permissions.

## Phase 4 administrator panel

Deploy the updated rules to the Firebase project before testing on a phone. Use the project operator's authorized Google Cloud credentials.

```sh
firebase deploy --only firestore:rules,storage --project <project-id>
```

From the Firebase build, open **Profile → Administrator access**.

1. Tap **Add course**, fill in the title, description, level, duration and a bundled thumbnail, then tap **Save**.
2. Tap **Add lesson**, fill in the title and order, then tap **Save**.
3. Tap **Choose and upload MP4**, select a file up to 100 MiB, and wait for the upload confirmation.
4. Tap **Publish lesson**, return to the course and tap **Publish course**. Learners can now see the lesson and video. Signed-in learners with verified emails can enroll for free.
5. **Move to draft** removes the course or lesson from the public catalog while preserving its content and learner progress. Move a lesson to draft before replacing its MP4. When withdrawing a video, revoke its old download token in Storage if previously shared links must stop working.

The panel uses bundled thumbnails and preserves drafts. Custom thumbnail uploads and permanent deletion are outside this version.

The default offline build continues to include 16 course previews and six pranayama previews.

### YouTube lessons without Firebase Storage

Publish the latest Firestore rules using `firebase deploy --only firestore:rules --project <project-id>` or the Firebase Console Rules tab. The YouTube workflow does not require deploying Storage rules or provisioning a bucket.

1. Upload your video to YouTube with visibility **Unlisted** or **Public** and copy its share link. Unlisted videos can be watched and reshared by anyone with the link.
2. Open **Profile → Administrator access**, select the course, then add a lesson. Paste the share link into **YouTube link**, save, and tap **Publish lesson**. For an existing published lesson, move it to draft before changing its video link.
3. Publish the course if it is still a draft. Learners can tap **Watch on YouTube** to open the video in the YouTube app or browser.
