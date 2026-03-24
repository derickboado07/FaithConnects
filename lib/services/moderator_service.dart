// Ini-import natin ang Firestore package para makapag-read/write tayo sa database.
import 'package:cloud_firestore/cloud_firestore.dart';
// Ini-import natin ang Firebase Auth para ma-identify kung sinong moderator
// ang naka-login ngayon. Ginamit ang alias na 'fb_auth' para hindi mag-conflict
// sa ibang class names.
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

/// Centralised service for all moderator actions.
/// Ito ang main service na ginagamit ng moderator para sa lahat ng actions
/// tulad ng ban, delete, hide, atbp. Lahat ng changes ay awtomatikong
/// nila-log sa 'logs' collection para may record.
class ModeratorService {
  // Private constructor — ibig sabihin, walang ibang class ang pwedeng
  // mag-create ng bagong instance nito gamit ang 'new ModeratorService()'.
  ModeratorService._();
  // Singleton pattern — isang instance lang ng ModeratorService ang gagamitin
  // sa buong app. Ina-access mo siya gamit ang ModeratorService.instance.
  static final ModeratorService instance = ModeratorService._();

  // Reference sa Firestore database. Ito ang gamit natin para mag-read at
  // mag-write ng data sa Firebase.
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Kinukuha ang UID (unique ID) ng kasalukuyang naka-login na moderator.
  // Kung walang naka-login, mag-rereturn ng null.
  String? get _moderatorId => fb_auth.FirebaseAuth.instance.currentUser?.uid;

  // ───────────────────────── ACTION LOGGING ─────────────────────────
  // Ito ang section para sa pag-log ng lahat ng ginagawa ng moderator.

  /// Private method na nagsa-save ng log entry sa Firestore tuwing may
  /// ginagawang action ang moderator (e.g., ban, delete, hide).
  /// [action] — ang pangalan ng ginawa (e.g., 'ban_user', 'delete_post')
  /// [targetId] — ang ID ng na-affect na user/post/comment
  Future<void> _log(String action, String targetId) async {
    // Kunin ang ID ng moderator na naka-login ngayon.
    final modId = _moderatorId;
    // Kung walang naka-login (null ang modId), wag na mag-log.
    if (modId == null) return;
    try {
      // Mag-add ng bagong document sa 'logs' collection na may detalye
      // kung sino ang gumawa, ano ang ginawa, kanino ginawa, at kailan.
      await _db.collection('logs').add({
        'moderatorId': modId,       // Sino ang moderator
        'action': action,           // Ano ang ginawa
        'targetId': targetId,       // Kanino ginawa
        'timestamp': FieldValue.serverTimestamp(), // Kailan ginawa (server time)
      });
    } catch (_) {
      // Kung mag-fail ang pag-save ng log, okay lang — hindi ito critical.
      // Ang mismong action (ban, delete, etc.) ay natapos na naman.
    }
  }

  // ───────────────────────── DASHBOARD ANALYTICS ────────────────────
  // Ito ang section para sa pagkuha ng mga stats/numbers na ipapakita
  // sa moderator dashboard.

  /// Kinukuha ang mga summary stats: total users, posts, reports, at
  /// kung ilan ang naka-ban. Magagamit ito para sa dashboard overview.
  Future<Map<String, int>> getDashboardStats() async {
    // Sabay-sabay (concurrently) kinukuha ang data mula sa tatlong
    // collections para mas mabilis — hindi na naghihintayan isa-isa.
    final results = await Future.wait([
      _db.collection('users').get(),    // Kunin lahat ng users
      _db.collection('posts').get(),    // Kunin lahat ng posts
      _db.collection('reports').get(),  // Kunin lahat ng reports
    ]);

    // I-assign ang results sa kanya-kanyang variable para madaling gamitin.
    final usersSnap = results[0];   // Lahat ng users
    final postsSnap = results[1];   // Lahat ng posts
    final reportsSnap = results[2]; // Lahat ng reports

    // Bilangin kung ilan ang users na naka-ban.
    int bannedUsers = 0;
    for (final doc in usersSnap.docs) {
      // Tinitignan ang 'status' field ng bawat user document.
      // Kung 'banned' ang status, dagdagan ang count.
      if ((doc.data() as Map<String, dynamic>)['status'] == 'banned') bannedUsers++;
    }

    // I-return ang Map na may mga bilang para sa dashboard.
    return {
      'totalUsers': usersSnap.size,       // Kabuuang bilang ng users
      'totalPosts': postsSnap.size,       // Kabuuang bilang ng posts
      'totalReports': reportsSnap.size,   // Kabuuang bilang ng reports
      'bannedUsers': bannedUsers,         // Bilang ng mga naka-ban na users
    };
  }

  // ───────────────────────── POSTS MANAGEMENT ───────────────────────
  // Ito ang section para sa pag-manage ng mga posts — view, delete, hide,
  // at restore.

