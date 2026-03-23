import 'package:flutter/material.dart';
import '../services/message_service.dart';
import 'group_settings_screen.dart';

/// Thin wrapper kept for backward compatibility.
/// Redirects to the full [GroupSettingsScreen].
class GroupInfoScreen extends StatelessWidget {
  final Conversation conversation;

  const GroupInfoScreen({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    return GroupSettingsScreen(convoId: conversation.id);
  }
}
