// ═══════════════════════════════════════════════════════════════════════════
// SEARCH SCREEN — Unified search across the app.
// Sabay-sabay nagha-hanap sa users, posts, at products gamit ang
// SearchService.searchAll(). May debounced input para hindi
// bawat keystroke nag-que-query.
//
// Results ay grouped by category: Users, Posts, Products.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/search_service.dart';
import '../screens/public_profile_screen.dart';
import '../screens/product_detail_screen.dart';

/// Main search screen ng app.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;               // Debounce timer para hindi bawat keystroke nag-que-query
  bool _loading = false;          // True habang nag-se-search
  SearchResults _results = SearchResults(); // Current search results (users, posts, products)

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Tinatawag kapag nagbago ang search input.
  /// May 350ms debounce para hindi bawat keystroke nag-trigger ng query.
  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _doSearch(v));
  }

  /// Nag-e-execute ng aggregated search via SearchService.
  /// Sabay-sabay nag-ha-hanap sa users, posts, at products.
  Future<void> _doSearch(String q) async {
    final txt = q.trim();
    if (txt.isEmpty) {
      setState(() => _results = SearchResults());
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await SearchService.instance.searchAll(txt);
      if (!mounted) return;
      setState(() {
        _results = r;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Search people, posts, products...',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
              onPressed: () {
                _ctrl.clear();
                setState(() => _results = SearchResults());
              },
              icon: const Icon(Icons.clear)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_results.users.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('People', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  ..._results.users.map((u) => ListTile(
                        leading: CircleAvatar(backgroundImage: u.avatarUrl.isNotEmpty ? NetworkImage(u.avatarUrl) : null, child: u.avatarUrl.isEmpty ? Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?') : null),
                        title: Text(u.name.isNotEmpty ? u.name : u.email),
                        subtitle: u.bio.isNotEmpty ? Text(u.bio, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: u.id))),
                      )),
                ],

                if (_results.posts.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Posts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  ..._results.posts.map((p) => ListTile(
                        title: Text(p.authorEmail),
                        subtitle: Text(p.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                                  title: Text(p.authorEmail),
                                  content: Text(p.content),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                                  ],
                                )),
                      )),
                ],

                if (_results.products.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  ..._results.products.map((prod) => ListTile(
                        leading: prod.imageUrl.isNotEmpty ? Image.network(prod.imageUrl, width: 48, height: 48, fit: BoxFit.cover) : null,
                        title: Text(prod.productName),
                        subtitle: Text(prod.formattedPrice),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: prod))),
                      )),
                ],

                if (_results.users.isEmpty && _results.posts.isEmpty && _results.products.isEmpty && _ctrl.text.isNotEmpty && !_loading)
                  Center(child: Text('No results for "${_ctrl.text}"', style: const TextStyle(color: Colors.grey))),
              ],
            ),
    );
  }
}
