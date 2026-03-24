// ═══════════════════════════════════════════════════════════════════════════
// MARKETPLACE FEED — Interleaved feed na nag-mi-mix ng posts at products.
// Ginagamit ang pagination (infinite scroll) para i-load ang mga items.
// Ang posts at products ay sine-sort by timestamp at alternating na
// ini-insert para varied ang feed experience.
//
// Key features:
//   • Lazy loading with scroll listener
//   • Pull-to-refresh
//   • Post cards at product cards na magkahaluan
//   • Navigation papunta sa post detail o product detail
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/post_service.dart';
import '../services/marketplace_service.dart';
import '../services/auth_service.dart';
import '../screens/product_detail_screen.dart';
import '../screens/public_profile_screen.dart';
import '../screens/post_detail_screen.dart';
import '../services/message_service.dart';
import '../screens/chat_screen.dart';
import '../models/product_model.dart';

/// Internal model na nagre-represent ng isang feed item (post o product).
class _FeedItem {
  final DateTime ts;      // Timestamp para sa sorting
  final Post? post;       // Post data (null kung product)
  final dynamic product; // Product (null kung post)
  _FeedItem({required this.ts, this.post, this.product});
}

class MarketplaceFeed extends StatefulWidget {
  const MarketplaceFeed({Key? key}) : super(key: key);

  @override
  State<MarketplaceFeed> createState() => MarketplaceFeedState();
}

class MarketplaceFeedState extends State<MarketplaceFeed> {
  final List<Post> _posts = [];         // Na-load na posts
  final List<Product> _products = [];   // Na-load na products
  final List<_FeedItem> _items = [];    // Merged at sorted feed items

  final ScrollController _sc = ScrollController(); // Para sa infinite scroll detection
  bool _loading = false;     // True habang nag-lo-load ng bagong items
  bool _postHasMore = true;  // True kung may pa talagang posts na pwede i-load
  bool _prodHasMore = true;  // True kung may pa talagang products na pwede i-load
  static const int _pageSize = 10; // Bilang ng items per page

  @override
  void initState() {
    super.initState();
    _sc.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _sc.removeListener(_onScroll);
    _sc.dispose();
    super.dispose();
  }

  /// Nag-me-merge ng posts at products sa iisang sorted list by timestamp.
  List<_FeedItem> _merge() {
    final l = <_FeedItem>[];
    for (final post in _posts) {
      DateTime ts;
      try {
        ts = DateTime.parse(post.timestamp);
      } catch (_) {
        ts = DateTime.now();
      }
      l.add(_FeedItem(ts: ts, post: post));
    }
    for (final prod in _products) {
      final ts = prod.createdAt;
      l.add(_FeedItem(ts: ts, product: prod));
    }
    l.sort((a, b) => b.ts.compareTo(a.ts));
    return l;
  }

  /// Nag-de-detect kung malapit na sa dulo ng scroll para mag-trigger ng load more.
  void _onScroll() {
    if (_sc.position.pixels >= _sc.position.maxScrollExtent - 300 && !_loading && (_postHasMore || _prodHasMore)) {
      _loadMore();
    }
  }

