# FaithConnects — System Documentation

## Overview

FaithConnects is a cross-platform Flutter application with Firebase backend integration. The repo contains platform folders for Android, iOS, Windows, macOS, Linux and Web, a Flutter `lib/` codebase containing UI screens, models, and services, plus assets and build outputs.

## High-level Architecture

- Frontend: Flutter app in `lib/` (UI screens, models, services).
- Backend: Firebase services (Authentication, Firestore, Storage, Cloud Functions configured via firebase.json and firebase rules).
- Platform builds: `android/`, `ios/`, `windows/`, `macos/`, `linux/`, `web/`.
- Assets & Media: `assets/`, `songs/`, `build/flutter_assets/` (generated build assets).

## Key Repo Locations

- Main entry: `lib/main.dart`
- Firebase options: `lib/firebase_options.dart`
- Screens: `lib/screens/` (login, register, chat, marketplace, profile, bible, music, etc.)
- Models: `lib/models/` (product_model.dart, order_model.dart)
- Rules & indexes: `firestore.rules`, `firestore.indexes.json`, `storage.rules`
- Firebase config: `firebase.json`, `cors.json`, `set_cors.js`

## Features Implemented (summary)

- Multi-platform Flutter app (Android, iOS, web, desktop)
- Authentication + profile screens
- Chat feature (chat list, chat screen, new chat)
- Marketplace (product list, product detail, checkout, orders)
- Bible reader screens (multiple language folders under `lib/Bible/`)
- Music player screens and asset support
- Firebase integration (options file present)

## Setup & Run (local)

Prerequisites: Flutter SDK, Android/iOS toolchains as needed, Firebase CLI (if deploying)

Example commands:

```bash
flutter pub get
flutter run -d <device-id>
```

To build for Android:

```bash
flutter build apk
```

To view Firebase config & rules edit/deploy:

```bash
firebase deploy --only firestore,storage,hosting
```

## Progress & Current Status

This project progress checklist reflects the current repository contents and what is implemented. Update this file as work progresses.

- [x] Multi-platform project scaffold (Android, iOS, web, desktop)
- [x] `lib/` app structure with main screens and models
- [x] Firebase options present (`lib/firebase_options.dart`)
- [x] Authentication UI screens implemented
- [x] Chat feature UI implemented
- [x] Marketplace UI implemented (products, checkout)
- [x] Bible content folders included (EN, TL)
- [x] Music screens and assets present
- [x] Firestore rules and indexes present
- [ ] Backend Cloud Functions (if needed) — not present / check `functions/` if required
- [x] Backend Cloud Functions (basic suggestion function added in `functions/`)
- [ ] Automated tests coverage — minimal tests present (`test/widget_test.dart`) and should be expanded

Notes: The checked items are present in the repository as of this documentation creation. Missing items are left as explicitly unchecked.

## How To View & Update Progress

- Edit this `DOCUMENTATION.md` and update the checklist checkboxes to reflect completed work.
- Use the repo TODO/issue tracking (recommended) to manage individual tasks.
- Quick status commands:

```powershell
git status
git add DOCUMENTATION.md
git commit -m "docs: add system documentation and progress checklist"
```

## Recommended Next Steps

1. Add a short `CONTRIBUTING.md` describing workflow and coding style.
2. Expand automated tests and add CI (GitHub Actions) to run `flutter test` on PRs.
3. Add Cloud Functions (if business logic requires server-side processing) into a `functions/` folder and reference them in this doc.
4. Keep this `Progress` checklist updated for transparency.

## Contact & Ownership

Update this section with the project owner and team contact details.

---
Generated: 2026-03-23 — initial documentation created by repository assistant.
