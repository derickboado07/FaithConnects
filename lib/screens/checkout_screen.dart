import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/marketplace_service.dart';
import 'order_confirmation_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHECKOUT SCREEN  (Buy Flow — Step 3)
//
// Collects shipping address and payment method from the user to finalize
// a product purchase.
//
// Process flow:
//   ProductDetailScreen → CheckoutScreen → OrderConfirmationScreen
//
// Features:
//   • Order summary card showing the selected product (image, name, price)
//   • Shipping address input field with validation
//   • Payment method selector (radio buttons):
//       - Cash on Delivery
//       - GCash
//       - Bank Transfer
//       - Credit / Debit Card
//   • "Confirm Order" button
//   • Form validation:
//       - Address must not be empty
//       - Payment method must be selected
//   • On valid form: calls MarketplaceService.placeOrder() to write the
//     order document to Firestore, then navigates to OrderConfirmationScreen.
//
// Firestore write (via MarketplaceService):
//   MarketplaceService.placeOrder() creates a document in /orders/{orderId}
//   and removes the product from /carts/{userId}/items/{productId}.
// ─────────────────────────────────────────────────────────────────────────────

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFF5E6B3);

class CheckoutScreen extends StatefulWidget {
  final Product product;
  final String userId;

  const CheckoutScreen({
    super.key,
    required this.product,
    required this.userId,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _addressCtrl = TextEditingController();

  // Currently selected payment method. None selected by default.
  String? _paymentMethod;

  bool _confirming = false;

  static const _paymentOptions = [
    ('Cash on Delivery', Icons.money_rounded),
    ('GCash', Icons.phone_android_rounded),
    ('Bank Transfer', Icons.account_balance_rounded),
    ('Credit / Debit Card', Icons.credit_card_rounded),
  ];

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  // ── Confirm Order ────────────────────────────────────────────────────────
  // Called when the user taps the "Confirm Order" button.
  //
  // Validation:
  //   1. Flutter form validator checks the address field is not empty.
  //   2. Manual check ensures a payment method has been selected.
  //
  // On success:
  //   3. Calls MarketplaceService.placeOrder() to write the order to Firestore.
  //   4. Navigates to OrderConfirmationScreen with the generated orderId.
  //
  // On failure:
  //   5. Shows a SnackBar with the error message.
  Future<void> _confirmOrder() async {
    // Step 1: Validate address field via Flutter form validator.
    if (!_formKey.currentState!.validate()) return;

    // Step 2: Ensure a payment method has been chosen.
    if (_paymentMethod == null) {
      _showSnack('Please select a payment method.', isError: true);
      return;
    }

    setState(() => _confirming = true);

    try {
      // Step 3: Firestore write — create the order document.
      final orderId = await MarketplaceService.instance.placeOrder(
        userId: widget.userId,
        product: widget.product,
        address: _addressCtrl.text.trim(),
        paymentMethod: _paymentMethod!,
      );

      if (!mounted) return;

      // Step 4: Navigate to order confirmation; remove all intermediate screens
      // from the stack so the user cannot "go back" to checkout.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(
            orderId: orderId,
            product: widget.product,
            address: _addressCtrl.text.trim(),
            paymentMethod: _paymentMethod!,
          ),
        ),
        // Remove all routes up to (but not including) the marketplace home.
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      // Step 5: Display the error to the user.
      _showSnack('Could not place order: $e', isError: true);
      setState(() => _confirming = false);
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
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF444444),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Checkout',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Order Summary Card ──────────────────────────────────────
              // Shows a snapshot of the product being purchased so the user
              // can confirm they're ordering the right item.
              _SectionLabel('Order Summary'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
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
                              width: 70,
                              height: 70,
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

              const SizedBox(height: 24),

              // ── Shipping Address ────────────────────────────────────────
              // Validation: field must not be empty.
              _SectionLabel('Shipping Address'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _addressCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Enter your full shipping address…',
                  hintStyle: const TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 14,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 44),
                    child: Icon(
                      Icons.location_on_outlined,
                      color: _gold,
                      size: 20,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
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
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.red.shade300),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.red.shade300,
                      width: 1.5,
                    ),
                  ),
                ),
                // Validation: address must not be blank.
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your shipping address.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // ── Payment Method ──────────────────────────────────────────
              // Radio-button selector. The selected value is stored in
              // _paymentMethod and validated manually before order placement.
              _SectionLabel('Payment Method'),
              const SizedBox(height: 10),
              Container(
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
                  children: List.generate(_paymentOptions.length, (index) {
                    final paymentOption = _paymentOptions[index];
                    final label = paymentOption.$1;
                    final icon = paymentOption.$2;
                    final isSelected = _paymentMethod == label;
                    final isLast = index == _paymentOptions.length - 1;

                    return Column(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _paymentMethod = label),
                          borderRadius: BorderRadius.vertical(
                            top: index == 0
                                ? const Radius.circular(16)
                                : Radius.zero,
                            bottom: isLast
                                ? const Radius.circular(16)
                                : Radius.zero,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                // Payment method icon
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _gold.withValues(alpha: 0.12)
                                        : const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    icon,
                                    size: 18,
                                    color: isSelected
                                        ? _gold
                                        : const Color(0xFF888888),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? const Color(0xFF2C2C2C)
                                          : const Color(0xFF555555),
                                    ),
                                  ),
                                ),
                                // Radio indicator
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? _gold
                                          : const Color(0xFFCCCCCC),
                                      width: isSelected ? 2 : 1.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _gold,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!isLast)
                          const Divider(
                            height: 1,
                            thickness: 0.6,
                            color: Color(0xFFF0F0F0),
                            indent: 16,
                            endIndent: 16,
                          ),
                      ],
                    );
                  }),
                ),
              ),

              const SizedBox(height: 24),

              // ── Price Breakdown ─────────────────────────────────────────
              Container(
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
                    _PriceRow('Subtotal', product.formattedPrice),
                    const SizedBox(height: 6),
                    _PriceRow('Shipping', '₱0.00'),
                    const SizedBox(height: 8),
                    const Divider(color: Color(0xFFF0F0F0), thickness: 0.8),
                    const SizedBox(height: 8),
                    _PriceRow(
                      'Total',
                      product.formattedPrice,
                      isBold: true,
                      valueColor: _gold,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Sticky Confirm Button ────────────────────────────────────────────
      bottomNavigationBar: Container(
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _confirming ? null : _confirmOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _goldLight,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _confirming
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Confirm Order',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: _goldLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.image_outlined,
        size: 32,
        color: Color(0xFFCCB060),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _PriceRow(
    this.label,
    this.value, {
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? const Color(0xFF2C2C2C) : const Color(0xFF888888),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color:
                valueColor ??
                (isBold ? const Color(0xFF2C2C2C) : const Color(0xFF444444)),
          ),
        ),
      ],
    );
  }
}
