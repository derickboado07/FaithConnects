import 'dart:async';
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

  /// Global navigator key – set this from the MaterialApp so we can show
  /// in-app banner notifications from anywhere.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Real-time listener for incoming notifications (shows banners to the
  /// current user when someone else triggers a notification for them).
  StreamSubscription? _incomingNotifSub;
  bool _initialSnapshotSkipped = false;

  /// Call this during app startup (e.g., in main())
  Future<void> initialize(BuildContext context) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap – navigate to notification screen
        navigatorKey.currentState?.pushNamed('/notifications');
      },
    );
  }

  // ── Real-time incoming notification listener ──────────────────────

  /// Start listening for NEW notifications for [userId].
  /// Shows an in-app banner whenever a new unread notification arrives.
  void startListeningForUser(String userId) {
    stopListening();
    _initialSnapshotSkipped = false;
    _incomingNotifSub = _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snap) {
        // Skip the very first snapshot (existing docs).
        if (!_initialSnapshotSkipped) {
          _initialSnapshotSkipped = true;
          return;
        }
        // Only react to newly added documents.
        for (final change in snap.docChanges) {
          if (change.type == DocumentChangeType.added) {
            try {
              final n = AppNotification.fromJson(change.doc.data()!);
              if (!n.read) {
                showInAppBanner(title: n.title, body: n.body);
              }
            } catch (e) {
              debugPrint('NotificationService: banner parse error: $e');
            }
          }
        }
      },
      onError: (e) {
        debugPrint('NotificationService: incoming listener error: $e');
      },
    );
    debugPrint('NotificationService: started listening for user $userId');
  }

  /// Stop the incoming-notification listener.
  void stopListening() {
    _incomingNotifSub?.cancel();
    _incomingNotifSub = null;
  }

  // ── In-app banner ────────────────────────────────────────────────

  /// Show an in-app banner at the top of the screen.
  void showInAppBanner({required String title, required String body}) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final overlay = Overlay.of(ctx);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopBannerNotification(
        title: title,
        body: body,
        onDismiss: () => entry.remove(),
        onTap: () {
          entry.remove();
          navigatorKey.currentState?.pushNamed('/notifications');
        },
      ),
    );
    overlay.insert(entry);
  }

  // ── Create / write notification ──────────────────────────────────

  /// Save a notification to Firestore for [userId] (the RECIPIENT).
  /// The in-app banner is NOT shown here — the recipient's real-time
  /// listener (`startListeningForUser`) takes care of that.
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
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        platformChannelSpecifics,
        payload: type,
      );
    } catch (_) {
      // Local notification failure is non-fatal; Firestore record still saved.
    }

    // Save to Firestore for notification list
    try {
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
      debugPrint('NotificationService: saved notification to users/$userId/notifications/${docRef.id}');
    } catch (e) {
      debugPrint('NotificationService: Firestore write FAILED for user $userId: $e');
    }
  }

  // ── Read / update helpers ────────────────────────────────────────

  /// Mark a single notification as read.
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugPrint('NotificationService: markAsRead failed: $e');
    }
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
    } catch (e) {
      debugPrint('NotificationService: markAllAsRead failed: $e');
    }
  }

  /// Stream notifications for a user (for notification screen).
  Stream<List<AppNotification>> notificationsForUser(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) {
                try {
                  return AppNotification.fromJson(d.data());
                } catch (e) {
                  debugPrint('NotificationService: failed to parse notification ${d.id}: $e');
                  return null;
                }
              }).whereType<AppNotification>().toList(),
        );
  }

  /// Stream unread notification count for badge display.
  Stream<int> unreadCountForUser(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}

// ============================================
// IN-APP TOP BANNER NOTIFICATION WIDGET
// ============================================

class _TopBannerNotification extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _TopBannerNotification({
    required this.title,
    required this.body,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_TopBannerNotification> createState() =>
      _TopBannerNotificationState();
}

class _TopBannerNotificationState extends State<_TopBannerNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _autoDismiss = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    _autoDismiss?.cancel();
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! < 0) {
              _dismiss();
            }
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFE8C95A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.body,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: _dismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}
