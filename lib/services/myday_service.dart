// ─────────────────────────────────────────────────────────────────────────────
// MY DAY SERVICE — Ang service na ito ang nag-ha-handle ng
// "My Day" stories feature (parang Facebook/Instagram stories).
// Mga responsibilidad:
//   • Pag-upload ng story images o videos sa Firebase Storage
//   • Pag-create ng story documents sa Firestore
//   • Real-time streaming ng stories (per user at across users)
//   • Pag-delete ng stories
//   • Auto-expiry (24 hours) ng stories
//
// Firestore collection: my_day/{docId}
// Firebase Storage path: my_day/{uid}/{timestamp}_{filename}
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart';

/// Nagre-represent ng isang "My Day" story entry (image o short video).
/// May 24-hour expiry — pagkatapos ng 24 oras, ita-treat na bilang expired.
class MyDayItem {
  final String id;            // Unique ID ng story
  final String uid;           // UID ng nag-post ng story
  final String mediaUrl;      // Download URL ng media (image/video)
  final String mediaType;     // 'image' o 'video'
  final String caption;       // Optional caption ng story
  final String createdAt;     // Kailan ginawa (ISO 8601)
  final String expiresAt;     // Kailan mag-e-expire (ISO 8601, 24h after creation)

  MyDayItem({
    required this.id,
    required this.uid,
    required this.mediaUrl,
    required this.mediaType,
    this.caption = '',
    required this.createdAt,
    required this.expiresAt,
  });

  /// Ginagawa ang MyDayItem object mula sa Firestore DocumentSnapshot.
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

  /// Chine-check kung expired na ba ang story (lagpas na sa 24 hours).
  bool get isExpired {
    try {
      return DateTime.now().isAfter(DateTime.parse(expiresAt));
    } catch (_) {
      return true;
    }
  }
}

/// Service para sa pag-upload, pag-delete, at pag-stream ng My Day stories.
///
/// Firestore structure:
///   my_day/{docId}
///     uid: string            — Sino ang nag-post
///     mediaUrl: string       — Download URL ng media
///     mediaType: 'image' | 'video'
///     caption: string        — Optional caption
///     createdAt: ISO string  — Kailan ginawa
///     expiresAt: ISO string  — Kailan mag-e-expire (24h later)
class MyDayService {
  // Private constructor at singleton instance.
  MyDayService._internal();
  static final MyDayService instance = MyDayService._internal();

  // Firebase instances.
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Kinukuha ang UID ng kasalukuyang naka-login na user.
  String get _myUid => _auth.currentUser?.uid ?? '';

  /// Nag-a-upload ng My Day entry (image o video bytes).
  /// [mediaType] ay dapat 'image' o 'video'.
  /// Ang videos ay kailangang <= 15 seconds (ine-enforce ng caller).
  /// Pagkatapos ma-upload ang media, gagawa ng Firestore document
  /// na may 24-hour expiry.
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

  /// Real-time stream ng lahat ng non-expired My Day entries ng specific user.
  /// Naka-sort by createdAt (pinakabago muna).
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

  /// Real-time stream ng lahat ng non-expired My Day entries ng multiple users.
  /// Returns isang map: { uid: [MyDayItem, ...] }.
  /// Limitado sa 30 users ang Firestore 'in' query.
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

  /// Dine-delete ang isang My Day entry mula sa Firestore.
  Future<void> deleteMyDay(String docId) async {
    await _db.collection('my_day').doc(docId).delete();
  }
}
