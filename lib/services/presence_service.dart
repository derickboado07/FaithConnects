import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

/// Service for managing user presence (online/offline), last-active timestamps,
/// and user notes (short status messages).
class PresenceService {
  PresenceService._internal();
  static final PresenceService instance = PresenceService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;

  // ── User Note ──────────────────────────────────────────────────────────

  /// Update the current user's note (short status message).
  /// [note] is capped at 100 characters. Notes expire after 24 hours.
  Future<void> setNote(String note) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final trimmed = note.length > 100 ? note.substring(0, 100) : note;
    await _db.collection('users').doc(uid).set({
      'note': trimmed,
      'noteSetAt': trimmed.isEmpty ? '' : DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  /// Returns true if the note is still within the 24-hour window.
  static bool isNoteActive(String? noteSetAt) {
    if (noteSetAt == null || noteSetAt.isEmpty) return false;
    try {
      final setAt = DateTime.parse(noteSetAt);
      return DateTime.now().difference(setAt).inHours < 24;
    } catch (_) {
      return false;
    }
  }

  /// Stream the current user's note.
  Stream<String> noteStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      return (data != null && data['note'] is String) ? data['note'] : '';
    });
  }

  // ── User Status (online / lastActive) ─────────────────────────────────

  /// Stream a single user's presence data as a map containing
  /// `isOnline` (bool) and `lastActive` (String ISO).
  Stream<Map<String, dynamic>> userStatusStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      return {
        'isOnline': data?['isOnline'] == true,
        'lastActive': data?['lastActive'] ?? '',
        'note': data?['note'] ?? '',
        'name': data?['name'] ?? '',
        'avatar': data?['avatar'] ?? '',
      };
    });
  }

  /// Format a "last seen" string from an ISO 8601 timestamp.
  static String formatLastSeen(String isoTimestamp) {
    if (isoTimestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoTimestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Active just now';
      if (diff.inMinutes < 60) {
        final m = diff.inMinutes;
        return 'Last seen $m ${m == 1 ? 'minute' : 'minutes'} ago';
      }
      if (diff.inHours < 24) {
        final h = diff.inHours;
        return 'Last seen $h ${h == 1 ? 'hour' : 'hours'} ago';
      }
      final d = diff.inDays;
      if (d == 1) return 'Last seen yesterday';
      return 'Last seen $d days ago';
    } catch (_) {
      return '';
    }
  }

  // ── Faith-based note suggestions ──────────────────────────────────────

  static const List<String> faithNoteSuggestions = [
    'God is good ❤️',
    'Pray for my exams 🙏',
    'Blessed and grateful 🙌',
    'Walking by faith ✨',
    'Trust in the Lord 📖',
    'Joy of the Lord is my strength 💪',
    'Be still, and know that I am God 🕊️',
    'Love one another ❤️',
    'Faith over fear 🙏',
    'In His presence always ✝️',
  ];
}
