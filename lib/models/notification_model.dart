import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for user notifications
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool read;

  /// Type of notification: 'reaction', 'comment', 'share', 'comment_reaction'
  final String type;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.timestamp,
    this.read = false,
    this.type = 'general',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'body': body,
    'timestamp': Timestamp.fromDate(timestamp),
    'read': read,
    'type': type,
  };

  static AppNotification fromJson(Map<String, dynamic> j) {
    DateTime ts;
    final raw = j['timestamp'];
    if (raw is Timestamp) {
      ts = raw.toDate();
    } else if (raw is String) {
      ts = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      ts = DateTime.now();
    }
    return AppNotification(
      id: j['id'] ?? '',
      userId: j['userId'] ?? '',
      title: j['title'] ?? '',
      body: j['body'] ?? '',
      timestamp: ts,
      read: j['read'] ?? false,
      type: j['type'] ?? 'general',
    );
  }
}