  /// Nagba-stream (real-time updates) ng lahat ng posts, naka-order by
  /// timestamp na pinakabago muna (descending). Kapag may nagbago sa
  /// Firestore, awtomatikong mag-update ang UI.
  Stream<QuerySnapshot> streamPosts() {
    return _db
        .collection('posts')                         // Pumunta sa 'posts' collection
        .orderBy('timestamp', descending: true)      // Pinakabago muna
        .snapshots();                                // Real-time stream
  }

  /// Hard-delete — permanenteng tatanggalin ang post mula sa database.
  /// Hindi na ito mare-recover. Pagkatapos, magla-log ng action.
  Future<void> deletePost(String postId) async {
    await _db.collection('posts').doc(postId).delete(); // Burahin ang post document
    await _log('delete_post', postId);                  // I-log ang action
  }

  /// Soft-delete — hindi binubura ang post, pero itatago lang (hidden).
  /// Ise-set ang status sa 'hidden' para hindi na makita ng users,
  /// pero nandoon pa rin sa database kung kailanganin i-restore.
  Future<void> hidePost(String postId) async {
    await _db
        .collection('posts')
        .doc(postId)
        .update({'status': 'hidden'});   // Palitan ang status ng 'hidden'
    await _log('hide_post', postId);     // I-log ang action
  }

  /// I-restore ang isang post na na-hide — ibabalik ang status sa 'active'
  /// para makita ulit ng users.
  Future<void> restorePost(String postId) async {
    await _db
        .collection('posts')
        .doc(postId)
        .update({'status': 'active'});     // Ibalik sa 'active' status
    await _log('restore_post', postId);    // I-log ang action
  }

  // ───────────────────────── COMMENTS MANAGEMENT ────────────────────
  // Ito ang section para sa pag-manage ng mga comments — view, remove,
  // at restore.

  /// Nagba-stream (real-time) ng lahat ng comments sa buong app,
  /// naka-order by 'createdAt' na pinakabago muna. Ang comments dito ay
  /// nasa top-level 'comments' collection (hindi sub-collection ng posts).
  Stream<QuerySnapshot> streamComments() {
    return _db
        .collection('comments')                        // Pumunta sa 'comments' collection
        .orderBy('createdAt', descending: true)        // Pinakabago muna
        .snapshots();                                  // Real-time stream
  }

  /// Soft-delete ng comment — hindi binubura, pero pinapalitan ang status
  /// ng 'removed' para hindi na makita ng users. Nandoon pa rin sa database.
  Future<void> removeComment(String commentId) async {
    await _db
        .collection('comments')
        .doc(commentId)
        .update({'status': 'removed'});      // Palitan status ng 'removed'
    await _log('remove_comment', commentId); // I-log ang action
  }

  /// I-restore ang isang comment na na-remove — ibabalik sa 'active'
  /// para makita ulit ng users.
  Future<void> restoreComment(String commentId) async {
    await _db
        .collection('comments')
        .doc(commentId)
        .update({'status': 'active'});          // Ibalik sa 'active'
    await _log('restore_comment', commentId);   // I-log ang action
  }

  // ───────────────────────── USER MANAGEMENT ────────────────────────
  // Ito ang section para sa pag-manage ng mga users — view, ban, unban,
  // disable/enable posting.

  /// Nagba-stream (real-time) ng lahat ng users. Kapag may nag-register,
  /// na-ban, o na-update, awtomatikong mag-refresh ang list.
  Stream<QuerySnapshot> streamUsers() {
    return _db.collection('users').snapshots(); // Real-time stream ng lahat ng users
  }

  /// Ban a user.
  /// I-ba-ban ang user gamit ang userId niya — ise-set ang status niya
  /// sa 'banned' para hindi na siya makapag-access o makapag-post.
  /// Pagkatapos ma-ban, awtomatikong magla-log ng action para sa record.
  Future<void> banUser(String userId) async {
    await _db
        .collection('users')
        .doc(userId)
        .update({'status': 'banned'});
    await _log('ban_user', userId);
  }

  /// I-unban ang user — ibabalik ang status sa 'active' para makapag-access
  /// at makapag-post ulit siya sa app.
  Future<void> unbanUser(String userId) async {
    await _db
        .collection('users')
        .doc(userId)
        .update({'status': 'active'});   // Ibalik sa 'active'
    await _log('unban_user', userId);    // I-log ang action
  }

  /// I-disable ang posting para sa specific na user — ise-set ang 'canPost'
  /// field sa false. Hindi siya naka-ban, pero hindi na siya makakapag-post.
  Future<void> disablePosting(String userId) async {
    await _db
        .collection('users')
        .doc(userId)
        .update({'canPost': false});        // Hindi na pwedeng mag-post
    await _log('disable_posting', userId);  // I-log ang action
  }

  /// I-enable ulit ang posting para sa user — ibabalik ang 'canPost' sa true
  /// para makakapag-post na ulit siya.
  Future<void> enablePosting(String userId) async {
    await _db
        .collection('users')
        .doc(userId)
        .update({'canPost': true});         // Pwede na ulit mag-post
    await _log('enable_posting', userId);   // I-log ang action
  }

