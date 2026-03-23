import 'package:flutter/material.dart';
import '../models/product_model.dart';
import 'marketplace_screen.dart';
import 'product_list_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ORDER CONFIRMATION SCREEN  (Buy Flow — Final Step)
//
// Displayed after a successful purchase. Confirms the order details to the user
// and provides navigation options to continue shopping or return to the feed.
//
// Process flow:
//   CheckoutScreen → OrderConfirmationScreen
//
// This screen is pushed via Navigator.pushAndRemoveUntil from CheckoutScreen,
// which removes all intermediate routes so the user cannot navigate back to
// the checkout form using the back button.
//
// The screen shows:
//   • Success animation icon (green checkmark)
//   • The generated orderId (for user reference)
//   • Product summary (image, name, price)
//   • Delivery address and payment method confirmation
//   • "Continue Shopping" — goes to ProductListScreen
//   • "Back to Home" — pops back to the app root (HomePage with bottom nav)
// ─────────────────────────────────────────────────────────────────────────────

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFF5E6B3);

class OrderConfirmationScreen extends StatelessWidget {
  final String orderId;
  final Product product;
  final String address;
  final String paymentMethod;

  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    required this.product,
    required this.address,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // No AppBar — this screen has its own back navigation via action buttons.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Success Icon ────────────────────────────────────────────
              // Large animated success badge at the top of the confirmation.
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF4CAF50),
                  size: 52,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Order Placed!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Your order has been placed successfully.\nThe seller will contact you shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).hintColor,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 28),

              // ── Order ID Badge ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _goldLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: _gold,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order ID',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFAA8820),
                          ),
                        ),
                        Text(
                          // Show a shortened version of the ID for readability.
                          orderId.length > 16
                              ? '#${orderId.substring(0, 16).toUpperCase()}...'
                              : '#${orderId.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C2C2C),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Product Summary Card ────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Product thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: product.imageUrl.isNotEmpty
                          ? Image.network(
                              product.imageUrl,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, st) => _thumbFallback(),
                            )
                          : _thumbFallback(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.category,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            product.formattedPrice,
                            style: const TextStyle(
                              fontSize: 16,
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

              const SizedBox(height: 14),

              // ── Delivery & Payment Details ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Delivery address row
                    _ConfirmRow(
                      icon: Icons.location_on_outlined,
                      label: 'Delivery Address',
                      value: address,
                    ),
                    const Divider(
                      color: Color(0xFFF0F0F0),
                      thickness: 0.8,
                      height: 20,
                    ),
                    // Payment method row
                    _ConfirmRow(
                      icon: Icons.payment_rounded,
                      label: 'Payment Method',
                      value: paymentMethod,
                    ),
                    const Divider(
                      color: Color(0xFFF0F0F0),
                      thickness: 0.8,
                      height: 20,
                    ),
                    // Order status row
                    _ConfirmRow(
                      icon: Icons.local_shipping_outlined,
                      label: 'Status',
                      value: 'Pending',
                      valueColor: const Color(0xFFFF9800),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Continue Shopping Button ────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProductListScreen(),
                    ),
                    (route) => route.isFirst,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Continue Shopping',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Back to Home Button ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MarketplaceScreen(),
                    ),
                    (route) => route.isFirst,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _gold,
                    side: const BorderSide(color: _gold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Back to Marketplace',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: _goldLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.image_outlined,
        size: 34,
        color: Color(0xFFCCB060),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ConfirmRow — label + value row used in the order detail card.
// ─────────────────────────────────────────────────────────────────────────────
class _ConfirmRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ConfirmRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _gold, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
