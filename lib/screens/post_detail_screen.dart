import 'package:flutter/material.dart';
import '../services/post_service.dart';
import '../services/auth_service.dart';

const List<_ReactionInfo> _postReactions = [
  _ReactionInfo('amen', 'Amen', Icons.thumb_up, Color(0xFFD4AF37)),
  _ReactionInfo('pray', 'Pray', Icons.pan_tool, Color(0xFF8B9DC3)),
  _ReactionInfo('worship', 'Worship', Icons.music_note, Color(0xFF9ACD32)),
  _ReactionInfo('love', 'Love', Icons.favorite, Color(0xFFE57373)),
];

class _ReactionInfo {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _ReactionInfo(this.key, this.label, this.icon, this.color);
}

class PostDetailScreen extends StatefulWidget {
  final Post post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post _post;
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? get _myReaction {
    final me = AuthService.instance.currentUser.value;
    if (me == null) return null;
    for (final e in _post.reactions.entries) {
      if ((e.value).contains(me.id)) return e.key;
    }
    return null;
  }

  int get _totalReactions {
    var tot = 0;
    for (final v in _post.reactions.values) tot += v.length;
    return tot;
  }

  void _showReactionPicker() {
    final me = AuthService.instance.currentUser.value;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to react')));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _postReactions.map((r) {
            final isActive = (_post.reactions[r.key] ?? []).contains(me.id);
            return GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                await PostService.instance.toggleReaction(_post.id, r.key, me.id);
                final refreshed = await PostService.instance.getById(_post.id);
                if (refreshed != null && mounted) setState(() => _post = refreshed);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(r.icon, size: 28, color: r.color),
                  const SizedBox(height: 6),
                  Text(r.label, style: TextStyle(color: r.color)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _postComment() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    final me = AuthService.instance.currentUser.value;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to comment')));
      return;
    }
    await PostService.instance.addComment(_post.id, me.id, me.email, txt);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Row(
                  children: [
                    CircleAvatar(backgroundImage: _post.authorAvatarUrl.isNotEmpty ? NetworkImage(_post.authorAvatarUrl) : null, child: _post.authorAvatarUrl.isEmpty ? Text(_post.authorEmail.isNotEmpty ? _post.authorEmail[0].toUpperCase() : '?') : null),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_post.authorEmail, style: const TextStyle(fontWeight: FontWeight.bold))),
                    Text(_post.timestamp.split('T').first, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_post.content),
                if (_post.mediaUrl != null && _post.mediaUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Image.network(_post.mediaUrl!),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  IconButton(onPressed: _showReactionPicker, icon: const Icon(Icons.emoji_emotions_outlined)),
                  Text('$_totalReactions'),
                  const SizedBox(width: 12),
                  IconButton(onPressed: () async { /* share - optional */ }, icon: const Icon(Icons.share_outlined)),
                ]),
                const Divider(),
                const SizedBox(height: 6),
                const Text('Comments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                StreamBuilder<List<Comment>>(
                  stream: PostService.instance.streamComments(_post.id),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final comments = snap.data ?? [];
                    if (comments.isEmpty) return const Center(child: Text('No comments yet'));
                    return Column(
                      children: comments.map((c) => ListTile(
                        title: Text(c.author),
                        subtitle: Text(c.text),
                      )).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: TextField(controller: _ctrl, decoration: const InputDecoration(hintText: 'Write a comment...')),
                )),
                IconButton(onPressed: _postComment, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
