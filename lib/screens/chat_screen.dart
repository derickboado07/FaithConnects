// ═══════════════════════════════════════════════════════════════════════════
// CHAT SCREEN — Ang actual messaging conversation screen.
// Real-time messaging UI na may mga features:
//   • Text messages with send/receive bubbles
//   • Image upload at preview (camera o gallery)
//   • In-chat search (i-filter messages by text)
//   • Custom reactions (emoji) sa messages
//   • Message suggestions (suggested replies)
//   • Forward at delete messages
//   • Pagination (infinite scroll pataas for older messages)
//   • Typing indicator at presence status
//
// Works para sa 1-on-1 at group conversations.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/message_service.dart';
import '../services/media_upload_service.dart';
import '../services/call_service.dart';
import '../widgets/message_suggestion_bar.dart';
import '../widgets/online_indicator.dart';
import 'group_settings_screen.dart';
import 'call_screen.dart';
import 'image_viewer_screen.dart';

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
  final Conversation? conversation;
  final String? initialText;
  final String? initialNoteText;
  final String? initialNoteOwnerName;

  const ChatScreen({
    super.key,
    required this.convoId,
    this.peerId = '',
    this.peerName,
    this.conversation,
    this.initialText,
    this.initialNoteText,
    this.initialNoteOwnerName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController(); // Text input controller

  // Pending note reply context — kapag nag-reply sa My Day note
  String? _pendingNoteText;          // Text ng note na sini-reply
  String? _pendingNoteOwnerName;     // Pangalan ng may-ari ng note

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _ctrl.text = widget.initialText!;
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    }
    // Kapag binuksan mula sa note reply, i-set ang pending note context
    if (widget.initialNoteText != null && widget.initialNoteText!.isNotEmpty) {
      _pendingNoteText = widget.initialNoteText;
      _pendingNoteOwnerName = widget.initialNoteOwnerName;
    }
  }

  bool _sending = false;          // True habang nag-se-send ang message
  bool _uploadingImage = false;   // True habang nag-u-upload ng image
  final Map<String, String> _senderNames = {}; // Cache ng sender names by UID

  // In-chat search state — para mag-filter ng messages by text
  bool _isSearching = false;           // True kapag active ang search mode
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';           // Current search query text
  Timer? _debounce;                   // Debounce timer para sa search input

  // ── Image picking ────────────────────────────────────────────────────
  Future<void> _pickAndSendImage() async {
    Uint8List? bytes;
    String? filename;

    if (kIsWeb) {
      // Use file_picker for web/desktop
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        bytes = result.files.single.bytes!;
        filename = result.files.single.name;
      }
    } else {
      // Use image_picker for mobile
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (picked != null) {
        bytes = await picked.readAsBytes();
        filename = picked.name;
      }
    }

    if (bytes == null || filename == null) return;
    setState(() => _uploadingImage = true);

    // Step 1: Upload image bytes to Firebase Storage
    String url;
    try {
      url = await MediaUploadService.instance.uploadChatImage(
        convoId: widget.convoId,
        bytes: bytes,
        filename: filename,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingImage = false);
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('Storage upload failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // Step 2: Write the message document to Firestore with the download URL
    try {
      await MessageService.instance.sendImageMessageWithUrl(
        widget.convoId,
        url,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('Failed to send image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  // ── Call initiation ──────────────────────────────────────────────────
  Future<void> _startCall(String type) async {
    final myUid = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    if (myUid.isEmpty) return;
    final participants =
        widget.conversation?.participants ??
        (widget.peerId.isNotEmpty ? [myUid, widget.peerId] : [myUid]);

    try {
      final callId = await CallService.instance.startCall(
        participants: participants,
        type: type,
        convoId: widget.convoId,
      );

      // Resolve peer name for the call screen
      final peerName = await _fetchPeerName();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callId: callId,
            convoId: widget.convoId,
            peerName: peerName,
            type: type,
            isIncoming: false,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('Failed to start call: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Nag-de-debounce ng search input — 300ms delay bago mag-query.
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = query.toLowerCase().trim());
    });
  }

  /// Nag-ca-cache ng sender name by UID para hindi paulit-ulit mag-query sa Firestore.
  void _cacheSenderName(String uid) {
    if (uid.isEmpty || uid == 'system' || _senderNames.containsKey(uid)) return;
    _senderNames[uid] = uid; // placeholder to avoid duplicate fetches
    FirebaseFirestore.instance.collection('users').doc(uid).get().then((d) {
      if (d.exists && mounted) {
        setState(() => _senderNames[uid] = d['name'] ?? uid);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<String> _fetchPeerName() async {
    if (widget.conversation != null)
      return widget.conversation!.name ?? 'Group';
    if (widget.peerName != null) return widget.peerName!;
    if (widget.peerId.isEmpty) return 'Chat';
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.peerId)
        .get();
    if (doc.exists) return doc['name'] ?? doc['email'] ?? 'User';
    return 'User';
  }

  /// Nagpapakita ng reaction picker bottom sheet para sa isang message.
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

  /// Nagpapakita ng message options (forward, delete, copy) via bottom sheet.
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
                  try {
                    await MessageService.instance.deleteMessageForMe(
                      widget.convoId,
                      m.id,
                    );
                    if (!mounted) return;
                    setState(
                      () {},
                    ); // force rebuild to hide locally-deleted message
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Message deleted for you')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Failed to delete: $e')),
                    );
                  }
                } else if (choice == 'everyone') {
                  try {
                    await MessageService.instance.deleteMessageForEveryone(
                      widget.convoId,
                      m.id,
                    );
                    if (!mounted) return;
                    setState(() {});
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Message deleted for everyone'),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete for everyone: $e'),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Nagpapakita ng conversation picker para i-forward ang message.
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
                final otherId = conv.participants.firstWhere(
                  (p) => p != currentUid,
                  orElse: () => conv.participants.isNotEmpty
                      ? conv.participants.first
                      : currentUid,
                );
                if (conv.type == 'group') {
                  return ListTile(
                    leading: conv.photoUrl != null && conv.photoUrl!.isNotEmpty
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(conv.photoUrl!),
                          )
                        : const CircleAvatar(child: Icon(Icons.group)),
                    title: Text(conv.name ?? 'Group'),
                    subtitle: conv.lastMessage != null
                        ? Text(conv.lastMessage!)
                        : null,
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        await MessageService.instance.sendForwardedMessage(
                          conv.id,
                          m,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('Message forwarded')),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('Failed to forward: $e')),
                        );
                      }
                    },
                  );
                }

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(otherId)
                      .get(),
                  builder: (ctx, userSnap) {
                    final displayName =
                        (userSnap.hasData && userSnap.data!.exists)
                        ? (userSnap.data!['name'] ?? otherId)
                        : otherId;
                    return ListTile(
                      title: Text(displayName),
                      subtitle: conv.lastMessage != null
                          ? Text(conv.lastMessage!)
                          : null,
                      onTap: () async {
                        Navigator.pop(context);
                        try {
                          await MessageService.instance.sendForwardedMessage(
                            conv.id,
                            m,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('Message forwarded')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('Failed to forward: $e')),
                          );
                        }
                      },
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
    final isGroup = widget.conversation?.type == 'group';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search in conversation...',
                  hintStyle: TextStyle(color: Color(0xFF888888)),
                  border: InputBorder.none,
                ),
              )
            : widget.conversation != null
                ? StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('conversations')
                        .doc(widget.convoId)
                        .snapshots(),
                    builder: (context, convoSnap) {
                      final convoData =
                          convoSnap.data?.data() as Map<String, dynamic>?;
                      final livePhotoUrl =
                          convoData?['photoUrl'] as String? ??
                          widget.conversation!.photoUrl;
                      final liveName =
                          convoData?['name'] as String? ??
                          widget.conversation!.name ??
                          '';

                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: (livePhotoUrl != null && livePhotoUrl.isNotEmpty)
                                ? NetworkImage(livePhotoUrl)
                                : null,
                            child: (livePhotoUrl == null || livePhotoUrl.isEmpty)
                                ? Text(
                                    (liveName.isNotEmpty)
                                        ? liveName
                                              .trim()
                                              .split(RegExp('\\s+'))
                                              .where((s) => s.isNotEmpty)
                                              .map((s) => s[0])
                                              .take(2)
                                              .join()
                                              .toUpperCase()
                                        : 'G',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF5C5C5C),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  liveName.isNotEmpty ? liveName : 'Chat',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C2C2C),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (!isGroup && widget.peerId.isNotEmpty)
                                  UserStatusText(
                                    uid: widget.peerId,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.normal,
                                      color: Color(0xFF888888),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FutureBuilder<String>(
                        future: _fetchPeerName(),
                        builder: (context, snap) => Text(
                          snap.data ?? 'Chat',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C2C2C),
                          ),
                        ),
                      ),
                      if (!isGroup && widget.peerId.isNotEmpty)
                        UserStatusText(
                          uid: widget.peerId,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                            color: Color(0xFF888888),
                          ),
                        ),
                    ],
                  ),
        actions: [
          // Voice call button
          IconButton(
            icon: const Icon(Icons.call, color: Color(0xFFD4AF37)),
            tooltip: 'Voice Call',
            onPressed: () => _startCall('voice'),
          ),
          // Video call button
          IconButton(
            icon: const Icon(Icons.videocam, color: Color(0xFFD4AF37)),
            tooltip: 'Video Call',
            onPressed: () => _startCall('video'),
          ),
          // Search toggle for in-conversation search
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Close search' : 'Search messages',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchCtrl.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          if (isGroup)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Group Settings',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        GroupSettingsScreen(convoId: widget.convoId),
                  ),
                );
              },
            ),
        ],
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
                final all = snap.data ?? [];
                var msgs = all.where((m) {
                  try {
                    final hidden = m.deletedFor[myUid] == true;
                    return !hidden;
                  } catch (_) {
                    return true;
                  }
                }).toList();

                // Apply in-chat search filter
                if (_searchQuery.isNotEmpty) {
                  msgs = msgs
                      .where(
                        (m) =>
                            m.text.toLowerCase().contains(_searchQuery) ||
                            (m.senderName ?? '').toLowerCase().contains(
                              _searchQuery,
                            ),
                      )
                      .toList();
                }

                if (_searchQuery.isNotEmpty && msgs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Color(0xFFCCCCCC),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No messages found',
                          style: TextStyle(color: Color(0xFF888888)),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    // Because reverse:true, index 0 is at the bottom.
                    // Flip so newest messages appear at the bottom.
                    i = msgs.length - 1 - i;
                    final m = msgs[i];
                    // System messages are rendered as centred notices
                    if (m.isSystemMessage) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                m.text,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF999999),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                      );
                    }
                    final isMe = myUid.isNotEmpty && m.senderId == myUid;
                    final isGroup = widget.conversation?.type == 'group';
                    // Gather non-empty reactions
                    final reactionEntries = m.reactions.entries
                        .where((e) => e.value.isNotEmpty)
                        .toList();
                    final totalReactions = m.reactions.values.fold<int>(
                      0,
                      (acc, l) => acc + l.length,
                    );

                    final isMydayReply =
                        m.mydayMediaUrl != null && m.mydayMediaUrl!.isNotEmpty;

                    final isNoteReply =
                        m.repliedToNote != null && m.repliedToNote!.isNotEmpty;

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
                            if (isGroup && !(m.senderName?.isEmpty ?? true))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  m.senderName ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF666666),
                                  ),
                                ),
                              )
                            else if (isGroup && (m.senderName?.isEmpty ?? true))
                              Builder(
                                builder: (_) {
                                  _cacheSenderName(m.senderId);
                                  final nm =
                                      _senderNames[m.senderId] ?? m.senderId;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      nm,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF666666),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            // ── MyDay story-reply bubble ──────────────────────
                            if (isMydayReply) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.reply_rounded,
                                      size: 13,
                                      color: Color(0xFF888888),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isMe
                                          ? 'You replied to ${m.mydayOwnerName}\'s story'
                                          : '${m.senderName ?? 'Someone'} replied to your story',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF888888),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(14),
                                  topRight: Radius.circular(14),
                                  bottomLeft: Radius.circular(4),
                                  bottomRight: Radius.circular(4),
                                ),
                                child: Image.network(
                                  m.mydayMediaUrl!,
                                  width: 180,
                                  height: 220,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (ctx, child, progress) {
                                    if (progress == null) return child;
                                    return const SizedBox(
                                      width: 180,
                                      height: 220,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFD4AF37),
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (ctx, err, st) =>
                                      const SizedBox(
                                        width: 180,
                                        height: 100,
                                        child: Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.grey,
                                            size: 36,
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            // ── Note reply bubble ────────────────────────────
                            if (isNoteReply) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.reply_rounded,
                                      size: 13,
                                      color: Color(0xFF888888),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isMe
                                          ? 'You replied to ${m.repliedToNoteOwnerName ?? 'their'}\'s note'
                                          : '${m.senderName ?? 'Someone'} replied to your note',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF888888),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 250,
                                ),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFF5E6B3,
                                  ).withValues(alpha: 0.45),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(14),
                                    topRight: Radius.circular(14),
                                    bottomLeft: Radius.circular(4),
                                    bottomRight: Radius.circular(4),
                                  ),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFD4AF37,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.sticky_note_2,
                                      size: 16,
                                      color: Color(0xFFD4AF37),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        m.repliedToNote!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF444444),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Container(
                              constraints: (isMydayReply || isNoteReply)
                                  ? const BoxConstraints(maxWidth: 250)
                                  : const BoxConstraints(maxWidth: 280),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFFD4AF37)
                                    : const Color(0xFFF0F0F0),
                                borderRadius: (isMydayReply || isNoteReply)
                                    ? const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        topRight: Radius.circular(4),
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      )
                                    : BorderRadius.circular(12),
                              ),
                              child: m.text.isNotEmpty
                                  ? _searchQuery.isNotEmpty
                                        ? _buildHighlightedMessage(
                                            m.text,
                                            _searchQuery,
                                            isMe: isMe,
                                          )
                                        : Text(
                                            m.text,
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          )
                                  : (m.imageUrl != null
                                        ? GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ImageViewerScreen(
                                                        imageUrl: m.imageUrl!,
                                                        heroTag: 'img_${m.id}',
                                                      ),
                                                ),
                                              );
                                            },
                                            child: Hero(
                                              tag: 'img_${m.id}',
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  m.imageUrl!,
                                                  width: 200,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder:
                                                      (ctx, child, progress) {
                                                        if (progress == null)
                                                          return child;
                                                        return const SizedBox(
                                                          width: 200,
                                                          height: 150,
                                                          child: Center(
                                                            child:
                                                                CircularProgressIndicator(
                                                                  color: Color(
                                                                    0xFFD4AF37,
                                                                  ),
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                  errorBuilder:
                                                      (
                                                        ctx,
                                                        err,
                                                        st,
                                                      ) => const SizedBox(
                                                        width: 200,
                                                        height: 120,
                                                        child: Center(
                                                          child: Icon(
                                                            Icons
                                                                .broken_image_outlined,
                                                            color:
                                                                Colors.white54,
                                                            size: 40,
                                                          ),
                                                        ),
                                                      ),
                                                ),
                                              ),
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
          // Upload progress indicator
          if (_uploadingImage)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LinearProgressIndicator(color: Color(0xFFD4AF37)),
            ),
          // Note reply banner
          if (_pendingNoteText != null && _pendingNoteText!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFF5E6B3).withValues(alpha: 0.5),
              child: Row(
                children: [
                  const Icon(
                    Icons.sticky_note_2,
                    size: 16,
                    color: Color(0xFFD4AF37),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Replying to ${_pendingNoteOwnerName ?? 'their'} note',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF888888),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _pendingNoteText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF444444),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _pendingNoteText = null;
                      _pendingNoteOwnerName = null;
                    }),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Image upload button
                  IconButton(
                    icon: const Icon(
                      Icons.photo_camera,
                      color: Color(0xFFD4AF37),
                    ),
                    tooltip: 'Send image',
                    onPressed: _uploadingImage ? null : _pickAndSendImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: 'Aa',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF0F0F0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                        backgroundColor: const Color(0xFFD4AF37),
                      ),
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
                                  repliedToNote: _pendingNoteText,
                                  repliedToNoteOwnerName: _pendingNoteOwnerName,
                                );
                                _ctrl.clear();
                                setState(() {
                                  _pendingNoteText = null;
                                  _pendingNoteOwnerName = null;
                                });
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
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
                          : const Icon(Icons.send, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a RichText widget with search matches highlighted in the message bubble.
  Widget _buildHighlightedMessage(
    String text,
    String query, {
    required bool isMe,
  }) {
    if (query.isEmpty) {
      return Text(
        text,
        style: TextStyle(color: isMe ? Colors.white : Colors.black87),
      );
    }
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    final baseStyle = TextStyle(color: isMe ? Colors.white : Colors.black87);
    int start = 0;
    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: baseStyle));
      }
      spans.add(
        TextSpan(
          text: text.substring(idx, idx + query.length),
          style: baseStyle.copyWith(
            backgroundColor: isMe
                ? Colors.white.withValues(alpha: 0.35)
                : const Color(0xFFF5E6B3),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = idx + query.length;
    }
    return RichText(text: TextSpan(children: spans));
  }
}
