import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

/// Handles media uploads for chat (images) to Firebase Storage.
class MediaUploadService {
  MediaUploadService._();
  static final MediaUploadService instance = MediaUploadService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;

  /// Uploads an image to Firebase Storage under chat_images/{convoId}/.
  /// Returns the download URL on success.
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
