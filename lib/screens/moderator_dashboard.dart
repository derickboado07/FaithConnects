import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/moderator_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODERATOR DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────

class ModeratorDashboard extends StatefulWidget {
  const ModeratorDashboard({super.key});

  @override
  State<ModeratorDashboard> createState() => _ModeratorDashboardState();
}

class _ModeratorDashboardState extends State<ModeratorDashboard> {
  static const _gold = Color(0xFFD4AF37);
  static const _bg = Color(0xFF1A1A2E);
  static const _card = Color(0xFF16213E);

  int _selectedIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(Icons.dashboard_outlined, 'Overview'),
    _NavItem(Icons.article_outlined, 'Posts'),
    _NavItem(Icons.comment_outlined, 'Comments'),
    _NavItem(Icons.people_outlined, 'Users'),
    _NavItem(Icons.report_outlined, 'Reports'),
    _NavItem(Icons.history_outlined, 'Logs'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text(
          'Moderator Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService.instance.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // ── Sidebar ────────────────────────────────────────────────
          Container(
            width: 220,
            color: _card,
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Moderator identity
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: _gold,
                        child: Icon(
                          Icons.shield,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AuthService.instance.currentUser.value?.name ??
                              'Moderator',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF2D2D44), height: 24),
                // Nav items
                for (int i = 0; i < _navItems.length; i++)
                  _SidebarTile(
                    icon: _navItems[i].icon,
                    label: _navItems[i].label,
                    selected: _selectedIndex == i,
                    onTap: () => setState(() => _selectedIndex = i),
                  ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'FaithConnect Admin',
                    style: TextStyle(
                      color: Color(0xFF5A5A7A),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Content area ───────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                _OverviewTab(),
                _PostsTab(),
                _CommentsTab(),
                _UsersTab(),
                _ReportsTab(),
                _LogsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? _gold.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? _gold : Colors.white54,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? _gold : Colors.white70,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPER: confirmation dialog
// ═════════════════════════════════════════════════════════════════════════════

Future<bool> _confirmAction(
  BuildContext context,
  String title,
  String message,
) async {
  const gold = Color(0xFFD4AF37);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF16213E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(message, style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  return result == true;
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPER: section header
// ═════════════════════════════════════════════════════════════════════════════

Widget _sectionTitle(String text) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFFD4AF37),
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 0 – OVERVIEW (Analytics)
// ═════════════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  Map<String, int>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await ModeratorService.instance.getDashboardStats();
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      );
    }
    final s = _stats!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                icon: Icons.people,
                label: 'Total Users',
                value: '${s['totalUsers']}',
                color: Colors.blueAccent,
              ),
              _StatCard(
                icon: Icons.article,
                label: 'Total Posts',
                value: '${s['totalPosts']}',
                color: Colors.greenAccent,
              ),
              _StatCard(
                icon: Icons.report,
                label: 'Total Reports',
                value: '${s['totalReports']}',
                color: Colors.orangeAccent,
              ),
              _StatCard(
                icon: Icons.block,
                label: 'Banned Users',
                value: '${s['bannedUsers']}',
                color: Colors.redAccent,
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Stats'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2D44)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1 – POSTS MANAGEMENT
// ═════════════════════════════════════════════════════════════════════════════

class _PostsTab extends StatefulWidget {
  const _PostsTab();

  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab> {
  String _filter = 'all'; // all | active | hidden
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Posts Management'),
        // Filter chips + search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _MiniChip(
                label: 'All',
                selected: _filter == 'all',
                onTap: () => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 8),
              _MiniChip(
                label: 'Active',
                selected: _filter == 'active',
                onTap: () => setState(() => _filter = 'active'),
              ),
              const SizedBox(width: 8),
              _MiniChip(
                label: 'Hidden',
                selected: _filter == 'hidden',
                onTap: () => setState(() => _filter = 'hidden'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search posts…',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white38,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF16213E),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Post list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: ModeratorService.instance.streamPosts(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFD4AF37),
                  ),
                );
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No posts found.',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }
              var docs = snap.data!.docs;
              // Filter by status
              if (_filter != 'all') {
                docs = docs.where((d) {
                  final status = d.data() is Map
                      ? (d.data() as Map)['status'] ?? 'active'
                      : 'active';
                  return status == _filter;
                }).toList();
              }
              // Filter by search
              final query = _searchCtrl.text.trim().toLowerCase();
              if (query.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final content =
                      (data['content'] as String? ?? '').toLowerCase();
                  final author =
                      (data['authorEmail'] as String? ?? '').toLowerCase();
                  return content.contains(query) || author.contains(query);
                }).toList();
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] as String? ?? 'active';
                  final isHidden = status == 'hidden';
                  return _PostCard(
                    postId: doc.id,
                    data: data,
                    isHidden: isHidden,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> data;
  final bool isHidden;

  const _PostCard({
    required this.postId,
    required this.data,
    required this.isHidden,
  });

  @override
  Widget build(BuildContext context) {
    final content = data['content'] as String? ?? '';
    final author = data['authorEmail'] as String? ?? 'Unknown';
    final ts = data['timestamp'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHidden
              ? Colors.orangeAccent.withValues(alpha: 0.4)
              : const Color(0xFF2D2D44),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  author,
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isHidden)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'HIDDEN',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                _formatTs(ts),
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content.length > 200 ? '${content.substring(0, 200)}…' : content,
            style: TextStyle(
              color: isHidden ? Colors.white38 : Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (!isHidden)
                _ActionBtn(
                  icon: Icons.visibility_off,
                  label: 'Hide',
                  color: Colors.orangeAccent,
                  onTap: () async {
                    if (await _confirmAction(
                      context,
                      'Hide Post',
                      'This post will be hidden from users. Continue?',
                    )) {
                      await ModeratorService.instance.hidePost(postId);
                    }
                  },
                ),
              if (isHidden)
                _ActionBtn(
                  icon: Icons.visibility,
                  label: 'Restore',
                  color: Colors.greenAccent,
                  onTap: () async {
                    if (await _confirmAction(
                      context,
                      'Restore Post',
                      'Restore this post so all users can see it?',
                    )) {
                      await ModeratorService.instance.restorePost(postId);
                    }
                  },
                ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: Icons.delete_forever,
                label: 'Delete',
                color: Colors.redAccent,
                onTap: () async {
                  if (await _confirmAction(
                    context,
                    'Delete Post',
                    'Are you sure you want to permanently delete this post? This cannot be undone.',
                  )) {
                    await ModeratorService.instance.deletePost(postId);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 – COMMENTS MANAGEMENT
// ═════════════════════════════════════════════════════════════════════════════

class _CommentsTab extends StatefulWidget {
  const _CommentsTab();

  @override
  State<_CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<_CommentsTab> {
  String _filter = 'all'; // all | active | removed
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Comments Management'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _MiniChip(
                label: 'All',
                selected: _filter == 'all',
                onTap: () => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 8),
              _MiniChip(
                label: 'Active',
                selected: _filter == 'active',
                onTap: () => setState(() => _filter = 'active'),
              ),
              const SizedBox(width: 8),
              _MiniChip(
                label: 'Removed',
                selected: _filter == 'removed',
                onTap: () => setState(() => _filter = 'removed'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search comments…',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white38,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF16213E),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: ModeratorService.instance.streamComments(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFD4AF37),
                  ),
                );
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No comments found.',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }
              var docs = snap.data!.docs;
              if (_filter != 'all') {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final status = data['status'] as String? ?? 'active';
                  return status == _filter;
                }).toList();
              }
              final query = _searchCtrl.text.trim().toLowerCase();
              if (query.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final content =
                      (data['content'] as String? ?? '').toLowerCase();
                  return content.contains(query);
                }).toList();
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] as String? ?? 'active';
                  final isRemoved = status == 'removed';
                  return _CommentCard(
                    commentId: doc.id,
                    data: data,
                    isRemoved: isRemoved,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  final String commentId;
  final Map<String, dynamic> data;
  final bool isRemoved;

  const _CommentCard({
    required this.commentId,
    required this.data,
    required this.isRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final content = data['content'] as String? ?? '';
    final userId = data['userId'] as String? ?? 'Unknown';
    final postId = data['postId'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRemoved
              ? Colors.redAccent.withValues(alpha: 0.3)
              : const Color(0xFF2D2D44),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'User: $userId',
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (postId.isNotEmpty)
                Text(
                  'Post: ${postId.length > 8 ? '${postId.substring(0, 8)}…' : postId}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              if (isRemoved) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'REMOVED',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              color: isRemoved ? Colors.white38 : Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (!isRemoved)
                _ActionBtn(
                  icon: Icons.remove_circle_outline,
                  label: 'Remove',
                  color: Colors.redAccent,
                  onTap: () async {
                    if (await _confirmAction(
                      context,
                      'Remove Comment',
                      'Remove this comment? It will be hidden from users.',
                    )) {
                      await ModeratorService.instance
                          .removeComment(commentId);
                    }
                  },
                ),
              if (isRemoved)
                _ActionBtn(
                  icon: Icons.restore,
                  label: 'Restore',
                  color: Colors.greenAccent,
                  onTap: () async {
                    if (await _confirmAction(
                      context,
                      'Restore Comment',
                      'Restore this comment?',
                    )) {
                      await ModeratorService.instance
                          .restoreComment(commentId);
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 3 – USERS MANAGEMENT
// ═════════════════════════════════════════════════════════════════════════════

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _filter = 'all'; // all | active | banned
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('User Management'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _MiniChip(
                label: 'All',
                selected: _filter == 'all',
                onTap: () => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 8),
              _MiniChip(
                label: 'Active',
                selected: _filter == 'active',
                onTap: () => setState(() => _filter = 'active'),
              ),
              const SizedBox(width: 8),
              _MiniChip(
                label: 'Banned',
                selected: _filter == 'banned',
                onTap: () => setState(() => _filter = 'banned'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search users…',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white38,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF16213E),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: ModeratorService.instance.streamUsers(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFD4AF37),
                  ),
                );
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No users found.',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }
              var docs = snap.data!.docs;
              if (_filter != 'all') {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final status = data['status'] as String? ?? 'active';
                  return status == _filter;
                }).toList();
              }
              final query = _searchCtrl.text.trim().toLowerCase();
              if (query.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] as String? ?? '').toLowerCase();
                  final email = (data['email'] as String? ?? '').toLowerCase();
                  return name.contains(query) || email.contains(query);
                }).toList();
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return _UserCard(userId: doc.id, data: data);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> data;

  const _UserCard({required this.userId, required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Unknown';
    final email = data['email'] as String? ?? '';
    final status = data['status'] as String? ?? 'active';
    final role = data['role'] as String? ?? 'user';
    final isBanned = status == 'banned';
    final canPost = data['canPost'] as bool? ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBanned
              ? Colors.redAccent.withValues(alpha: 0.4)
              : const Color(0xFF2D2D44),
        ),
      ),
      child: Row(
        children: [
          // Avatar placeholder
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (role == 'moderator')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'MOD',
                          style: TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (isBanned) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'BANNED',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    if (!canPost) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'NO POST',
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Actions
          if (role != 'moderator') ...[
            if (!isBanned)
              _ActionBtn(
                icon: Icons.block,
                label: 'Ban',
                color: Colors.redAccent,
                onTap: () async {
                  if (await _confirmAction(
                    context,
                    'Ban User',
                    'Ban this user? They will not be able to access the app.',
                  )) {
                    await ModeratorService.instance.banUser(userId);
                  }
                },
              ),
            if (isBanned)
              _ActionBtn(
                icon: Icons.check_circle_outline,
                label: 'Unban',
                color: Colors.greenAccent,
                onTap: () async {
                  if (await _confirmAction(
                    context,
                    'Unban User',
                    'Restore this user\'s access?',
                  )) {
                    await ModeratorService.instance.unbanUser(userId);
                  }
                },
              ),
            const SizedBox(width: 6),
            if (canPost)
              _ActionBtn(
                icon: Icons.edit_off,
                label: 'Disable Post',
                color: Colors.orangeAccent,
                onTap: () async {
                  if (await _confirmAction(
                    context,
                    'Disable Posting',
                    'Disable posting for this user?',
                  )) {
                    await ModeratorService.instance.disablePosting(userId);
                  }
                },
              ),
            if (!canPost)
              _ActionBtn(
                icon: Icons.edit,
                label: 'Enable Post',
                color: Colors.greenAccent,
                onTap: () async {
                  if (await _confirmAction(
                    context,
                    'Enable Posting',
                    'Allow this user to post again?',
                  )) {
                    await ModeratorService.instance.enablePosting(userId);
                  }
                },
              ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 4 – REPORTS MANAGEMENT
// ═════════════════════════════════════════════════════════════════════════════

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  String _filter = 'all'; // all | pending | resolved

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Report Management'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _MiniChip(
                label: 'All',
                selected: _filter == 'all',
                onTap: () => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 8),
              _MiniChip(
                label: 'Pending',
                selected: _filter == 'pending',
                onTap: () => setState(() => _filter = 'pending'),
              ),
              const SizedBox(width: 8),
              _MiniChip(
                label: 'Resolved',
                selected: _filter == 'resolved',
                onTap: () => setState(() => _filter = 'resolved'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: ModeratorService.instance.streamReports(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFD4AF37),
                  ),
                );
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No reports found.',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }
              var docs = snap.data!.docs;
              if (_filter != 'all') {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final status = data['status'] as String? ?? 'pending';
                  return status == _filter;
                }).toList();
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return _ReportCard(reportId: doc.id, data: data);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String reportId;
  final Map<String, dynamic> data;

  const _ReportCard({required this.reportId, required this.data});

  @override
  Widget build(BuildContext context) {
    final targetId = data['targetId'] as String? ?? '';
    final type = data['type'] as String? ?? 'post';
    final reason = data['reason'] as String? ?? 'No reason';
    final status = data['status'] as String? ?? 'pending';
    final reportedBy = data['reportedBy'] as String? ?? 'Unknown';
    final isPending = status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending
              ? Colors.orangeAccent.withValues(alpha: 0.3)
              : Colors.greenAccent.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                type == 'post' ? Icons.article : Icons.comment,
                color: Colors.white38,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '${type.toUpperCase()} Report',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isPending
                      ? Colors.orangeAccent.withValues(alpha: 0.15)
                      : Colors.greenAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: isPending ? Colors.orangeAccent : Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Reason: $reason',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reported by: $reportedBy',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          Text(
            'Target ID: ${targetId.length > 16 ? '${targetId.substring(0, 16)}…' : targetId}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          if (isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _ActionBtn(
                  icon: Icons.delete,
                  label: 'Delete Content',
                  color: Colors.redAccent,
                  onTap: () async {
                    if (await _confirmAction(
                      context,
                      'Delete Reported Content',
                      'Delete the reported $type and resolve this report?',
                    )) {
                      await ModeratorService.instance
                          .deleteReportedContent(reportId, targetId, type);
                    }
                  },
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.check,
                  label: 'Resolve',
                  color: Colors.greenAccent,
                  onTap: () async {
                    if (await _confirmAction(
                      context,
                      'Resolve Report',
                      'Mark this report as resolved?',
                    )) {
                      await ModeratorService.instance
                          .resolveReport(reportId);
                    }
                  },
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.close,
                  label: 'Ignore',
                  color: Colors.white54,
                  onTap: () async {
                    if (await _confirmAction(
                      context,
                      'Ignore Report',
                      'Ignore this report and mark as resolved?',
                    )) {
                      await ModeratorService.instance
                          .ignoreReport(reportId);
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 5 – LOGS VIEWER
// ═════════════════════════════════════════════════════════════════════════════

class _LogsTab extends StatelessWidget {
  const _LogsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Moderator Action Logs'),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: ModeratorService.instance.streamLogs(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFD4AF37),
                  ),
                );
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No logs yet.',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }
              final docs = snap.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final action = data['action'] as String? ?? '';
                  final modId = data['moderatorId'] as String? ?? '';
                  final targetId = data['targetId'] as String? ?? '';
                  final ts = data['timestamp'];
                  String timeStr = '';
                  if (ts is Timestamp) {
                    final dt = ts.toDate();
                    timeStr =
                        '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
                        '${_pad(dt.hour)}:${_pad(dt.minute)}';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16213E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _logIcon(action),
                          size: 18,
                          color: _logColor(action),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(
                                  color: _logColor(action),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Target: ${targetId.length > 16 ? '${targetId.substring(0, 16)}…' : targetId}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                'Mod: ${modId.length > 16 ? '${modId.substring(0, 16)}…' : modId}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _MiniChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MiniChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _gold : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _gold : const Color(0xFF2D2D44),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═════════════════════════════════════════════════════════════════════════════

String _formatTs(String timestamp) {
  if (timestamp.isEmpty) return '';
  try {
    final dt = DateTime.parse(timestamp);
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}';
  } catch (_) {
    return timestamp;
  }
}

String _pad(int n) => n.toString().padLeft(2, '0');

IconData _logIcon(String action) {
  if (action.contains('delete')) return Icons.delete;
  if (action.contains('hide')) return Icons.visibility_off;
  if (action.contains('restore')) return Icons.restore;
  if (action.contains('ban')) return Icons.block;
  if (action.contains('unban')) return Icons.check_circle;
  if (action.contains('remove')) return Icons.remove_circle;
  if (action.contains('resolve') || action.contains('ignore')) {
    return Icons.flag;
  }
  if (action.contains('disable') || action.contains('enable')) {
    return Icons.edit;
  }
  return Icons.history;
}

Color _logColor(String action) {
  if (action.contains('delete') || action.contains('ban') ||
      action.contains('remove')) {
    return Colors.redAccent;
  }
  if (action.contains('hide') || action.contains('disable')) {
    return Colors.orangeAccent;
  }
  if (action.contains('restore') || action.contains('unban') ||
      action.contains('enable')) {
    return Colors.greenAccent;
  }
  if (action.contains('resolve') || action.contains('ignore')) {
    return Colors.blueAccent;
  }
  return Colors.white54;
}
