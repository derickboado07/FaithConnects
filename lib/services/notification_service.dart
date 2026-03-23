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

  /// Show a notification to the user and save it to Firestore
  Future<void> showNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    // Local notification
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'like_channel',
          'Likes',
          channelDescription: 'Notifications for post likes',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await _flutterLocalNotificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: null,
    );

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
    );
    await docRef.set(notification.toJson());
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
