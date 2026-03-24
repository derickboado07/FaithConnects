// Ini-import ang mga kailangan na packages.
import 'dart:io';
import 'package:flutter/foundation.dart'; // Uint8List para sa raw bytes (web)
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore database
import 'package:firebase_storage/firebase_storage.dart'; // Firebase Storage para sa images
import '../models/product_model.dart'; // Product data model
import '../models/order_model.dart'; // ProductOrder data model

// ─────────────────────────────────────────────────────────────────────────────
// MARKETPLACE SERVICE — Ang service na ito ang nag-ha-handle ng lahat ng
// Firestore read/write operations at Firebase Storage uploads para sa
// Marketplace module ng app.
//
// Mga responsibilidad:
//   • Pagkuha ng product list mula sa Firestore (real-time stream)
//   • Pag-upload ng product images sa Firebase Storage
//   • Pag-save ng bagong product listings sa Firestore
//   • Pag-manage ng user shopping cart (Firestore subcollection)
//   • Pag-create ng order documents sa Firestore kapag nag-checkout
//
// Mga Firestore collections na ginagamit:
//   - products/{productId}              — Mga product listings
//   - carts/{userId}/items/{productId}  — Shopping cart ng user
//   - orders/{orderId}                  — Mga placed orders
//
// Firebase Storage paths:
//   - product_images/{userId}/{timestamp}_{filename}
// ─────────────────────────────────────────────────────────────────────────────

class MarketplaceService {
  // Private constructor at singleton instance.
  // Isang instance lang ng MarketplaceService ang gagamitin sa buong app.
  MarketplaceService._internal();
  static final MarketplaceService instance = MarketplaceService._internal();

  // Firestore at Storage instances para sa database at file operations.
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ─── PRODUCT READ OPERATIONS (PAGKUHA NG PRODUCTS) ─────────────────

  /// Nire-return ang real-time stream ng products mula sa Firestore
  /// "products" collection, naka-order by creation date (pinakabago muna).
  ///
  /// [category] — optional filter. I-pass ang 'All' o null para lahat ng products.
  ///
  /// Awtomatikong nagba-broadcast ng updates kapag may na-add, na-update,
  /// o na-remove na product sa Firestore.
  Stream<List<Product>> getProductsStream({String? category}) {
    Query<Map<String, dynamic>> query = _db
        .collection('products')
        .orderBy('createdAt', descending: true);

    if (category != null && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList(),
    );
  }

  /// Paged fetch para sa products (pinakabago muna). [startAfter] ay ang
  /// DateTime ng last product mula sa previous page para sa pagination.
  Future<List<Product>> getProductsPage({int limit = 20, DateTime? startAfter, String? category}) async {
    Query<Map<String, dynamic>> query = _db.collection('products').orderBy('createdAt', descending: true);
    if (startAfter != null) {
      query = query.startAfter([Timestamp.fromDate(startAfter)]);
    }
    if (category != null && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }
    query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
  }

  /// Kinukuha ang isang product document by ID. Returns null kung hindi nahanap.
  Future<Product?> getProduct(String productId) async {
    final doc = await _db.collection('products').doc(productId).get();
    if (!doc.exists) return null;
    return Product.fromFirestore(doc);
  }

  /// Basic product search by name o description (prefix match).
  /// Hinahanap sa parehong productName at description fields.
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

  // ─── IMAGE UPLOAD SA FIREBASE STORAGE ────────────────────────────

  /// Nag-a-upload ng product image sa Firebase Storage.
  ///
  /// Nag-ha-handle ng parehong web (imageBytes) at mobile/desktop (imagePath).
  /// Naka-store ang images sa: product_images/{userId}/{timestamp}_{filename}
  ///
  /// Nire-return ang public download URL ng uploaded image, na pagkatapos
  /// ay ise-store sa Firestore product document bilang [imageUrl].
  Future<String> uploadProductImage({
    String? imagePath, // Mobile/desktop: local file path
    Uint8List? imageBytes, // Web: raw image bytes
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

  // ─── PRODUCT WRITE OPERATIONS (PAG-SAVE NG PRODUCTS) ──────────────

  /// Sine-save ang bagong product listing sa Firestore "products" collection.
  ///
  /// Tinatawag mula sa SellProductScreen pagkatapos successful ang image upload.
  /// Ang [imageUrl] ay kailangang Firebase Storage download URL na galing sa
  /// [uploadProductImage].
  ///
  /// Nire-return ang auto-generated Firestore document ID (productId).
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

  // ─── CART OPERATIONS (SHOPPING CART) ─────────────────────────────

  /// Nagda-dagdag ng product sa shopping cart ng user, o dina-dagdagan ang
  /// quantity kung nasa cart na ang product.
  ///
  /// Cart Firestore path: /carts/{userId}/items/{productId}
  ///
  /// Tinatawag mula sa ProductDetailScreen kapag ni-tap ng user ang "Buy Now".
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
      await cartItemRef.update({'quantity': FieldValue.increment(quantity)});
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

  // ─── ORDER WRITE OPERATIONS (PAG-PLACE NG ORDER) ─────────────────

  /// Gumagawa ng bagong order document sa Firestore "orders" collection.
  ///
  /// Tinatawag mula sa CheckoutScreen pagkatapos i-confirm ng user ang purchase
  /// at lahat ng form fields ay pumasa sa validation.
  ///
  /// Pagkatapos i-save ang order, awtomatikong tinatanggal ang product
  /// mula sa cart ng user para consistent ang cart state.
  ///
  /// Nire-return ang auto-generated orderId, na ipapasa sa
  /// OrderConfirmationScreen para i-display.
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
      buyerId: userId,
      productId: product.productId,
      productName: product.productName,
      imageUrl: product.imageUrl,
      address: address,
      paymentMethod: paymentMethod,
      price: product.price,
      status: 'pending', // Initial order status
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
