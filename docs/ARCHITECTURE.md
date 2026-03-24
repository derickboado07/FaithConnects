# FaithConnect Architecture

## Overview
FaithConnect is a Flutter social app using Firebase for backend services. The app follows a service-oriented architecture where UI screens call singleton service classes that encapsulate Firestore, Auth, and Storage interactions.

## State Management
- No external state-management package (Provider/Riverpod/Bloc) is used.
- App state is handled via singletons and Listenables: `ValueNotifier` (e.g., `AuthService.instance.currentUser`) and `ChangeNotifier` (e.g., `MusicPlayerService`).

## Backend & Database
- Firebase services: Authentication, Cloud Firestore, Firebase Storage.
- Firestore is used for posts, users, conversations, and comments; Storage holds media assets.

## Core Features
- Authentication & user profiles (register, login, presence).  
- Feed & posting (posts with images/videos, comments, reactions, sharing).  
- Real-time chat (conversations, messages, image messages, reactions).  
- Marketplace (products, orders, checkout flows).  
- Music player (asset playback).  
- Bible reader (local SQL assets).

## High-level Folder Structure (lib/)
- `lib/screens/` — UI pages and screens.  
- `lib/services/` — Business logic and Firebase access (singletons).  
- `lib/models/` — Data models used by services and UI.  
- `lib/` root — `main.dart`, app routing, and top-level helpers.

## Key Dependencies
- `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`  
- `image_picker`, `file_picker`, `audioplayers`, `shared_preferences`, `crypto`

## Typical Data Flow (Create Post)
1. UI: `CreatePostScreen` collects caption + media (via `image_picker`).
2. UI calls `PostService.instance.addPost(...)` with media bytes or path.
3. `PostService` enforces upload quota, uploads media to Firebase Storage, then writes a `posts` document to Firestore.
4. Clients receive updates via Firestore snapshot streams (`streamFeed()`) and update UI in real time.

## Recommendations / Optimizations
- Introduce a DI/state-management solution (Riverpod or Provider) for better testability and scoped state.  
- Implement cursor-based feed pagination and thumbnail generation for media to reduce reads and bandwidth.  
- Offload critical logic (quota checks, denormalization) to Cloud Functions to avoid client-side race conditions.  
- Review Firestore/Storage security rules for least privilege and validate content types/sizes server-side.  
- Add analytics, Crashlytics, and FCM (Cloud Functions) for notifications and monitoring.

## Next Steps (optional)
- Migrate one or two services to a DI/state-management pattern as an example.  
- Add feed pagination and thumbnail handling in `PostService` and UI.  
- Audit `firestore.rules` for security gaps.

---
Generated from a codebase scan of the FaithConnect Flutter project.
