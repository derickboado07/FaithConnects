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
  });

  AuthUser copyWith({
    String? name,
    String? bio,
    String? phone,
    String? gender,
    String? dob,
    String? avatarUrl,
    String? bannerUrl,
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
  );
}

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final ValueNotifier<AuthUser?> currentUser = ValueNotifier<AuthUser?>(null);

  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> init() async {
    // Listen to auth state and load Firestore user
    _auth.authStateChanges().listen((fbUser) async {
      if (fbUser == null) {
        currentUser.value = null;
        return;
      }
      final doc = await _db.collection('users').doc(fbUser.uid).get();
      if (doc.exists) {
        currentUser.value = AuthUser.fromJson(doc.data()!);
      } else {
        // Create minimal user doc if missing
        final u = AuthUser(
          id: fbUser.uid,
          email: fbUser.email ?? '',
          name: fbUser.displayName ?? '',
        );
        await _db.collection('users').doc(fbUser.uid).set(u.toJson());
        currentUser.value = u;
      }
    });
    // If already signed in, trigger loading
    final cur = _auth.currentUser;
    if (cur != null) {
      final doc = await _db.collection('users').doc(cur.uid).get();
      if (doc.exists) currentUser.value = AuthUser.fromJson(doc.data()!);
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
        currentUser.value = AuthUser.fromJson(doc.data()!);
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
    await _auth.signOut();
    currentUser.value = null;
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
      final docRef = _db
          .collection('users')
          .doc(cur.uid)
          .collection('following')
          .doc(targetUid);
      final snap = await docRef.get();
      if (snap.exists) {
        await docRef.delete();
        return false;
      } else {
        await docRef.set({'since': DateTime.now().toIso8601String()});
        return true;
      }
    } catch (_) {
      return false;
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
      final docRef = _db
          .collection('users')
          .doc(cur.uid)
          .collection('following')
          .doc(targetUid);
      final snap = await docRef.get();
      return snap.exists;
    } catch (_) {
      return false;
    }
  }
}
