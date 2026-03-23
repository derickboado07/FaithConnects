import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

/// NotificationService handles local notifications for the app.
/// You can extend this to support push notifications (e.g., Firebase Cloud Messaging) if needed.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Call this during app startup (e.g., in main())
  Future<void> initialize(BuildContext context) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap
        // You can navigate to a specific screen if needed
      },
    );
  }

  /// Show a notification to the user and save it to Firestore.
  /// [type] can be 'reaction', 'comment', 'share', 'comment_reaction', or 'general'.
  Future<void> showNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'general',
  }) async {
    // Local notification (best-effort — may not work on all platforms)
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'faithconnect_channel',
            'FaithConnect Notifications',
            channelDescription:
                'Notifications for reactions, comments, and shares',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          );
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );
      await _flutterLocalNotificationsPlugin.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
        payload: type,
      );
    } catch (_) {
      // Local notification failure is non-fatal; Firestore record still saved.
    }

    // Save to Firestore for notification list
    final docRef = _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc();
    final notification = AppNotification(
      id: docRef.id,
      userId: userId,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      type: type,
    );
    await docRef.set(notification.toJson());
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (_) {}
  }

  /// Mark all notifications as read for a user.
  Future<void> markAllAsRead(String userId) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Stream notifications for a user (for notification screen)
  Stream<List<AppNotification>> notificationsForUser(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => AppNotification.fromJson(d.data())).toList(),
        );
  }
}
