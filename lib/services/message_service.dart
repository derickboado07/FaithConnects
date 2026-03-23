import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'auth_service.dart';
// cloud_functions client not used here; server-side callable function is available
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Conversation {
  final String id;
  final String type; // 'direct' or 'group'
  final String? name; // group name
  final String? photoUrl; // group avatar
  final String? createdBy;
  final String createdAt;
  final List<String> participants; // members for group or two uids for direct
  final List<String> admins; // group admins
  final String? lastMessage;
  final String? lastSenderId;
  final String updatedAt;
  final Map<String, String> lastRead;

  Conversation({
    required this.id,
    required this.type,
    this.name,
    this.photoUrl,
    this.createdBy,
    required this.createdAt,
    required this.participants,
    List<String>? admins,
    this.lastMessage,
    this.lastSenderId,
    required this.updatedAt,
    Map<String, String>? lastRead,
  }) : admins = admins ?? [],
       lastRead = lastRead ?? {};

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
      type: (d['type'] ?? 'direct') as String,
      name: d['name'] as String?,
      photoUrl: d['photoUrl'] as String?,
      createdBy: d['createdBy'] as String?,
      createdAt: d['createdAt'] ?? '',
      participants: List<String>.from(d['participants'] ?? []),
      admins: d['admins'] is List ? List<String>.from(d['admins']) : [],
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
  final String? senderName;
  final String text;
  final String ts;
  final String? imageUrl;
  final Map<String, List<String>> reactions;
  final Map<String, bool> deletedFor;

  MessageItem({
    required this.id,
    required this.senderId,
    this.senderName,
    required this.text,
    required this.ts,
    this.imageUrl,
    Map<String, List<String>>? reactions,
    Map<String, bool>? deletedFor,
  }) : reactions = reactions ?? {},
       deletedFor = deletedFor ?? {};
  // initialize deletedFor
  // ignore: prefer_initializing_formals

  factory MessageItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MessageItem(
      id: doc.id,
      senderId: d['senderId'] ?? '',
      senderName: d['senderName'],
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
      deletedFor: d['deletedFor'] is Map<String, dynamic>
          ? (d['deletedFor'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, v == true),
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

  // Set this to your deployed functions base URL, for example:
  // https://us-central1-<your-project-id>.cloudfunctions.net
  // Leave empty to attempt direct client delete (may fail if security rules block it).
  static const String _functionsBaseUrl = '';

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
      'type': 'direct',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    return id;
  }

  /// Create a group conversation. Returns the new conversation id.
  Future<String> createGroup({
    required String name,
    required List<String> memberUids,
    Uint8List? avatarBytes,
    String? avatarFilename,
  }) async {
    final uid = _myUid;
    if (uid.isEmpty) throw Exception('Not signed in');
    final docRef = _db.collection('conversations').doc();
    final now = DateTime.now().toIso8601String();
    final convoId = docRef.id;
    String? photoUrl;
    if (avatarBytes != null && avatarFilename != null) {
      final storagePath = 'group_avatars/$convoId/$avatarFilename';
      final upload = await _storage
          .ref()
          .child(storagePath)
          .putData(avatarBytes);
      photoUrl = await upload.ref.getDownloadURL();
    }
    final members = <String>{...memberUids};
    members.add(uid);
    final data = {
      'type': 'group',
      'name': name,
      'photoUrl': photoUrl,
      'createdBy': uid,
      'createdAt': now,
      'participants': members.toList(),
      'admins': [uid],
      'updatedAt': now,
    };
    await docRef.set(data);
    return convoId;
  }

  Future<void> addMember(String convoId, String uidToAdd) async {
    if (_functionsBaseUrl.isNotEmpty) {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not signed in');
      final token = await user.getIdToken();
      final url = '$_functionsBaseUrl/addGroupMemberHttp';
      final resp = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'convoId': convoId, 'uidToAdd': uidToAdd}),
      );
      if (resp.statusCode != 200) {
        throw Exception('Function error (${resp.statusCode}): ${resp.body}');
      }
      final j = jsonDecode(resp.body);
      if (j == null || j['success'] != true) {
        throw Exception('Failed to add member: ${resp.body}');
      }
      return;
    }

    await _db.collection('conversations').doc(convoId).update({
      'participants': FieldValue.arrayUnion([uidToAdd]),
    });
  }

  Future<void> removeMember(String convoId, String uidToRemove) async {
    if (_functionsBaseUrl.isNotEmpty) {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not signed in');
      final token = await user.getIdToken();
      final url = '$_functionsBaseUrl/removeGroupMemberHttp';
      final resp = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'convoId': convoId, 'uidToRemove': uidToRemove}),
      );
      if (resp.statusCode != 200) {
        throw Exception('Function error (${resp.statusCode}): ${resp.body}');
      }
      final j = jsonDecode(resp.body);
      if (j == null || j['success'] != true) {
        throw Exception('Failed to remove member: ${resp.body}');
      }
      return;
    }

    await _db.collection('conversations').doc(convoId).update({
      'participants': FieldValue.arrayRemove([uidToRemove]),
      'admins': FieldValue.arrayRemove([uidToRemove]),
    });
  }

  Future<void> sendMessage(String convoId, String text) async {
    final uid = _myUid;
    if (uid.isEmpty) throw Exception('Not signed in');
    final messagesRef = _db
        .collection('conversations')
        .doc(convoId)
        .collection('messages');
    final now = DateTime.now().toIso8601String();

    // If functions base URL is configured, use server to validate membership and write
    if (_functionsBaseUrl.isNotEmpty) {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not signed in');
      final token = await user.getIdToken();
      final url = '$_functionsBaseUrl/sendMessageHttp';
      final resp = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'convoId': convoId, 'text': text}),
      );
      if (resp.statusCode != 200) {
        throw Exception('Function error (${resp.statusCode}): ${resp.body}');
      }
      final j = jsonDecode(resp.body);
      if (j == null || j['success'] != true) {
        throw Exception('Failed to send message: ${resp.body}');
      }
      return;
    }

    // Client-side write when functions not configured
    try {
      final senderName = AuthService.instance.currentUser.value?.name ?? '';
      await messagesRef.add({
        'senderId': uid,
        'senderName': senderName,
        'text': text,
        'ts': now,
      });
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

  Future<void> deleteGroup(String convoId) async {
    // remove doc and all messages subcollection documents
    final convoRef = _db.collection('conversations').doc(convoId);
    final msgs = await convoRef.collection('messages').get();
    for (final d in msgs.docs) {
      await d.reference.delete();
    }
    await convoRef.delete();
  }

  Future<void> markConversationRead(String convoId) async {
    final uid = _myUid;
    if (uid.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await _db.collection('conversations').doc(convoId).set({
      'lastRead': {uid: now},
    }, SetOptions(merge: true));
  }

  /// Send a forwarded message into an existing conversation.
  Future<void> sendForwardedMessage(String convoId, MessageItem m) async {
    final uid = _myUid;
    if (uid.isEmpty) throw Exception('Not signed in');
    final messagesRef = _db
        .collection('conversations')
        .doc(convoId)
        .collection('messages');
    final now = DateTime.now().toIso8601String();
    final senderName = AuthService.instance.currentUser.value?.name ?? '';
    final payload = {
      'senderId': uid,
      'senderName': senderName,
      'text': m.text,
      'ts': now,
      'forwarded': true,
      'originalSenderId': m.senderId,
      'originalTs': m.ts,
    };
    await messagesRef.add(payload);
    await _db.collection('conversations').doc(convoId).set({
      'lastMessage': '[forwarded] ${m.text}',
      'lastSenderId': uid,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  /// Mark a message as deleted for the current user (hidden locally).
  Future<void> deleteMessageForMe(String convoId, String messageId) async {
    final uid = _myUid;
    if (uid.isEmpty) throw Exception('Not signed in');
    final msgRef = _db
        .collection('conversations')
        .doc(convoId)
        .collection('messages')
        .doc(messageId);
    await msgRef.set({
      'deletedFor': {uid: true},
    }, SetOptions(merge: true));
  }

  /// Delete a message document for everyone (requires appropriate security rules).
  Future<void> deleteMessageForEveryone(
    String convoId,
    String messageId,
  ) async {
    if (_functionsBaseUrl.isNotEmpty) {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not signed in');
      final token = await user.getIdToken();
      final url = '$_functionsBaseUrl/deleteMessageHttp';
      final resp = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'convoId': convoId, 'messageId': messageId}),
      );
      if (resp.statusCode != 200) {
        String body = resp.body ?? '';
        throw Exception('Function error (${resp.statusCode}): $body');
      }
      final j = jsonDecode(resp.body);
      if (j == null || j['success'] != true) {
        throw Exception('Failed to delete message: ${resp.body}');
      }
      return;
    }

    final msgRef = _db
        .collection('conversations')
        .doc(convoId)
        .collection('messages')
        .doc(messageId);
    await msgRef.delete();
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
      final senderName = AuthService.instance.currentUser.value?.name ?? '';
      await docRef.set({
        'senderId': uid,
        'senderName': senderName,
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
