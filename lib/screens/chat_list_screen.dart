import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../services/message_service.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Conversation> _cached = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.create),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewChatScreen()),
        ),
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: MessageService.instance.conversationsStreamForCurrentUser(),
        builder: (context, snap) {
          if (snap.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Messaging error: ${snap.error}')),
              );
            });
          }

          // Update cache when we have data
          if (snap.hasData) {
            final data = snap.data ?? [];
            if (data.isNotEmpty) {
              _cached = data;
            } else {
              // Keep cached if server returned empty (avoid UI flicker)
              // but if cache empty, fallthrough to show empty state below
            }
          }

          final convosToShow = snap.hasData && (snap.data ?? []).isNotEmpty
              ? snap.data!
              : _cached;

          if (convosToShow.isEmpty) {
            if (snap.connectionState == ConnectionState.waiting &&
                _cached.isNotEmpty) {
              // show cached while waiting
            } else if (snap.hasError && _cached.isNotEmpty) {
              // show cached despite error
            } else {
              return const Center(child: Text('No conversations'));
            }
          }

          final myUid = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';

          return ListView.builder(
            itemCount: convosToShow.length,
            itemBuilder: (context, i) {
              final c = convosToShow[i];
              final peerId = c.participants.firstWhere(
                (p) => p != myUid,
                orElse: () => c.participants.first,
              );
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(peerId)
                    .get(),
                builder: (context, userSnap) {
                  final userDoc = userSnap.data;
                  final data = (userDoc != null && userDoc.exists)
                      ? (userDoc.data() as Map<String, dynamic>?)
                      : null;
                  final name = (data != null && data.isNotEmpty)
                      ? (data['name'] ?? data['email'] ?? 'User')
                      : 'User';
                  final avatar = data != null ? (data['avatar'] ?? '') : '';

                  final lastMsg = c.lastMessage ?? '';
                  final lastSender = c.lastSenderId ?? '';
                  final isSentByMe =
                      lastSender.isNotEmpty && lastSender == myUid;
                  final subtitle = isSentByMe ? 'You: $lastMsg' : lastMsg;

                  String fmtTs(String iso) {
                    try {
                      final dt = DateTime.parse(iso).toLocal();
                      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
                      final minute = dt.minute.toString().padLeft(2, '0');
                      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
                      return '$hour12:$minute $ampm';
                    } catch (_) {
                      return iso;
                    }
                  }

                  final tsText = c.updatedAt.isNotEmpty
                      ? fmtTs(c.updatedAt)
                      : '';
                  // Determine unread using conversation.lastRead map
                  final lastReadForMe = c.lastRead[myUid];
                  bool isUnread;
                  if (c.lastSenderId == null || c.lastSenderId == myUid) {
                    isUnread = false;
                  } else if (lastReadForMe == null || lastReadForMe.isEmpty) {
                    isUnread = true;
                  } else {
                    try {
                      final lr = DateTime.parse(lastReadForMe);
                      final up = DateTime.parse(c.updatedAt);
                      isUnread = up.isAfter(lr);
                    } catch (_) {
                      isUnread = true;
                    }
                  }

                  // Determine if peer has seen our last message
                  final peerRead = c.lastRead[peerId];
                  bool seenByPeer = false;
                  if (c.lastSenderId != null &&
                      c.lastSenderId == myUid &&
                      peerRead != null &&
                      peerRead.isNotEmpty) {
                    try {
                      final pr = DateTime.parse(peerRead);
                      final up = DateTime.parse(c.updatedAt);
                      seenByPeer = !up.isAfter(pr);
                    } catch (_) {
                      seenByPeer = false;
                    }
                  }

                  return ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundImage: avatar.isNotEmpty
                              ? NetworkImage(avatar)
                              : null,
                          child: avatar.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        // online indicator
                        if (userDoc != null && userDoc.exists)
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Builder(
                              builder: (_) {
                                final data =
                                    userDoc.data() as Map<String, dynamic>?;
                                final isOnline =
                                    data != null && data['isOnline'] == true;
                                final lastActive = data != null
                                    ? data['lastActive']
                                    : null;
                                bool recent = false;
                                if (!isOnline && lastActive is String) {
                                  try {
                                    final dt = DateTime.parse(lastActive);
                                    recent =
                                        DateTime.now()
                                            .difference(dt)
                                            .inSeconds <
                                        60;
                                  } catch (_) {}
                                }
                                if (!isOnline && !recent) {
                                  return const SizedBox.shrink();
                                }
                                return Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: isOnline
                                        ? Colors.green
                                        : Colors.green.shade200,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    title: Text(name),
                    subtitle: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (tsText.isNotEmpty)
                          Text(
                            tsText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        const SizedBox(height: 6),
                        if (isUnread)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2E7DFF),
                              shape: BoxShape.circle,
                            ),
                          )
                        else if (seenByPeer)
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: avatar.isNotEmpty
                                ? NetworkImage(avatar)
                                : null,
                            child: avatar.isEmpty
                                ? const Icon(Icons.person, size: 12)
                                : null,
                          )
                        else
                          const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          convoId: c.id,
                          peerId: peerId,
                          peerName: name,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