  // ───────────────────────── REPORT MANAGEMENT ──────────────────────
  // Ito ang section para sa pag-manage ng mga reports na galing sa users
  // na nag-report ng abusive/inappropriate na content.

  /// Nagba-stream (real-time) ng mga reports. Pwede i-filter by status
  /// (e.g., 'pending', 'resolved'). Kung walang ibinigay na status,
  /// lahat ng reports ang makikita, pinakabago muna.
  Stream<QuerySnapshot> streamReports({String? status}) {
    // Base query: lahat ng reports, naka-order by timestamp (pinakabago muna)
    Query q = _db.collection('reports').orderBy('timestamp', descending: true);
    if (status != null) {
      // Kung may ibinigay na status filter, i-filter ang results
      q = q.where('status', isEqualTo: status);
    }
    return q.snapshots(); // Real-time stream
  }

  /// I-resolve ang report — ibig sabihin, na-review na ng moderator at
  /// may ginawang action. Ise-set ang status sa 'resolved'.
  Future<void> resolveReport(String reportId) async {
    await _db
        .collection('reports')
        .doc(reportId)
        .update({'status': 'resolved'});    // Mark as resolved
    await _log('resolve_report', reportId); // I-log ang action
  }

  /// I-ignore ang report — i-mark din as 'resolved' pero walang ginawang
  /// action sa reported content. Ginagamit kung hindi naman totoong
  /// violation ang report.
  Future<void> ignoreReport(String reportId) async {
    await _db
        .collection('reports')
        .doc(reportId)
        .update({'status': 'resolved'});   // Mark as resolved (pero ignored lang)
    await _log('ignore_report', reportId); // I-log na 'ignore' ang action para distinct sa 'resolve'
  }

  /// I-delete ang content na ni-report (post o comment), tapos i-resolve
  /// ang report. Dalawang hakbang sa isang method:
  /// 1. I-delete/remove ang mismong post o comment.
  /// 2. I-mark as resolved ang report.
  Future<void> deleteReportedContent(
    String reportId,   // ID ng report
    String targetId,   // ID ng post o comment na iri-remove
    String type,       // 'post' o 'comment' — para malaman kung alin ang ide-delete
  ) async {
    if (type == 'post') {
      await deletePost(targetId);      // Kung post, i-hard-delete
    } else if (type == 'comment') {
      await removeComment(targetId);   // Kung comment, i-soft-delete (removed)
    }
    await resolveReport(reportId);     // Tapos, i-resolve ang report
  }

  // ───────────────────────── LOGS ───────────────────────────────────
  // Ito ang section para sa pag-view ng moderator action logs (history
  // ng lahat ng ginawa ng mga moderator).

  /// Nagba-stream (real-time) ng lahat ng moderator action logs.
  /// Makikita dito ang history kung sino ang nag-ban, nag-delete, nag-hide,
  /// atbp. — pinakabagong action muna ang nasa taas.
  Stream<QuerySnapshot> streamLogs() {
    return _db
        .collection('logs')                          // Pumunta sa 'logs' collection
        .orderBy('timestamp', descending: true)      // Pinakabago muna
        .snapshots();                                // Real-time stream
  }

  // ───────────────────────── CONTENT FILTERING / SEARCH ─────────────
  // Ito ang section para sa pag-search ng posts at comments gamit ang
  // keyword. Client-side filtering ang ginagamit (kinukuha muna lahat,
  // tapos fini-filter sa Dart code).

  /// Hanapin ang mga posts na may laman ng keyword. Kinukuha muna lahat
  /// ng posts mula sa Firestore, tapos fini-filter sa client-side.
  /// Case-insensitive ang search (hindi alintana kung uppercase o lowercase).
  Future<List<QueryDocumentSnapshot>> searchPosts(String keyword) async {
    final snap = await _db.collection('posts').get(); // Kunin lahat ng posts
    final lower = keyword.toLowerCase();               // Gawing lowercase ang keyword
    // I-filter: ibalik lang ang mga post na may content na naglalaman ng keyword.
    return snap.docs.where((d) {
      final content = (d.data()['content'] as String? ?? '').toLowerCase();
      return content.contains(lower); // True kung may match
    }).toList();
  }

  /// Hanapin ang mga comments na may laman ng keyword — same logic sa
  /// searchPosts. Kinukuha lahat ng comments tapos fini-filter client-side.
  Future<List<QueryDocumentSnapshot>> searchComments(String keyword) async {
    final snap = await _db.collection('comments').get(); // Kunin lahat ng comments
    final lower = keyword.toLowerCase();                  // Gawing lowercase ang keyword
    // I-filter: ibalik lang ang mga comment na naglalaman ng keyword.
    return snap.docs.where((d) {
      final content = (d.data()['content'] as String? ?? '').toLowerCase();
      return content.contains(lower); // True kung may match
    }).toList();
  }
}
