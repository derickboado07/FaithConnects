import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class Conversation {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final String? lastSenderId;
  final String updatedAt;
  final Map<String, String> lastRead;

  Conversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastSenderId,
    required this.updatedAt,
    Map<String, String>? lastRead,
  }) : lastRead = lastRead ?? {};

  factory Conversation.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final lr = <String, String>{};
    if (d['lastRead'] is Map<String, dynamic>) {
      (d['lastRead'] as Map<String, dynamic>).forEach((k, v) {
        lr[k] = v?.toString() ?? '';
      });
    }
    return Conversation(
      id: doc.id,
      participants: List<String>.from(d['participants'] ?? []),
      lastMessage: d['lastMessage'],
      lastSenderId: d['lastSenderId'],
      updatedAt: d['updatedAt'] ?? '',
      lastRead: lr,
    );
  }
}

class MessageItem {
  final String id;
  final String senderId;
  final String text;
  final String ts;
  final String? imageUrl;
  final Map<String, List<String>> reactions;

  MessageItem({
    required this.id,
    required this.senderId,
    required this.text,
    required this.ts,
    this.imageUrl,
    Map<String, List<String>>? reactions,
  }) : reactions = reactions ?? {};

  factory MessageItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MessageItem(
      id: doc.id,
      senderId: d['senderId'] ?? '',
      text: d['text'] ?? '',
      ts: d['ts'] ?? '',
      imageUrl: d['imageUrl'],
      reactions: d['reactions'] is Map<String, dynamic>
          ? (d['reactions'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(
                k,
                v is List
                    ? List<String>.from(v.map((e) => e.toString()))
                    : <String>[],
              ),
            )
          : {},
    );
  }
}

class MessageService {
  MessageService._internal();
  static final MessageService instance = MessageService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String get _myUid => _auth.currentUser?.uid ?? '';

  String _convoId(String a, String b) {
    final parts = [a, b]..sort();
    return parts.join('_');
  }

  Stream<List<Conversation>> conversationsStreamForCurrentUser() {
    final uid = _myUid;
    if (uid.isEmpty) return Stream.value([]);
    return _db
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => Conversation.fromDoc(d)).toList();
          list.sort((a, b) {
            try {
              final da = DateTime.parse(a.updatedAt);
              final db = DateTime.parse(b.updatedAt);
              return db.compareTo(da);
            } catch (_) {
              return b.updatedAt.compareTo(a.updatedAt);
            }
          });
          return list;
        });
  }

  Stream<List<MessageItem>> messagesStream(String convoId) {
    return _db
        .collection('conversations')
        .doc(convoId)
        .collection('messages')
        .orderBy('ts', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MessageItem.fromDoc(d)).toList());
  }

  Future<String> ensureConversationWith(String otherUid) async {
    final uid = _myUid;
    if (uid.isEmpty) throw Exception('Not signed in');
    final id = _convoId(uid, otherUid);
    final docRef = _db.collection('conversations').doc(id);
    await docRef.set({
      'participants': [uid, otherUid],
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    return id;
  }

  Future<void> markConversationRead(String convoId) async {
    final uid = _myUid;
    if (uid.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await _db.collection('conversations').doc(convoId).set({
      'lastRead': {uid: now},
    }, SetOptions(merge: true));
  }

  Future<void> sendMessage(String convoId, String text) async {
    final uid = _myUid;
    if (uid.isEmpty) throw Exception('Not signed in');
    final messagesRef = _db
        .collection('conversations')
        .doc(convoId)
        .collection('messages');
    final now = DateTime.now().toIso8601String();
    try {
      await messagesRef.add({'senderId': uid, 'text': text, 'ts': now});
    } catch (e) {
      throw Exception('Failed to write message: $e');
    }

    try {
      await _db.collection('conversations').doc(convoId).set({
        'lastMessage': text,
        'lastSenderId': uid,
        'updatedAt': now,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update conversation metadata: $e');
    }
  }

  /// Uploads image bytes and sends an image message.
  Future<void> sendImageMessage(
    String convoId,
    Uint8List bytes,
    String filename,
  ) async {
    final uid = _myUid;
    if (uid.isEmpty) throw Exception('Not signed in');
    final messagesRef = _db
        .collection('conversations')
        .doc(convoId)
        .collection('messages');
    final now = DateTime.now().toIso8601String();
    final docRef = messagesRef.doc();
    final storagePath = 'messages/$convoId/${docRef.id}_$filename';
    try {
      final upload = await _storage.ref().child(storagePath).putData(bytes);
      final url = await upload.ref.getDownloadURL();
      await docRef.set({
        'senderId': uid,
        'text': '',
        'ts': now,
        'imageUrl': url,
      });
      await _db.collection('conversations').doc(convoId).set({
        'lastMessage': '[image]',
        'lastSenderId': uid,
        'updatedAt': now,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to send image message: $e');
    }
  }

  /// Toggle reaction for a message: adds or removes current user's uid from the emoji array.
  Future<void> toggleReaction(
    String convoId,
    String messageId,
    String emoji,
  ) async {
    final uid = _myUid;
    if (uid.isEmpty) throw Exception('Not signed in');
    final msgRef = _db
        .collection('conversations')
        .doc(convoId)
        .collection('messages')
        .doc(messageId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(msgRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final reactions = <String, List<String>>{};
      if (data['reactions'] is Map<String, dynamic>) {
        (data['reactions'] as Map<String, dynamic>).forEach((k, v) {
          reactions[k] = v is List
              ? List<String>.from(v.map((e) => e.toString()))
              : [];
        });
      }
      final users = reactions[emoji] ?? <String>[];
      if (users.contains(uid)) {
        users.remove(uid);
      } else {
        users.add(uid);
      }
      reactions[emoji] = users;
      tx.update(msgRef, {'reactions': reactions});
    });
  }
}
