// ─────────────────────────────────────────────────────────────────────────────
// SEARCH SERVICE — Aggregated search across multiple collections sa app.
// Ito ang central na search na sabay-sabay nag-ha-hanap sa:
//   • Users (AuthService.searchUsers)
//   • Posts (PostService.searchPosts)
//   • Products (MarketplaceService.searchProducts)
//
// Ginagamit ang Future.wait para sabay-sabay mag-query (parallel),
// kaya mas mabilis kaysa sunod-sunod na calls.
// ─────────────────────────────────────────────────────────────────────────────

import 'auth_service.dart';
import 'post_service.dart';
import 'marketplace_service.dart';
import '../models/product_model.dart';
import 'dart:async';

/// Data model na nag-ho-hold ng combined search results mula sa iba't ibang collections.
class SearchResults {
  final List<AuthUser> users;      // Mga nahanap na users
  final List<Post> posts;          // Mga nahanap na posts
  final List<Product> products;    // Mga nahanap na products

  SearchResults({List<AuthUser>? users, List<Post>? posts, List<Product>? products})
      : users = users ?? [],
        posts = posts ?? [],
        products = products ?? [];
}

/// Singleton service para sa aggregated search across the app.
class SearchService {
  SearchService._(); // Private constructor
  static final SearchService instance = SearchService._(); // Global instance

  /// Nag-a-aggregate ng search results mula sa users, posts, at products.
  /// Gumagamit ng Future.wait para sabay-sabay mag-query (parallel fetching).
  Future<SearchResults> searchAll(String query, {int limitPerCollection = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return SearchResults();

    final futures = <Future>[];
    futures.add(AuthService.instance.searchUsers(q, limit: limitPerCollection));
    futures.add(PostService.instance.searchPosts(q, limit: limitPerCollection));
    futures.add(MarketplaceService.instance.searchProducts(q, limit: limitPerCollection));

    final results = await Future.wait(futures);

    return SearchResults(
      users: results[0] as List<AuthUser>,
      posts: results[1] as List<Post>,
      products: results[2] as List<Product>,
    );
  }
}
