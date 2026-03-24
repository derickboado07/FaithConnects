// ─────────────────────────────────────────────────────────────────────────────
// MESSAGE SERVICE — Ang service na ito ang nag-ha-handle ng lahat ng
// messaging-related operations sa app tulad ng:
//   • Direct messages (1-on-1 na usapan)
//   • Group conversations (group chat)
//   • Pag-send ng text, image, at forwarded messages
//   • Reactions sa messages
//   • Group management (create, rename, add/remove members, etc.)
//   • Message deletion (for me / for everyone)
//   • MyDay story replies
//
// Mga Firestore collections na ginagamit:
//   - conversations/{convoId}                    — Conversation metadata
//   - conversations/{convoId}/messages/{msgId}   — Messages
//
// Firebase Storage paths:
//   - group_avatars/{convoId}/{filename}         — Group avatars
//   - messages/{convoId}/{msgId}_{filename}      — Image messages
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'auth_service.dart';
// cloud_functions client not used here; server-side callable function is available
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL — Conversation
// Nagre-represent ng isang conversation (direct o group chat).
// Nag-ho-hold ng participants, admins, last message, at iba pa.
// ─────────────────────────────────────────────────────────────────────────────
class Conversation {
  final String id;                          // Unique ID ng conversation
  final String type;                        // 'direct' o 'group'
  final String? name;                       // Group name (null kung direct)
  final String? photoUrl;                   // Group avatar URL
  final String? createdBy;                  // UID ng gumawa ng group
  final String createdAt;                   // Kailan ginawa (ISO 8601)
  final List<String> participants;          // Mga members (o dalawang UIDs kung direct)
  final List<String> admins;                // Mga group admins
  final String? lastMessage;                // Huling message na na-send
  final String? lastSenderId;               // Sino ang nag-send ng huling message
  final String updatedAt;                   // Huling na-update (para sa sorting)
  final Map<String, String> lastRead;       // Kelan huling binasa ng bawat user

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

  /// Ginagawa ang Conversation object mula sa Firestore DocumentSnapshot.
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

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL — MessageItem
// Nagre-represent ng isang individual na message sa conversation.
// May support para sa text, images, reactions, deletions, system messages,
// MyDay replies, at note replies.
// ─────────────────────────────────────────────────────────────────────────────
class MessageItem {
  final String id;                              // Unique message ID
  final String senderId;                        // UID ng nag-send
  final String? senderName;                     // Display name ng sender
  final String text;                            // Message text content
  final String ts;                              // Timestamp (ISO 8601)
  final String? imageUrl;                       // URL ng attached image (kung meron)
  final Map<String, List<String>> reactions;     // emoji → list ng user IDs na nag-react
  final Map<String, bool> deletedFor;           // uid → true kung deleted for that user
  final bool isSystemMessage;                   // True kung system message (e.g., "User joined")
  final String? mydayMediaUrl;                  // URL ng MyDay story (kung story reply)
  final String? mydayOwnerName;                 // Name ng MyDay owner
  final String? repliedToNote;                  // Content ng note na nireplyan
  final String? repliedToNoteOwnerName;         // Name ng note owner

  MessageItem({
    required this.id,
    required this.senderId,
    this.senderName,
    required this.text,
    required this.ts,
    this.imageUrl,
    Map<String, List<String>>? reactions,
    Map<String, bool>? deletedFor,
    this.isSystemMessage = false,
    this.mydayMediaUrl,
    this.mydayOwnerName,
    this.repliedToNote,
    this.repliedToNoteOwnerName,
  }) : reactions = reactions ?? {},
       deletedFor = deletedFor ?? {};

