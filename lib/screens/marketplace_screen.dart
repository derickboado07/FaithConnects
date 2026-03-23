import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'product_list_screen.dart';
import 'sell_product_screen.dart';
import 'marketplace_feed.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MARKETPLACE SCREEN
//
// This is the entry point / landing page of the Marketplace module.
// It is displayed when the user taps the "Market" tab in the bottom navigation.
//
// Process flow implemented here:
//   • User sees two primary action cards:
//       1. Browse Products  → navigates to ProductListScreen (Buy flow)
//       2. Sell a Product   → navigates to SellProductScreen (Sell flow)
//   • A horizontal category row lets users jump directly to a filtered product
//     list for a specific product category.
//
// Authentication:
//   • Browsing products is open to all users (even unauthenticated).
//   • Selling requires a logged-in user (validated before navigation).
// ─────────────────────────────────────────────────────────────────────────────

// Shared color tokens — match the rest of the FaithConnect design system.
const _gold = Color(0xFFD4AF37);

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser.value;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Custom App Bar ──────────────────────────────────────────────
            Container(
              color: Theme.of(context).appBarTheme.backgroundColor,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  // Marketplace icon badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD4AF37), Color(0xFFF5E6B3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _gold.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Marketplace',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Welcome Banner ──────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD4AF37), Color(0xFFB8962E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _gold.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'FaithConnect',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Marketplace',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Buy & sell faith-inspired products\nwithin your community.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13.5,
                              height: 1.5,
                            ),
                          ),
                          // Show a personalized greeting when logged in.
                          if (user != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.waving_hand_rounded,
                                  color: Colors.white,
                                  size: 15,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Welcome, ${user.name.isNotEmpty ? user.name : user.email}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    Text(
                      'What would you like to do?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Buy Products Action Card ─────────────────────────────
                    // Navigates to ProductListScreen where the user can browse
                    // all products listed in the Firestore "products" collection.
                    _ActionCard(
                      icon: Icons.shopping_bag_outlined,
                      iconBg: const Color(0xFF4CAF50),
                      title: 'Browse Products',
                      subtitle:
                          'Explore faith-inspired items listed by our community.',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProductListScreen(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Sell Product Action Card ─────────────────────────────
                    // Navigates to SellProductScreen.
                    // Requires the user to be logged in — validated here before
                    // navigating so the sell screen always has a valid sellerId.
                    _ActionCard(
                      icon: Icons.sell_outlined,
                      iconBg: _gold,
                      title: 'Sell a Product',
                      subtitle:
                          'List your faith-inspired product for the community.',
                      onTap: () {
                        final currentUser =
                            AuthService.instance.currentUser.value;

                        // Validation: user must be authenticated to sell.
                        if (currentUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Please log in to sell products.',
                              ),
                              backgroundColor: Colors.red.shade600,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SellProductScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // ── Marketplace Feed (Posts + Products) ─────────
                    Text(
                      'Community Listings & Posts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      height: 600, // allow scrolling inside main scroll view
                      child: const MarketplaceFeed(),
                    ),

                    Text(
                      'Browse by Category',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Categories Row ──────────────────────────────────────
                    // Horizontal scrollable row of category chips.
                    // Each chip taps to ProductListScreen filtered by category.
                    const _CategoriesRow(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionCard
//
// Reusable card widget used to display the Buy and Sell action buttons on the
// MarketplaceScreen. Shows an icon badge, title, subtitle, and a chevron.
// ─────────────────────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Colored icon badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBg.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconBg, size: 28),
            ),
            const SizedBox(width: 16),
            // Title & subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).hintColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: Theme.of(context).disabledColor,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CategoriesRow
//
// Horizontal scrollable list of product category filter chips.
// Tapping a category navigates to ProductListScreen with an initial category
// filter pre-applied.
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryItem {
  final String label;
  final IconData icon;
  const _CategoryItem(this.label, this.icon);
}

class _CategoriesRow extends StatelessWidget {
  const _CategoriesRow();

  static const _categories = [
    _CategoryItem('All', Icons.apps_rounded),
    _CategoryItem('Bibles', Icons.auto_stories_rounded),
    _CategoryItem('Apparel', Icons.checkroom_rounded),
    _CategoryItem('Journals', Icons.book_outlined),
    _CategoryItem('Accessories', Icons.star_outline_rounded),
    _CategoryItem('Music', Icons.music_note_rounded),
    _CategoryItem('Decor', Icons.home_outlined),
    _CategoryItem('Other', Icons.category_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (ctx, idx) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isFirst = index == 0;

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductListScreen(initialCategory: cat.label),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isFirst ? _gold.withValues(alpha: 0.10) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isFirst ? _gold : Theme.of(context).dividerColor,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat.icon,
                    size: 15,
                    color: isFirst ? _gold : Theme.of(context).hintColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isFirst ? _gold : const Color(0xFF555555),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
