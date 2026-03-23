import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import '../services/myday_service.dart';
import '../services/message_service.dart';
import '../widgets/user_avatar.dart';
import '../services/presence_service.dart';

/// Full-screen viewer for a user's My Day items (images & short videos).
/// Swipes through multiple items; auto-advances with a progress bar.
class MyDayViewerScreen extends StatefulWidget {
  final String uid;
  final String userName;
  final String userAvatar;
  final List<MyDayItem> items;

  const MyDayViewerScreen({
    super.key,
    required this.uid,
    required this.userName,
    required this.userAvatar,
    required this.items,
  });

  @override
  State<MyDayViewerScreen> createState() => _MyDayViewerScreenState();
}

class _MyDayViewerScreenState extends State<MyDayViewerScreen>
    with SingleTickerProviderStateMixin {
  int _current = 0;
  late AnimationController _progressCtrl;
  VideoPlayerController? _videoCtrl;

  // Reply / reaction state
  late final bool _isOwner;
  final TextEditingController _replyCtrl = TextEditingController();
  final FocusNode _replyFocus = FocusNode();
  bool _isSending = false;

  // Christian reactions
  static const _reactions = [
    ('\u{1F64F}', 'Amen!'),
    ('\u{1F64C}', 'Praise God!'),
    ('\u2705', 'Glory to God!'),
    ('\u{1F4D6}', 'God\'s Word!'),
    ('\u{1F54A}\uFE0F', 'Peace!'),
    ('\u2764\uFE0F', 'God\'s Love!'),
    ('\u{1F525}', 'Holy Fire!'),
  ];

  @override
  void initState() {
    super.initState();
    _isOwner = FirebaseAuth.instance.currentUser?.uid == widget.uid;
    _progressCtrl = AnimationController(vsync: this);
    _replyFocus.addListener(() {
      if (_replyFocus.hasFocus) {
        _progressCtrl.stop();
      } else {
        if (mounted && !_isSending) _progressCtrl.forward();
      }
    });
    _loadItem(0);
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _videoCtrl?.dispose();
    _replyCtrl.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  void _loadItem(int index) {
    if (index >= widget.items.length) {
      // All items viewed — close
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => _current = index);
    _videoCtrl?.dispose();
    _videoCtrl = null;

    final item = widget.items[index];
    if (item.mediaType == 'video') {
      _loadVideo(item, index);
    } else {
      // Image: show for 5 seconds with progress bar
      _progressCtrl.duration = const Duration(seconds: 5);
      _progressCtrl.forward(from: 0).then((_) {
        if (mounted) _loadItem(index + 1);
      });
    }
  }

  void _loadVideo(MyDayItem item, int index) {
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(item.mediaUrl));
    _videoCtrl = ctrl;
    ctrl.initialize().then((_) {
      if (!mounted) return;
      // Use actual video duration for progress (max 15s)
      final dur = ctrl.value.duration.inMilliseconds > 0
          ? ctrl.value.duration
          : const Duration(seconds: 15);
      _progressCtrl.duration = dur;
      _progressCtrl.forward(from: 0).then((_) {
        if (mounted) _loadItem(index + 1);
      });
      ctrl.play();
      setState(() {});
    });
  }

  void _goNext() {
    _progressCtrl.stop();
    _videoCtrl?.pause();
    _loadItem(_current + 1);
  }

  void _goPrev() {
    _progressCtrl.stop();
    _videoCtrl?.pause();
    if (_current > 0) {
      _loadItem(_current - 1);
    } else {
      _loadItem(0);
    }
  }

  Future<void> _sendReaction(String emoji, String label) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    _progressCtrl.stop();
    try {
      final convoId = await MessageService.instance.ensureConversationWith(
        widget.uid,
      );
      await MessageService.instance.sendMessage(convoId, '$emoji $label');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$emoji Sent!'),
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFFD4AF37),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _progressCtrl.forward();
      }
    }
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _replyFocus.unfocus();
    try {
      final convoId = await MessageService.instance.ensureConversationWith(
        widget.uid,
      );
      await MessageService.instance.sendMessage(convoId, text);
      _replyCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message sent! \u2728'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFFD4AF37),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showMoreOptions(BuildContext context) {
    final item = widget.items[_current];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Delete this story',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Remove this item from your My Day',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dlg) => AlertDialog(
                    backgroundColor: const Color(0xFF2A2A2A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Delete this story?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'This story will be permanently removed.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dlg, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dlg, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm != true || !mounted) return;
                await MyDayService.instance.deleteMyDay(item.id);
                if (!mounted) return;
                if (widget.items.length == 1) {
                  Navigator.pop(context); // last story deleted — close viewer
                } else {
                  _goNext(); // advance to next story
                }
              },
            ),
            if (widget.items.length > 1)
              ListTile(
                leading: const Icon(
                  Icons.delete_forever,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Delete all stories',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'Remove all ${widget.items.length} stories from your My Day',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dlg) => AlertDialog(
                      backgroundColor: const Color(0xFF2A2A2A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text(
                        'Delete all stories?',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: Text(
                        'All ${widget.items.length} stories will be permanently removed from your My Day.',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dlg, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dlg, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Delete All'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true || !mounted) return;
                  for (final i in widget.items) {
                    await MyDayService.instance.deleteMyDay(i.id);
                  }
                  if (mounted) Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_current];
    final timeAgo = PresenceService.formatLastSeen(
      item.createdAt,
    ).replaceFirst('Last seen ', '');

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Media content ──────────────────────────────────────────
          if (item.mediaType == 'video' &&
              _videoCtrl != null &&
              _videoCtrl!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _videoCtrl!.value.aspectRatio,
                child: VideoPlayer(_videoCtrl!),
              ),
            )
          else if (item.mediaType == 'image')
            Image.network(
              item.mediaUrl,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                );
              },
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            )
          else
            // Video loading
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            ),

          // ── Tap zone for prev/next (excludes bottom bar) ──────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: _isOwner ? 0 : 110,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) {
                if (details.localPosition.dx <
                    MediaQuery.of(context).size.width / 2) {
                  _goPrev();
                } else {
                  _goNext();
                }
              },
            ),
          ),

          // ── Top: progress bars + user info ─────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Segmented progress bars (one per item)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: List.generate(widget.items.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: SizedBox(
                                height: 3,
                                child: i < _current
                                    ? const LinearProgressIndicator(
                                        value: 1,
                                        backgroundColor: Colors.white30,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      )
                                    : i == _current
                                    ? AnimatedBuilder(
                                        animation: _progressCtrl,
                                        builder: (_, __) =>
                                            LinearProgressIndicator(
                                              value: _progressCtrl.value,
                                              backgroundColor: Colors.white30,
                                              valueColor:
                                                  const AlwaysStoppedAnimation(
                                                    Colors.white,
                                                  ),
                                            ),
                                      )
                                    : const LinearProgressIndicator(
                                        value: 0,
                                        backgroundColor: Colors.white30,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white30,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // User info row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        UserAvatar(
                          photoUrl: widget.userAvatar,
                          name: widget.userName,
                          radius: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (timeAgo.isNotEmpty)
                                Text(
                                  timeAgo,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // 3-dot menu — only for the owner
                        if (_isOwner)
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                            ),
                            onPressed: () => _showMoreOptions(context),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom caption ──────────────────────────────────────────
          if (item.caption.isNotEmpty)
            Positioned(
              bottom: _isOwner ? 0 : 110,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Text(
                    item.caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.4,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                    ),
                  ),
                ),
              ),
            ),

          // ── Bottom reply bar (non-owner only) ────────────────────────
          if (!_isOwner)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Reaction row ────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: _reactions.map((r) {
                            final emoji = r.$1;
                            final label = r.$2;
                            return GestureDetector(
                              onTap: _isSending
                                  ? null
                                  : () => _sendReaction(emoji, label),
                              child: Tooltip(
                                message: label,
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // ── Reply text field ────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                                child: TextField(
                                  controller: _replyCtrl,
                                  focusNode: _replyFocus,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Reply to \${widget.userName}...',
                                    hintStyle: TextStyle(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                  ),
                                  onSubmitted: (_) => _sendReply(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _sendReply,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD4AF37),
                                  shape: BoxShape.circle,
                                ),
                                child: _isSending
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
