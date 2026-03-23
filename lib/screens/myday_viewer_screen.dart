import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/myday_service.dart';
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

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this);
    _loadItem(0);
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _videoCtrl?.dispose();
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

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_current];
    final timeAgo = PresenceService.formatLastSeen(
      item.createdAt,
    ).replaceFirst('Last seen ', '');

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          // Tap left half → previous, right half → next
          if (details.globalPosition.dx <
              MediaQuery.of(context).size.width / 2) {
            _goPrev();
          } else {
            _goNext();
          }
        },
        child: Stack(
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
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
                bottom: 0,
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
          ],
        ),
      ),
    );
  }
}
