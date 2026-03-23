import 'auth_service.dart';
import 'post_service.dart';
import 'marketplace_service.dart';
import '../models/product_model.dart';
import 'dart:async';

class SearchResults {
  final List<AuthUser> users;
  final List<Post> posts;
  final List<Product> products;

  SearchResults({List<AuthUser>? users, List<Post>? posts, List<Product>? products})
      : users = users ?? [],
        posts = posts ?? [],
        products = products ?? [];
}

class SearchService {
  SearchService._();
  static final SearchService instance = SearchService._();

  /// Aggregates search across users, posts and products.
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
