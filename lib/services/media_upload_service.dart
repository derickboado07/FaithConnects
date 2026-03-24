// ─────────────────────────────────────────────────────────────────────────────
// MEDIA UPLOAD SERVICE — Ang service na ito ang nag-ha-handle ng
// pag-upload ng images para sa chat messages. Ina-upload ang files
// sa Firebase Storage at nire-return ang download URL.
//
// Firebase Storage path: chat_images/{convoId}/{timestamp}_{filename}
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

/// Nag-ha-handle ng media uploads para sa chat (images) sa Firebase Storage.
/// Singleton pattern — isang instance lang sa buong app.
class MediaUploadService {
  MediaUploadService._();
  static final MediaUploadService instance = MediaUploadService._();

  // Firebase Storage at Auth instances.
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;

  /// Nag-a-upload ng image sa Firebase Storage sa ilalim ng
  /// chat_images/{convoId}/ folder.
  /// Nire-return ang download URL kapag successful.
  /// Ang content type ay awtomatikong dine-determine base sa file extension.
  Future<String> uploadChatImage({
    required String convoId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'chat_images/$convoId/${timestamp}_$filename';

    // Determine content type from extension
    String contentType = 'image/jpeg';
    final ext = filename.split('.').last.toLowerCase();
    if (ext == 'png') {
      contentType = 'image/png';
    } else if (ext == 'gif') {
      contentType = 'image/gif';
    } else if (ext == 'webp') {
      contentType = 'image/webp';
    }

    final ref = _storage.ref().child(storagePath);
    final upload = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return await upload.ref.getDownloadURL();
  }
}
