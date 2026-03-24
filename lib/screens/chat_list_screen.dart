// ═══════════════════════════════════════════════════════════════════════════
// CHAT LIST SCREEN — Ang main messaging list/inbox ng app.
// Nagdi-display ng lahat ng active conversations (1-on-1 at groups) na may:
//   • Search bar para i-filter ang conversations
//   • Presence indicators (online/offline status)
//   • My Day (stories) preview strip sa taas
//   • Latest message preview at timestamp
//   • Unread message count badges
//   • FAB para mag-start ng new chat o group
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:image_picker/image_picker.dart';
import '../services/message_service.dart';
import '../services/myday_service.dart';
import '../services/presence_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/online_indicator.dart';
import '../widgets/set_note_dialog.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';
import 'create_group_screen.dart';
import 'myday_viewer_screen.dart';

/// Main messaging inbox screen.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Conversation> _cached = [];  // Cached list ng conversations para sa fast search filtering

  // Search state — para i-filter ang conversations
  bool _isSearching = false;            // True kapag naka-open ang search mode
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';             // Current lowercase search query
  Timer? _debounce;                     // Debounce timer para sa search input

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Nag-de-debounce ng search input para hindi bawat keystroke nag-re-render.
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = query.toLowerCase().trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search chats or users...',
                  hintStyle: TextStyle(color: Color(0xFF888888)),
                  border: InputBorder.none,
                ),
              )
            : const Text('Messages'),
        actions: [
          // Toggle search
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Close search' : 'Search chats',
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
          // Set note button
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Set your note',
            onPressed: () async {
              // Fetch current note
              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(myUid)
                  .get();
              final currentNote = (doc.data()?['note'] as String?) ?? '';
              if (!mounted) return;
              await SetNoteDialog.show(context, currentNote: currentNote);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.create),
        onPressed: () => showModalBottomSheet(
          context: context,
          builder: (c) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1),
                  title: const Text('New Chat'),
                  onTap: () {
                    Navigator.pop(c);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NewChatScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.group_add),
                  title: const Text('Create Group'),
                  onTap: () {
                    Navigator.pop(c);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateGroupScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
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
            }
          }

          final convosToShow = snap.hasData && (snap.data ?? []).isNotEmpty
              ? snap.data!
              : _cached;

          // Collect unique direct-chat peer UIDs for the circle row
          final peerUids = <String>[];
          for (final c in convosToShow) {
            if (c.type != 'group') {
              final pid = c.participants.firstWhere(
                (p) => p != myUid,
                orElse: () => '',
              );
              if (pid.isNotEmpty && !peerUids.contains(pid)) {
                peerUids.add(pid);
              }
            }
          }

          if (convosToShow.isEmpty) {
            if (snap.connectionState == ConnectionState.waiting &&
                _cached.isNotEmpty) {
              // show cached while waiting
            } else if (snap.hasError && _cached.isNotEmpty) {
              // show cached despite error
            } else {
              return Column(
                children: [
                  _buildNotesRow(myUid, peerUids),
                  const Expanded(
                    child: Center(child: Text('No conversations')),
                  ),
                ],
              );
            }
          }

          return Column(
            children: [
              // ── Messenger-style horizontal Notes / My Day circle row ──
              if (!_isSearching) _buildNotesRow(myUid, peerUids),
              // ── Conversation list ──
              Expanded(
                child: ListView.builder(
                  itemCount: convosToShow.length,
                  itemBuilder: (context, i) {
                    final c = convosToShow[i];
                    final peerId = c.participants.isNotEmpty
                        ? c.participants.firstWhere(
                            (p) => p != myUid,
                            orElse: () => c.participants.first,
                          )
                        : '';

                    // Use StreamBuilder for real-time user data
                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(peerId)
                          .snapshots(),
                      builder: (context, userSnap) {
                        final userDoc = userSnap.data;
                        String name = 'User';
                        String avatar = '';
                        String peerNote = '';
                        if (c.type == 'group') {
                          name = c.name ?? 'Group';
                          avatar = c.photoUrl ?? '';
                        } else {
                          final data = (userDoc != null && userDoc.exists)
                              ? (userDoc.data() as Map<String, dynamic>?)
                              : null;
                          name = (data != null && data.isNotEmpty)
                              ? (data['name'] ?? data['email'] ?? 'User')
                              : 'User';
                          avatar = data != null ? (data['avatar'] ?? '') : '';
                          final rawPeerNote = data?['note'] as String? ?? '';
                          final peerNoteSetAt =
                              data?['noteSetAt'] as String? ?? '';
                          // Notes expire after 24 hours
                          peerNote =
                              (rawPeerNote.isNotEmpty &&
                                  PresenceService.isNoteActive(peerNoteSetAt))
                              ? rawPeerNote
                              : '';
                        }

                        // Client-side search filtering
                        if (_searchQuery.isNotEmpty) {
                          final nameMatch = name.toLowerCase().contains(
                            _searchQuery,
                          );
                          final msgMatch = (c.lastMessage ?? '')
                              .toLowerCase()
                              .contains(_searchQuery);
                          final noteMatch = peerNote.toLowerCase().contains(
                            _searchQuery,
                          );
                          if (!nameMatch && !msgMatch && !noteMatch) {
                            return const SizedBox.shrink();
                          }
                        }

                        final lastMsg = c.lastMessage ?? '';
                        final lastSender = c.lastSenderId ?? '';
                        final isSentByMe =
                            lastSender.isNotEmpty && lastSender == myUid;
                        final subtitle = isSentByMe ? 'You: $lastMsg' : lastMsg;

                        String fmtTs(String iso) {
                          try {
                            final dt = DateTime.parse(iso).toLocal();
                            final hour12 = dt.hour % 12 == 0
                                ? 12
                                : dt.hour % 12;
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

                        // Determine unread
                        final lastReadForMe = c.lastRead[myUid];
                        bool isUnread;
                        if (c.lastSenderId == null || c.lastSenderId == myUid) {
                          isUnread = false;
                        } else if (lastReadForMe == null ||
                            lastReadForMe.isEmpty) {
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
                          leading: SizedBox(
                            width: 48,
                            height: 48,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                UserAvatar(
                                  photoUrl: avatar,
                                  name: name,
                                  radius: 22,
                                ),
                                if (c.type != 'group' && peerId.isNotEmpty)
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: OnlineIndicator(
                                      uid: peerId,
                                      size: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (peerNote.isNotEmpty && c.type != 'group')
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    peerNote,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFD4AF37),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              if (subtitle.isNotEmpty)
                                _searchQuery.isNotEmpty
                                    ? _buildHighlightedText(
                                        subtitle,
                                        _searchQuery,
                                      )
                                    : Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: isUnread
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (tsText.isNotEmpty)
                                Text(
                                  tsText,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF888888),
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
                          onTap: () {
                            if (c.type == 'group') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    convoId: c.id,
                                    conversation: c,
                                  ),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    convoId: c.id,
                                    peerId: peerId,
                                    peerName: name,
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Messenger-style horizontal Notes / My Day circle row ──────────────
  Widget _buildNotesRow(String myUid, List<String> peerUids) {
    final allUids = [myUid, ...peerUids];
    return StreamBuilder<Map<String, List<MyDayItem>>>(
      stream: MyDayService.instance.myDayStreamForUsers(allUids),
      builder: (context, myDaySnap) {
        final myDayMap = myDaySnap.data ?? {};
        return SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            itemCount: 1 + peerUids.length,
            itemBuilder: (context, i) {
              if (i == 0) {
                return _buildMyNoteCircle(myUid, myDayMap[myUid] ?? []);
              }
              final uid = peerUids[i - 1];
              return _buildPeerNoteCircle(uid, myDayMap[uid] ?? []);
            },
          ),
        );
      },
    );
  }

  /// Builds a note bubble overlay widget (Messenger-style speech bubble above the circle).
  Widget _buildNoteBubble(String note, {VoidCallback? onReply}) {
    if (note.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      left: -12,
      right: -12,
      child: Center(
        child: GestureDetector(
          onTap: onReply,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  note,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C2C2C),
                    height: 1.3,
                  ),
                ),
                if (onReply != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.reply, size: 11, color: Color(0xFFD4AF37)),
                      SizedBox(width: 3),
                      Text(
                        'Reply',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFFD4AF37),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The first circle: current user — "Create story" style.
  /// Shows My Day photo as background if available, avatar otherwise.
  /// Has "+" badge. Tap to view own story or add new one.
  Widget _buildMyNoteCircle(String myUid, List<MyDayItem> myDayItems) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final avatar = (data?['avatar'] ?? '') as String;
        final name = (data?['name'] ?? 'You') as String;
        final rawNote = (data?['note'] ?? '') as String;
        final noteSetAt = (data?['noteSetAt'] ?? '') as String;
        // Notes expire after 24 hours
        final note =
            (rawNote.isNotEmpty && PresenceService.isNoteActive(noteSetAt))
            ? rawNote
            : '';
        final hasMyDay = myDayItems.isNotEmpty;
        final hasNote = note.isNotEmpty;

        // Use the latest My Day media as circle thumbnail
        final thumbUrl = hasMyDay ? myDayItems.first.mediaUrl : '';
        final isVideo = hasMyDay && myDayItems.first.mediaType == 'video';

        return GestureDetector(
          onTap: () {
            // Always show options (view, add, set note) on tap
            _showMyCircleOptions(
              context,
              note,
              myDayItems: myDayItems,
              userName: name,
              userAvatar: avatar,
              myUid: myUid,
            );
          },
          onLongPress: () => _showMyCircleOptions(
            context,
            note,
            myDayItems: myDayItems,
            userName: name,
            userAvatar: avatar,
            myUid: myUid,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: SizedBox(
              width: 88,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Main circle
                        Positioned(
                          bottom: 0,
                          left: 6,
                          right: 6,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: hasMyDay
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFD4AF37),
                                        Color(0xFFF5E6B3),
                                        Color(0xFFD4AF37),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              border: hasMyDay
                                  ? null
                                  : Border.all(
                                      color: hasNote
                                          ? const Color(0xFFD4AF37)
                                          : const Color(0xFFDDDDDD),
                                      width: hasNote ? 2.5 : 1.5,
                                    ),
                            ),
                            padding: EdgeInsets.all(hasMyDay ? 3 : 2),
                            child: ClipOval(
                              child: hasMyDay && thumbUrl.isNotEmpty
                                  ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          thumbUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              UserAvatar(
                                                photoUrl: avatar,
                                                name: name,
                                                radius: 34,
                                              ),
                                        ),
                                        if (isVideo)
                                          const Center(
                                            child: Icon(
                                              Icons.play_circle_fill,
                                              color: Colors.white70,
                                              size: 28,
                                            ),
                                          ),
                                      ],
                                    )
                                  : UserAvatar(
                                      photoUrl: avatar,
                                      name: name,
                                      radius: 34,
                                    ),
                            ),
                          ),
                        ),
                        // "+" badge — always visible; tapping goes straight to upload
                        Positioned(
                          right: 4,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () => _uploadMyDay(context),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                        // Note bubble overlay — last child so it renders on top
                        if (hasNote) _buildNoteBubble(note),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    hasMyDay ? 'Your day' : 'Create story',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Options when tapping own circle — view My Day, add to My Day, set note.
  void _showMyCircleOptions(
    BuildContext context,
    String currentNote, {
    List<MyDayItem> myDayItems = const [],
    String userName = '',
    String userAvatar = '',
    String myUid = '',
  }) {
    final hasMyDay = myDayItems.isNotEmpty;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasMyDay)
              ListTile(
                leading: const Icon(Icons.visibility, color: Color(0xFFD4AF37)),
                title: const Text('View My Day'),
                subtitle: Text(
                  '${myDayItems.length} ${myDayItems.length == 1 ? 'story' : 'stories'}',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MyDayViewerScreen(
                        uid: myUid,
                        userName: userName,
                        userAvatar: userAvatar,
                        items: myDayItems,
                      ),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFD4AF37)),
              title: const Text('Add to My Day'),
              subtitle: const Text('Photo or video (max 15s)'),
              onTap: () {
                Navigator.pop(ctx);
                _uploadMyDay(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note, color: Color(0xFFD4AF37)),
              title: const Text('Set Your Note'),
              subtitle: const Text('Short status message (lasts 24h)'),
              onTap: () {
                Navigator.pop(ctx);
                SetNoteDialog.show(context, currentNote: currentNote);
              },
            ),
            if (hasMyDay)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete My Day',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: Text(
                  'Remove all ${myDayItems.length} ${myDayItems.length == 1 ? 'story' : 'stories'}',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dlgCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text('Delete My Day?'),
                      content: Text(
                        'This will permanently remove all ${myDayItems.length} ${myDayItems.length == 1 ? 'story' : 'stories'} from your My Day.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dlgCtx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dlgCtx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true || !mounted) return;
                  for (final item in myDayItems) {
                    await MyDayService.instance.deleteMyDay(item.id);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Show a picker: upload photo or short video for My Day.
  Future<void> _uploadMyDay(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Add to My Day',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo, color: Color(0xFFD4AF37)),
              title: const Text('Upload Photo'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Color(0xFFD4AF37)),
              title: const Text('Upload Video (max 15s)'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFD4AF37)),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final picker = ImagePicker();
    XFile? file;
    String mediaType = 'image';

    if (choice == 'photo') {
      file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } else if (choice == 'camera') {
      file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
    } else if (choice == 'video') {
      file = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 15),
      );
      mediaType = 'video';
    }

    if (file == null || !mounted) return;

    // Optional caption
    final captionCtrl = TextEditingController();
    final caption = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add a caption'),
        content: TextField(
          controller: captionCtrl,
          maxLength: 100,
          decoration: const InputDecoration(
            hintText: 'Say something... (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, captionCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
            ),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    captionCtrl.dispose();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Uploading to My Day...')));

    try {
      final bytes = await file.readAsBytes();
      await MyDayService.instance.uploadMyDay(
        bytes: bytes,
        filename: file.name,
        mediaType: mediaType,
        caption: caption ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Posted to My Day!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload: $e')));
    }
  }

  /// A peer user's circle — shows My Day photo as background, note bubble overlay,
  /// online dot. Tapping opens My Day viewer or note viewer.
  Widget _buildPeerNoteCircle(String uid, List<MyDayItem> myDayItems) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final avatar = (data?['avatar'] ?? '') as String;
        final rawName = (data?['name'] ?? 'User') as String;
        final rawNote = (data?['note'] ?? '') as String;
        final noteSetAt = (data?['noteSetAt'] ?? '') as String;
        // Notes expire after 24 hours
        final note =
            (rawNote.isNotEmpty && PresenceService.isNoteActive(noteSetAt))
            ? rawNote
            : '';
        final isOnline = data?['isOnline'] == true;
        final hasNote = note.isNotEmpty;
        final hasMyDay = myDayItems.isNotEmpty;
        final hasContent = hasMyDay || hasNote;

        final firstName = rawName.trim().split(RegExp(r'\s+')).first;
        final displayName = firstName.length > 10
            ? '${firstName.substring(0, 9)}…'
            : firstName;

        // Use the latest My Day media as circle thumbnail
        final thumbUrl = hasMyDay ? myDayItems.first.mediaUrl : '';
        final isVideo = hasMyDay && myDayItems.first.mediaType == 'video';

        return GestureDetector(
          onTap: () {
            if (hasMyDay) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MyDayViewerScreen(
                    uid: uid,
                    userName: rawName,
                    userAvatar: avatar,
                    items: myDayItems,
                  ),
                ),
              );
            } else if (hasNote) {
              _showNoteViewer(
                context,
                rawName,
                avatar,
                note,
                peerId: uid,
                peerName: rawName,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: SizedBox(
              width: 88,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Main circle
                        Positioned(
                          bottom: 0,
                          left: 6,
                          right: 6,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: hasMyDay
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFD4AF37),
                                        Color(0xFFF5E6B3),
                                        Color(0xFFD4AF37),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              border: hasMyDay
                                  ? null
                                  : Border.all(
                                      color: hasNote
                                          ? const Color(0xFFD4AF37)
                                          : const Color(0xFFDDDDDD),
                                      width: hasNote ? 2.5 : 1.5,
                                    ),
                            ),
                            padding: EdgeInsets.all(hasMyDay ? 3 : 2),
                            child: ClipOval(
                              child: hasMyDay && thumbUrl.isNotEmpty
                                  ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          thumbUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              UserAvatar(
                                                photoUrl: avatar,
                                                name: rawName,
                                                radius: 34,
                                              ),
                                        ),
                                        if (isVideo)
                                          const Center(
                                            child: Icon(
                                              Icons.play_circle_fill,
                                              color: Colors.white70,
                                              size: 28,
                                            ),
                                          ),
                                      ],
                                    )
                                  : UserAvatar(
                                      photoUrl: avatar,
                                      name: rawName,
                                      radius: 34,
                                    ),
                            ),
                          ),
                        ),
                        // Green online dot
                        if (isOnline)
                          Positioned(
                            right: 6,
                            bottom: 0,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        // Note bubble overlay — last child so it renders on top
                        if (hasNote)
                          _buildNoteBubble(
                            note,
                            onReply: () => _showNoteViewer(
                              context,
                              rawName,
                              avatar,
                              note,
                              peerId: uid,
                              peerName: rawName,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: hasContent
                          ? const Color(0xFF2C2C2C)
                          : const Color(0xFF888888),
                      fontWeight: hasContent
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Bottom sheet that shows a user's note when tapping their circle.
  /// Pass [peerId] and [peerName] to enable the Reply button.
  void _showNoteViewer(
    BuildContext context,
    String name,
    String avatar,
    String note, {
    String? peerId,
    String? peerName,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User avatar
            UserAvatar(photoUrl: avatar, name: name, radius: 32),
            const SizedBox(height: 12),
            // User name
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C2C2C),
              ),
            ),
            const SizedBox(height: 10),
            // The note in a styled container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5E6B3).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                note,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF2C2C2C),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Reply button — only when peerId is provided
            if (peerId != null && peerId.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.reply, size: 18),
                  label: Text('Reply to ${peerName ?? name}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    try {
                      final convoId = await MessageService.instance
                          .ensureConversationWith(peerId);
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            convoId: convoId,
                            peerId: peerId,
                            peerName: peerName ?? name,
                            initialNoteText: note,
                            initialNoteOwnerName: peerName ?? name,
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open chat: $e')),
                      );
                    }
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Builds a RichText widget that highlights [query] matches in [text].
  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(
        TextSpan(
          text: text.substring(idx, idx + query.length),
          style: const TextStyle(
            backgroundColor: Color(0xFFF5E6B3),
            fontWeight: FontWeight.bold,
            color: Color(0xFF5A4800),
          ),
        ),
      );
      start = idx + query.length;
    }
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: Color(0xFF2C2C2C)),
        children: spans,
      ),
    );
  }
}
