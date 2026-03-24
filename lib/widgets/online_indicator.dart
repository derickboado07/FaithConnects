import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/presence_service.dart';

/// A small green dot that appears when [uid] is online.
/// Uses a real-time Firestore stream so the dot updates instantly.
class OnlineIndicator extends StatelessWidget {
  final String uid;
  final double size;
  final double borderWidth;

  const OnlineIndicator({
    super.key,
    required this.uid,
    this.size = 14,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<Map<String, dynamic>>(
      stream: PresenceService.instance.userStatusStream(uid),
      builder: (context, snap) {
        final data = snap.data;
        final isOnline = data?['isOnline'] == true;
        final rawLastActive = data?['lastActive'];
        bool showDot = isOnline;
        if (!isOnline && rawLastActive != null) {
          try {
            final DateTime dt;
            if (rawLastActive is Timestamp) {
              dt = rawLastActive.toDate();
            } else {
              dt = DateTime.parse(rawLastActive.toString());
            }
            showDot = DateTime.now().difference(dt).inSeconds < 60;
          } catch (_) {}
        }
        if (!showDot) return const SizedBox.shrink();
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isOnline ? Colors.green : Colors.green.shade200,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: borderWidth),
          ),
        );
      },
    );
  }
}

/// Shows "Active now" or "Last seen X ago" for a given user.
class UserStatusText extends StatelessWidget {
  final String uid;
  final TextStyle? style;

  const UserStatusText({super.key, required this.uid, this.style});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<Map<String, dynamic>>(
      stream: PresenceService.instance.userStatusStream(uid),
      builder: (context, snap) {
        final data = snap.data;
        final isOnline = data?['isOnline'] == true;
        final rawLastActive = data?['lastActive'];
        final lastActive = rawLastActive is Timestamp
            ? rawLastActive.toDate().toIso8601String()
            : (rawLastActive is String ? rawLastActive : '');
        String text;
        if (isOnline) {
          text = 'Active now';
        } else {
          text = PresenceService.formatLastSeen(lastActive);
        }
        if (text.isEmpty) return const SizedBox.shrink();
        return Text(
          text,
          style:
              style ??
              TextStyle(
                fontSize: 12,
                color: isOnline ? Colors.green : const Color(0xFF888888),
              ),
        );
      },
    );
  }
}

/// Shows the user's note (short status message) if set.
class UserNoteText extends StatelessWidget {
  final String uid;
  final TextStyle? style;
  final int maxLines;

  const UserNoteText({
    super.key,
    required this.uid,
    this.style,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final note = data?['note'] as String? ?? '';
        if (note.isEmpty) return const SizedBox.shrink();
        return Text(
          note,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style:
              style ??
              const TextStyle(
                fontSize: 12,
                color: Color(0xFF888888),
                fontStyle: FontStyle.italic,
              ),
        );
      },
    );
  }
}
