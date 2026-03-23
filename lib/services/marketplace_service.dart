import 'dart:io';
import 'package:flutter/foundation.dart'; // Uint8List is re-exported here
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/product_model.dart';
import '../models/order_model.dart'; // ProductOrder

// ─────────────────────────────────────────────────────────────────────────────
// MARKETPLACE SERVICE
//
// Singleton service class that handles all Firestore read/write operations and
// Firebase Storage uploads for the Marketplace module.
//
// Responsibilities:
//   • Retrieving the product list from Firestore (real-time stream)
//   • Uploading product images to Firebase Storage
//   • Saving new product listings to Firestore
//   • Managing the user's shopping cart (Firestore subcollection)
//   • Creating order documents in Firestore on purchase confirmation
//
// Firestore collections used:
//   - products/{productId}         — Product listings
//   - carts/{userId}/items/{productId} — User shopping cart
//   - orders/{orderId}             — Placed orders
//
// Firebase Storage paths:
//   - product_images/{userId}/{timestamp}_{filename}
// ─────────────────────────────────────────────────────────────────────────────

class MarketplaceService {
  // Private constructor enforces singleton usage.
  MarketplaceService._internal();
  static final MarketplaceService instance = MarketplaceService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ─── PRODUCT READ OPERATIONS ────────────────────────────────────────────

  /// Returns a real-time stream of products from the Firestore "products"
  /// collection, ordered by creation date (newest first).
  ///
  /// [category] — optional filter. Pass 'All' or null to fetch all products.
  ///
  /// The stream automatically emits updates whenever a product is added,
  /// updated, or removed in Firestore.
  Stream<List<Product>> getProductsStream({String? category}) {
    // To avoid requiring composite indexes (where + orderBy), we always
    // order by createdAt on the server and apply the category filter client-side
    // when a specific category is requested. This makes the stream resilient
    // to missing indexes and prevents a transient empty/error snapshot that
    // would hide items briefly in the UI.
    final query = _db.collection('products').orderBy('createdAt', descending: true);
    return query.snapshots().map((snapshot) {
      final all = snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
      if (category != null && category.isNotEmpty && category != 'All') {
        return all.where((p) => p.category == category).toList();
      }
      return all;
    });
  }

  /// Paged fetch for products (newest first). [startAfter] is the DateTime of
  /// the last product from the previous page to continue pagination.
  Future<List<Product>> getProductsPage({int limit = 20, DateTime? startAfter, String? category}) async {
    // Query server for newest products and apply category filter client-side
    Query<Map<String, dynamic>> query = _db.collection('products').orderBy('createdAt', descending: true);
    if (startAfter != null) {
      query = query.startAfter([Timestamp.fromDate(startAfter)]);
    }
    final snap = await query.limit(limit).get();
    final all = snap.docs.map((d) => Product.fromFirestore(d)).toList();
    if (category != null && category.isNotEmpty && category != 'All') {
      return all.where((p) => p.category == category).toList();
    }
    return all;
  }

  /// Fetches a single product document by ID. Returns null if not found.
  Future<Product?> getProduct(String productId) async {
    final doc = await _db.collection('products').doc(productId).get();
    if (!doc.exists) return null;
    return Product.fromFirestore(doc);
  }

  /// Basic product search by name or description (prefix match).
  Future<List<Product>> searchProducts(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final end = q + '\uf8ff';

    final nameSnap = await _db
        .collection('products')
        .where('productName', isGreaterThanOrEqualTo: q)
        .where('productName', isLessThanOrEqualTo: end)
        .limit(limit)
        .get();

    final descSnap = await _db
        .collection('products')
        .where('description', isGreaterThanOrEqualTo: q)
        .where('description', isLessThanOrEqualTo: end)
        .limit(limit)
        .get();

    final docs = <QueryDocumentSnapshot>{};
    docs.addAll(nameSnap.docs);
    docs.addAll(descSnap.docs);

    final products = docs.map((d) => Product.fromFirestore(d)).toList();
    return products;
  }

  // ─── IMAGE UPLOAD TO FIREBASE STORAGE ───────────────────────────────────

