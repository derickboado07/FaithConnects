import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/marketplace_service.dart';
import 'product_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT LIST SCREEN  (Buy Flow — Step 1)
//
// Displays all products stored in the Firestore "products" collection.
//
// Process flow:
//   MarketplaceScreen → ProductListScreen → ProductDetailScreen
//
// Features:
//   • Real-time product updates via Firestore StreamBuilder
//   • Category filter chips (All, Bibles, Apparel, Journals, etc.)
//   • Search bar to filter products by name client-side
//   • 2-column responsive product grid
//   • Each card shows image, name, category, and price
//   • Tap a card → opens ProductDetailScreen for that product
//
// Firestore read:
//   MarketplaceService.getProductsStream(category) listens to the
//   "products" collection and filters by category when one is selected.
// ─────────────────────────────────────────────────────────────────────────────

// Shared color tokens.
const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFF5E6B3);

class ProductListScreen extends StatefulWidget {
  /// [initialCategory] pre-selects a category when navigating here from the
  /// category row on MarketplaceScreen. Defaults to 'All'.
  final String initialCategory;

  const ProductListScreen({super.key, this.initialCategory = 'All'});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late String _selectedCategory;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  static const _categories = [
    'All',
    'Bibles',
    'Apparel',
    'Journals',
    'Accessories',
    'Music',
    'Decor',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    // Apply the initial category passed from the parent screen.
    _selectedCategory = widget.initialCategory;

    // Rebuild the grid whenever the search text changes.
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Client-side search filter ───────────────────────────────────────────
  // Firestore query handles category filtering; search refinement is done
  // locally on the already-fetched list to avoid redundant Firestore reads.
  List<Product> _applySearch(List<Product> products) {
    if (_searchQuery.isEmpty) return products;
    return products
        .where(
          (p) =>
              p.productName.toLowerCase().contains(_searchQuery) ||
              p.description.toLowerCase().contains(_searchQuery) ||
              p.category.toLowerCase().contains(_searchQuery),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF444444),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Browse Products',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C2C2C),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Search Bar ─────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search products…',
                hintStyle: const TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _gold,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF888888),
                        ),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFFAF9F6),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _gold, width: 1.5),
                ),
              ),
            ),
          ),

          // ── Category Filter Chips ───────────────────────────────────────
          // Selecting a chip updates _selectedCategory, which changes the
          // Firestore stream passed to the StreamBuilder below.
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isActive = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? _gold : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? _gold : const Color(0xFFE0E0E0),
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
                              : const Color(0xFF666666),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          Divider(
            height: 1,
            thickness: 0.8,
            color: Colors.grey.withValues(alpha: 0.15),
          ),

          // ── Product Grid via StreamBuilder ─────────────────────────────
          // StreamBuilder subscribes to the Firestore "products" collection.
          // The stream is keyed by _selectedCategory so it re-subscribes
          // automatically whenever the category filter changes.
          Expanded(
            child: StreamBuilder<List<Product>>(
              // Firestore read: stream of products, filtered by category.
              stream: MarketplaceService.instance.getProductsStream(
                category: _selectedCategory,
              ),
              builder: (context, snapshot) {
                // ── Loading state ─────────────────────────────────────
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _gold,
                      strokeWidth: 2.5,
                    ),
                  );
                }

                // ── Error state (only when no cached data available) ──────
                if (snapshot.hasError &&
                    (snapshot.data == null || snapshot.data!.isEmpty)) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 56,
                            color: _gold.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No products found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF444444),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Check back later for new listings.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Apply client-side search on top of Firestore results.
                final products = _applySearch(snapshot.data ?? []);

                // ── Empty state ───────────────────────────────────────
                if (products.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 56,
                            color: _gold.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No products found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF444444),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try a different category or search term.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // ── Product Grid ──────────────────────────────────────
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) =>
                      _ProductCard(product: products[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProductCard
//
// Individual product card displayed in the ProductListScreen grid.
// Shows the product image, name, category badge, and price.
// Tapping navigates to ProductDetailScreen for that product.
// ─────────────────────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product image ───────────────────────────────────────────
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        // Show a gold shimmer placeholder while loading.
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: _goldLight.withValues(alpha: 0.3),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: _gold,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (ctx, err, st) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
            ),

            // ── Product info ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _goldLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      product.category,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFAA8820),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Product name — clamped to 2 lines.
                  Text(
                    product.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C2C2C),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Price
                  Text(
                    product.formattedPrice,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _gold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: _goldLight.withValues(alpha: 0.3),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 40, color: Color(0xFFCCB060)),
      ),
    );
  }
}
