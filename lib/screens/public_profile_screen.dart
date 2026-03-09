import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../main.dart' show CommentsSheet, ShareSheet, SharedPostPreview;
import '../services/message_service.dart';
import 'chat_screen.dart';

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFF5E6B3);

String _fmtCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
  return '$n';
}

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _isFollowing = false;
  bool _followLoading = false;
  // Store streams as fields so they survive outer-StreamBuilder rebuilds.
  late final Stream<AuthUser?> _userStream;
  late final Stream<List<Post>> _postsStream;
  late final Stream<int> _followersStream;
  late final Stream<int> _followingStream;

  @override
  void initState() {
    super.initState();
    _userStream = AuthService.instance.streamUser(widget.userId);
    _postsStream = PostService.instance.streamPostsForUser(widget.userId);
    _followersStream = AuthService.instance.streamFollowersCount(widget.userId);
    _followingStream = AuthService.instance.streamFollowingCount(widget.userId);
    _checkFollowing();
  }

  Future<void> _checkFollowing() async {
    final following = await AuthService.instance.isFollowingById(widget.userId);
    if (mounted) setState(() => _isFollowing = following);
  }

  Future<void> _toggleFollow() async {
    if (_followLoading) return;
    setState(() => _followLoading = true);
    final nowFollowing = await AuthService.instance.toggleFollowById(
      widget.userId,
    );
    if (mounted)
      setState(() {
        _isFollowing = nowFollowing;
        _followLoading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: _userStream,
      builder: (context, userSnap) {
        final user = userSnap.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator(color: _gold)),
          );
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF4F4F4),
          body: CustomScrollView(
            slivers: [
              // ── Banner / App Bar ──────────────────────────────────────
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF333333),
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: user.bannerUrl.isNotEmpty
                      ? Image.network(
                          user.bannerUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _DefaultBanner(),
                        )
                      : _DefaultBanner(),
                ),
              ),

              // ── Profile info ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              color: const Color(0xFFE8D5B7),
                            ),
                            child: ClipOval(
                              child: user.avatarUrl.isNotEmpty
                                  ? Image.network(
                                      user.avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _avatarFallback(user),
                                    )
                                  : _avatarFallback(user),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name.isNotEmpty ? user.name : user.email,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C2C2C),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user.email,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF888888),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (user.bio.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          user.bio,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF555555),
                            height: 1.4,
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Stats row – real-time
                      Row(
                        children: [
                          StreamBuilder<int>(
                            stream: _followersStream,
                            builder: (_, snap) => _StatPill(
                              number: _fmtCount(snap.data ?? 0),
                              label: 'Followers',
                            ),
                          ),
                          const SizedBox(width: 12),
                          StreamBuilder<int>(
                            stream: _followingStream,
                            builder: (_, snap) => _StatPill(
                              number: _fmtCount(snap.data ?? 0),
                              label: 'Following',
                            ),
                          ),
                          const SizedBox(width: 12),
                          StreamBuilder<List<Post>>(
                            stream: _postsStream,
                            builder: (_, snap) => _StatPill(
                              number: '${snap.data?.length ?? 0}',
                              label: 'Posts',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Follow / Unfollow + Message buttons
                      Row(
                        children: [
                          Expanded(
                            child: _followLoading
                                ? const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _gold,
                                      ),
                                    ),
                                  )
                                : _isFollowing
                                ? OutlinedButton.icon(
                                    onPressed: _toggleFollow,
                                    icon: const Icon(
                                      Icons.person_remove_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Unfollow'),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: _gold),
                                      foregroundColor: _gold,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: _toggleFollow,
                                    icon: const Icon(
                                      Icons.person_add_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Follow'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _gold,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final convoId = await MessageService.instance
                                  .ensureConversationWith(widget.userId);
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    convoId: convoId,
                                    peerId: widget.userId,
                                    peerName: user.name.isNotEmpty
                                        ? user.name
                                        : user.email,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.message_rounded, size: 16),
                            label: const Text('Message'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _gold),
                              foregroundColor: _gold,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Posts header ──────────────────────────────────────────
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text(
                    'Posts',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                ),
              ),

              // ── Posts list ────────────────────────────────────────────
              StreamBuilder<List<Post>>(
                stream: _postsStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: _gold),
                        ),
                      ),
                    );
                  }
                  final posts = snap.data ?? [];
                  if (posts.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No posts yet',
                            style: TextStyle(color: Color(0xFF888888)),
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _PublicPostCard(post: posts[index], user: user),
                      childCount: posts.length,
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
    );
  }

  Widget _avatarFallback(AuthUser user) {
    return Container(
      color: const Color(0xFFE8D5B7),
      child: Center(
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─── Default Banner ───────────────────────────────────────────────────────────
class _DefaultBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_gold, _goldLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.landscape, size: 72, color: Colors.white70),
      ),
    );
  }
}

// ─── Stat Pill ────────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String number;
  final String label;
  const _StatPill({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          number,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C2C2C),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
        ),
      ],
    );
  }
}

// ─── Public Post Card ─────────────────────────────────────────────────────────
class _PublicPostCard extends StatefulWidget {
  final Post post;
  final AuthUser user;
  const _PublicPostCard({required this.post, required this.user});

  @override
  State<_PublicPostCard> createState() => _PublicPostCardState();
}

class _PublicPostCardState extends State<_PublicPostCard> {
  bool _showPicker = false;
  bool _busy = false;

