import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AuthUser {
  final String id;
  final String email;
  final String name;
  final String bio;
  final String phone;
  final String gender;
  final String? dob; // ISO date string (YYYY-MM-DD)
  final String avatarUrl;
  final String bannerUrl;
  final String role; // 'user' | 'moderator'
  final String status; // 'active' | 'banned'
  final bool canPost;

  AuthUser({
    required this.id,
    required this.email,
    required this.name,
    this.bio = '',
    this.phone = '',
    this.gender = '',
    this.dob,
    this.avatarUrl = '',
    this.bannerUrl = '',
    this.role = 'user',
    this.status = 'active',
    this.canPost = true,
  });

  bool get isModerator => role == 'moderator';
  bool get isBanned => status == 'banned';

  AuthUser copyWith({
    String? name,
    String? bio,
    String? phone,
    String? gender,
    String? dob,
    String? avatarUrl,
    String? bannerUrl,
    String? role,
    String? status,
    bool? canPost,
  }) {
    return AuthUser(
      id: id,
      email: email,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      role: role ?? this.role,
      status: status ?? this.status,
      canPost: canPost ?? this.canPost,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'bio': bio,
    'phone': phone,
    'gender': gender,
    'dob': dob,
    'avatar': avatarUrl,
    'banner': bannerUrl,
    // role is NOT written here — moderator role is set manually in Firestore
    'status': status,
    'canPost': canPost,
  };

  static AuthUser fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['id'] ?? '',
    email: j['email'] ?? '',
    name: j['name'] ?? '',
    bio: j['bio'] ?? '',
    phone: j['phone'] ?? '',
    gender: j['gender'] ?? '',
    dob: j['dob'],
    avatarUrl: j['avatar'] ?? '',
    bannerUrl: j['banner'] ?? '',
    role: j['role'] as String? ?? 'user',
    status: j['status'] as String? ?? 'active',
    canPost: j['canPost'] as bool? ?? true,
  );
}

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final ValueNotifier<AuthUser?> currentUser = ValueNotifier<AuthUser?>(null);

  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  Future<void> _bindCurrentUserDoc(String uid) async {
    await _userDocSub?.cancel();
    _userDocSub = _db.collection('users').doc(uid).snapshots().listen((doc) async {
      if (!doc.exists) {
        currentUser.value = null;
        await _auth.signOut();
        return;
      }

      final loadedUser = AuthUser.fromJson(doc.data()!);
      if (loadedUser.isBanned) {
        currentUser.value = null;
        await _auth.signOut();
        return;
      }

      currentUser.value = loadedUser;
    });
  }

  Future<void> init() async {
    // Listen to auth state and load Firestore user
    _auth.authStateChanges().listen((fbUser) async {
      if (fbUser == null) {
        await _userDocSub?.cancel();
        _userDocSub = null;
        currentUser.value = null;
        return;
      }
      final doc = await _db.collection('users').doc(fbUser.uid).get();
      if (doc.exists) {
        final loadedUser = AuthUser.fromJson(doc.data()!);
        if (loadedUser.isBanned) {
          currentUser.value = null;
          await _auth.signOut();
          return;
        }
        currentUser.value = loadedUser;
        await _bindCurrentUserDoc(fbUser.uid);
      } else {
        // Create minimal user doc if missing
        final u = AuthUser(
          id: fbUser.uid,
          email: fbUser.email ?? '',
          name: fbUser.displayName ?? '',
        );
        await _db.collection('users').doc(fbUser.uid).set(u.toJson());
        currentUser.value = u;
        await _bindCurrentUserDoc(fbUser.uid);
      }
    });
    // If already signed in, trigger loading
    final cur = _auth.currentUser;
    if (cur != null) {
      final doc = await _db.collection('users').doc(cur.uid).get();
      if (doc.exists) {
        final loadedUser = AuthUser.fromJson(doc.data()!);
        if (loadedUser.isBanned) {
          currentUser.value = null;
          await _auth.signOut();
        } else {
          currentUser.value = loadedUser;
          await _bindCurrentUserDoc(cur.uid);
        }
      }
    }
    // mark active if already signed in
    if (_auth.currentUser != null) {
      try {
        await setPresence(true);
        await updateLastActive();
      } catch (_) {}
    }
  }

  // Returns `null` on success, or an error message on failure.
  Future<String?> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String gender,
    String? dob,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;
      final userDoc = AuthUser(
        id: uid,
        email: email,
        name: name,
        phone: phone,
        gender: gender,
        dob: dob,
      );
      try {
        await _db.collection('users').doc(uid).set(userDoc.toJson());
        currentUser.value = userDoc;
        return null;
      } on FirebaseException catch (fe) {
        // If Firestore write failed (e.g. permission-denied), roll back the
        // created Authentication user to avoid leaving a dangling auth-only
        // account.
        try {
          await cred.user?.delete();
        } catch (_) {
          // ignore failures when deleting the user
        }
        final code = fe.code;
        if (code == 'permission-denied' ||
            (fe.message != null &&
                fe.message!.toLowerCase().contains('permission'))) {
          final msg =
              '[permission-denied] Missing or insufficient permissions.\n'
              'Ensure Firestore rules allow authenticated users to create their own /users/{uid} document.\n'
              'See Firebase Console → Firestore → Rules.';
          debugPrint('AuthService.register FirestoreException: $msg');
          return msg;
        }
        final msg = fe.message ?? fe.toString();
        debugPrint('AuthService.register FirestoreException: $msg');
        return msg;
      }
    } on fb_auth.FirebaseAuthException catch (e, st) {
      final code = e.code;
      String friendly;
      if (code == 'configuration-not-found' ||
          (e.message != null &&
              e.message!.toLowerCase().contains('configuration'))) {
        friendly =
            'Firebase Authentication is not enabled.\n\n'
            'Please enable it in Firebase Console:\n'
            '1. Visit https://console.firebase.google.com/\n'
            '2. Select project: faith-connects-c7a7e\n'
            '3. Go to Authentication → Get Started\n'
            '4. Enable Email/Password sign-in method\n'
            '5. Rebuild and run this app';
      } else if (code == 'email-already-in-use') {
        friendly = 'The email address is already in use.';
      } else if (code == 'invalid-email') {
        friendly = 'The email address is invalid.';
      } else if (code == 'weak-password') {
        friendly = 'The password is too weak. Use at least 6 characters.';
      } else {
        friendly = e.message ?? 'Registration failed.';
      }
      final msg = '[${code}] $friendly';
      debugPrint('AuthService.register FirebaseAuthException: $msg');
      debugPrintStack(label: 'AuthService.register stack', stackTrace: st);
      return msg;
    } catch (e, st) {
      final msg = e.toString();
      debugPrint('AuthService.register unexpected error: $msg');
      debugPrintStack(label: 'AuthService.register stack', stackTrace: st);
      return msg;
    }
  }

  // Returns null on success, or an error message string on failure.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final loadedUser = AuthUser.fromJson(doc.data()!);
        if (loadedUser.isBanned) {
          await _auth.signOut();
          currentUser.value = null;
          return 'This account has been banned.';
        }
        currentUser.value = loadedUser;
      } else {
        // User exists in Auth but not in Firestore — create the doc.
        final u = AuthUser(
          id: uid,
          email: email,
          name: cred.user?.displayName ?? '',
        );
        try {
          await _db.collection('users').doc(uid).set(u.toJson());
        } catch (_) {}
        currentUser.value = u;
      }
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found for that email.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect password. Please try again.';
        case 'invalid-email':
          return 'The email address is invalid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please try again later.';
        default:
          return e.message ?? 'Login failed.';
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    try {
      await setPresence(false);
    } catch (_) {}
    await _userDocSub?.cancel();
    _userDocSub = null;
    await _auth.signOut();
    currentUser.value = null;
  }

  /// Marks the current user as online/offline in their /users/{uid} document.
  Future<void> setPresence(bool online) async {
    final cur = _auth.currentUser;
    if (cur == null) return;
    try {
      await _db.collection('users').doc(cur.uid).set({
        'isOnline': online,
        'lastActive': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('setPresence failed: $e');
    }
  }

  /// Update the user's lastActive timestamp without changing isOnline flag.
  Future<void> updateLastActive() async {
    final cur = _auth.currentUser;
    if (cur == null) return;
    try {
      await _db.collection('users').doc(cur.uid).set({
        'lastActive': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('updateLastActive failed: $e');
    }
  }

  Future<String?> _uploadAvatar(String uid, String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;
      final ref = _storage.ref().child('avatars').child('$uid.jpg');
      final task = await ref.putFile(file);
      final url = await task.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('AuthService: avatar upload failed: $e');
      return null;
    }
  }

  Future<String?> _uploadBanner(String uid, String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;
      final ref = _storage.ref().child('banners').child('$uid.jpg');
      final task = await ref.putFile(file);
      final url = await task.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('AuthService: banner upload failed: $e');
      return null;
    }
  }

  String _mimeFromFilename(String filename) {
    final ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : '';
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  Future<String?> _uploadImageBytes(
    String storagePath,
    Uint8List bytes,
    String filename,
  ) async {
    try {
      final mime = _mimeFromFilename(filename);
      final ref = _storage.ref().child(storagePath);
      final task = await ref.putData(
        bytes,
        SettableMetadata(contentType: mime),
      );
      return await task.ref.getDownloadURL();
    } catch (e) {
      debugPrint('AuthService: image bytes upload failed: $e');
      return null;
    }
  }

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
      // find user doc by email (emails are unique in FirebaseAuth)
      final q = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return false;
      final doc = q.docs.first;
      final uid = doc.id;

      String? avatarUrl = doc.data()['avatar'];
      if (avatarBytes != null && avatarFilename != null) {
        // Web: upload raw bytes directly to Firebase Storage
        final uploaded = await _uploadImageBytes(
          'avatars/$uid/${avatarFilename}',
          avatarBytes,
          avatarFilename,
        );
        if (uploaded != null) avatarUrl = uploaded;
      } else if (avatarPath != null && avatarPath.isNotEmpty) {
        if (avatarPath.startsWith('/') ||
            avatarPath.contains(':\\') ||
            avatarPath.startsWith('file://')) {
          final uploaded = await _uploadAvatar(
            uid,
            avatarPath.replaceFirst('file://', ''),
          );
          if (uploaded != null) avatarUrl = uploaded;
        }
        // Blob URLs and unrecognised paths are ignored — they are not permanent.
      }

      String? bannerUrl = doc.data()['banner'];
      if (bannerBytes != null && bannerFilename != null) {
        final uploaded = await _uploadImageBytes(
          'banners/$uid/${bannerFilename}',
          bannerBytes,
          bannerFilename,
        );
        if (uploaded != null) bannerUrl = uploaded;
      } else if (bannerPath != null && bannerPath.isNotEmpty) {
        if (bannerPath.startsWith('/') ||
            bannerPath.contains(':\\') ||
            bannerPath.startsWith('file://')) {
          final uploaded = await _uploadBanner(
            uid,
            bannerPath.replaceFirst('file://', ''),
          );
          if (uploaded != null) bannerUrl = uploaded;
        }
        // Blob URLs are ignored.
      }

      final updateMap = <String, dynamic>{};
      if (name != null) updateMap['name'] = name;
      if (bio != null) updateMap['bio'] = bio;
      if (phone != null) updateMap['phone'] = phone;
      if (gender != null) updateMap['gender'] = gender;
      if (dob != null) updateMap['dob'] = dob;
      if (avatarUrl != null) updateMap['avatar'] = avatarUrl;
      if (bannerUrl != null) updateMap['banner'] = bannerUrl;
      if (updateMap.isNotEmpty) {
        await _db.collection('users').doc(uid).update(updateMap);
      }
      final updatedDoc = await _db.collection('users').doc(uid).get();
      currentUser.value = AuthUser.fromJson(updatedDoc.data()!);
      return true;
    } catch (e) {
      debugPrint('AuthService.updateProfile error: $e');
      return false;
    }
  }

  Future<bool> toggleFollow(String email) async {
    try {
      final cur = _auth.currentUser;
      if (cur == null) return false;
      final q = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return false;
      final targetUid = q.docs.first.id;
      return await toggleFollowById(targetUid);
    } catch (_) {
      return false;
    }
  }

  /// Toggle follow/unfollow by UID. Maintains both `following` and `followers`
  /// subcollections for real-time count streaming.
  Future<bool> toggleFollowById(String targetUid) async {
    try {
      final cur = _auth.currentUser;
      if (cur == null) return false;
      final myFollowingRef = _db
          .collection('users')
          .doc(cur.uid)
          .collection('following')
          .doc(targetUid);
      final theirFollowersRef = _db
          .collection('users')
          .doc(targetUid)
          .collection('followers')
          .doc(cur.uid);
      final snap = await myFollowingRef.get();
      if (snap.exists) {
        final batch = _db.batch();
        batch.delete(myFollowingRef);
        batch.delete(theirFollowersRef);
        await batch.commit();
        return false; // now unfollowed
      } else {
        final since = {'since': DateTime.now().toIso8601String()};
        final batch = _db.batch();
        batch.set(myFollowingRef, since);
        batch.set(theirFollowersRef, since);
        await batch.commit();
        return true; // now following
      }
    } catch (_) {
      return false;
    }
  }

  /// Check if the current user follows [targetUid].
  Future<bool> isFollowingById(String targetUid) async {
    try {
      final cur = _auth.currentUser;
      if (cur == null) return false;
      final snap = await _db
          .collection('users')
          .doc(cur.uid)
          .collection('following')
          .doc(targetUid)
          .get();
      return snap.exists;
    } catch (_) {
      return false;
    }
  }

  /// Real-time stream of how many people follow [uid].
  Stream<int> streamFollowersCount(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('followers')
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// Real-time stream of how many people [uid] is following.
  Stream<int> streamFollowingCount(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// Real-time stream of a user document.
  Stream<AuthUser?> streamUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AuthUser.fromJson(snap.data()!);
    });
  }

  /// Fetch a user document by UID.
  Future<AuthUser?> getUserById(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return AuthUser.fromJson(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  /// Search users by display name (case-insensitive prefix match).
  /// Returns up to [limit] results.
  Future<List<AuthUser>> searchUsers(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    try {
      final lower = query.trim().toLowerCase();
      // Firestore doesn't support full-text search; fetch a reasonable batch
      // and filter client-side by lowercased name or email.
      final snap = await _db.collection('users').limit(200).get();
      final cur = _auth.currentUser;
      final results = snap.docs
          .map((d) => AuthUser.fromJson(d.data()))
          .where(
            (u) =>
                u.id != (cur?.uid ?? '') &&
                (u.name.toLowerCase().contains(lower) ||
                    u.email.toLowerCase().contains(lower)),
          )
          .take(limit)
          .toList();
      return results;
    } catch (_) {
      return [];
    }
  }

  Future<bool> isFollowing(String email) async {
    try {
      final cur = _auth.currentUser;
      if (cur == null) return false;
      final q = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return false;
      final targetUid = q.docs.first.id;
      return await isFollowingById(targetUid);
    } catch (_) {
      return false;
    }
  }
}
