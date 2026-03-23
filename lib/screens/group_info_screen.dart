import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/message_service.dart';

class GroupInfoScreen extends StatefulWidget {
  final Conversation conversation;

  const GroupInfoScreen({super.key, required this.conversation});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  bool _loading = false;

  Future<void> _removeMember(String uid) async {
    setState(() => _loading = true);
    try {
      await MessageService.instance.removeMember(widget.conversation.id, uid);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to remove: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMemberDialog() async {
    final textCtrl = TextEditingController();
    final uid = await showDialog<String?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add member by UID'),
        content: TextField(
          controller: textCtrl,
          decoration: const InputDecoration(hintText: 'Enter user id'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, textCtrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (uid == null || uid.isEmpty) return;
    setState(() => _loading = true);
    try {
      await MessageService.instance.addMember(widget.conversation.id, uid);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.conversation.name ?? 'Group Info')),
      body: Column(
        children: [
          ListTile(
            title: const Text('Members'),
            trailing: IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _addMemberDialog,
            ),
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(widget.conversation.id)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());
                final d = snap.data!.data() as Map<String, dynamic>?;
                final members = (d != null && d['participants'] is List)
                    ? List<String>.from(d['participants'])
                    : <String>[];
                final admins = (d != null && d['admins'] is List)
                    ? List<String>.from(d['admins'])
                    : <String>[];
                return ListView.separated(
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final uid = members[i];
                    final isAdmin = admins.contains(uid);
                    return ListTile(
                      title: Text(uid),
                      subtitle: isAdmin ? const Text('Admin') : null,
                      trailing: admins.contains(uid)
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _loading
                                  ? null
                                  : () => _removeMember(uid),
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
