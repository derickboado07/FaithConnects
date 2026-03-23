import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../services/message_service.dart';
import '../widgets/message_suggestion_bar.dart';

// Reaction definitions for chat messages (emoji-first for FaithConnects)
const List<_ChatReaction> _chatReactions = [
  _ChatReaction('like', 'Like', '👍', Color(0xFF4A90E2)),
  _ChatReaction('love', 'Love', '❤️', Color(0xFFE24A6A)),
  _ChatReaction('pray', 'Pray', '🙏', Color(0xFF8B9DC3)),
  _ChatReaction('laugh', 'Haha', '😂', Color(0xFFF5A623)),
  _ChatReaction('praise', 'Praise', '🙌', Color(0xFF9ACD32)),
  _ChatReaction('bible', 'Bible', '📖', Color(0xFF7B67FF)),
  _ChatReaction('sparkle', 'Shine', '✨', Color(0xFFFFD54F)),
];

class _ChatReaction {
  final String key;
  final String label;
  final String emoji;
  final Color color;
  const _ChatReaction(this.key, this.label, this.emoji, this.color);
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
          color: Colors.white,
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
                    Text(r.emoji, style: TextStyle(fontSize: 26)),
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

  void _showMessageOptions(BuildContext context, MessageItem m) {
    final isMe = m.senderId == fb_auth.FirebaseAuth.instance.currentUser?.uid;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.emoji_emotions),
              title: const Text('React'),
              onTap: () {
                Navigator.pop(context);
                _showReactionPicker(context, m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(context);
                _showForwardPicker(context, m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.pop(context);
                final choice = await showDialog<String>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Delete Message'),
                    content: Text(
                      isMe
                          ? 'Delete this message for yourself or for everyone?'
                          : 'Delete this message for yourself?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, 'me'),
                        child: const Text('Delete for me'),
                      ),
                      if (isMe)
                        TextButton(
                          onPressed: () => Navigator.pop(c, 'everyone'),
                          child: const Text('Delete for everyone'),
                        ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, null),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                );
                if (choice == 'me') {
                  await MessageService.instance.deleteMessageForMe(
                    widget.convoId,
                    m.id,
                  );
                } else if (choice == 'everyone') {
                  await MessageService.instance.deleteMessageForEveryone(
                    widget.convoId,
                    m.id,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showForwardPicker(BuildContext context, MessageItem m) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SizedBox(
        height: 360,
        child: StreamBuilder<List<Conversation>>(
          stream: MessageService.instance.conversationsStreamForCurrentUser(),
          builder: (c, snap) {
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return const Center(child: Text('No conversations'));
            }
            return ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final conv = list[i];
                final currentUid =
                    fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
                return ListTile(
                  title: Text(
                    conv.participants.where((p) => p != currentUid).join(', '),
                  ),
                  subtitle: conv.lastMessage != null
                      ? Text(conv.lastMessage!)
                      : null,
                  onTap: () async {
                    Navigator.pop(context);
                    await MessageService.instance.sendForwardedMessage(
                      conv.id,
                      m,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Message forwarded')),
                    );
                  },
                );
              },
            );
          },
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
                      (acc, l) => acc + l.length,
                    );

                    return GestureDetector(
                      onTap: () => _showMessageOptions(context, m),
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
                                    : const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: m.text.isNotEmpty
                                  ? Text(
                                      m.text,
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black87,
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
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFEEEEEE),
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
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: Text(
                                            rd.emoji,
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        );
                                      }),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$totalReactions',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF666666),
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
          // Suggestion bar (encouraging, faith-centered) placed above input
          MessageSuggestionBar(
            controller: _ctrl,
            onInsert: (t) {
              // keep focus on input when a suggestion is inserted
              _ctrl.text = t;
              _ctrl.selection = TextSelection.collapsed(offset: t.length);
            },
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
                                ScaffoldMessenger.of(this.context).showSnackBar(
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
