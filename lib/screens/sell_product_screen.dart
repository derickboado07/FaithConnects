import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/marketplace_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SELL PRODUCT SCREEN  (Sell Flow)
//
// Allows an authenticated user to list a new product in the Marketplace.
//
// Process flow:
//   MarketplaceScreen → SellProductScreen → (success → back to Marketplace)
//
// Form fields:
//   • Product Name   (required, max 100 chars)
//   • Description    (required, max 500 chars)
//   • Price          (required, must be a valid positive number)
//   • Category       (required, chosen from a fixed dropdown list)
//   • Product Image  (required, picked via ImagePicker)
//
// Image upload (Firebase Storage):
//   MarketplaceService.uploadProductImage() is called first to upload the
//   selected image to Firebase Storage at:
//     product_images/{userId}/{timestamp}_{filename}
//   The returned download URL is then embedded in the Firestore product document.
//
// Firestore write:
//   MarketplaceService.addProduct() creates a document in /products/{productId}
//   with all product fields including the imageUrl from Storage.
//
// Validation:
//   All validation happens in _submit() before any network call is made.
//   The Flutter form key handles text field validation; image and category
//   are validated manually with clear user feedback.
// ─────────────────────────────────────────────────────────────────────────────

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFF5E6B3);

class SellProductScreen extends StatefulWidget {
  const SellProductScreen({super.key});

  @override
  State<SellProductScreen> createState() => _SellProductScreenState();
}

