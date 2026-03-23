# FaithConnect — File Architecture

This document lists the main files and folders in the FaithConnect repository and the purpose of each area to help onboard contributors.

Top-level

- `pubspec.yaml` — Flutter dependencies and assets.
- `firebase.json` — Firebase hosting/emulator config (project settings).
- `firestore.rules` — Firestore security rules.
- `README.md` — Project overview.

Platform folders

- `android/` — Android app project and Gradle config.
- `ios/` — iOS Xcode project files.
- `web/` — Web entry (`index.html`, manifest, icons).
- `windows/`, `macos/`, `linux/` — Platform runner files.

Key app folders (lib/)

- `lib/main.dart` — App entry point, routing, and root widgets.
- `lib/firebase_options.dart` — Generated Firebase platform options.
- `lib/models/` — Data model classes (e.g., `post_model.dart`, `product_model.dart`).
- `lib/services/` — Singleton services that encapsulate business logic and Firebase access, examples:
  - `auth_service.dart` — Authentication, user loading, presence.
  - `post_service.dart` — Posts, media uploads, comments, reactions.
  - `message_service.dart` — Conversations and message operations.
  - `music_player_service.dart` — Audio playback (ChangeNotifier).
- `lib/screens/` — UI screens (login/register/profile/create_post/chat/marketplace/etc.).
- `lib/Bible/` — Local Bible SQL assets used by the reader.
- `lib/LOGO/` — App logo assets.

Assets

- `assets/` — Images and other assets packaged with the app.
- `songs/` — Local audio files used by `MusicPlayerService`.

Build & output

- `build/` — Generated build artifacts.

Tests

- `test/` — Widget and unit tests (e.g., `widget_test.dart`).

Notes

- Services are implemented as singletons and expose `ValueNotifier`/`ChangeNotifier` for UI updates.
- Firebase is the primary backend: Authentication, Firestore, Storage. Look in `lib/services/*` for concrete usage patterns.

If you want, I can expand this into a visual tree (with `tree` output) or add links from `README.md` to these docs.
