import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../services/message_service.dart';

// Reaction definitions for chat messages
const List<_ChatReaction> _chatReactions = [
  _ChatReaction('amen', 'Amen', Icons.thumb_up, Color(0xFFD4AF37)),
  _ChatReaction('pray', 'Pray', Icons.pan_tool, Color(0xFF8B9DC3)),
  _ChatReaction('worship', 'Worship', Icons.music_note, Color(0xFF9ACD32)),
  _ChatReaction('love', 'Love', Icons.favorite, Color(0xFFE57373)),
];

class _ChatReaction {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _ChatReaction(this.key, this.label, this.icon, this.color);
}

class ChatScreen extends StatefulWidget {
  final String convoId;
  final String peerId;
  final String? peerName;

  const ChatScreen({
    super.key,
    required this.convoId,
    required this.peerId,
    this.peerName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<String> _fetchPeerName() async {
    if (widget.peerName != null) return widget.peerName!;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.peerId)
        .get();
    if (doc.exists) return doc['name'] ?? doc['email'] ?? 'User';
    return 'User';
  }

  void _showReactionPicker(BuildContext context, MessageItem m) {
    final myUid = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _chatReactions.map((r) {
            final isActive = (m.reactions[r.key] ?? []).contains(myUid);
            return GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                await MessageService.instance.toggleReaction(
                  widget.convoId,
                  m.id,
                  r.key,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? r.color.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  border: isActive
                      ? Border.all(color: r.color.withValues(alpha: 0.4))
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(r.icon, size: 26, color: r.color),
                    const SizedBox(height: 4),
                    Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: r.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: _fetchPeerName(),
          builder: (context, snap) => Text(snap.data ?? 'Chat'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageItem>>(
              stream: MessageService.instance.messagesStream(widget.convoId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snap.data ?? [];
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final isMe = myUid.isNotEmpty && m.senderId == myUid;
                    // Gather non-empty reactions
                    final reactionEntries = m.reactions.entries
                        .where((e) => e.value.isNotEmpty)
                        .toList();
                    final totalReactions = m.reactions.values.fold<int>(
                      0,
                      (sum, l) => sum + l.length,
                    );

                    return GestureDetector(
                      onLongPress: () => _showReactionPicker(context, m),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFFD4AF37)
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: m.text.isNotEmpty
                                  ? Text(
                                      m.text,
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Theme.of(context).colorScheme.onSurface,
                                      ),
                                    )
                                  : (m.imageUrl != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.network(
                                              m.imageUrl!,
                                              width: 180,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const SizedBox.shrink()),
                            ),
                            // Reaction summary
                            if (totalReactions > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.06,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ...reactionEntries.take(3).map((e) {
                                        final rd = _chatReactions.firstWhere(
                                          (r) => r.key == e.key,
                                          orElse: () => _chatReactions[0],
                                        );
                                        return Icon(
                                          rd.icon,
                                          size: 13,
                                          color: rd.color,
                                        );
                                      }),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$totalReactions',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Mark conversation read when chat screen is visible
          FutureBuilder<void>(
            future: MessageService.instance.markConversationRead(
              widget.convoId,
            ),
            builder: (context, _) => const SizedBox.shrink(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _sending
                        ? null
                        : () async {
                            final txt = _ctrl.text.trim();
                            if (txt.isEmpty) return;
                            setState(() => _sending = true);
                            try {
                              await MessageService.instance.sendMessage(
                                widget.convoId,
                                txt,
                              );
                              _ctrl.clear();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to send: $e'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _sending = false);
                            }
                          },
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
