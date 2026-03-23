import 'package:flutter/material.dart';

/// A reusable avatar widget that shows a network image when [photoUrl] is
/// provided and non-empty, otherwise shows the user's initials derived from
/// [name] on a gold-tinted background.
///
/// Usage:
/// ```dart
/// UserAvatar(photoUrl: user.avatarUrl, name: user.name, radius: 20)
/// ```
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 20,
    this.backgroundColor,
  });

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    return parts.map((s) => s[0]).take(2).join().toUpperCase();
  }

  Color get _bg =>
      backgroundColor ?? const Color(0xFFD4AF37).withValues(alpha: 0.20);

  @override
  Widget build(BuildContext context) {
    final url = (photoUrl?.isNotEmpty == true) ? photoUrl! : null;

    return CircleAvatar(
      radius: radius,
      backgroundColor: _bg,
      child: ClipOval(
        child: url != null
            ? Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return SizedBox(
                    width: radius * 2,
                    height: radius * 2,
                    child: Center(
                      child: SizedBox(
                        width: radius * 0.7,
                        height: radius * 0.7,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: const Color(0xFFD4AF37),
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (ctx, err, st) => _initialsWidget,
              )
            : _initialsWidget,
      ),
    );
  }

  Widget get _initialsWidget => SizedBox(
    width: radius * 2,
    height: radius * 2,
    child: Center(
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: radius * 0.75,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF5A4800),
        ),
      ),
    ),
  );
}
