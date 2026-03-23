import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

/// Firestore-based call signaling service.
/// Creates call documents for voice/video calls and listens for status changes.
class CallService {
  CallService._();
  static final CallService instance = CallService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;

  String get _myUid => _auth.currentUser?.uid ?? '';

  /// Initiates a call. Returns the call document ID.
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

  /// Accept an incoming call.
  Future<void> acceptCall(String callId) async {
    await _db.collection('calls').doc(callId).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  /// End / reject a call.
  Future<void> endCall(String callId) async {
    await _db.collection('calls').doc(callId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream call document changes (for ringing → accepted → ended).
  Stream<DocumentSnapshot> callStream(String callId) {
    return _db.collection('calls').doc(callId).snapshots();
  }

  /// Listen for incoming calls where the current user is a participant.
  Stream<QuerySnapshot> incomingCallsStream() {
    final uid = _myUid;
    if (uid.isEmpty) return const Stream.empty();
    return _db
        .collection('calls')
        .where('participants', arrayContains: uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots();
  }

  /// Send a missed call system message into the conversation.
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