  /// Ginagawa ang MessageItem object mula sa Firestore DocumentSnapshot.
  factory MessageItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MessageItem(
      id: doc.id,
      senderId: d['senderId'] ?? '',
      senderName: d['senderName'],
      text: d['text'] ?? '',
      ts: d['ts'] ?? '',
      imageUrl: d['imageUrl'],
      isSystemMessage: d['isSystemMessage'] == true,
      mydayMediaUrl: d['mydayMediaUrl'] as String?,
      mydayOwnerName: d['mydayOwnerName'] as String?,
      repliedToNote: d['repliedToNote'] as String?,
      repliedToNoteOwnerName: d['repliedToNoteOwnerName'] as String?,
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

// ─────────────────────────────────────────────────────────────────────────────
// MESSAGE SERVICE CLASS
// Singleton service para sa lahat ng messaging operations.
// Nag-ha-handle ng conversations, messages, groups, at reactions.
// ─────────────────────────────────────────────────────────────────────────────
class MessageService {
  // Private constructor at singleton instance.
  MessageService._internal();
  static final MessageService instance = MessageService._internal();

  // Firebase instances para sa database, auth, at storage.
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Kinukuha ang UID ng kasalukuyang naka-login na user.
  String get _myUid => _auth.currentUser?.uid ?? '';

  // Base URL para sa Cloud Functions. Kung may value ito,
  // gagamitin ang server-side functions para sa operations
  // (mas secure kasi may server-side validation).
  // Kung walang value, client-side operations ang gagamitin.
  static const String _functionsBaseUrl = '';

  /// Helper na gumagawa ng deterministic conversation ID para sa
  /// direct (1-on-1) chats. Ini-sort ang dalawang UIDs para lagi
  /// pareho ang resulting ID kahit sino ang nag-initiate.
  String _convoId(String a, String b) {
    final parts = [a, b]..sort();
    return parts.join('_');
  }

  /// Real-time stream ng lahat ng conversations kung saan kasama
  /// ang current user. Naka-sort by updatedAt (pinakabago muna).
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

  /// Real-time stream ng lahat ng messages sa isang conversation,
  /// naka-order by timestamp (pinakaluma muna para chat-like ang dating).
  Stream<List<MessageItem>> messagesStream(String convoId) {
    return _db
        .collection('conversations')
        .doc(convoId)
        .collection('messages')
        .orderBy('ts', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MessageItem.fromDoc(d)).toList());
  }

  /// Sine-ensure na merong conversation document sa Firestore para sa
  /// direct chat between two users. Kung wala pa, gagawa ng bago.
  /// Returns ang conversation ID.
  Future<String> ensureConversationWith(String otherUid) async {
    final uid = _myUid;
    if (uid.isEmpty) throw Exception('Not signed in');
    final id = _convoId(uid, otherUid);
    final docRef = _db.collection('conversations').doc(id);
    bool exists = false;
    try {
      final snap = await docRef.get();
      exists = snap.exists;
    } catch (_) {
      // Permission denied means the doc exists but user isn't in it — shouldn't
      // happen with a deterministic id, but fall through to the create attempt.
      exists = false;
    }
    if (!exists) {
      await docRef.set({
        'participants': [uid, otherUid],
        'type': 'direct',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
    return id;
  }

  /// Gumagawa ng group conversation. Returns ang bagong conversation ID.
  /// Pwedeng mag-upload ng group avatar (optional).
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
      try {
        // Log uid for debugging authorization issues
        try {
          final currentUid = _auth.currentUser?.uid;
          // ignore: avoid_print
          print(
            'createGroup: uploading avatar. currentUid=$currentUid convoId=$convoId',
          );
        } catch (_) {}
        final storagePath = 'group_avatars/$convoId/$avatarFilename';
        final upload = await _storage
            .ref()
            .child(storagePath)
            .putData(avatarBytes);
        photoUrl = await upload.ref.getDownloadURL();
      } catch (e, st) {
        // Ignore upload failure but log it so group creation can continue without avatar.
        // ignore: avoid_print
        print('createGroup: avatar upload failed: $e\n$st');
        photoUrl = null;
      }
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
    // Debug: log the saved photoUrl for troubleshooting
    try {
      // ignore: avoid_print
      print('createGroup: saved conversation $convoId photoUrl=$photoUrl');
    } catch (_) {}
    return convoId;
  }

  /// Nagda-dagdag ng member sa group. Kung may Cloud Function URL,
  /// gagamitin ang server-side function para sa server-side validation.
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

  /// Tinatanggal ang member mula sa group.
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

  /// Nagse-send ng text message sa isang conversation.
  /// Kung may Cloud Function URL, gagamitin ang server para sa validation.
  /// Kung wala, client-side write ang gagawin.
  Future<void> sendMessage(
    String convoId,
    String text, {
    String? repliedToNote,
    String? repliedToNoteOwnerName,
  }) async {
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
      final msgData = <String, dynamic>{
        'senderId': uid,
        'senderName': senderName,
        'text': text,
        'ts': now,
      };
      if (repliedToNote != null && repliedToNote.isNotEmpty) {
        msgData['repliedToNote'] = repliedToNote;
        msgData['repliedToNoteOwnerName'] = repliedToNoteOwnerName ?? '';
      }
      await messagesRef.add(msgData);
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

  /// Nagse-send ng MyDay story reply message na may kasamang story thumbnail
  /// at owner name para ma-render ng chat screen bilang story-reply bubble.
  Future<void> sendMydayReplyMessage(
    String convoId,
    String text,
    String mydayMediaUrl,
    String mydayOwnerName,
  ) async {
    final uid = _myUid;
    if (uid.isEmpty) throw Exception('Not signed in');
    final now = DateTime.now().toIso8601String();
    final senderName = AuthService.instance.currentUser.value?.name ?? '';
    final messagesRef = _db
        .collection('conversations')
        .doc(convoId)
        .collection('messages');
    await messagesRef.add({
      'senderId': uid,
      'senderName': senderName,
      'text': text,
      'ts': now,
      'mydayMediaUrl': mydayMediaUrl,
      'mydayOwnerName': mydayOwnerName,
    });
    await _db.collection('conversations').doc(convoId).set({
      'lastMessage': text,
      'lastSenderId': uid,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  /// Ini-update ang group name (admin-only). Ginagamit ang Cloud Function
  /// kung may URL, otherwise client-side update.
  Future<void> updateGroupName(String convoId, String newName) async {
    if (newName.isEmpty) throw Exception('Name cannot be empty');
    if (newName.length > 60)
      throw Exception('Name too long (max 60 characters)');
    if (_functionsBaseUrl.isNotEmpty) {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not signed in');
      final token = await user.getIdToken();
      final url = '$_functionsBaseUrl/renameGroupHttp';
      final resp = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'convoId': convoId, 'newName': newName}),
      );
      if (resp.statusCode != 200) {
        throw Exception('Function error (${resp.statusCode}): ${resp.body}');
      }
      final j = jsonDecode(resp.body);
      if (j == null || j['success'] != true) {
        throw Exception('Failed to rename group: ${resp.body}');
      }
      return;
    }
    await _db.collection('conversations').doc(convoId).update({
      'name': newName,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Nag-a-upload ng avatar bytes at sine-save ang download URL sa Firestore.
  Future<void> updateGroupAvatar(
    String convoId,
    Uint8List bytes,
    String filename,
  ) async {
    if (_myUid.isEmpty) throw Exception('Not signed in');
    final storagePath =
        'group_avatars/$convoId/${DateTime.now().millisecondsSinceEpoch}_$filename';
    try {
      // Determine content type from filename extension so Storage rules accept the upload
      String contentType = 'image/jpeg';
      final ext = filename.split('.').last.toLowerCase();
      if (ext == 'png') {
        contentType = 'image/png';
      } else if (ext == 'gif') {
        contentType = 'image/gif';
      } else if (ext == 'webp') {
        contentType = 'image/webp';
      }
      final upload = await _storage
          .ref()
          .child(storagePath)
          .putData(bytes, SettableMetadata(contentType: contentType));
      final photoUrl = await upload.ref.getDownloadURL();
      await _db.collection('conversations').doc(convoId).update({
        'photoUrl': photoUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update avatar: $e');
    }
  }

  /// Nagpo-post ng system message (e.g., "Si User X ay naidagdag sa group").
  Future<void> sendSystemMessage(String convoId, String text) async {
    final now = DateTime.now().toIso8601String();
    try {
      await _db
          .collection('conversations')
          .doc(convoId)
          .collection('messages')
          .add({
            'senderId': 'system',
            'senderName': '',
            'text': text,
            'ts': now,
            'isSystemMessage': true,
          });
    } catch (_) {
      // System message failure is non-fatal
    }
  }

  /// Nag-po-promote ng member bilang admin ng group.
  Future<void> promoteToAdmin(String convoId, String uid) async {
    if (_myUid.isEmpty) throw Exception('Not signed in');
    await _db.collection('conversations').doc(convoId).update({
      'admins': FieldValue.arrayUnion([uid]),
    });
  }

  /// Nag-le-leave ang current user sa group. Kung siya ang sole admin,
  /// awtomatikong mag-po-promote ng ibang member bilang admin bago umalis.
  Future<void> leaveGroup(String convoId) async {
    final uid = _myUid;
    if (uid.isEmpty) throw Exception('Not signed in');
    final convoRef = _db.collection('conversations').doc(convoId);
    final snap = await convoRef.get();
    if (!snap.exists) throw Exception('Group not found');
    final data = snap.data() as Map<String, dynamic>;
    final members = List<String>.from(data['participants'] ?? []);
    final admins = List<String>.from(data['admins'] ?? []);
    // Auto-promote another member if this user is the sole admin and others remain
    if (admins.contains(uid) && admins.length == 1 && members.length > 1) {
      final newAdmin = members.firstWhere((m) => m != uid, orElse: () => '');
      if (newAdmin.isNotEmpty) {
        await convoRef.update({
          'admins': FieldValue.arrayUnion([newAdmin]),
        });
      }
    }
    await convoRef.update({
      'participants': FieldValue.arrayRemove([uid]),
      'admins': FieldValue.arrayRemove([uid]),
    });
  }

  /// Dine-delete ang group at lahat ng messages nito.
  /// Ginagamit ang Cloud Function kung may URL; otherwise client-side
  /// batched deletion ang gagawin.
  Future<void> deleteGroup(String convoId) async {
    if (_functionsBaseUrl.isNotEmpty) {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not signed in');
      final token = await user.getIdToken();
      final url = '$_functionsBaseUrl/deleteGroupHttp';
      final resp = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'convoId': convoId}),
      );
      if (resp.statusCode != 200) {
        throw Exception('Function error (${resp.statusCode}): ${resp.body}');
      }
      final j = jsonDecode(resp.body);
      if (j == null || j['success'] != true) {
        throw Exception('Failed to delete group: ${resp.body}');
      }
      return;
    }
    // Client-side fallback — delete messages then the conversation doc
    final convoRef = _db.collection('conversations').doc(convoId);
    final msgs = await convoRef.collection('messages').get();
    for (final d in msgs.docs) {
      await d.reference.delete();
    }
    await convoRef.delete();
  }

  /// Ini-mark ang conversation bilang nabasa na ng current user.
  Future<void> markConversationRead(String convoId) async {
    final uid = _myUid;
    if (uid.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await _db.collection('conversations').doc(convoId).set({
      'lastRead': {uid: now},
    }, SetOptions(merge: true));
  }

  /// Nagse-send ng forwarded message sa existing conversation.
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

  /// Ini-mark ang message bilang deleted para sa current user (hidden locally).
  /// Hindi nabubura ang message sa database — natatago lang sa user na 'to.
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

  /// Dine-delete ang message document para sa lahat (everyone).
  /// Kailangan ng appropriate security rules o Cloud Function.
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
        final body = resp.body;
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

  /// Nag-a-upload ng image bytes at nagse-send ng image message.
  /// Una, ina-upload ang image sa Firebase Storage, tapos sine-send
  /// ang message na may imageUrl.
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

  /// Nagse-send ng image message gamit ang pre-uploaded download URL.
  /// Ginagamit ito kapag naka-upload na ang image sa Firebase Storage.
  Future<void> sendImageMessageWithUrl(String convoId, String imageUrl) async {
    final uid = _myUid;
    if (uid.isEmpty) throw Exception('Not signed in');
    final now = DateTime.now().toIso8601String();
    final senderName = AuthService.instance.currentUser.value?.name ?? '';
    try {
      await _db
          .collection('conversations')
          .doc(convoId)
          .collection('messages')
          .add({
            'senderId': uid,
            'senderName': senderName,
            'text': '',
            'ts': now,
            'imageUrl': imageUrl,
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

  /// Toggle reaction sa isang message: nagda-dagdag o nagta-tanggal ng
  /// current user's UID mula sa emoji array. Kung nag-react na siya
  /// dati sa same emoji, tatanggalin; kung hindi pa, idadagdag.
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
