/// Model for user notifications
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool read;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.timestamp,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
    'read': read,
  };

  static AppNotification fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'],
    userId: j['userId'],
    title: j['title'],
    body: j['body'],
    timestamp: DateTime.parse(j['timestamp']),
    read: j['read'] ?? false,
  );
}
