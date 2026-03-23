import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final cur = AuthService.instance.currentUser.value;
    if (cur == null) {
      return const Scaffold(body: Center(child: Text('Sign in first')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('New Chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or email',
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('name')
                  .limit(100)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) {
                  if (d.id == cur.id) return false;
                  if (_query.isEmpty) return true;
                  final name = (d['name'] ?? '').toString().toLowerCase();
                  final email = (d['email'] ?? '').toString().toLowerCase();
                  final q = _query.toLowerCase();
                  return name.contains(q) || email.contains(q);
                }).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_search,
                          size: 56,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _query.isEmpty
                              ? 'No users yet'
                              : 'No users match "$_query"',
                          style: const TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final d = filtered[i];
                    final name = (d['name'] ?? d['email'] ?? 'User').toString();
                    final avatar = (d['avatar'] ?? '').toString();
                    return ListTile(
                      leading: UserAvatar(
                        photoUrl: avatar,
                        name: name,
                        radius: 22,
                      ),
                      title: Text(name),
                      subtitle: Text(
                        (d['email'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888888),
                        ),
                      ),
                      onTap: () async {
                        try {
                          final convoId = await MessageService.instance
                              .ensureConversationWith(d.id);
                          if (!mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                convoId: convoId,
                                peerId: d.id,
                                peerName: name,
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to start chat: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
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
