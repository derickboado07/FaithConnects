import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart';

/// Represents a single "My Day" story entry (image or short video).
class MyDayItem {
  final String id;
  final String uid;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String caption;
  final String createdAt; // ISO 8601
  final String expiresAt; // ISO 8601 (24h after creation)

  MyDayItem({
    required this.id,
    required this.uid,
    required this.mediaUrl,
    required this.mediaType,
    this.caption = '',
    required this.createdAt,
    required this.expiresAt,
  });

  factory MyDayItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MyDayItem(
      id: doc.id,
      uid: d['uid'] ?? '',
      mediaUrl: d['mediaUrl'] ?? '',
      mediaType: d['mediaType'] ?? 'image',
      caption: d['caption'] ?? '',
      createdAt: d['createdAt'] ?? '',
      expiresAt: d['expiresAt'] ?? '',
    );
  }

  bool get isExpired {
    try {
      return DateTime.now().isAfter(DateTime.parse(expiresAt));
    } catch (_) {
      return true;
    }
  }
}

/// Service for uploading, deleting, and streaming My Day stories.
///
/// Firestore structure:
///   my_day/{docId}
///     uid: string
///     mediaUrl: string
///     mediaType: 'image' | 'video'
///     caption: string
///     createdAt: ISO string
///     expiresAt: ISO string (24h later)
class MyDayService {
  MyDayService._internal();
  static final MyDayService instance = MyDayService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String get _myUid => _auth.currentUser?.uid ?? '';

  /// Upload a My Day entry (image or video bytes).
  /// [mediaType] should be 'image' or 'video'.
  /// Videos must be <= 15 seconds (enforced by the caller).
  Future<void> uploadMyDay({
    required Uint8List bytes,
    required String filename,
    required String mediaType,
    String caption = '',
  }) async {
    final uid = _myUid;
    if (uid.isEmpty) throw Exception('Not signed in');

    final now = DateTime.now();
    final ts = now.millisecondsSinceEpoch;
    final storagePath = 'my_day/$uid/${ts}_$filename';

    // Determine content type
    String contentType = 'image/jpeg';
    final ext = filename.split('.').last.toLowerCase();
    if (mediaType == 'video') {
      contentType = ext == 'webm' ? 'video/webm' : 'video/mp4';
    } else {
      if (ext == 'png') contentType = 'image/png';
      if (ext == 'gif') contentType = 'image/gif';
      if (ext == 'webp') contentType = 'image/webp';
    }

    final upload = await _storage
        .ref()
        .child(storagePath)
        .putData(bytes, SettableMetadata(contentType: contentType));
    final url = await upload.ref.getDownloadURL();

    final createdAt = now.toIso8601String();
    final expiresAt = now.add(const Duration(hours: 24)).toIso8601String();

    await _db.collection('my_day').add({
      'uid': uid,
      'mediaUrl': url,
      'mediaType': mediaType,
      'caption': caption,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
    });
  }

  /// Stream all non-expired My Day entries for a specific user.
  Stream<List<MyDayItem>> userMyDayStream(String uid) {
    return _db
        .collection('my_day')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final items = snap.docs
              .map((d) => MyDayItem.fromDoc(d))
              .where((item) => !item.isExpired)
              .toList();
          // Sort client-side (newest first) to avoid requiring composite index
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  /// Stream all non-expired My Day entries across a list of user IDs.
  /// Returns a map: { uid: [MyDayItem, ...] }.
  Stream<Map<String, List<MyDayItem>>> myDayStreamForUsers(List<String> uids) {
    if (uids.isEmpty) return Stream.value({});
    // Firestore 'in' queries limited to 30 items
    final batch = uids.length > 30 ? uids.sublist(0, 30) : uids;
    return _db
        .collection('my_day')
        .where('uid', whereIn: batch)
        .snapshots()
        .map((snap) {
          final map = <String, List<MyDayItem>>{};
          for (final doc in snap.docs) {
            final item = MyDayItem.fromDoc(doc);
            if (!item.isExpired) {
              map.putIfAbsent(item.uid, () => []).add(item);
            }
          }
          // Sort each user's items client-side (newest first)
          for (final list in map.values) {
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }
          return map;
        });
  }

  /// Delete a My Day entry.
  Future<void> deleteMyDay(String docId) async {
    await _db.collection('my_day').doc(docId).delete();
  }
}
