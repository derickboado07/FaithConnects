// ═══════════════════════════════════════════════════════════════════════════
// GROUP SETTINGS SCREEN — Full group management screen.
// Admin controls:
//   • I-edit ang group name
//   • I-change ang group avatar
//   • Mag-add ng mga bagong members
//   • Mag-remove ng existing members
//   • I-leave ang group (for non-admins)
//
// Kung hindi admin — read-only view lang (nakikita ang info pero
// hindi pwede mag-edit).
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:image_picker/image_picker.dart';
import '../services/message_service.dart';

/// Full group management screen — accessible from the group chat header.
/// Admins see edit controls; regular members see a read-only view.
class GroupSettingsScreen extends StatefulWidget {
  final String convoId;

  const GroupSettingsScreen({super.key, required this.convoId});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final String _myUid = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? ''; // UID ng current user
  bool _uploading = false; // True habang nag-u-upload ng group avatar

  // ── Avatar ─────────────────────────────────────────────────────────
  /// Admin-only: Pumipili ng bagong group avatar at ina-upload sa Firestore.
  Future<void> _pickAndUploadAvatar(String convoId) async {
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 512,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open gallery: $e')));
      return;
    }
    if (picked == null) return;
    Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not read image: $e')));
      return;
    }
    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      await MessageService.instance.updateGroupAvatar(
        convoId,
        bytes,
        picked.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Group photo updated ✨')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Edit Name ──────────────────────────────────────────────────────────
  /// Admin-only: Nagpapakita ng dialog para i-edit ang group name.
  Future<void> _showEditNameDialog(
    BuildContext context,
    String convoId,
    String currentName,
  ) async {
    final ctrl = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Edit Group Name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Group name'),
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(c, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newName == null || newName.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await MessageService.instance.updateGroupName(convoId, newName);
      if (!mounted) return;
      await MessageService.instance.sendSystemMessage(
        convoId,
        'Group name changed to "$newName"',
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Group name updated')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update name: $e')),
      );
    }
  }

  // ── Add Members Sheet ──────────────────────────────────────────────────
  /// Admin-only: Nagpapakita ng bottom sheet para mag-add ng bagong members.
  Future<void> _showAddMemberSheet(
    BuildContext context,
    String convoId,
    List<String> currentMembers,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMemberSheet(
        convoId: convoId,
        currentMembers: List.unmodifiable(currentMembers),
      ),
    );
  }

  // ── Remove Member ──────────────────────────────────────────────────────
  /// Admin-only: Nag-aalis ng member mula sa group.
  Future<void> _removeMember(
    BuildContext context,
    String convoId,
    String uid,
    String displayName,
    List<String> admins,
  ) async {
    if (admins.length == 1 && admins.contains(uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove the last admin from the group'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove $displayName from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await MessageService.instance.removeMember(convoId, uid);
      if (!mounted) return;
      await MessageService.instance.sendSystemMessage(
        convoId,
        '$displayName was removed from the group',
      );
      messenger.showSnackBar(
        SnackBar(content: Text('$displayName was removed')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to remove: $e')));
    }
  }

  // ── Promote to Admin ───────────────────────────────────────────────────
  /// Admin-only: Nag-po-promote ng member bilang admin.
  Future<void> _promoteToAdmin(
    BuildContext context,
    String convoId,
    String uid,
    String displayName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Promote to Admin'),
        content: Text('Make $displayName a group admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Promote'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await MessageService.instance.promoteToAdmin(convoId, uid);
      if (!mounted) return;
      await MessageService.instance.sendSystemMessage(
        convoId,
        '$displayName is now an admin 🙌',
      );
      messenger.showSnackBar(
        SnackBar(content: Text('$displayName is now an admin')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to promote: $e')));
    }
  }

  // ── Leave Group ────────────────────────────────────────────────────────
  /// Para sa regular members: nag-le-leave sa group.
  /// Kung admin at wala nang ibang admin, hindi pwede mag-leave basta-basta.
  Future<void> _leaveGroup(
    BuildContext context,
    String convoId,
    List<String> members,
    List<String> admins,
  ) async {
    // Guard: sole admin with other members must promote first
    if (admins.contains(_myUid) && admins.length == 1 && members.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You are the only admin. '
            'Promote another member before leaving.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await MessageService.instance.leaveGroup(convoId);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to leave group: $e')));
    }
  }

  // ── Delete Group ───────────────────────────────────────────────────────
  /// Admin-only: Nag-de-delete ng buong group conversation.
  Future<void> _deleteGroup(BuildContext context, String convoId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
          'This will permanently delete the group and all its messages. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await MessageService.instance.deleteGroup(convoId);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete group: $e')));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('Group Settings'), centerTitle: true),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.convoId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // Group was deleted — navigate away
          if (snap.hasData && !snap.data!.exists) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            });
            return const SizedBox.shrink();
          }

          final d = (snap.data?.data() ?? {}) as Map<String, dynamic>;
          final convoId = widget.convoId;
          final name = (d['name'] as String?) ?? 'Group';
          final photoUrl = d['photoUrl'] as String?;
          final members = d['participants'] is List
              ? List<String>.from(d['participants'])
              : <String>[];
          final admins = d['admins'] is List
              ? List<String>.from(d['admins'])
              : <String>[];
          final isAdmin = admins.contains(_myUid);

          return ListView(
            children: [
              // ── Header: avatar + name ──────────────────────────────
              _GroupHeader(
                name: name,
                photoUrl: photoUrl,
                memberCount: members.length,
                isAdmin: isAdmin,
                uploading: _uploading,
                onTapAvatar: () => _pickAndUploadAvatar(convoId),
                onTapName: () => _showEditNameDialog(context, convoId, name),
              ),

              // ── Members section ────────────────────────────────────
              _SectionHeader(label: 'MEMBERS (${members.length})'),

              if (isAdmin)
                _AddMemberTile(
                  onTap: () => _showAddMemberSheet(context, convoId, members),
                ),

              ...members.map(
                (uid) => _MemberTile(
                  uid: uid,
                  myUid: _myUid,
                  isAdminOfGroup: isAdmin,
                  isMemberAdmin: admins.contains(uid),
                  admins: admins,
                  onRemove: (displayName) =>
                      _removeMember(context, convoId, uid, displayName, admins),
                  onPromote: (displayName) =>
                      _promoteToAdmin(context, convoId, uid, displayName),
                ),
              ),

              const Divider(height: 32, thickness: 1),

              // ── Actions ────────────────────────────────────────────
              _SectionHeader(label: 'ACTIONS'),

              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3E0),
                  child: Icon(Icons.logout, color: Colors.orange),
                ),
                title: const Text(
                  'Leave Group',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () => _leaveGroup(context, convoId, members, admins),
              ),

              if (isAdmin)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE),
                    child: Icon(Icons.delete_forever, color: Colors.red),
                  ),
                  title: const Text(
                    'Delete Group',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => _deleteGroup(context, convoId),
                ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

// ── Subwidgets ──────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final int memberCount;
  final bool isAdmin;
  final bool uploading;
  final VoidCallback onTapAvatar;
  final VoidCallback onTapName;

  const _GroupHeader({
    required this.name,
    required this.photoUrl,
    required this.memberCount,
    required this.isAdmin,
    required this.uploading,
    required this.onTapAvatar,
    required this.onTapName,
  });

  String _initials(String n) {
    if (n.isEmpty) return 'G';
    return n
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: const Color(0xFFD4AF37),
                backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                    ? NetworkImage(photoUrl!)
                    : null,
                child: (photoUrl == null || photoUrl!.isEmpty)
                    ? Text(
                        _initials(name),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              if (isAdmin)
                GestureDetector(
                  onTap: uploading ? null : onTapAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onTapName,
                  child: const Icon(
                    Icons.edit,
                    size: 18,
                    color: Color(0xFFD4AF37),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$memberCount member${memberCount == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF999999),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _AddMemberTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMemberTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.white,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.15),
        child: const Icon(Icons.person_add, color: Color(0xFFD4AF37)),
      ),
      title: const Text(
        'Add Members',
        style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }
}

/// Displays a single member row.  Resolves user name + avatar from Firestore.
class _MemberTile extends StatelessWidget {
  final String uid;
  final String myUid;
  final bool isAdminOfGroup; // current user is admin
  final bool isMemberAdmin; // this member is admin
  final List<String> admins;
  final void Function(String displayName) onRemove;
  final void Function(String displayName) onPromote;

  const _MemberTile({
    required this.uid,
    required this.myUid,
    required this.isAdminOfGroup,
    required this.isMemberAdmin,
    required this.admins,
    required this.onRemove,
    required this.onPromote,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = uid == myUid;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (ctx, snap) {
        final userData = (snap.hasData && snap.data!.exists)
            ? snap.data!.data() as Map<String, dynamic>
            : <String, dynamic>{};
        final displayName =
            userData['name'] as String? ?? userData['email'] as String? ?? uid;
        final avatarUrl = userData['photoUrl'] as String?;

        return ListTile(
          tileColor: Colors.white,
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFEEEEEE),
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? NetworkImage(avatarUrl)
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          title: Text(
            isMe ? '$displayName (You)' : displayName,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: isMemberAdmin
              ? const Text(
                  'Admin',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )
              : const Text('Member', style: TextStyle(fontSize: 12)),
          trailing: (!isMe && isAdminOfGroup)
              ? PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'remove') onRemove(displayName);
                    if (val == 'promote') onPromote(displayName);
                  },
                  itemBuilder: (_) => [
                    if (!isMemberAdmin)
                      const PopupMenuItem(
                        value: 'promote',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.star_outline),
                          title: Text('Make admin'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red,
                        ),
                        title: Text(
                          'Remove from group',
                          style: TextStyle(color: Colors.red),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}

// ── Add Member Bottom Sheet ─────────────────────────────────────────────────

class _AddMemberSheet extends StatefulWidget {
  final String convoId;
  final List<String> currentMembers;

  const _AddMemberSheet({required this.convoId, required this.currentMembers});

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  final Set<String> _adding = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _results = []);
      return;
    }
    if (mounted) setState(() => _searching = true);
    try {
      final q = query.trim().toLowerCase();
      // Search by name prefix; falls back to showing all if index not set up
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('nameLower')
          .startAt([q])
          .endAt(['$q\uf8ff'])
          .limit(20)
          .get();
      final myUid = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
      // Fall back to a simple name search if nameLower field doesn't exist
      final List<Map<String, dynamic>> found;
      if (snap.docs.isEmpty) {
        // Broad search — fetch recent users and filter client-side
        final fallback = await FirebaseFirestore.instance
            .collection('users')
            .limit(50)
            .get();
        found = fallback.docs
            .where(
              (d) =>
                  d.id != myUid &&
                  !widget.currentMembers.contains(d.id) &&
                  ((d['name'] as String?)?.toLowerCase().contains(q) ?? false),
            )
            .map((d) => {'uid': d.id, ...d.data()})
            .toList();
      } else {
        found = snap.docs
            .where(
              (d) => d.id != myUid && !widget.currentMembers.contains(d.id),
            )
            .map((d) => {'uid': d.id, ...d.data()})
            .toList();
      }
      if (mounted) setState(() => _results = found);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addMember(String uid, String displayName) async {
    if (_adding.contains(uid)) return;
    setState(() => _adding.add(uid));
    try {
      await MessageService.instance.addMember(widget.convoId, uid);
      if (!mounted) return;
      await MessageService.instance.sendSystemMessage(
        widget.convoId,
        '$displayName was added to the group 🙏',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$displayName added 🙏')));
      setState(() => _results.removeWhere((u) => u['uid'] == uid));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
    } finally {
      if (mounted) setState(() => _adding.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Members',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search by name…',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: _search,
                ),
              ),
              if (_searching) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _searchCtrl.text.isEmpty
                                ? 'Type a name to search for people'
                                : 'No users found',
                            style: const TextStyle(color: Color(0xFF888888)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final user = _results[i];
                          final uid = user['uid'] as String;
                          final displayName =
                              user['name'] as String? ??
                              user['email'] as String? ??
                              uid;
                          final avatarUrl = user['photoUrl'] as String?;
                          final isAdding = _adding.contains(uid);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFEEEEEE),
                              backgroundImage:
                                  (avatarUrl != null && avatarUrl.isNotEmpty)
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: (avatarUrl == null || avatarUrl.isEmpty)
                                  ? Text(
                                      displayName.isNotEmpty
                                          ? displayName[0].toUpperCase()
                                          : '?',
                                    )
                                  : null,
                            ),
                            title: Text(displayName),
                            trailing: isAdding
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.person_add_alt_1,
                                      color: Color(0xFFD4AF37),
                                    ),
                                    onPressed: () =>
                                        _addMember(uid, displayName),
                                  ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
