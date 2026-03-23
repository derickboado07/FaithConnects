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
    'timestamp': timestamp.toIso8601String(),
    'read': read,
    'type': type,
  };

  static AppNotification fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'],
    userId: j['userId'],
    title: j['title'],
    body: j['body'],
    timestamp: DateTime.parse(j['timestamp']),
    read: j['read'] ?? false,
    type: j['type'] ?? 'general',
  );
}
