// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION SERVICE — Ang service na ito ang nag-ha-handle ng
// lahat ng notifications sa app. Mga responsibilidad:
//   • Local notifications (device-level notifications)
//   • In-app banner notifications (overlay sa taas ng screen)
//   • Firestore-based notification storage at retrieval
//   • Real-time listening para sa incoming notifications
//   • Mark as read (isa-isa at lahat)
//   • Unread count streaming para sa badge display
//
// Firestore collection: users/{userId}/notifications/{notifId}
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

/// Nag-ha-handle ng local at in-app notifications.
/// Singleton pattern — isang instance lang sa buong app.
/// Pwede i-extend ito para sa push notifications (Firebase Cloud Messaging).
class NotificationService {
  // Private constructor at singleton instance.
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  // Flutter Local Notifications plugin para sa device-level notifications.
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Firestore instance para sa pag-save at pag-read ng notifications.
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Global navigator key — ini-set ito mula sa MaterialApp para
  /// makapag-show ng in-app banner notifications kahit saan sa app.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Real-time listener para sa incoming notifications.
  /// Nagsha-show ng banners sa current user kapag may bagong notification.
  StreamSubscription? _incomingNotifSub;
  bool _initialSnapshotSkipped = false; // Para i-skip ang existing docs sa first load

  /// Tinatawag ito during app startup (sa main()) para i-initialize
  /// ang local notifications plugin.
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

  /// Magsisimulang makinig sa mga BAGONG notifications para sa [userId].
  /// Nagsha-show ng in-app banner kapag may dumating na bagong unread notification.
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

  /// Ihihinto ang incoming-notification listener.
  void stopListening() {
    _incomingNotifSub?.cancel();
    _incomingNotifSub = null;
  }

  // ── In-app banner ────────────────────────────────────────────────

  /// Nagsha-show ng in-app banner notification sa taas ng screen.
  /// May auto-dismiss after 4 seconds, at navi-navigate sa
  /// notifications screen kapag ni-tap.
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

  /// Sine-save ang notification sa Firestore para sa [userId] (ang RECIPIENT).
  /// Ang in-app banner ay HINDI sini-show dito — ang real-time listener
  /// ng recipient (`startListeningForUser`) ang bahala doon.
  /// Nag-a-attempt din mag-show ng local notification (device-level).
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

  /// Ini-mark ang isang notification bilang nabasa na (read).
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

  /// Ini-mark ang LAHAT ng notifications bilang nabasa na para sa isang user.
  /// Ginagamit ang batched write para mas efficient.
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

  /// Real-time stream ng notifications para sa isang user.
  /// Ginagamit sa notification screen para ipakita ang list ng notifications.
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

  /// Real-time stream ng unread notification count para sa badge display.
  /// Ginagamit sa bottom nav bar o notification icon para ipakita
  /// kung ilan ang hindi pa nabasa.
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
