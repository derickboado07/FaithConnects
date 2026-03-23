import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT MODEL
//
// Mirrors the Firestore "products" collection document structure.
// Used throughout the Marketplace module for reading and writing product data.
//
// Firestore path: /products/{productId}
// ─────────────────────────────────────────────────────────────────────────────

class Product {
  final String productId;
  final String productName;
  final String description;
  final double price;
  final String imageUrl; // Firebase Storage download URL
  final String sellerId; // UID of the seller (Firebase Auth UID)
  final String sellerName; // Display name of the seller
  final String sellerEmail; // Email of the seller
  final String category; // e.g. Bibles, Apparel, Journals, etc.
  final DateTime createdAt; // Timestamp when the product was listed

  const Product({
    required this.productId,
    required this.productName,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.sellerId,
    this.sellerName = '',
    this.sellerEmail = '',
    required this.category,
    required this.createdAt,
  });

  // ── Firestore deserialization ──────────────────────────────────────────────
  // Called when reading a product document from Firestore.
  // DocumentSnapshot.data() is cast to Map<String, dynamic> and mapped to fields.
  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      productId: data['productId'] as String? ?? doc.id,
      productName: data['productName'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['imageUrl'] as String? ?? '',
      sellerId: data['sellerId'] as String? ?? '',
      sellerName: data['sellerName'] as String? ?? '',
      sellerEmail: data['sellerEmail'] as String? ?? '',
      category: data['category'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // ── Map deserialization ────────────────────────────────────────────────────
  // Used when constructing a Product from a plain Map (e.g. cart item data).
  factory Product.fromMap(Map<String, dynamic> data) {
    return Product(
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['imageUrl'] as String? ?? '',
      sellerId: data['sellerId'] as String? ?? '',
      sellerName: data['sellerName'] as String? ?? '',
      sellerEmail: data['sellerEmail'] as String? ?? '',
      category: data['category'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // ── Firestore serialization ────────────────────────────────────────────────
  // Called when writing a product document to Firestore.
  // Converts the Product object to a Map<String, dynamic> for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerEmail': sellerEmail,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Formatted price string with Philippine Peso symbol.
  String get formattedPrice => '₱${price.toStringAsFixed(2)}';
}
