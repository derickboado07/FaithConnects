import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ORDER MODEL
//
// Renamed to 'ProductOrder' to avoid the naming collision with the 'Order'
// identifier exported by cloud_firestore (used in Firestore query ordering).
//
// Mirrors the Firestore "orders" collection document structure.
// A ProductOrder is created when the user confirms a purchase in CheckoutScreen.
//
// Firestore path: /orders/{orderId}
// ─────────────────────────────────────────────────────────────────────────────

class ProductOrder {
  final String orderId; // Auto-generated Firestore document ID
  final String userId; // Firebase Auth UID of the buyer
  final String productId; // ID of the purchased product
  final String productName; // Snapshot of product name at time of purchase
  final String imageUrl; // Snapshot of product image URL
  final String address; // Shipping address entered at checkout
  final String paymentMethod; // Payment method selected at checkout
  final double price; // Price at time of purchase
  final String status; // 'pending' | 'confirmed' | 'shipped' | 'delivered'
  final DateTime createdAt; // Timestamp when the order was placed

  const ProductOrder({
    required this.orderId,
    required this.userId,
    required this.productId,
    required this.productName,
    this.imageUrl = '',
    required this.address,
    required this.paymentMethod,
    required this.price,
    this.status = 'pending',
    required this.createdAt,
  });

  // ── Firestore deserialization ──────────────────────────────────────────────
  // Called when reading an order document back from Firestore.
  factory ProductOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductOrder(
      orderId: data['orderId'] as String? ?? doc.id,
      userId: data['userId'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      address: data['address'] as String? ?? '',
      paymentMethod: data['paymentMethod'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // ── Firestore serialization ────────────────────────────────────────────────
  // Called when writing a new order document to Firestore.
  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'userId': userId,
      'productId': productId,
      'productName': productName,
      'imageUrl': imageUrl,
      'address': address,
      'paymentMethod': paymentMethod,
      'price': price,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Formatted price string with Philippine Peso symbol.
  String get formattedPrice => '₱${price.toStringAsFixed(2)}';
}
