# FaithConnects — System Documentation

## Table of Contents

1. [Overview](#1-overview)
2. [High-Level Architecture](#2-high-level-architecture)
3. [Repository Structure](#3-repository-structure)
4. [Flutter Application — lib/](#4-flutter-application--lib)
   - [Entry Point](#41-entry-point)
   - [Screens](#42-screens)
   - [Services](#43-services)
   - [Models](#44-models)
   - [Widgets](#45-widgets)
5. [Data Models & Firestore Schema](#5-data-models--firestore-schema)
6. [Firestore Security Rules](#6-firestore-security-rules)
7. [Storage Security Rules](#7-storage-security-rules)
8. [Cloud Functions (Node.js)](#8-cloud-functions-nodejs)
9. [Theme & Design System](#9-theme--design-system)
10. [Dependencies](#10-dependencies)
11. [Setup & Local Development](#11-setup--local-development)
12. [Deployment](#12-deployment)
13. [Progress Checklist](#13-progress-checklist)

---

## 1. Overview

**FaithConnects** is a cross-platform Flutter application built for faith-based communities. It combines social networking, scripture reading, devotional media, and a peer-to-peer marketplace in a single app. The backend is powered entirely by Firebase (Authentication, Firestore, Cloud Storage, Cloud Functions).

**Supported Platforms**: Android · iOS · Web · Windows · macOS · Linux

---

## 2. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              Flutter Client  (lib/)                          │
│  Screens ──► Services ──► Firebase SDKs                     │
│  Widgets                                                     │
│  Models                                                      │
└────────────────────┬────────────────────────────────────────┘
                     │ Firebase
        ┌────────────┼────────────────────┐
        ▼            ▼                    ▼
  Firebase Auth  Firestore DB       Cloud Storage
  (email/pass)  (real-time data)   (media files)
                     │
                     ▼
            Cloud Functions (Node.js)
            (secure server-side ops)
```

- **Frontend**: Flutter (`lib/`) — screens, services, models, and reusable widgets.
- **Backend**: Firebase (Auth, Firestore, Storage) + Cloud Functions for privileged operations.
- **Platform targets**: `android/`, `ios/`, `windows/`, `macos/`, `linux/`, `web/`.
- **Assets**: `assets/` (images/icons), `songs/` (worship audio), `lib/Bible/` (scripture SQL dumps), `lib/LOGO/`.

---

## 3. Repository Structure

```
FaithConnects/
├── lib/                    # Flutter Dart source code
│   ├── main.dart           # App entry point + home page
│   ├── firebase_options.dart
│   ├── screens/            # 21 full-page screens
│   ├── services/           # 8 service classes (business logic + Firebase)
│   ├── models/             # 2 standalone model files
│   ├── widgets/            # 4 shared reusable widgets
│   ├── Bible/              # Scripture SQL assets
│   │   ├── EN-English/asv.sql
│   │   └── TL-Wikang_Tagalog/tagab.sql
│   └── LOGO/               # App logo assets
├── functions/              # Firebase Cloud Functions (Node.js)
│   ├── index.js
│   └── package.json
├── android/                # Android platform project
├── ios/                    # iOS platform project
├── web/                    # Web platform entry files
├── windows/ macos/ linux/  # Desktop platform projects
├── assets/                 # Static assets (images, icons)
├── songs/                  # Worship audio files (.mp3)
├── firestore.rules         # Firestore security rules
├── firestore.indexes.json  # Firestore composite indexes
├── storage.rules           # Firebase Storage security rules
├── firebase.json           # Firebase project config
├── cors.json               # CORS config for Storage bucket
├── set_cors.js             # Script to apply CORS config
└── pubspec.yaml            # Flutter/Dart package manifest
```

---

## 4. Flutter Application — `lib/`

### 4.1 Entry Point

**`lib/main.dart`**

- Initialises Firebase with platform-specific `DefaultFirebaseOptions` and falls back gracefully when unsupported.
- Wraps the app in `AuthStateListener` which redirects unauthenticated users to `/login`.
- Defines the `MaterialApp` with a gold-themed `ThemeData` (primary `#D4AF37`).
- Hosts the **Home page** with a 5-tab `BottomNavigationBar`:
  | Tab | Screen |
  |-----|--------|
  | 0 — Home | Social feed + Verse of the Day + preview cards |
  | 1 — Bible | `BibleScreen` |
  | 2 — Marketplace | `MarketplaceScreen` |
  | 3 — Music | `MusicScreen` |
  | 4 — Profile | `ProfileScreen` |
- **Mini music player** floats above the nav bar when a song is playing.
- **Named routes** registered: `/login`, `/register`, `/profile`, `/edit-profile`, `/messages`, `/marketplace`, `/product-list`, `/bible`, `/music`.

---

### 4.2 Screens

#### Authentication

| File | Purpose |
|------|---------|
| `login_screen.dart` | Email/password sign-in with "Forgot password?" link |
| `register_screen.dart` | New account creation; writes user doc to Firestore on success |

#### Profile

| File | Purpose |
|------|---------|
| `profile_screen.dart` | Current user's profile: avatar, banner, bio, posts, followers/following counts, My Day upload |
| `public_profile_screen.dart` | Read-only view of any user's profile; follow/unfollow button; view their My Day stories |
| `edit_profile_screen.dart` | Edit name, bio, phone, gender, DOB, avatar, and banner photo |

#### Social Feed

| File | Purpose |
|------|---------|
| `create_post_screen.dart` | Compose a new post with optional image or video media |

#### My Day Stories

| File | Purpose |
|------|---------|
| `myday_viewer_screen.dart` | Full-screen story viewer (images auto-advance at 5 s; videos play at their natural duration, max 15 s). Displays a top progress bar segmented per item, user avatar, name, timestamp, and caption. Tap left/right halves to skip backward/forward. |

#### Messaging

| File | Purpose |
|------|---------|
| `chat_list_screen.dart` | Lists all conversations (direct + group) with last message and unread indicators |
| `chat_screen.dart` | Real-time 1-on-1 or group message thread with image sending, emoji reactions, reply, forward, delete options. Supports voice/video call initiation, note reply rendering, and auto-scroll to latest messages. Group avatar in the AppBar streams live from Firestore. |
| `call_screen.dart` | Full-screen call UI for voice and video calls. Shows ringing/accepted/ended status, call duration timer, mute/camera/speaker toggles. Uses Firestore-based signaling via `CallService`. |
| `new_chat_screen.dart` | User search to start a new direct conversation |
| `create_group_screen.dart` | Select members and name/photo to create a group. Group avatar uploads to Firebase Storage and displays immediately. |
| `group_info_screen.dart` | Group metadata viewer; member list |
| `group_settings_screen.dart` | Admin controls: rename group, change photo, add/remove members, promote/demote admins |

#### Marketplace

| File | Purpose |
|------|---------|
| `marketplace_screen.dart` | Landing with featured products, category chips, and quick links |
| `product_list_screen.dart` | Filterable product grid with search |
| `product_detail_screen.dart` | Full product view; add-to-cart button |
| `sell_product_screen.dart` | Create a new product listing with photo, price, description, category |
| `checkout_screen.dart` | Cart review, address input, payment method selection, order placement |
| `order_confirmation_screen.dart` | Post-purchase confirmation with order summary |

#### Content

| File | Purpose |
|------|---------|
| `bible_screen.dart` | Book/chapter/verse navigation; search; save verses; switch between English and Tagalog translations |
| `music_screen.dart` | Worship music player with playlist, play/pause/skip controls, and progress slider |

---

### 4.3 Services

All services are implemented as **singletons** (`ServiceName.instance`) unless noted otherwise.

---

#### `auth_service.dart` — `AuthService`

Handles user authentication, profile management, and social graph.

**Data class**: `AuthUser`
| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Firebase UID |
| `email` | String | Login email |
| `name` | String | Display name |
| `bio` | String | Profile biography |
| `phone` | String | Phone number |
| `gender` | String | Gender |
| `dob` | String? | Date of birth (ISO `YYYY-MM-DD`) |
| `avatarUrl` | String | Profile picture download URL |
| `bannerUrl` | String | Banner image download URL |
| `note` | String | Short status message (24-hour note) |

**Key methods**:
- `signIn(email, password)` / `signOut()` / `register(email, password, name)`
- `currentUser` — Stream of the signed-in `AuthUser`
- `updateProfile(name, bio, phone, gender, dob)` — Updates Firestore user document
- `uploadAvatar(bytes, filename)` / `uploadBanner(bytes, filename)` — Upload to Storage, update Firestore
- `followUser(targetUid)` / `unfollowUser(targetUid)` — Manage follow/follower subcollections
- `isFollowing(targetUid)` → `bool`
- `searchUsers(query)` → `List<AuthUser>`
- `setOnline(bool)` — Updates `isOnline` and `lastActive` in Firestore (presence)
- `sendPasswordResetEmail(email)`

---

#### `message_service.dart` — `MessageService`

Manages all conversation and message operations.

**Data classes**:

`Conversation`
| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Document ID |
| `type` | String | `'direct'` or `'group'` |
| `participants` | List\<String\> | UIDs of all members |
| `admins` | List\<String\> | UIDs of group admins |
| `name` | String | Group name (empty for direct) |
| `photoUrl` | String | Group photo URL |
| `lastMessage` | String | Preview of last message |
| `lastSenderId` | String | UID who sent last message |
| `lastRead` | Map\<String, dynamic\> | Per-user last-read timestamp |
| `createdAt` / `updatedAt` | String | ISO 8601 timestamps |

`MessageItem`
| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Document ID |
| `senderId` | String | Sender UID |
| `senderName` | String | Sender display name |
| `text` | String | Message body |
| `ts` | String | ISO 8601 timestamp |
| `imageUrl` | String? | Attached image URL |
| `reactions` | Map\<String, List\<String\>\> | Emoji → list of reactor UIDs |
| `deletedFor` | List\<String\> | UIDs for whom this is hidden ("delete for me") |
| `isSystemMessage` | bool | True for group event notifications |
| `mydayMediaUrl` | String? | My Day story media URL (for story replies) |
| `mydayOwnerName` | String? | Name of the story owner being replied to |
| `repliedToNote` | String? | Text of the user note being replied to |
| `repliedToNoteOwnerName` | String? | Name of the note owner being replied to |

**Key methods**:
- `conversationsStream(uid)` — Real-time stream of all user conversations
- `messagesStream(convoId)` — Real-time stream of messages
- `getOrCreateDirectConvo(myUid, otherUid)` → conversation ID (deterministic)
- `createGroup(name, participantUids, creatorUid, photoBytes?)` → conversation ID
- `sendMessage(convoId, senderId, senderName, text, {imageBytes?, repliedToNote?, repliedToNoteOwnerName?})`
- `deleteMessageForMe(convoId, msgId, myUid)` — Soft delete (adds UID to `deletedFor`)
- `deleteMessageForEveryone(convoId, msgId, senderId)` — Hard delete via Firestore or HTTP function
- `reactToMessage(convoId, msgId, emoji, uid)` — Toggle reaction
- `forwardMessage(msgItem, targetConvoId, senderId, senderName)`
- `addMember(convoId, uidToAdd, callerUid)` / `removeMember(convoId, uidToRemove, callerUid)`
- `updateGroupPhoto(convoId, bytes, filename)`
- `markRead(convoId, uid)` — Updates `lastRead` timestamp
- `_functionsBaseUrl` — Static const; set to your deployed Cloud Functions base URL to enable server-side operations

---

#### `post_service.dart` — `PostService`

Manages the social feed of posts and comments.

**Data classes**:

`Post`
| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Document ID |
| `authorId` | String | Author UID |
| `authorEmail` | String | Author email |
| `authorAvatarUrl` | String | Author profile picture URL |
| `content` | String | Post text |
| `timestamp` | String | ISO 8601 |
| `mediaUrl` | String? | Attached media download URL |
| `mediaType` | String? | `'image'` or `'video'` |
| `reactions` | Map\<String, List\<String\>\> | Reaction type → list of user identifiers |
| `comments` | List\<Comment\> | Embedded comment list (first page) |
| `commentCount` | int | Total comment count |
| Shared post fields | String? | `sharedPostId`, `sharedAuthorEmail`, `sharedAuthorAvatarUrl`, `sharedContent`, `sharedMediaUrl`, `sharedMediaType` |

`Comment`
| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Document ID |
| `author` | String | Author email |
| `text` | String | Comment body |
| `ts` | String | ISO 8601 |
| `reactions` | Map\<String, List\<String\>\> | Emoji → reactor list |

**Reactions available**: `Amen` · `Pray` · `Worship` · `Love`

**Key methods**:
- `postsStream()` — Real-time feed of all posts
- `userPostsStream(authorId)` — Posts by a specific user
- `createPost(authorId, email, avatarUrl, content, {mediaBytes?, mediaType?})`
- `sharePost(originalPost, sharerEmail, sharerAvatarUrl, caption)` — Creates a share post
- `deletePost(postId, authorId, mediaUrl?)` — Deletes post and cleans up Storage
- `reactToPost(postId, reactionType, identifier)` — Toggle reaction
- `addComment(postId, author, text)` / `deleteComment(postId, commentId, authorEmail)`
- `reactToComment(postId, commentId, emoji, identifier)`
- `enforceUploadQuota(authorId)` — Checks daily upload limit (20/day); throws if exceeded
- `savedPostsStream(userId)` / `savePost(userId, post)` / `unsavePost(userId, postId)`

---

#### `myday_service.dart` — `MyDayService`

Manages ephemeral 24-hour story entries ("My Day"), similar to Stories in messaging apps.

**Data class**: `MyDayItem`
| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Document ID |
| `uid` | String | Owner UID |
| `mediaUrl` | String | Download URL from Storage |
| `mediaType` | String | `'image'` or `'video'` |
| `caption` | String | Optional caption |
| `createdAt` | String | ISO 8601 creation time |
| `expiresAt` | String | ISO 8601 (24 h after creation) |
| `isExpired` | bool (computed) | True if current time is past `expiresAt` |

**Key methods**:
- `uploadMyDay(bytes, filename, mediaType, {caption})` — Uploads media to `my_day/{uid}/{ts}_filename` in Storage, writes Firestore doc to `my_day/`
- `deleteMyDay(docId, storagePath)` — Deletes Storage file and Firestore document
- `myDayStream(uid)` — Real-time stream of a specific user's active (non-expired) stories
- `activeStoriesForFeed(uids)` — Fetches stories for a list of UIDs (used to populate story row in home feed)
- Video clips must be ≤ 15 seconds (enforced by the caller/upload UI)
- Supported formats: JPEG, PNG, GIF, WEBP images; MP4/WEBM videos

---

#### `call_service.dart` — `CallService`

Manages voice and video call signaling via Firestore documents.

**Key methods**:
- `startCall(participants, type, convoId)` → `String` — Creates a call document with status `'ringing'` and returns the call ID
- `acceptCall(callId)` — Updates call status to `'accepted'` with server timestamp
- `endCall(callId)` — Updates call status to `'ended'` with server timestamp
- `callStream(callId)` — Real-time stream of call document changes (ringing → accepted → ended)
- `incomingCallsStream()` — Stream of calls where current user is a participant and status is `'ringing'`
- `sendMissedCallMessage(convoId, type)` — Writes a system message to the conversation for missed calls

Calls are stored in the `calls/` collection with fields: `callId`, `callerId`, `participants`, `type` (`'voice'`/`'video'`), `status`, `convoId`, `createdAt`, `acceptedAt`, `endedAt`.

---

#### `presence_service.dart` — `PresenceService`

Manages online/offline status, last-active timestamps, and short user notes.

**Key methods**:
- `setNote(note)` — Saves a short status message (max 100 chars) with a timestamp; clearing saves an empty string
- `isNoteActive(noteSetAt)` → `bool` — Static helper; returns `true` if the note was set within the last 24 hours
- `noteStream(uid)` — Stream of a user's current note text
- `userStatusStream(uid)` — Stream returning `{ isOnline, lastActive, note, name, avatar }`
- `formatLastSeen(isoTimestamp)` — Static helper that returns a human-readable string such as `"Active just now"`, `"Last seen 3 minutes ago"`, etc.

Notes are stored in the `users/{uid}` document under fields `note` and `noteSetAt`.

---

#### `bible_service.dart` — `BibleService`

Provides scripture access for two translations loaded from bundled SQL assets.

**Data class**: `BibleVerse { id, book, chapter, verse, text, language }`

**Translations**:
| Key | File | Description |
|-----|------|-------------|
| `en` | `lib/Bible/EN-English/asv.sql` | American Standard Version |
| `tl` | `lib/Bible/TL-Wikang_Tagalog/tagab.sql` | Ang Biblia (Tagalog) |

**Key methods**:
- `loadBible(language)` — Parses SQL asset and caches verses in memory
- `getChapter(book, chapter, language)` → `List<BibleVerse>`
- `searchVerses(query, language)` → `List<BibleVerse>`
- `getDailyVerse(language)` → `BibleVerse` — Deterministic; same verse all day based on `DateTime.now()` day-of-year
- `saveVerse(verse)` / `getSavedVerses()` / `removeSavedVerse(id)` — Persisted locally via `SharedPreferences`
- `books` — Ordered list of all 66 Bible books

---

#### `music_player_service.dart` — `MusicPlayerService`

Controls worship music playback.

**Data class**: `Song { title, artist, assetPath }`

**Key methods**:
- `play(index)` / `pause()` / `resume()` / `next()` / `previous()`
- `seekTo(Duration)` — Seek within current track
- `positionStream` / `durationStream` — Streams for UI progress bar
- `currentSongIndex` — Current track index
- `isPlaying` — Playback state
- Web platform uses `BytesSource` to load audio bytes directly (avoids service-worker caching issues)
- 13 worship songs stored under `songs/` as `.mp3` files

---

#### `marketplace_service.dart` — `MarketplaceService`

Handles product listings, shopping cart, and orders.

See [Section 4.4](#44-models) for model field details.

**Key methods**:
- `productsStream({category?})` — Real-time stream; optionally filtered by category
- `createProduct(sellerId, sellerName, sellerEmail, name, description, price, category, imageBytes?)` → product ID
- `deleteProduct(productId, imageUrl?)`
- `addToCart(userId, product, {quantity})` / `removeFromCart(userId, productId)` / `updateCartQuantity(userId, productId, qty)`
- `cartStream(userId)` — Real-time stream of cart items
- `placeOrder(buyerId, cartItems, address, paymentMethod)` — Writes order docs; clears cart
- `ordersStream(userId)` — Orders where user is buyer or seller
- `updateOrderStatus(orderId, status)` — `pending` → `confirmed` → `shipped` → `delivered`

---

### 4.4 Models

#### `lib/models/product_model.dart` — `Product`

| Field | Type | Description |
|-------|------|-------------|
| `productId` | String | Firestore document ID |
| `productName` | String | Listing title |
| `description` | String | Detailed description |
| `price` | double | Price in currency |
| `imageUrl` | String | Product photo URL |
| `sellerId` | String | Seller UID |
| `sellerName` | String | Seller display name |
| `sellerEmail` | String | Seller email |
| `category` | String | Product category |
| `createdAt` | String | ISO 8601 creation time |

#### `lib/models/order_model.dart` — `ProductOrder`

| Field | Type | Description |
|-------|------|-------------|
| `orderId` | String | Firestore document ID |
| `buyerId` | String | Buyer UID |
| `productId` | String | Referenced product |
| `productName` | String | Product name at time of order |
| `imageUrl` | String | Product image URL |
| `address` | String | Delivery address |
| `paymentMethod` | String | Payment method string |
| `price` | double | Price at time of order |
| `status` | String | `pending` / `confirmed` / `shipped` / `delivered` |
| `createdAt` | String | ISO 8601 |

---

### 4.5 Widgets

#### `user_avatar.dart` — `UserAvatar`

Circular avatar widget. Shows a network image if `avatarUrl` is provided; otherwise renders a fallback circle with the user's initials. Accepts `radius` and optional border styling.

#### `message_suggestion_bar.dart` — `MessageSuggestionBar`

Horizontal scrollable bar shown in `chat_screen.dart`. Displays context-aware encouragement suggestions fetched from the `suggest` Cloud Function, plus quick-reaction buttons (`🙏 Praying`, `❤️ Amen`, `🙌 Praise God`, etc.). Tapping a suggestion pre-fills the message input field.

#### `online_indicator.dart` — `OnlineIndicator`

Small green dot widget overlaid on a user avatar when `isOnline == true`. Used in chat headers and conversation list tiles to show real-time presence.

#### `set_note_dialog.dart` — `SetNoteDialog`

Modal dialog for editing a user's short status note (max 100 characters). Includes faith-based predefined suggestions the user can tap to auto-fill. Calls `PresenceService.instance.setNote()` on save. Use `SetNoteDialog.show(context, currentNote: ...)` to present it and receive the saved note text.

---

## 5. Data Models & Firestore Schema

```
users/{uid}
  name, email, bio, phone, gender, dob    — profile fields
  avatar, banner                          — storage URLs
  isOnline (bool), lastActive (ISO)       — presence
  note (string), noteSetAt (ISO)          — 24-hour status note

  following/{targetUid}                   — people this user follows
  followers/{sourceUid}                   — people who follow this user
  saved/{postId}                          — saved posts

upload_quotas/{userId}
  count (int), date (string)              — daily upload counter (resets per date)

posts/{postId}
  id, authorId, author, authorAvatar      — identity
  content, ts                             — body and timestamp
  mediaUrl, mediaType                     — optional image/video
  reactions (map emoji→[ids])             — post reactions
  commentsCount (int)                     — denormalised count
  sharedPostId, sharedAuthorEmail,        — shared-post fields
  sharedAuthorAvatarUrl, sharedContent,
  sharedMediaUrl, sharedMediaType

  comments/{commentId}
    id, author, text, ts
    reactions (map emoji→[ids])

my_day/{docId}
  uid, mediaUrl, mediaType                — owner and media
  caption                                 — optional text
  createdAt, expiresAt                    — ISO 8601 (expiresAt = createdAt + 24h)

conversations/{convoId}
  type ('direct'|'group')
  participants ([uid,...])
  admins ([uid,...])                      — group admins
  name, photoUrl                          — group identity
  createdBy, createdAt, updatedAt
  lastMessage, lastSenderId
  lastRead {uid: ISO}                     — per-user read receipts

  messages/{msgId}
    senderId, senderName, text, ts
    imageUrl                              — optional attached image
    reactions (map emoji→[uids])
    deletedFor ([uid,...])                — soft-delete per user
    isSystemMessage (bool)                — group event notifications
    mydayMediaUrl                         — My Day story URL (story replies)
    mydayOwnerName                        — story owner name
    repliedToNote                         — note text being replied to
    repliedToNoteOwnerName                — note owner name

calls/{callId}
  callId, callerId                        — call identity
  participants ([uid,...])                — all call participants
  type ('voice'|'video')                  — call type
  status ('ringing'|'accepted'|'ended')   — current state
  convoId                                 — linked conversation
  createdAt, acceptedAt, endedAt          — timestamps

products/{productId}
  productName, description, price
  imageUrl
  sellerId, sellerName, sellerEmail
  category, createdAt

orders/{orderId}
  orderId, buyerId, productId
  productName, imageUrl
  address, paymentMethod, price
  status, createdAt

carts/{userId}/items/{productId}
  productId, productName, price, imageUrl
  sellerId, quantity, addedAt
```

---

## 6. Firestore Security Rules

`firestore.rules` enforces the following access patterns:

| Collection | Read | Write |
|-----------|------|-------|
| `users/{uid}` | Any authenticated user | Owner only |
| `users/{uid}/following` | Any authenticated user | Owner (following side) |
| `users/{uid}/followers` | Any authenticated user | Source user (follower side) |
| `users/{uid}/saved` | Owner only | Owner only |
| `upload_quotas/{userId}` | Owner only | Owner only |
| `posts/{postId}` | Any authenticated user | Create: auth + `authorId == uid`; Update: any (reactions); Delete: author |
| `posts/{postId}/comments` | Any authenticated user | Create: any auth; Update/Delete: comment author by email |
| `my_day/{docId}` | Any authenticated user | Create: `uid == auth.uid`; Delete: owner; Update: disallowed |
| `products/{productId}` | Any authenticated user | Create: `sellerId == uid`; Update/Delete: seller |
| `carts/{userId}/items` | Cart owner | Cart owner |
| `orders/{orderId}` | Buyer or seller | Create: buyer; Update/Delete: disallowed |
| `conversations/{convoId}` | Participants only | Create: caller in participants; Update: participant (admin-guarded for name/photo/members); Delete: group admin |
| `conversations/{convoId}/messages` | Participants only | Read/Create: participants; Update: participants (reactions/deletedFor); Delete: sender, `token.admin == true`, or group admin |
| `calls/{callId}` | Any authenticated user | Create/Update: any authenticated; Delete: disallowed |

---

## 7. Storage Security Rules

`storage.rules` restricts file access to authenticated users. Key path patterns:
- `my_day/{uid}/**` — readable by all authenticated users; writable only by `{uid}`
- `avatars/{uid}/**` — writable only by `{uid}`
- `banners/{uid}/**` — writable only by `{uid}`
- `chat_images/**` — readable and writable by authenticated users
- `group_photos/**` — readable and writable by authenticated users
- `products/**` — writable only by authenticated users; readable by all authenticated users

CORS for the Storage bucket is configured in `cors.json` and applied via `set_cors.js`.

---

## 8. Cloud Functions (Node.js)

All functions live in `functions/index.js` and use the Firebase Admin SDK. Every HTTP function requires a `Bearer <ID_TOKEN>` `Authorization` header and verifies the token with `admin.auth().verifyIdToken()`.

### `suggest` — POST (HTTP)

**Purpose**: Rule-based encouragement message suggestions for the chat input.

**Request body**: `{ text: string }` — the text currently typed (may be empty)

**Response**: `{ suggestions: string[], reactions: string[] }`

Matches keywords (tired, stressed, sad, etc.) and returns up to 5 contextual encouragement strings plus a fixed set of quick-reaction labels.

---

### `deleteMessage` — Callable Function

**Purpose**: Securely delete a message (server-side, bypasses Firestore rules when client permissions are insufficient).

**Request data**: `{ convoId: string, messageId: string }`

**Auth requirement**: Caller must be the original `senderId` or have an `admin: true` custom claim.

---

### `deleteMessageHttp` — POST (HTTP)

**Purpose**: HTTP equivalent of `deleteMessage` for clients that prefer REST.

**Request body**: `{ convoId: string, messageId: string }`

**Auth**: `Authorization: Bearer <ID_TOKEN>`

**Responses**: `200 { success: true }` · `401` · `403` · `404` · `500`

---

### `sendMessageHttp` — POST (HTTP)

**Purpose**: Send a text message into a conversation after verifying the caller is a participant.

**Request body**: `{ convoId: string, text: string }`

**Auth**: `Authorization: Bearer <ID_TOKEN>`

**Side effects**: Writes a new `messages/` document; updates `lastMessage`, `lastSenderId`, `updatedAt` on the conversation document.

**Responses**: `200 { success: true, messageId: string }` · `401` · `403` · `404` · `500`

---

### `addGroupMemberHttp` — POST (HTTP)

**Purpose**: Add a user to a group conversation. Caller must be a group admin or have `admin: true` custom claim.

**Request body**: `{ convoId: string, uidToAdd: string }`

**Auth**: `Authorization: Bearer <ID_TOKEN>`

**Side effects**: Appends `uidToAdd` to `participants` array; posts a system message `"<name> was added to the group 🙏"`.

**Responses**: `200 { success: true }` · `400 (not a group / already member)` · `401` · `403` · `404`

---

### `removeGroupMemberHttp` — POST (HTTP)

**Purpose**: Remove a user from a group. Caller must be a group admin (or the member removing themselves).

**Request body**: `{ convoId: string, uidToRemove: string }`

**Auth**: `Authorization: Bearer <ID_TOKEN>`

**Side effects**: Removes `uidToRemove` from `participants`; posts a system message.

**Responses**: `200 { success: true }` · `400` · `401` · `403` · `404`

---

### Configuring the Functions Base URL (Flutter side)

After deploying functions, set the constant in `lib/services/message_service.dart`:

```dart
static const String _functionsBaseUrl =
    'https://us-central1-<your-project-id>.cloudfunctions.net';
```

Leave it empty (`''`) to fall back to direct Firestore writes.

---

## 9. Theme & Design System

| Token | Value | Usage |
|-------|-------|-------|
| Primary (Gold) | `#D4AF37` | App bar, buttons, active icons |
| Soft Gold | `#F5E6B3` | Card backgrounds, chip fills |
| Background | `#FFFFFF` | Scaffold background |
| Text Primary | `#333333` | Body text |
| Reaction icon set | Custom emoji set | Post and message reactions |
| Border radius | 12–20 px | Cards, dialogs, input fields |
| App bar elevation | 0 | Flat top bar with logo |

---

## 10. Dependencies

### Runtime

| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_auth` | ^6.2.0 | Authentication |
| `firebase_core` | ^4.5.0 | Firebase SDK initialisation |
| `cloud_firestore` | ^6.1.3 | Real-time database |
| `firebase_storage` | ^13.1.0 | Media file storage |
| `audioplayers` | ^6.6.0 | Music playback |
| `video_player` | ^2.11.1 | My Day video story playback |
| `http` | ^1.6.0 | Cloud Functions HTTP calls |
| `shared_preferences` | ^2.1.1 | Local storage (saved verses) |
| `file_picker` | ^10.3.10 | File selection (desktop/web) |
| `image_picker` | ^1.2.1 | Camera/gallery (mobile) |
| `crypto` | ^3.0.2 | Deterministic conversation ID hashing |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |

### Dev

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | SDK | Unit and widget testing |
| `flutter_lints` | ^6.0.0 | Lint rules |

---

## 11. Setup & Local Development

### Prerequisites

- Flutter SDK (Dart SDK ^3.10.4)
- Android Studio / Xcode (for mobile targets)
- Firebase CLI (`npm install -g firebase-tools`)
- Node.js (for Cloud Functions development)

### Flutter App

```bash
# Clone and install packages
flutter pub get

# Run on a connected device / emulator
flutter run -d <device-id>

# Build release APK
flutter build apk

# Build for web
flutter build web
```

### Cloud Functions (local emulator)

```bash
cd functions
npm install
firebase emulators:start --only functions,firestore
```

### Apply Storage CORS

```bash
node set_cors.js
```

---

## 12. Deployment

### Full Firebase deployment

```bash
# Deploy everything (hosting + firestore rules/indexes + storage rules + functions)
firebase deploy
```

### Individual targets

```bash
# Firestore rules only
firebase deploy --only firestore:rules

# Firestore indexes only
firebase deploy --only firestore:indexes

# Storage rules only
firebase deploy --only storage

# Cloud Functions only
cd functions && firebase deploy --only functions

# Flutter web hosting only (after flutter build web)
firebase deploy --only hosting
```

---

## 13. Progress Checklist

- [x] Multi-platform project scaffold (Android, iOS, web, Windows, macOS, Linux)
- [x] Flutter `lib/` structure with screens, services, models, and widgets
- [x] Firebase options configured (`lib/firebase_options.dart`)
- [x] Authentication — login, register, password reset, sign-out
- [x] User profiles — avatar, banner, bio, follow/unfollow, public view, edit
- [x] Presence system — online status, last-active timestamp, 24-hour note
- [x] Social feed — create posts (text + media), reactions, comments, shares, saved posts
- [x] My Day stories — 24-hour image/video stories with full-screen viewer
- [x] Messaging — direct and group chats, image messages, reactions, forward, delete
- [x] Group management — create, rename, photo, add/remove members, admin roles
- [x] Bible reader — EN and TL translations, search, daily verse, saved verses
- [x] Music player — worship playlist, controls, mini player, web support
- [x] Marketplace — listings, cart, checkout, orders, status tracking
- [x] Firestore security rules and composite indexes
- [x] Cloud Functions: `suggest`, `deleteMessage`, `deleteMessageHttp`, `sendMessageHttp`, `addGroupMemberHttp`, `removeGroupMemberHttp`
- [x] Per-user upload quota (20 posts/day)
- [x] Voice/video call signaling — Firestore-based call documents with ringing/accepted/ended states
- [x] Note reply in chat — reply to a user's status note with visual context in the message bubble
- [x] Auto-scroll chat to latest messages on open
- [x] Live group avatar — streams from Firestore in real-time in the chat AppBar
- [ ] Push notifications (FCM) — not yet implemented
- [ ] Automated test coverage — only `test/widget_test.dart` exists; should be expanded

4. Update Flutter packages and run the app:

```bash
flutter pub get
flutter run -d <device-id>
```

## How to Test "Delete for everyone"

1. Ensure you are signed in as the message sender (or as an admin user if testing admin path).
2. Open the conversation and locate the message to delete.
3. Tap the message, choose "Delete for everyone". The client will call the configured HTTP function which verifies your ID token and performs the deletion server-side (or the client will perform a direct delete if rules permit).
4. If you see a Firestore permission error, verify you deployed `firestore.rules` that allow sender deletes or use the server function path above.

## Notes and Cautions

- Security: Do not broadly relax delete permissions in Firestore. The current change limits deletion to the message sender or admin users. If you need stricter control (audit logs, moderation), prefer server-side callable functions and an admin workflow.
- Dependency: The `http` package was upgraded to `^1.6.0` to remain compatible with Firebase platform interfaces. If you update Firebase packages later, re-check `pubspec.yaml` for compatibility.


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