  /// Uploads a product image to Firebase Storage.
  ///
  /// Handles both web (imageBytes) and mobile/desktop (imagePath) platforms.
  /// Images are stored at: product_images/{userId}/{timestamp}_{filename}
  ///
  /// Returns the public download URL of the uploaded image, which is then
  /// stored in the Firestore product document as [imageUrl].
  Future<String> uploadProductImage({
    String? imagePath,       // Mobile/desktop: local file path
    Uint8List? imageBytes,   // Web: raw image bytes
    required String filename,
    required String userId,
  }) async {
    // Build a unique storage path to avoid filename collisions.
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'product_images/$userId/${timestamp}_$filename';
    final ref = _storage.ref().child(storagePath);

    UploadTask task;

    if (kIsWeb || imageBytes != null) {
      // Web platform: upload raw bytes with JPEG content type.
      if (imageBytes == null) {
        throw Exception('Image bytes are required on the web platform.');
      }
      task = ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } else {
      // Mobile / desktop: upload directly from the local file path.
      if (imagePath == null) {
        throw Exception('Image path is required on mobile/desktop platforms.');
      }
      task = ref.putFile(File(imagePath));
    }

    // Await the upload task and retrieve the public download URL.
    final snapshot = await task;
    return await snapshot.ref.getDownloadURL();
  }

  // ─── PRODUCT WRITE OPERATIONS ───────────────────────────────────────────

  /// Saves a new product listing to the Firestore "products" collection.
  ///
  /// Called by SellProductScreen after image upload succeeds.
  /// The [imageUrl] must be the Firebase Storage download URL returned by
  /// [uploadProductImage].
  ///
  /// Returns the auto-generated Firestore document ID (productId).
  Future<String> addProduct({
    required String productName,
    required String description,
    required double price,
    required String category,
    required String imageUrl,
    required String sellerId,
    required String sellerName,
    required String sellerEmail,
  }) async {
    // Generate a new document reference with an auto-ID before writing,
    // so we can embed the productId inside the document itself.
    final docRef = _db.collection('products').doc();

    final product = Product(
      productId: docRef.id,
      productName: productName,
      description: description,
      price: price,
      imageUrl: imageUrl,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerEmail: sellerEmail,
      category: category,
      createdAt: DateTime.now(),
    );

    // Write the serialized product map to Firestore.
    await docRef.set(product.toMap());
    return docRef.id;
  }

  // ─── CART OPERATIONS ────────────────────────────────────────────────────

  /// Adds a product to the user's cart, or increments its quantity if the
  /// product is already in the cart.
  ///
  /// Cart Firestore path: /carts/{userId}/items/{productId}
  ///
  /// Called from ProductDetailScreen when the user taps "Buy Now".
  Future<void> addToCart({
    required String userId,
    required Product product,
    int quantity = 1,
  }) async {
    final cartItemRef = _db
        .collection('carts')
        .doc(userId)
        .collection('items')
        .doc(product.productId);

    final existing = await cartItemRef.get();

    if (existing.exists) {
      // Item already in cart — increment quantity using FieldValue.increment
      // to avoid race conditions with concurrent writes.
      await cartItemRef.update({
        'quantity': FieldValue.increment(quantity),
      });
    } else {
      // First time adding — create a new cart item document.
      await cartItemRef.set({
        'productId': product.productId,
        'productName': product.productName,
        'price': product.price,
        'imageUrl': product.imageUrl,
        'sellerId': product.sellerId,
        'quantity': quantity,
        'addedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  // ─── ORDER WRITE OPERATIONS ─────────────────────────────────────────────

  /// Creates a new order document in the Firestore "orders" collection.
  ///
  /// This is called from CheckoutScreen after the user confirms their purchase
  /// and all form fields pass validation.
  ///
  /// After saving the order, this method removes the product from the user's
  /// cart to keep the cart state consistent.
  ///
  /// Returns the auto-generated orderId, which is passed to
  /// OrderConfirmationScreen for display.
  Future<String> placeOrder({
    required String userId,
    required Product product,
    required String address,
    required String paymentMethod,
  }) async {
    // Generate a new order document reference with an auto-ID.
    final docRef = _db.collection('orders').doc();

    final order = ProductOrder(
      orderId: docRef.id,
      userId: userId,
      productId: product.productId,
      productName: product.productName,
      imageUrl: product.imageUrl,
      address: address,
      paymentMethod: paymentMethod,
      price: product.price,
      status: 'pending',      // Initial order status
      createdAt: DateTime.now(),
    );

    // Write the order document to Firestore.
    // Firestore security rules expect `buyerId` and `sellerId` keys —
    // ensure these aliases are present so the create rule allows the write.
    final map = order.toMap();
    map['buyerId'] = userId;
    map['sellerId'] = product.sellerId;
    await docRef.set(map);

    // Remove the ordered item from the user's cart (best-effort; no throw).
    try {
      await _db
          .collection('carts')
          .doc(userId)
          .collection('items')
          .doc(product.productId)
          .delete();
    } catch (_) {
      // Cart item may not exist (e.g. user bypassed cart) — safe to ignore.
    }

    return docRef.id;
  }
}