class _SellProductScreenState extends State<SellProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();

  // Category selector state
  String? _selectedCategory;

  // Image picker state
  XFile? _imageFile; // Picked image file (mobile / desktop)
  Uint8List? _imageBytes; // Picked image raw bytes (web & preview)
  bool _submitting = false;

  // Image source mode: upload from device vs. paste a URL
  bool _useImageUrl = false;
  final TextEditingController _imageUrlCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  // Available product categories — must match categories on ProductListScreen.
  static const _categories = [
    'Bibles',
    'Apparel',
    'Journals',
    'Accessories',
    'Music',
    'Decor',
    'Other',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  // ── Image Picker ─────────────────────────────────────────────────────────
  // Opens the device gallery. On web, reads bytes immediately for preview.
  // On mobile, stores the XFile path for later upload in _submit().
  // Maximum image size: 10 MB (same limit as create_post_screen).
  static const int _maxImageBytes = 10 * 1024 * 1024; // 10 MB

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;

      // Always read bytes for preview rendering and web upload.
      final bytes = await file.readAsBytes();

      // Validate file size before accepting the image.
      if (bytes.length > _maxImageBytes) {
        if (!mounted) return;
        _showSnack('Image is too large. Maximum size is 10 MB.', isError: true);
        return;
      }

      setState(() {
        _imageFile = file;
        _imageBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to pick image. Please try again.', isError: true);
    }
  }

  // ── Submit / List Product ────────────────────────────────────────────────
  // Full validation and submission pipeline:
  //   1. Run Flutter form validators (name, description, price).
  //   2. Validate category selection.
  //   3. Validate image is selected.
  //   4. Parse and range-check the price.
  //   5. Upload image to Firebase Storage → get download URL.
  //   6. Save product document to Firestore.
  //   7. Show success dialog and navigate back to MarketplaceScreen.
  Future<void> _submit() async {
    // Step 1: Run all form field validators.
    if (!_formKey.currentState!.validate()) return;

    // Step 2: Validate category selection.
    if (_selectedCategory == null) {
      _showSnack('Please select a product category.', isError: true);
      return;
    }

    // Step 3: Validate that an image has been provided (file or URL).
    if (_useImageUrl) {
      final url = _imageUrlCtrl.text.trim();
      if (url.isEmpty) {
        _showSnack('Please enter an image URL.', isError: true);
        return;
      }
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !uri.hasAbsolutePath ||
          (!url.startsWith('http://') && !url.startsWith('https://'))) {
        _showSnack(
          'Please enter a valid image URL (http/https).',
          isError: true,
        );
        return;
      }
    } else {
      if (_imageFile == null) {
        _showSnack('Please select a product image.', isError: true);
        return;
      }
    }

    // Step 4: Parse and validate the price value.
    final price = double.tryParse(_priceCtrl.text.trim());
    if (price == null || price <= 0) {
      _showSnack(
        'Please enter a valid price greater than zero.',
        isError: true,
      );
      return;
    }

    final user = AuthService.instance.currentUser.value;
    if (user == null) {
      _showSnack('You must be logged in to sell products.', isError: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      // Step 5: Either use the provided URL directly, or upload to Firebase Storage.
      final String imageUrl;
      if (_useImageUrl) {
        imageUrl = _imageUrlCtrl.text.trim();
      } else {
        imageUrl = await MarketplaceService.instance.uploadProductImage(
          imagePath: kIsWeb ? null : _imageFile!.path,
          imageBytes: _imageBytes,
          filename: _imageFile!.name,
          userId: user.id,
        );
      }

      // Step 6: Save the product to the Firestore "products" collection.
      await MarketplaceService.instance.addProduct(
        productName: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: price,
        category: _selectedCategory!,
        imageUrl: imageUrl,
        sellerId: user.id,
        sellerName: user.name,
        sellerEmail: user.email,
      );

      if (!mounted) return;

      // Step 7: Show success dialog and navigate back.
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      String msg = e
          .toString()
          .replaceAll(RegExp(r'^.*Exception:\s*'), '')
          .trim();
      _showSnack(
        msg.isNotEmpty ? msg : 'Failed to list product. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Success Dialog ────────────────────────────────────────────────────────
  // Shown after a product is successfully listed. Navigating back returns the
  // user to the MarketplaceScreen.
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF4CAF50),
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Product Listed!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C2C2C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"${_nameCtrl.text.trim()}" has been listed in the Marketplace.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context); // Return to MarketplaceScreen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back to Marketplace',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.close_rounded,
            color: Color(0xFF444444),
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sell a Product',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C2C2C),
          ),
        ),
        centerTitle: true,
        // Submit button in the app bar (visible but disabled while submitting).
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _submitting
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _gold,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _submit,
                    style: TextButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'List',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image Source ───────────────────────────────────────────
              // Toggle between uploading a file or pasting an image URL.
              _FieldLabel('Product Image'),
              const SizedBox(height: 8),

              // Mode toggle
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDE4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _ImageModeTab(
                      label: 'Upload File',
                      icon: Icons.upload_file_rounded,
                      selected: !_useImageUrl,
                      onTap: () {
                        if (_useImageUrl) {
                          setState(() => _useImageUrl = false);
                        }
                      },
                    ),
                    _ImageModeTab(
                      label: 'Use URL',
                      icon: Icons.link_rounded,
                      selected: _useImageUrl,
                      onTap: () {
                        if (!_useImageUrl) {
                          setState(() => _useImageUrl = true);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Upload picker
              if (!_useImageUrl)
                GestureDetector(
                  onTap: _submitting ? null : _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _imageFile != null
                            ? _gold
                            : const Color(0xFFE0E0E0),
                        width: _imageFile != null ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.07),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _imageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(_imageBytes!, fit: BoxFit.cover),
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.edit_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Change',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: _goldLight.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: _gold,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Tap to upload product image',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF555555),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'JPG, PNG — max 10 MB',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF999999),
                                ),
                              ),
                            ],
                          ),
                  ),
                )
              // URL input
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _imageUrlCtrl,
                      keyboardType: TextInputType.url,
                      decoration: _inputDec(
                        'https://example.com/image.jpg',
                        Icons.link_rounded,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    // Live URL preview
                    if (_imageUrlCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          _imageUrlCtrl.text.trim(),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Text(
                                'Could not load preview — URL may be invalid.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF856404),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

              const SizedBox(height: 22),

              // ── Product Name ──────────────────────────────────────────
              _FieldLabel('Product Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                maxLength: 100,
                decoration: _inputDec(
                  'e.g. Leather Bible Cover',
                  Icons.label_outline_rounded,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Product name is required.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ── Description ───────────────────────────────────────────
              _FieldLabel('Description'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                minLines: 3,
                maxLines: 6,
                maxLength: 500,
                decoration: _inputDec(
                  'Describe your product…',
                  Icons.description_outlined,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Description is required.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ── Price ─────────────────────────────────────────────────
              _FieldLabel('Price (₱)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _inputDec('e.g. 150.00', Icons.sell_outlined),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Price is required.';
                  }
                  final parsed = double.tryParse(v.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid price greater than zero.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ── Category Dropdown ─────────────────────────────────────
              // Validated manually in _submit() (not inside the form).
              _FieldLabel('Category'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF9F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedCategory != null
                        ? _gold
                        : const Color(0xFFE8E8E8),
                    width: _selectedCategory != null ? 1.5 : 1,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    hint: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Select a category',
                        style: TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    borderRadius: BorderRadius.circular(14),
                    items: _categories
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.category_outlined,
                                  size: 16,
                                  color: _gold,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  cat,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF2C2C2C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── List Product Button (full width) ──────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _goldLight,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'List Product',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  /// Consistent input field decoration reused across all form fields.
  InputDecoration _inputDec(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
      prefixIcon: Icon(icon, color: _gold, size: 20),
      filled: true,
      fillColor: const Color(0xFFFAF9F6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
      ),
      counterStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 11),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widget — image source mode toggle tab.
// ─────────────────────────────────────────────────────────────────────────────
class _ImageModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ImageModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFD4AF37) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : const Color(0xFF888888),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF888888),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widget — consistent form field label typography.
// ─────────────────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2C2C2C),
      ),
    );
  }
}
