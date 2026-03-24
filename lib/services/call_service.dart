// ─────────────────────────────────────────────────────────────────────────────
// CALL SERVICE — Ang service na ito ang nag-ha-handle ng voice at video
// call signaling gamit ang Firestore. Mga responsibilidad:
//   • Pag-create ng call documents (para i-start ang call)
//   • Pag-accept ng incoming calls
//   • Pag-end/reject ng calls
//   • Pag-listen sa call status changes (ringing → accepted → ended)
//   • Pag-detect ng incoming calls
//   • Pag-send ng missed call messages
//
// Firestore collection: calls/{callId}
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

/// Firestore-based call signaling service.
/// Gumagawa ng call documents para sa voice/video calls at nakikinig
/// sa status changes (ringing, accepted, ended).
class CallService {
  // Singleton pattern — private constructor at isang instance lang.
  CallService._();
  static final CallService instance = CallService._();

  // Firestore at Auth instances para sa database operations at user identification.
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;

  // Kinukuha ang UID ng kasalukuyang naka-login na user.
  String get _myUid => _auth.currentUser?.uid ?? '';

  /// Nag-i-initiate ng call. Gumagawa ng call document sa Firestore
  /// na may status na 'ringing'. Returns ang call document ID.
  Future<String> startCall({
    required List<String> participants,
    required String type, // 'voice' or 'video'
    required String convoId,
  }) async {
    final uid = _myUid;
    if (uid.isEmpty) throw Exception('Not signed in');

    final callRef = _db.collection('calls').doc();
    await callRef.set({
      'callId': callRef.id,
      'callerId': uid,
      'participants': participants,
      'type': type,
      'status': 'ringing',
      'convoId': convoId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return callRef.id;
  }

  /// Ina-accept ang incoming call — ini-update ang status sa 'accepted'.
  Future<void> acceptCall(String callId) async {
    await _db.collection('calls').doc(callId).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Ini-end o ni-reject ang call — ini-update ang status sa 'ended'.
  Future<void> endCall(String callId) async {
    await _db.collection('calls').doc(callId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Real-time stream ng call document changes.
  /// Ginagamit para ma-track ang status (ringing → accepted → ended).
  Stream<DocumentSnapshot> callStream(String callId) {
    return _db.collection('calls').doc(callId).snapshots();
  }

  /// Nakikinig sa mga incoming calls kung saan kasama ang current user
  /// bilang participant at 'ringing' pa ang status.
  Stream<QuerySnapshot> incomingCallsStream() {
    final uid = _myUid;
    if (uid.isEmpty) return const Stream.empty();
    return _db
        .collection('calls')
        .where('participants', arrayContains: uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots();
  }

  /// Nagse-send ng missed call system message sa conversation.
  /// Ginagamit kapag hindi sinagot ang call.
  Future<void> sendMissedCallMessage({
    required String convoId,
    required String type,
  }) async {
    final uid = _myUid;
    if (uid.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    final emoji = type == 'video' ? '📹' : '📞';
    await _db
        .collection('conversations')
        .doc(convoId)
        .collection('messages')
        .add({
          'senderId': 'system',
          'senderName': '',
          'text': 'Missed $type call $emoji',
          'ts': now,
          'isSystemMessage': true,
        });
  }
}
