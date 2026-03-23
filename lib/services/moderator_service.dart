import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

/// Centralised service for all moderator actions.
/// Every mutation is automatically logged to the `logs` collection.
class ModeratorService {
  ModeratorService._();
  static final ModeratorService instance = ModeratorService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _moderatorId => fb_auth.FirebaseAuth.instance.currentUser?.uid;

  // ───────────────────────── ACTION LOGGING ─────────────────────────

  Future<void> _log(String action, String targetId) async {
    final modId = _moderatorId;
    if (modId == null) return;
    await _db.collection('logs').add({
      'moderatorId': modId,
      'action': action,
      'targetId': targetId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ───────────────────────── DASHBOARD ANALYTICS ────────────────────

  Future<Map<String, int>> getDashboardStats() async {
    final usersSnap = await _db.collection('users').get();
    final postsSnap = await _db.collection('posts').get();
    final reportsSnap = await _db.collection('reports').get();

    int bannedUsers = 0;
    for (final doc in usersSnap.docs) {
      if (doc.data()['status'] == 'banned') bannedUsers++;
    }

    return {
      'totalUsers': usersSnap.size,
      'totalPosts': postsSnap.size,
      'totalReports': reportsSnap.size,
      'bannedUsers': bannedUsers,
    };
  }

  // ───────────────────────── POSTS MANAGEMENT ───────────────────────

  /// Stream all posts ordered by creation date (newest first).
  Stream<QuerySnapshot> streamPosts() {
    return _db
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Hard-delete a post.
  Future<void> deletePost(String postId) async {
    await _db.collection('posts').doc(postId).delete();
    await _log('delete_post', postId);
  }

  /// Soft-delete: set status to hidden.
  Future<void> hidePost(String postId) async {
    await _db
        .collection('posts')
        .doc(postId)
        .update({'status': 'hidden'});
    await _log('hide_post', postId);
  }

  /// Restore a hidden post.
  Future<void> restorePost(String postId) async {
    await _db
        .collection('posts')
        .doc(postId)
        .update({'status': 'active'});
    await _log('restore_post', postId);
  }

  // ───────────────────────── COMMENTS MANAGEMENT ────────────────────

  /// Stream all comments across all posts (top-level `comments` collection
  /// style). Adjust if comments live as sub-collections under posts.
  Stream<QuerySnapshot> streamComments() {
    return _db
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Remove a comment (soft-delete → status = removed).
  Future<void> removeComment(String commentId) async {
    await _db
        .collection('comments')
        .doc(commentId)
        .update({'status': 'removed'});
    await _log('remove_comment', commentId);
  }

  /// Restore a removed comment.
  Future<void> restoreComment(String commentId) async {
    await _db
        .collection('comments')
        .doc(commentId)
        .update({'status': 'active'});
    await _log('restore_comment', commentId);
  }

  // ───────────────────────── USER MANAGEMENT ────────────────────────

  /// Stream all users.
  Stream<QuerySnapshot> streamUsers() {
    return _db.collection('users').snapshots();
  }

  /// Ban a user.
  Future<void> banUser(String userId) async {
    await _db
        .collection('users')
        .doc(userId)
        .set({'status': 'banned'}, SetOptions(merge: true));
    await _log('ban_user', userId);
  }

  /// Unban a user.
  Future<void> unbanUser(String userId) async {
    await _db
        .collection('users')
        .doc(userId)
        .set({'status': 'active'}, SetOptions(merge: true));
    await _log('unban_user', userId);
  }

  /// Disable posting for a specific user.
  Future<void> disablePosting(String userId) async {
    await _db
        .collection('users')
        .doc(userId)
        .set({'canPost': false}, SetOptions(merge: true));
    await _log('disable_posting', userId);
  }

  /// Enable posting for a specific user.
  Future<void> enablePosting(String userId) async {
    await _db
        .collection('users')
        .doc(userId)
        .set({'canPost': true}, SetOptions(merge: true));
    await _log('enable_posting', userId);
  }

  // ───────────────────────── REPORT MANAGEMENT ──────────────────────

  /// Stream reports, optionally filtered by status.
  Stream<QuerySnapshot> streamReports({String? status}) {
    Query q = _db.collection('reports').orderBy('timestamp', descending: true);
    if (status != null) {
      q = q.where('status', isEqualTo: status);
    }
    return q.snapshots();
  }

  /// Resolve a report.
  Future<void> resolveReport(String reportId) async {
    await _db
        .collection('reports')
        .doc(reportId)
        .update({'status': 'resolved'});
    await _log('resolve_report', reportId);
  }

  /// Ignore a report (mark resolved without action).
  Future<void> ignoreReport(String reportId) async {
    await _db
        .collection('reports')
        .doc(reportId)
        .update({'status': 'resolved'});
    await _log('ignore_report', reportId);
  }

  /// Delete the content targeted by a report, then resolve the report.
  Future<void> deleteReportedContent(
    String reportId,
    String targetId,
    String type,
  ) async {
    if (type == 'post') {
      await deletePost(targetId);
    } else if (type == 'comment') {
      await removeComment(targetId);
    }
    await resolveReport(reportId);
  }

  // ───────────────────────── LOGS ───────────────────────────────────

  /// Stream moderator action logs.
  Stream<QuerySnapshot> streamLogs() {
    return _db
        .collection('logs')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ───────────────────────── CONTENT FILTERING / SEARCH ─────────────

  /// Search posts by keyword (client-side filter for simplicity).
  Future<List<QueryDocumentSnapshot>> searchPosts(String keyword) async {
    final snap = await _db.collection('posts').get();
    final lower = keyword.toLowerCase();
    return snap.docs.where((d) {
      final content = (d.data()['content'] as String? ?? '').toLowerCase();
      return content.contains(lower);
    }).toList();
  }

  /// Search comments by keyword.
  Future<List<QueryDocumentSnapshot>> searchComments(String keyword) async {
    final snap = await _db.collection('comments').get();
    final lower = keyword.toLowerCase();
    return snap.docs.where((d) {
      final content = (d.data()['content'] as String? ?? '').toLowerCase();
      return content.contains(lower);
    }).toList();
  }
}
