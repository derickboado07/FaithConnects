// ─────────────────────────────────────────────────────────────────────────────
// PRESENCE SERVICE — Nag-ma-manage ng user presence (online/offline status),
// last-active timestamps, at user notes (short status messages tulad ng
// "God is good ❤️"). Ginagamit para makita ng ibang users kung online ka
// o kailan ka huling nag-online.
//
// Firestore: users/{uid}.isOnline, users/{uid}.lastActive, users/{uid}.note
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

/// Singleton service para sa user presence at status notes.
class PresenceService {
  PresenceService._internal(); // Private constructor para sa Singleton
  static final PresenceService instance = PresenceService._internal(); // Global instance

  final FirebaseFirestore _db = FirebaseFirestore.instance;              // Firestore ref
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;     // Auth ref

  // ── User Note ──────────────────────────────────────────────────────────
  // Ang "note" ay isang short status message na sine-set ng user.
  // Nag-e-expire ito after 24 hours.

  /// I-update ang note ng current user.
  /// Naka-cap sa 100 characters. Nag-e-expire after 24 hours.
  Future<void> setNote(String note) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final trimmed = note.length > 100 ? note.substring(0, 100) : note;
    await _db.collection('users').doc(uid).set({
      'note': trimmed,
      'noteSetAt': trimmed.isEmpty ? '' : DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  /// Nagre-return ng true kung ang note ay nasa loob pa ng 24-hour window.
  static bool isNoteActive(String? noteSetAt) {
    if (noteSetAt == null || noteSetAt.isEmpty) return false;
    try {
      final setAt = DateTime.parse(noteSetAt);
      return DateTime.now().difference(setAt).inHours < 24;
    } catch (_) {
      return false;
    }
  }

  /// Stream ng note ng current user — real-time updates kapag nagbago.
  Stream<String> noteStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      return (data != null && data['note'] is String) ? data['note'] : '';
    });
  }

  // ── User Status (online / lastActive) ─────────────────────────────────
  // Nag-sstream ng user presence data (isOnline, lastActive, note, etc.)

  /// Stream ng presence data ng isang user.
  /// Nag-re-return ng map na may: isOnline, lastActive, note, name, avatar.
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

  /// Nag-fo-format ng "last seen" string mula sa ISO 8601 timestamp.
  /// Halimbawa: "Active just now", "Last seen 5 minutes ago", "Last seen yesterday".
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

  // ── Faith-based note suggestions ──────────────────────────────────────  // Mga suggested notes na pwedeng piliin ng user — lahat faith-related.
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
