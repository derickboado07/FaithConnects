// ─────────────────────────────────────────────────────────────────────────────
// AUTH SERVICE — Handles authentication, user profile management,
// and social graph (follow/unfollow) operations.
//
// Firestore collections:
//   - users/{uid}                    — User profile documents
//   - users/{uid}/followers/{fid}    — Follower sub-documents
//   - users/{uid}/following/{fid}    — Following sub-documents
//
// Firebase Storage: users/{uid}/avatar, users/{uid}/banner
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL — AuthUser
// ─────────────────────────────────────────────────────────────────────────────

class AuthUser {
  final String id;
  final String email;
  final String name;
  final String bio;
  final String phone;
  final String gender;
  final String? dob;
  final String avatarUrl;
  final String bannerUrl;
  final String verseBackground;
  final bool isModerator;

  AuthUser({
    required this.id,
    required this.email,
    this.name = '',
    this.bio = '',
    this.phone = '',
    this.gender = '',
    this.dob,
    this.avatarUrl = '',
    this.bannerUrl = '',
    this.verseBackground = '',
    this.isModerator = false,
  });

  factory AuthUser.fromFirestore(String uid, Map<String, dynamic> data) {
    return AuthUser(
      id: uid,
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      gender: data['gender'] as String? ?? '',
      dob: data['dob'] as String?,
      avatarUrl: data['avatarUrl'] as String? ?? '',
      bannerUrl: data['bannerUrl'] as String? ?? '',
      verseBackground: data['verseBackground'] as String? ?? '',
      isModerator: data['isModerator'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'name': name,
        'bio': bio,
        'phone': phone,
        'gender': gender,
        'dob': dob,
        'avatarUrl': avatarUrl,
        'bannerUrl': bannerUrl,
        'verseBackground': verseBackground,
        'isModerator': isModerator,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH SERVICE — Singleton
// ─────────────────────────────────────────────────────────────────────────────

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Reactive holder for the currently signed-in user profile.
  final ValueNotifier<AuthUser?> currentUser = ValueNotifier(null);

  StreamSubscription<DocumentSnapshot>? _userSub;

  /// Initialises the service: restores session if a user is already signed in.
  Future<void> init() async {
    final fbUser = _auth.currentUser;
    if (fbUser != null) {
      await _loadUser(fbUser.uid);
    }
  }

  // ── Presence ────────────────────────────────────────────────────────────

  /// Sets the current user's online/offline presence in Firestore.
  void setPresence(bool online) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _db.collection('users').doc(uid).set(
      {'isOnline': online},
      SetOptions(merge: true),
    );
  }

  /// Updates the current user's last-active timestamp in Firestore.
  void updateLastActive() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _db.collection('users').doc(uid).set(
      {'lastActive': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ── Authentication ──────────────────────────────────────────────────────

  /// Logs in with email & password. Returns error string on failure, null on success.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) return 'Login failed.';
      await _loadUser(uid);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Login failed.';
    } catch (e) {
      return e.toString();
    }
  }

  /// Registers a new account. Returns error string on failure, null on success.
  Future<String?> register({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? gender,
    String? dob,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) return 'Registration failed.';
      await _db.collection('users').doc(uid).set({
        'email': email,
        'name': name,
        'bio': '',
        'phone': phone ?? '',
        'gender': gender ?? '',
        'dob': dob,
        'avatarUrl': '',
        'bannerUrl': '',
        'isModerator': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Sign out after registration so user logs in explicitly
      await _auth.signOut();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Registration failed.';
    } catch (e) {
      return e.toString();
    }
  }

  /// Signs out the current user.
  Future<void> logout() async {
    _userSub?.cancel();
    _userSub = null;
    currentUser.value = null;
    await _auth.signOut();
  }

  /// Sends a password-reset email. Returns error string on failure, null on success.
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Failed to send reset email.';
    } catch (e) {
      return e.toString();
    }
  }

  // ── Profile ─────────────────────────────────────────────────────────────

  /// Updates the current user's profile. Supports text fields and media uploads.
  /// Returns true on success.
  Future<bool> updateProfile({
    required String email,
    String? name,
    String? bio,
    String? phone,
    String? gender,
    String? dob,
    String? avatarPath,
    Uint8List? avatarBytes,
    String? avatarFilename,
    String? bannerPath,
    Uint8List? bannerBytes,
    String? bannerFilename,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      final updates = <String, dynamic>{};

      if (name != null) updates['name'] = name;
      if (bio != null) updates['bio'] = bio;
      if (phone != null) updates['phone'] = phone;
      if (gender != null) updates['gender'] = gender;
      if (dob != null) updates['dob'] = dob;

      // Avatar upload
      if (avatarBytes != null && avatarFilename != null) {
        final ref = _storage.ref().child('users/$uid/avatar');
        await ref.putData(avatarBytes);
        updates['avatarUrl'] = await ref.getDownloadURL();
      } else if (avatarPath != null && avatarPath.isNotEmpty && !avatarPath.startsWith('http')) {
        final ref = _storage.ref().child('users/$uid/avatar');
        if (kIsWeb) {
          // On web, avatarPath isn't a local file — skip
        } else {
          await ref.putFile(File(avatarPath));
          updates['avatarUrl'] = await ref.getDownloadURL();
        }
      }

      // Banner upload
      if (bannerBytes != null && bannerFilename != null) {
        final ref = _storage.ref().child('users/$uid/banner');
        await ref.putData(bannerBytes);
        updates['bannerUrl'] = await ref.getDownloadURL();
      } else if (bannerPath != null && bannerPath.isNotEmpty && !bannerPath.startsWith('http')) {
        final ref = _storage.ref().child('users/$uid/banner');
        if (kIsWeb) {
          // On web, bannerPath isn't a local file — skip
        } else {
          await ref.putFile(File(bannerPath));
          updates['bannerUrl'] = await ref.getDownloadURL();
        }
      }

      if (updates.isNotEmpty) {
        await _db.collection('users').doc(uid).set(updates, SetOptions(merge: true));
      }
      return true;
    } catch (e) {
      debugPrint('updateProfile error: $e');
      return false;
    }
  }

  // ── User lookup ─────────────────────────────────────────────────────────

  /// Real-time stream of a user profile by UID.
  Stream<AuthUser?> streamUser(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return AuthUser.fromFirestore(snap.id, snap.data()!);
    });
  }

  /// Searches users by name or email. Returns up to [limit] results.
  Future<List<AuthUser>> searchUsers(String query, {int limit = 20}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    // Search by name prefix
    final nameSnap = await _db
        .collection('users')
        .orderBy('name')
        .startAt([q])
        .endAt(['$q\uf8ff'])
        .limit(limit)
        .get();

    // Search by email prefix
    final emailSnap = await _db
        .collection('users')
        .orderBy('email')
        .startAt([q])
        .endAt(['$q\uf8ff'])
        .limit(limit)
        .get();

    final Map<String, AuthUser> merged = {};
    for (final doc in nameSnap.docs) {
      merged[doc.id] = AuthUser.fromFirestore(doc.id, doc.data());
    }
    for (final doc in emailSnap.docs) {
      merged.putIfAbsent(doc.id, () => AuthUser.fromFirestore(doc.id, doc.data()));
    }
    return merged.values.take(limit).toList();
  }

  // ── Follow / Social graph ──────────────────────────────────────────────

  /// Checks whether the current user follows [targetUid].
  Future<bool> isFollowingById(String targetUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(targetUid)
        .get();
    return doc.exists;
  }

  /// Toggles follow/unfollow for [targetUid].
  /// Returns the new state: true = now following, false = now unfollowed.
  Future<bool> toggleFollowById(String targetUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final myFollowingRef =
        _db.collection('users').doc(uid).collection('following').doc(targetUid);
    final theirFollowersRef =
        _db.collection('users').doc(targetUid).collection('followers').doc(uid);

    final snap = await myFollowingRef.get();
    if (snap.exists) {
      // Unfollow
      await myFollowingRef.delete();
      await theirFollowersRef.delete();
      return false;
    } else {
      // Follow
      final now = DateTime.now().toIso8601String();
      await myFollowingRef.set({'ts': now});
      await theirFollowersRef.set({'ts': now});
      return true;
    }
  }

  /// Real-time follower count for [userId].
  Stream<int> streamFollowersCount(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Real-time following count for [userId].
  Stream<int> streamFollowingCount(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ── Verse background ───────────────────────────────────────────────────

  /// Uploads an image (from bytes, local path, or URL) and saves it as the
  /// verse background for the current user. Returns the download URL on
  /// success, or null on failure.
  Future<String?> uploadAndSaveVerseBackground({
    required String email,
    Uint8List? bytes,
    String? localPath,
    String? filename,
    String? url,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;

      String? downloadUrl;

      if (url != null && url.isNotEmpty) {
        // URL provided directly — store it as-is
        downloadUrl = url;
      } else if (bytes != null) {
        final ref = _storage.ref().child('users/$uid/verse_bg');
        await ref.putData(bytes);
        downloadUrl = await ref.getDownloadURL();
      } else if (localPath != null && localPath.isNotEmpty) {
        final ref = _storage.ref().child('users/$uid/verse_bg');
        if (!kIsWeb) {
          await ref.putFile(File(localPath));
          downloadUrl = await ref.getDownloadURL();
        }
      }

      if (downloadUrl != null) {
        await _db.collection('users').doc(uid).set(
          {'verseBackground': downloadUrl},
          SetOptions(merge: true),
        );
      }
      return downloadUrl;
    } catch (e) {
      debugPrint('uploadAndSaveVerseBackground error: $e');
      return null;
    }
  }

  /// Clears the verse background for the current user.
  Future<void> clearVerseBackground({required String email}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set(
      {'verseBackground': ''},
      SetOptions(merge: true),
    );
  }

  // ── One-shot user lookup ────────────────────────────────────────────────

  /// Fetches a single user profile by UID (one-shot, no stream).
  Future<AuthUser?> getUserById(String userId) async {
    try {
      final snap = await _db.collection('users').doc(userId).get();
      if (!snap.exists || snap.data() == null) return null;
      return AuthUser.fromFirestore(snap.id, snap.data()!);
    } catch (e) {
      debugPrint('getUserById error: $e');
      return null;
    }
  }

  // ── Internal helpers ────────────────────────────────────────────────────

  /// Loads the user profile from Firestore and starts listening for changes.
  Future<void> _loadUser(String uid) async {
    _userSub?.cancel();
    _userSub = _db.collection('users').doc(uid).snapshots().listen((snap) {
      if (snap.exists && snap.data() != null) {
        currentUser.value = AuthUser.fromFirestore(snap.id, snap.data()!);
      } else {
        currentUser.value = null;
      }
    });
    // Wait for the first value to be loaded
    final snap = await _db.collection('users').doc(uid).get();
    if (snap.exists && snap.data() != null) {
      currentUser.value = AuthUser.fromFirestore(snap.id, snap.data()!);
    }
  }
}