  /// Nag-lo-load ng susunod na batch ng posts at products.
  Future<void> _loadMore() async {
    if (_loading) return;
    _loading = true;
    try {
      // I-fetch ang susunod na page ng posts
      String? postStart;
      if (_posts.isNotEmpty) {
        postStart = _posts.last.timestamp;
      }
      final posts = await PostService.instance.fetchFeedPaged(limit: _pageSize, startAfterTs: postStart);
      if (posts.length < _pageSize) _postHasMore = false;
      _posts.addAll(posts);

      // Fetch next page for products
      DateTime? prodStart;
      if (_products.isNotEmpty) prodStart = _products.last.createdAt;
      final prods = await MarketplaceService.instance.getProductsPage(limit: _pageSize, startAfter: prodStart);
      if (prods.length < _pageSize) _prodHasMore = false;
      _products.addAll(prods);

      _items.clear();
      _items.addAll(_merge());
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('MarketplaceFeed: page load failed: $e');
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && !_loading) {
      return const Center(child: Text('No community listings yet'));
    }
    return ListView.builder(
      controller: _sc,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _items.length + (_loading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _items.length) return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        );
        final it = _items[i];
        if (it.post != null) return _buildPostCard(it.post!);
        return _buildProductCard(it.product);
      },
    );
  }

  Widget _buildPostCard(Post p) {
    final me = AuthService.instance.currentUser.value;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: p.authorAvatarUrl.isNotEmpty ? NetworkImage(p.authorAvatarUrl) : null,
                  child: p.authorAvatarUrl.isEmpty ? Text(p.authorEmail.isNotEmpty ? p.authorEmail[0].toUpperCase() : '?') : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: p.authorId)));
                }, child: Text(p.authorEmail, style: const TextStyle(fontWeight: FontWeight.bold)))),
                Text(p.timestamp.split('T').first, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final full = await PostService.instance.getById(p.id);
                if (full != null) Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: full)));
              },
              child: Text(p.content),
            ),
            if (p.mediaUrl != null && p.mediaUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Image.network(p.mediaUrl!),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Builder(builder: (ctx) {
                  final amenCount = (p.reactions['amen'] ?? []).length;
                  final myReacted = me != null && (p.reactions['amen'] ?? []).contains(me.id);
                  return TextButton.icon(
                    onPressed: () async {
                      if (me == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to react')));
                        return;
                      }
                      await PostService.instance.toggleReaction(p.id, 'amen', me.id);
                      if (mounted) setState(() {});
                    },
                    icon: Icon(myReacted ? Icons.thumb_up : Icons.thumb_up_alt_outlined, color: myReacted ? Colors.blue : null),
                    label: Text('$amenCount Amen'),
                  );
                }),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    final comment = await _showCommentDialog();
                    if (comment == null || comment.trim().isEmpty) return;
                    if (me == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to comment')));
                      return;
                    }
                    await PostService.instance.addComment(p.id, me.id, me.email, comment);
                  },
                  icon: const Icon(Icons.comment_outlined),
                  label: const Text('Comment'),
                ),
                const Spacer(),
                FutureBuilder<bool>(
                  future: me == null ? Future.value(false) : PostService.instance.isSaved(p.id, me.id),
                  builder: (ctx, snap) {
                    final saved = snap.data ?? false;
                    return IconButton(
                      onPressed: () async {
                        if (me == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to save')));
                          return;
                        }
                        await PostService.instance.toggleSave(p.id, me.id);
                        setState(() {});
                      },
                      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showCommentDialog() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add comment'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Post')),
        ],
      ),
    );
    return res;
  }

  Widget _buildProductCard(dynamic prod) {
    final me = AuthService.instance.currentUser.value;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                prod.imageUrl.isNotEmpty
                    ? Image.network(prod.imageUrl, width: 56, height: 56, fit: BoxFit.cover)
                    : Container(width: 56, height: 56, color: Colors.grey[200]),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prod.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(prod.formattedPrice, style: const TextStyle(color: Colors.green)),
                      const SizedBox(height: 4),
                      Text('Sold by ${prod.sellerName.isNotEmpty ? prod.sellerName : prod.sellerEmail}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: prod)));
                  },
                  child: const Text('View'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    if (me == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to buy')));
                      return;
                    }
                    await MarketplaceService.instance.addToCart(userId: me.id, product: prod);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart')));
                  },
                  child: const Text('Add to cart'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    // Share product to community feed
                    final me = AuthService.instance.currentUser.value;
                    if (me == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to share')));
                      return;
                    }
                    final content = 'Selling: ${prod.productName} for ${prod.formattedPrice}';
                    await PostService.instance.addPost(me.id, me.email, content, authorAvatarUrl: me.avatarUrl);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shared to feed')));
                  },
                  child: const Text('Share'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    final me = AuthService.instance.currentUser.value;
                    if (me == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to contact seller')));
                      return;
                    }
                    try {
                      final convoId = await MessageService.instance.ensureConversationWith(prod.sellerId);
                      if (!mounted) return;
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(convoId: convoId, peerId: prod.sellerId, peerName: prod.sellerName)));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start chat: $e')));
                    }
                  },
                  child: const Text('Contact Seller'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