  static const _reactionDefs = [
    ('amen', 'Amen', Icons.thumb_up, Color(0xFFD4AF37)),
    ('pray', 'Pray', Icons.pan_tool, Color(0xFF8B9DC3)),
    ('worship', 'Worship', Icons.music_note, Color(0xFF9ACD32)),
    ('love', 'Love', Icons.favorite, Color(0xFFE57373)),
  ];

  String? get _myReaction {
    final u = AuthService.instance.currentUser.value;
    if (u == null) return null;
    for (final e in widget.post.reactions.entries) {
      if (e.value.contains(u.id)) return e.key;
    }
    return null;
  }

  String _fmt(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return ts;
    }
  }

  Future<void> _react(String key) async {
    if (_busy) return;
    final u = AuthService.instance.currentUser.value;
    if (u == null) return;
    setState(() {
      _busy = true;
      _showPicker = false;
    });
    try {
      await PostService.instance.toggleReaction(widget.post.id, key, u.id);
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final myReaction = _myReaction;
    final totalReactions = widget.post.reactions.values.fold<int>(
      0,
      (s, l) => s + l.length,
    );

    return GestureDetector(
      onTap: () {
        if (_showPicker) setState(() => _showPicker = false);
      },
      behavior: HitTestBehavior.translucent,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 6, 0),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE8D5B7),
                      border: Border.all(
                        color: _gold.withOpacity(0.35),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: widget.user.avatarUrl.isNotEmpty
                          ? Image.network(
                              widget.user.avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 22,
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name.isNotEmpty
                              ? widget.user.name
                              : widget.user.email,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: Color(0xFF2C2C2C),
                          ),
                        ),
                        Text(
                          _fmt(widget.post.timestamp),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (widget.post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Text(
                  widget.post.content,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.55,
                    color: Color(0xFF3A3A3A),
                  ),
                ),
              ),

            if (widget.post.isSharedPost)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: SharedPostPreview(
                  authorEmail: widget.post.sharedAuthorEmail ?? '',
                  authorAvatarUrl: widget.post.sharedAuthorAvatarUrl ?? '',
                  content: widget.post.sharedContent ?? '',
                  mediaUrl: widget.post.sharedMediaUrl,
                  mediaType: widget.post.sharedMediaType,
                ),
              ),

            if (!widget.post.isSharedPost &&
                widget.post.mediaUrl != null &&
                widget.post.mediaUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Image.network(
                  widget.post.mediaUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

            if (totalReactions > 0 || widget.post.commentCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  children: [
                    if (totalReactions > 0) ...[
                      ...widget.post.reactions.entries
                          .where((e) => e.value.isNotEmpty)
                          .take(3)
                          .map((entry) {
                            final def = _reactionDefs.firstWhere(
                              (d) => d.$1 == entry.key,
                              orElse: () => _reactionDefs[0],
                            );
                            return Container(
                              margin: const EdgeInsets.only(right: 1),
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: def.$4.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(def.$3, size: 12, color: def.$4),
                            );
                          }),
                      const SizedBox(width: 5),
                      Text(
                        '$totalReactions',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (widget.post.commentCount > 0)
                      InkWell(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => CommentsSheet(
                            post: widget.post,
                            onCommentAdded: () {},
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                            horizontal: 4,
                          ),
                          child: Text(
                            '${widget.post.commentCount} comment${widget.post.commentCount != 1 ? "s" : ""}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Divider(
                height: 1,
                thickness: 0.8,
                color: Color(0xFFEEEEEE),
              ),
            ),

            // Action row
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showPicker)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                      child: _ReactionPicker(
                        myReaction: myReaction,
                        onReact: _react,
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ActionBtn(
                        icon: myReaction != null
                            ? _reactionDefs
                                  .firstWhere(
                                    (d) => d.$1 == myReaction,
                                    orElse: () => _reactionDefs[0],
                                  )
                                  .$3
                            : Icons.thumb_up_outlined,
                        label: myReaction != null
                            ? _reactionDefs
                                  .firstWhere(
                                    (d) => d.$1 == myReaction,
                                    orElse: () => _reactionDefs[0],
                                  )
                                  .$2
                            : 'React',
                        color: myReaction != null
                            ? _reactionDefs
                                  .firstWhere(
                                    (d) => d.$1 == myReaction,
                                    orElse: () => _reactionDefs[0],
                                  )
                                  .$4
                            : null,
                        onTap: () => setState(() => _showPicker = !_showPicker),
                      ),
                      _ActionBtn(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Comment',
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => CommentsSheet(
                            post: widget.post,
                            onCommentAdded: () {},
                          ),
                        ),
                      ),
                      _ActionBtn(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ShareSheet(post: widget.post),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Compact helpers ──────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF888888);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: c),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionPicker extends StatelessWidget {
  final String? myReaction;
  final ValueChanged<String> onReact;
  static const _defs = [
    ('amen', 'Amen', Icons.thumb_up, Color(0xFFD4AF37)),
    ('pray', 'Pray', Icons.pan_tool, Color(0xFF8B9DC3)),
    ('worship', 'Worship', Icons.music_note, Color(0xFF9ACD32)),
    ('love', 'Love', Icons.favorite, Color(0xFFE57373)),
  ];
  const _ReactionPicker({required this.myReaction, required this.onReact});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(40),
      shadowColor: Colors.black.withOpacity(0.15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _defs.map((d) {
            final isActive = myReaction == d.$1;
            return GestureDetector(
              onTap: () => onReact(d.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? d.$4.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  border: isActive
                      ? Border.all(color: d.$4.withOpacity(0.4))
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(d.$3, size: 24, color: d.$4),
                    const SizedBox(height: 3),
                    Text(
                      d.$2,
                      style: TextStyle(
                        fontSize: 10,
                        color: d.$4,
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
}
