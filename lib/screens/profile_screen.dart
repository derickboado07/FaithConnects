import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../main.dart' show CommentsSheet, ShareSheet, SharedPostPreview;

// ─── Color constants ──────────────────────────────────────────────────────────
const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFF5E6B3);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = AuthService.instance.currentUser.value;
    if (user == null) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    _showUploadSnack('Uploading profile photo...');
    bool ok;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      ok = await AuthService.instance.updateProfile(
        email: user.email,
        avatarBytes: bytes,
        avatarFilename: file.name,
      );
    } else {
      ok = await AuthService.instance.updateProfile(
        email: user.email,
        avatarPath: file.path,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Profile photo updated!' : 'Upload failed. Try again.',
        ),
        backgroundColor: ok ? _gold : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickAndUploadBanner() async {
    final user = AuthService.instance.currentUser.value;
    if (user == null) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    _showUploadSnack('Uploading cover photo...');
    bool ok;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      ok = await AuthService.instance.updateProfile(
        email: user.email,
        bannerBytes: bytes,
        bannerFilename: file.name,
      );
    } else {
      ok = await AuthService.instance.updateProfile(
        email: user.email,
        bannerPath: file.path,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Cover photo updated!' : 'Upload failed. Try again.',
        ),
        backgroundColor: ok ? _gold : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showUploadSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(msg),
          ],
        ),
        backgroundColor: _gold,
        duration: const Duration(minutes: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _shareProfile(AuthUser user) async {
    final url =
        'https://faithconnect.page.link/u/${Uri.encodeComponent(user.email)}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.link, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Profile link copied!'),
          ],
        ),
        backgroundColor: const Color(0xFF64B5F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: ValueListenableBuilder<AuthUser?>(
        valueListenable: AuthService.instance.currentUser,
        builder: (context, user, _) {
          if (user == null) {
            return SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: _goldLight.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 44,
                        color: _gold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Not logged in',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF444444),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to access your profile',
                      style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 180,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // ── Banner / App Bar ──────────────────────────────────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF333333),
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout_rounded),
                    tooltip: 'Logout',
                    onPressed: () async {
                      await AuthService.instance.logout();
                      if (!context.mounted) return;
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Banner image or default gradient
                      user.bannerUrl.isNotEmpty
                          ? Image.network(
                              user.bannerUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _DefaultBanner(),
                            )
                          : _DefaultBanner(),
                      // Bottom gradient fade
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.45),
                            ],
                            stops: const [0.55, 1.0],
                          ),
                        ),
                      ),
                      // Edit cover button
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: _pickAndUploadBanner,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Edit Cover',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                      // Avatar + name row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Avatar with camera badge
                          Stack(
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
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
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: _pickAndUploadAvatar,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: _gold,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          // Name + email
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name.isNotEmpty
                                      ? user.name
                                      : 'Your Name',
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

                      // Stats row
                      Row(
                        children: [
                          _StatPill(number: '2.5K', label: 'Followers'),
                          const SizedBox(width: 12),
                          _StatPill(number: '890', label: 'Following'),
                          const SizedBox(width: 12),
                          _StatPill(number: '-', label: 'Posts'),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/edit_profile'),
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: const Text('Edit Profile'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _gold,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => _shareProfile(user),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _gold),
                              foregroundColor: _gold,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 16,
                              ),
                            ),
                            child: const Icon(Icons.share_rounded, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Create Post bar ───────────────────────────────────────
              SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/create_post'),
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    color: Colors.white,
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
                          child: user.avatarUrl.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    user.avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 22,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F4F4),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFEEEEEE),
                              ),
                            ),
                            child: const Text(
                              'Share your testimony...',
                              style: TextStyle(
                                color: Color(0xFFAAAAAA),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: _goldLight.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.photo_camera_outlined,
                            color: _gold,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Posts header ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: const Text(
                    'Posts',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                ),
              ),

              // ── Posts list (real-time stream) ─────────────────────────
              StreamBuilder<List<Post>>(
                stream: PostService.instance.streamPostsForUser(user.id),
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
                  if (snap.hasError) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Failed to load posts',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ),
                    );
                  }
                  final posts = snap.data ?? [];
                  if (posts.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 32,
                          horizontal: 24,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: _goldLight.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.article_outlined,
                                  size: 32,
                                  color: _gold,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No posts yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF444444),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Share your first testimony!',
                                style: TextStyle(
                                  color: Color(0xFF888888),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ProfilePostCard(
                        post: posts[index],
                        user: user,
                        onRefresh: () {},
                      ),
                      childCount: posts.length,
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
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

// ─── Profile Post Card ────────────────────────────────────────────────────────
class _ProfilePostCard extends StatefulWidget {
  final Post post;
  final AuthUser user;
  final VoidCallback onRefresh;
  const _ProfilePostCard({
    required this.post,
    required this.user,
    required this.onRefresh,
  });

  @override
  State<_ProfilePostCard> createState() => _ProfilePostCardState();
}

class _ProfilePostCardState extends State<_ProfilePostCard> {
  bool _showPicker = false;
  bool _saved = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final u = AuthService.instance.currentUser.value;
    if (u == null) return;
    try {
      final s = await PostService.instance.isSaved(widget.post.id, u.id);
      if (mounted) setState(() => _saved = s);
    } catch (_) {}
  }

  String? get _myReaction {
    final u = AuthService.instance.currentUser.value;
    if (u == null) return null;
    for (final e in widget.post.reactions.entries) {
      if (e.value.contains(u.id)) return e.key;
    }
    return null;
  }

  static const _reactionDefs = [
    ('amen', 'Amen', Icons.thumb_up, Color(0xFFD4AF37)),
    ('pray', 'Pray', Icons.pan_tool, Color(0xFF8B9DC3)),
    ('worship', 'Worship', Icons.music_note, Color(0xFF9ACD32)),
    ('love', 'Love', Icons.favorite, Color(0xFFE57373)),
  ];

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
      widget.onRefresh();
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toggleSave() async {
    final u = AuthService.instance.currentUser.value;
    if (u == null) return;
    setState(() => _saved = !_saved);
    try {
      await PostService.instance.toggleSave(widget.post.id, u.id);
    } catch (_) {
      if (mounted) setState(() => _saved = !_saved);
    }
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
                  Builder(
                    builder: (ctx) {
                      final current = AuthService.instance.currentUser.value;
                      final isOwner =
                          current != null && current.id == widget.post.authorId;
                      return PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_horiz,
                          color: Color(0xFFAAAAAA),
                        ),
                        onSelected: (v) async {
                          if (v == 'delete') {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete post?'),
                                content: const Text('This cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              try {
                                await PostService.instance.deletePost(
                                  widget.post.id,
                                );
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Post deleted'),
                                    backgroundColor: _gold,
                                  ),
                                );
                              } catch (_) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to delete post'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          if (isOwner)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // Content
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

            // Shared post card (embedded original post)
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

            // Media (only for non-shared posts)
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

            // Reaction summary
            if (totalReactions > 0 || widget.post.comments.isNotEmpty)
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
                    if (widget.post.comments.isNotEmpty)
                      Text(
                        '${widget.post.comments.length} comment${widget.post.comments.length != 1 ? "s" : ""}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888888),
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
                      child: _ProfileReactionPicker(
                        myReaction: myReaction,
                        onReact: _react,
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // React
                      _ProfileActionBtn(
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
                      // Comment
                      _ProfileActionBtn(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Comment',
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => CommentsSheet(
                            post: widget.post,
                            onCommentAdded: widget.onRefresh,
                          ),
                        ),
                      ),
                      // Share
                      _ProfileActionBtn(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ShareSheet(post: widget.post),
                        ),
                      ),
                      // Save
                      _ProfileActionBtn(
                        icon: _saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        label: 'Save',
                        color: _saved ? _gold : null,
                        onTap: _toggleSave,
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

// ─── Profile Reaction Picker ──────────────────────────────────────────────────
class _ProfileReactionPicker extends StatelessWidget {
  final String? myReaction;
  final ValueChanged<String> onReact;
  const _ProfileReactionPicker({
    required this.myReaction,
    required this.onReact,
  });

  static const _defs = [
    ('amen', 'Amen', Icons.thumb_up, Color(0xFFD4AF37)),
    ('pray', 'Pray', Icons.pan_tool, Color(0xFF8B9DC3)),
    ('worship', 'Worship', Icons.music_note, Color(0xFF9ACD32)),
    ('love', 'Love', Icons.favorite, Color(0xFFE57373)),
  ];

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

// ─── Profile Action Button ────────────────────────────────────────────────────
class _ProfileActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ProfileActionBtn({
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
            Icon(icon, size: 18, color: c),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: c,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
