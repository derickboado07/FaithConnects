// ═══════════════════════════════════════════════════════════════════════════
// PRODUCT DETAIL SCREEN — Full product preview page.
// Nagdi-display ng product image, name, description, price, at seller info.
// May "Buy Now" button na nag-a-add sa cart at nagpupunta sa checkout.
// Kailangan naka-login bago maka-buy.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import '../services/marketplace_service.dart';
import 'checkout_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT DETAIL SCREEN  (Buy Flow — Step 2)
//
// Displays the full details of a selected product and allows the user to
// add the product to their cart and proceed to checkout.
//
// Process flow:
//   ProductListScreen → ProductDetailScreen → CheckoutScreen
//
// Features:
//   • Full-size product image with Hero animation from the list card
//   • Product name, category, description, and formatted price
//   • Seller information (name / email)
//   • "Buy Now" button — adds the product to the Firestore cart and navigates
//     to CheckoutScreen
//   • Authentication check — prompts login if the user is not signed in
//
// Firestore write (via MarketplaceService):
//   MarketplaceService.addToCart() writes a document to:
//   /carts/{userId}/items/{productId}
// ─────────────────────────────────────────────────────────────────────────────

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFF5E6B3);

/// Screen para sa detalyadong view ng isang produkto — may Buy Now at product info.
class ProductDetailScreen extends StatefulWidget {
  /// The product whose details are being displayed.
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _addingToCart = false;   // True habang nag-ppo-process ng cart/checkout

  // ── Buy Now ──────────────────────────────────────────────────────────────
  // Called when the user taps the "Buy Now" button.
  //
  // Flow:
  //   1. Validate the user is authenticated.
  //   2. Call MarketplaceService.addToCart() to write the cart item to Firestore.
  //   3. Navigate to CheckoutScreen, passing the product and user info.
  Future<void> _buyNow() async {
    // Validation: require authentication before purchasing.
    final user = AuthService.instance.currentUser.value;
    if (user == null) {
      _showSnack('Please log in to buy products.', isError: true);
      return;
    }

    setState(() => _addingToCart = true);

    try {
      // Firestore write: add product to user's cart subcollection.
      await MarketplaceService.instance.addToCart(
        userId: user.id,
        product: widget.product,
      );

      if (!mounted) return;

      // Navigate to CheckoutScreen after successfully adding to cart.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CheckoutScreen(product: widget.product, userId: user.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to add to cart: $e', isError: true);
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade600 : _gold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Sliver App Bar with product image ─────────────────────
          SliverAppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            elevation: 0,
            expandedHeight: 300,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Theme.of(context).iconTheme.color,
                    size: 18,
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              // Product image fills the app bar when expanded.
              background: product.imageUrl.isNotEmpty
                  ? Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
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
                      errorBuilder: (ctx, err, st) => _imageFallback(),
                    )
                  : _imageFallback(),
            ),
          ),

          // ── Product Details ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _goldLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product.category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFAA8820),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Product name
                  Text(
                    product.productName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Price
                  Text(
                    product.formattedPrice,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _gold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Divider(color: Color(0xFFF0F0F0), thickness: 0.8),

                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description.isNotEmpty
                        ? product.description
                        : 'No description provided.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Seller info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Row(
                      children: [
                        // Seller avatar placeholder
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _goldLight.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: _gold,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Seller',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF888888),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                product.sellerName.isNotEmpty
                                    ? product.sellerName
                                    : product.sellerEmail.isNotEmpty
                                    ? product.sellerEmail
                                    : 'FaithConnect Member',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              if (product.sellerEmail.isNotEmpty &&
                                  product.sellerName.isNotEmpty)
                                Text(
                                  product.sellerEmail,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).hintColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.verified_rounded,
                          color: _gold,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Sticky Buy Now Button ──────────────────────────────────────────
      // Fixed at the bottom of the screen so it's always visible.
      bottomNavigationBar: Container(
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _addingToCart ? null : _buyNow,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _goldLight,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _addingToCart
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Buy Now',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: _goldLight.withValues(alpha: 0.3),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 60, color: Color(0xFFCCB060)),
      ),
    );
  }
}
