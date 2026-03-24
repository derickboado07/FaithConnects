// ─────────────────────────────────────────────────────────────────────────────
// POST SERVICE — Ang service na ito ang nag-ha-handle ng lahat ng
// post-related operations sa app (social media feed). Mga responsibilidad:
//   • Pag-create ng posts (with optional image/video media)
//   • Pag-fetch ng feed (latest posts, paged)
//   • Real-time streaming ng posts
//   • Reactions system (like, love, etc.)
//   • Comments at comment reactions
//   • Post sharing (reshare/quote)
//   • Post deletion (with Storage cleanup)
//   • Post search
//   • Save/unsave posts
//   • Upload quota per user (20 uploads per day)
//
// Firestore collections:
//   - posts/{postId}                         — Post documents
//   - posts/{postId}/comments/{commentId}    — Comments
//   - users/{userId}/saved/{postId}          — Saved posts
//   - upload_quotas/{uid}                    — Upload limits
//
// Firebase Storage: posts/{postId}/media
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'notification_service.dart'; // Para sa notifications sa post owner

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL — Comment
// Nagre-represent ng isang comment sa post.
// May support para sa reactions per comment.
// ─────────────────────────────────────────────────────────────────────────────
class Comment {
  final String id;                              // Unique comment ID
  final String authorId;                        // UID ng nag-comment
  final String author;                          // Email/display ng nag-comment
  final String text;                            // Comment text
  final String ts;                              // Timestamp (ISO 8601)
  final Map<String, List<String>> reactions;     // Reactions sa comment

  Comment({
    required this.id,
    required this.authorId,
    required this.author,
    required this.text,
    required this.ts,
    Map<String, List<String>>? reactions,
  }) : reactions = reactions ?? {};
  Map<String, dynamic> toJson() => {
    'id': id,
    'authorId': authorId,
    'author': author,
    'text': text,
    'ts': ts,
    'reactions': reactions.map((k, v) => MapEntry(k, v)),
  };

  static Comment fromJson(Map<String, dynamic> j) => Comment(
    id: j['id'],
    authorId: j['authorId'] ?? '',
    author: j['author'],
    text: j['text'],
    ts: j['ts'],
    reactions:
        (j['reactions'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, List<String>.from(v as List)),
        ) ??
        {},
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL — Post
// Nagre-represent ng isang post sa social feed.
// May support para sa media (image/video), reactions, comments, at sharing.
// ─────────────────────────────────────────────────────────────────────────────
class Post {
  final String id;                              // Unique post ID
  final String authorId;                        // UID ng nag-post
  final String authorEmail;                     // Email ng nag-post
  final String authorAvatarUrl;                 // Avatar URL ng nag-post
  final String content;                         // Post text content
  final String timestamp;                       // Kailan ginawa (ISO 8601)
  final String? mediaUrl;                       // URL ng attached media (kung meron)
  final String? mediaType;                      // 'image' o 'video' o null
  final Map<String, List<String>> reactions;     // reaction → list ng user ids
  final List<Comment> comments;                 // Mga comments sa post
  final int commentCount;                       // Bilang ng comments

  // Shared post fields — populated kapag ito ay reshare ng ibang post.
  final String? sharedPostId;                   // ID ng original post
  final String? sharedAuthorEmail;              // Email ng original author
  final String? sharedAuthorAvatarUrl;          // Avatar ng original author
  final String? sharedContent;                  // Content ng original post
  final String? sharedMediaUrl;                 // Media URL ng original post
  final String? sharedMediaType;                // Media type ng original post

  Post({
    required this.id,
    required this.authorId,
    required this.authorEmail,
    this.authorAvatarUrl = '',
    required this.content,
    required this.timestamp,
    this.mediaUrl,
    this.mediaType,
    Map<String, List<String>>? reactions,
    List<Comment>? comments,
    this.commentCount = 0,
    this.sharedPostId,
    this.sharedAuthorEmail,
    this.sharedAuthorAvatarUrl,
    this.sharedContent,
    this.sharedMediaUrl,
    this.sharedMediaType,
  }) : reactions = reactions ?? {},
       comments = comments ?? [];

  bool get isSharedPost => sharedPostId != null; // True kung reshare ito ng ibang post

  /// Kino-convert ang Post object sa Map para ma-save sa Firestore.
  Map<String, dynamic> toJson() => {
    'id': id,
    'authorId': authorId,
    'author': authorEmail,
    'authorAvatar': authorAvatarUrl,
    'content': content,
    'ts': timestamp,
    'mediaUrl': mediaUrl,
    'mediaType': mediaType,
    'reactions': reactions.map((k, v) => MapEntry(k, v)),
    if (sharedPostId != null) 'sharedPostId': sharedPostId,
    if (sharedAuthorEmail != null) 'sharedAuthorEmail': sharedAuthorEmail,
    if (sharedAuthorAvatarUrl != null)
      'sharedAuthorAvatarUrl': sharedAuthorAvatarUrl,
    if (sharedContent != null) 'sharedContent': sharedContent,
    if (sharedMediaUrl != null) 'sharedMediaUrl': sharedMediaUrl,
    if (sharedMediaType != null) 'sharedMediaType': sharedMediaType,
  };

  /// Ginagawa ang Post object mula sa Firestore data (Map).
  static Post fromJson(Map<String, dynamic> j) => Post(
    id: j['id'],
    authorId: j['authorId'],
    authorEmail: j['author'],
    authorAvatarUrl: j['authorAvatar'] ?? '',
    content: j['content'],
    timestamp: j['ts'],
    mediaUrl: j['mediaUrl'],
    mediaType: j['mediaType'],
    reactions:
        (j['reactions'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, List<String>.from(v as List)),
        ) ??
        {},
    sharedPostId: j['sharedPostId'],
    sharedAuthorEmail: j['sharedAuthorEmail'],
    sharedAuthorAvatarUrl: j['sharedAuthorAvatarUrl'],
    sharedContent: j['sharedContent'],
    sharedMediaUrl: j['sharedMediaUrl'],
    sharedMediaType: j['sharedMediaType'],
    commentCount: (j['commentsCount'] as int?) ?? 0,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// POST SERVICE CLASS
// Singleton na nag-ha-handle ng lahat ng post CRUD operations,
// media uploads, reactions, comments, sharing, at saving.
// ═══════════════════════════════════════════════════════════════════════════
class PostService {
  PostService._internal(); // Private constructor para sa Singleton pattern
  static final PostService instance = PostService._internal(); // Global instance

  final FirebaseFirestore _db = FirebaseFirestore.instance;   // Firestore reference
  final FirebaseStorage _storage = FirebaseStorage.instance;  // Storage reference

  // ─── UPLOAD QUOTA ─────────────────────────────────────────────────────
  // Simple per-user upload quota para i-limit ang uploads at iwasan ang
  // unexpected overage sa Firebase Storage. Nag-ttrack ng uploads per
  // rolling window (default: 1 araw). Ginagamit ang Firestore collection
  // `upload_quotas/{uid}` na may fields: `count` (int) at `windowStart` (Timestamp).
  Future<void> _checkAndIncrementUploadQuota(
    String uid, {
    int limit = 20,
    Duration window = const Duration(days: 1),
  }) async {
    final docRef = _db.collection('upload_quotas').doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final now = DateTime.now();
      if (!snap.exists) {
        tx.set(docRef, {'count': 1, 'windowStart': Timestamp.fromDate(now)});
        return;
      }
      final data = snap.data()!;
      final ts = data['windowStart'] as Timestamp?;
      final int count = (data['count'] as int?) ?? 0;
      if (ts == null) {
        tx.update(docRef, {'count': 1, 'windowStart': Timestamp.fromDate(now)});
        return;
      }
      final windowStart = ts.toDate();
      if (now.difference(windowStart) > window) {
        // reset window
        tx.update(docRef, {'count': 1, 'windowStart': Timestamp.fromDate(now)});
        return;
      }
      if (count >= limit) {
        throw Exception('Upload limit exceeded. Try again later.');
      }
      tx.update(docRef, {'count': count + 1});
    });
  }

  /// Init method — wala pang local cache; Firestore ang gamit.
  Future<void> init() async {
    // Nothing to cache locally; Firestore will be used.
    return;
  }

  // ─── FEED — FETCH & STREAM ────────────────────────────────────────────
  /// Kino-fetch ang latest posts mula sa Firestore (default: 50).
  /// Nilo-load din ang mga comments at nireresolve ang missing avatars.
  Future<List<Post>> fetchFeed({int limit = 50}) async {
    final snap = await _db
        .collection('posts')
        .orderBy('ts', descending: true)
        .limit(limit)
        .get();
    final posts = snap.docs.map((d) => Post.fromJson(d.data())).toList();

    // Batch-fetch ng author avatars para sa posts na walang avatar.
    final missingAvatarIds = posts
        .where((p) => p.authorAvatarUrl.isEmpty && p.authorId.isNotEmpty)
        .map((p) => p.authorId)
        .toSet()
        .toList();
    final Map<String, String> avatarCache = {};
    for (final uid in missingAvatarIds) {
      try {
        final doc = await _db.collection('users').doc(uid).get();
        if (doc.exists) {
          final avatar = doc.data()?['avatar'] as String? ?? '';
          if (avatar.isNotEmpty) avatarCache[uid] = avatar;
        }
      } catch (_) {}
    }

    // I-load ang comments at i-apply ang cached avatars.
    for (var i = 0; i < posts.length; i++) {
      final p = posts[i];
      final cm = await _loadCommentsForPost(p.id);
      final resolvedAvatar = p.authorAvatarUrl.isNotEmpty
          ? p.authorAvatarUrl
          : (avatarCache[p.authorId] ?? '');
      posts[i] = Post(
        id: p.id,
        authorId: p.authorId,
        authorEmail: p.authorEmail,
        authorAvatarUrl: resolvedAvatar,
        content: p.content,
        timestamp: p.timestamp,
        mediaUrl: p.mediaUrl,
        mediaType: p.mediaType,
        reactions: p.reactions,
        comments: cm,
      );
    }
    return posts;
  }

  /// Paged na pag-fetch ng posts (newest first).
  /// Gamitin ang [startAfterTs] — ISO8601 timestamp ng last item sa previous page.
  Future<List<Post>> fetchFeedPaged({int limit = 20, String? startAfterTs}) async {
    Query<Map<String, dynamic>> query = _db.collection('posts').orderBy('ts', descending: true);
    if (startAfterTs != null && startAfterTs.isNotEmpty) {
      query = query.startAfter([startAfterTs]);
    }
    final snap = await query.limit(limit).get();
    final posts = snap.docs.map((d) => Post.fromJson(Map<String, dynamic>.from(d.data() as Map))).toList();
    return posts;
  }

  /// Real-time stream ng feed posts — automatic update kapag may bago.
  Stream<List<Post>> streamFeed({int limit = 50}) {
    return _db
        .collection('posts')
        .orderBy('ts', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Post.fromJson(d.data())).toList());
  }

  /// Kukunin ang isang post by ID (kasama ang comments).
  Future<Post?> getById(String id) async {
    final doc = await _db.collection('posts').doc(id).get();
    if (!doc.exists) return null;
    final p = Post.fromJson(doc.data()!);
    final comments = await _loadCommentsForPost(id);
    return Post(
      id: p.id,
      authorId: p.authorId,
      authorEmail: p.authorEmail,
      authorAvatarUrl: p.authorAvatarUrl,
      content: p.content,
      timestamp: p.timestamp,
      mediaUrl: p.mediaUrl,
      mediaType: p.mediaType,
      reactions: p.reactions,
      comments: comments,
    );
  }

  // ─── SEARCH ─────────────────────────────────────────────────────────
  /// Basic search sa posts by content o author (prefix match).
  /// Note: Firestore walang built-in full-text search; prefix matching lang
  /// sa 'content' at 'author' fields tapos merge results.
  Future<List<Post>> searchPosts(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final end = q + '\uf8ff';

    final contentSnap = await _db
        .collection('posts')
        .where('content', isGreaterThanOrEqualTo: q)
        .where('content', isLessThanOrEqualTo: end)
        .limit(limit)
        .get();

    final authorSnap = await _db
        .collection('posts')
        .where('author', isGreaterThanOrEqualTo: q)
        .where('author', isLessThanOrEqualTo: end)
        .limit(limit)
        .get();

    final docs = <QueryDocumentSnapshot>{};
    docs.addAll(contentSnap.docs);
    docs.addAll(authorSnap.docs);

    final posts = docs
      .map((d) => Post.fromJson(Map<String, dynamic>.from(d.data() as Map)))
      .toList();
    return posts;
  }

  // ─── MEDIA UPLOAD ─────────────────────────────────────────────────────
  // Nag-a-upload ng media either mula sa local file path (mobile/desktop)
  // o mula sa raw bytes (web). Kapag may [data], gagamitin ang [filename];
  // kung wala, gagamitin ang [localPath].
  Future<String?> _uploadMedia(
    String postId, {
    String? localPath,
    Uint8List? data,
    String? filename,
    String? mediaType,
  }) async {
    try {
      final refBase = _storage.ref().child('posts').child(postId);
      Reference ref;
      TaskSnapshot task;

      if (data != null && filename != null) {
        ref = refBase.child(filename);
        final ext = filename.contains('.')
            ? filename.split('.').last.toLowerCase()
            : '';
        String mime;
        switch (ext) {
          case 'png':
            mime = 'image/png';
            break;
          case 'gif':
            mime = 'image/gif';
            break;
          case 'webp':
            mime = 'image/webp';
            break;
          case 'mp4':
            mime = 'video/mp4';
            break;
          case 'mov':
            mime = 'video/quicktime';
            break;
          case 'avi':
            mime = 'video/x-msvideo';
            break;
          case 'jpg':
          case 'jpeg':
            mime = 'image/jpeg';
            break;
          default:
            mime = (mediaType == 'video') ? 'video/mp4' : 'image/jpeg';
        }
        final metadata = SettableMetadata(contentType: mime);
        final uploadTask = ref.putData(data, metadata);
        task = await uploadTask.timeout(
          const Duration(seconds: 120),
          onTimeout: () => throw TimeoutException(
            'Media upload timed out. Check your connection and try again.',
          ),
        );
      } else if (localPath != null && localPath.isNotEmpty) {
        final file = File(localPath);
        if (!await file.exists()) {
          debugPrint('PostService: media file not found at $localPath');
          return null;
        }
        ref = refBase.child('media');
        task = await ref.putFile(file);
      } else {
        return null;
      }

      final url = await task.ref.getDownloadURL().timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
            throw TimeoutException('Failed to get download URL. Try again.'),
      );
      return url;
    } catch (e) {
      debugPrint('PostService: media upload failed: $e');
      rethrow; // Let addPost decide whether to proceed or fail
    }
  }

  // ─── ADD POST ─────────────────────────────────────────────────────────
  /// Gumagawa ng bagong post (with optional media upload).
  /// Nag-che-check muna ng upload quota bago mag-proceed.
  Future<void> addPost(
    String authorId,
    String authorEmail,
    String content, {
    String authorAvatarUrl = '',
    String? mediaPath,
    Uint8List? mediaBytes,
    String? mediaFilename,
    String? mediaType,
  }) async {
    // Enforce per-user quota para iwasan ang accidental overage. Mag-throw kung exceeded.
    try {
      await _checkAndIncrementUploadQuota(
        authorId,
        limit: 20,
        window: Duration(days: 1),
      );
    } catch (e) {
      debugPrint(
        'PostService.addPost: upload quota exceeded for $authorId: $e',
      );
      rethrow;
    }
    final docRef = _db.collection('posts').doc();
    final id = docRef.id;
    String? mediaUrl;
    try {
      if (mediaBytes != null && mediaFilename != null) {
        mediaUrl = await _uploadMedia(
          id,
          data: mediaBytes,
          filename: mediaFilename,
          mediaType: mediaType,
        );
      } else if (mediaPath != null && mediaPath.isNotEmpty) {
        final cleanPath = mediaPath.startsWith('file://')
            ? mediaPath.substring(7)
            : mediaPath;
        mediaUrl = await _uploadMedia(
          id,
          localPath: cleanPath,
          mediaType: mediaType,
        );
      }
    } catch (e) {
      debugPrint('PostService.addPost: media upload error: $e');
      // Rethrow so the UI can show the error and reset the spinner.
      rethrow;
    }
    final post = Post(
      id: id,
      authorId: authorId,
      authorEmail: authorEmail,
      authorAvatarUrl: authorAvatarUrl,
      content: content,
      timestamp: DateTime.now().toIso8601String(),
      mediaUrl: mediaUrl,
      mediaType: mediaUrl != null ? mediaType : null,
      comments: [],
    );
    debugPrint('PostService: creating post id=$id author=$authorId');
    await docRef.set(post.toJson());
    debugPrint('PostService: post created successfully');
  }

  // ─── SHARED POST ─────────────────────────────────────────────────────
  /// Gumagawa ng share/reshare ng existing post.
  /// Kinokopya ang original post data sa new post document.
  /// [content] ay ang optional caption ng sharer.
  Future<void> addSharedPost({
    required String authorId,
    required String authorEmail,
    String authorAvatarUrl = '',
    required String content,
    required Post originalPost,
  }) async {
    try {
      await _checkAndIncrementUploadQuota(
        authorId,
        limit: 20,
        window: Duration(days: 1),
      );
    } catch (e) {
      debugPrint(
        'PostService.addSharedPost: upload quota exceeded for $authorId: $e',
      );
      rethrow;
    }
    final docRef = _db.collection('posts').doc();
    final id = docRef.id;
    final post = Post(
      id: id,
      authorId: authorId,
      authorEmail: authorEmail,
      authorAvatarUrl: authorAvatarUrl,
      content: content,
      timestamp: DateTime.now().toIso8601String(),
      sharedPostId: originalPost.id,
      sharedAuthorEmail: originalPost.authorEmail,
      sharedAuthorAvatarUrl: originalPost.authorAvatarUrl,
      sharedContent: originalPost.content,
      sharedMediaUrl: originalPost.mediaUrl,
      sharedMediaType: originalPost.mediaType,
    );
    debugPrint(
      'PostService: creating shared post id=$id author=$authorId sharedPost=${originalPost.id}',
    );
    await docRef.set(post.toJson());
    debugPrint('PostService: shared post created successfully');

    // I-notify ang original post owner kung may nag-share
    if (originalPost.authorId != authorId) {
      try {
        await NotificationService.instance.showNotification(
          userId: originalPost.authorId,
          title: 'Your post was shared!',
          body: '$authorEmail shared your post.',
          type: 'share',
        );
      } catch (e) {
        debugPrint('PostService: share notification failed (non-fatal): $e');
      }
    }
  }

  // ─── COMMENTS ─────────────────────────────────────────────────────────
  /// Nilo-load ang lahat ng comments para sa isang post.
  Future<List<Comment>> _loadCommentsForPost(String postId) async {
    final snap = await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('ts')
        .get();
    return snap.docs.map((d) => Comment.fromJson(d.data())).toList();
  }

  /// Real-time stream ng comments para sa isang post.
  Stream<List<Comment>> streamComments(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => Comment.fromJson(d.data()))
              .toList();
          list.sort((a, b) => a.ts.compareTo(b.ts));
          return list;
        });
  }

  // ─── COMMENT REACTIONS ────────────────────────────────────────────────
  /// Toggle ng reaction sa isang comment. Gumagamit ng per-comment `reactions` map
  /// kung saan keys ang reaction ids at values ang lists ng user ids.
  Future<void> toggleCommentReaction(
    String postId,
    String commentId,
    String reactionKey,
    String userId,
  ) async {
    final docRef = _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    bool reactionAdded = false;
    String? commentAuthorId;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      commentAuthorId = data['authorId'] as String?;
      final Map<String, dynamic> existing =
          (data['reactions'] as Map<String, dynamic>?) ?? {};
      final List<String> list = List<String>.from(existing[reactionKey] ?? []);
      if (list.contains(userId)) {
        list.remove(userId);
      } else {
        list.add(userId);
        reactionAdded = true;
      }
      final updated = Map<String, dynamic>.from(existing);
      updated[reactionKey] = list;
      tx.update(docRef, {'reactions': updated});
    });

    // I-notify ang comment author kapag may nag-react sa comment nila
    if (reactionAdded && commentAuthorId != null && commentAuthorId != userId) {
      try {
        final userDoc = await _db.collection('users').doc(userId).get();
        final userName =
            (userDoc.data()?['name'] as String?)?.isNotEmpty == true
            ? userDoc.data()!['name'] as String
            : (userDoc.data()?['email'] as String?) ?? 'Someone';
        await NotificationService.instance.showNotification(
          userId: commentAuthorId!,
          title: 'Someone reacted to your comment!',
          body: '$userName reacted "$reactionKey" to your comment.',
          type: 'comment_reaction',
        );
      } catch (e) {
        debugPrint(
          'PostService: comment reaction notification failed (non-fatal): $e',
        );
      }
    }
  }

  // ─── USER POSTS ──────────────────────────────────────────────────────
  /// Kinukuha ang lahat ng posts ng isang user (by email o userId).
  /// Kasama na ang comments ng bawat post.
  Future<List<Post>> getPostsForUser(String email, {String? userId}) async {
    // Query by authorId if available (avoids composite index requirement),
    // otherwise fall back to querying by author email.
    Query<Map<String, dynamic>> query;
    if (userId != null && userId.isNotEmpty) {
      query = _db.collection('posts').where('authorId', isEqualTo: userId);
    } else {
      query = _db.collection('posts').where('author', isEqualTo: email);
    }
    final snap = await query.get();
    final posts = snap.docs.map((d) => Post.fromJson(d.data())).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    for (var i = 0; i < posts.length; i++) {
      final cm = await _loadCommentsForPost(posts[i].id);
      posts[i] = Post(
        id: posts[i].id,
        authorId: posts[i].authorId,
        authorEmail: posts[i].authorEmail,
        authorAvatarUrl: posts[i].authorAvatarUrl,
        content: posts[i].content,
        timestamp: posts[i].timestamp,
        mediaUrl: posts[i].mediaUrl,
        mediaType: posts[i].mediaType,
        reactions: posts[i].reactions,
        comments: cm,
      );
    }
    return posts;
  }

  /// Real-time stream ng posts para sa specific user.
  Stream<List<Post>> streamPostsForUser(String userId) {
    return _db
        .collection('posts')
        .where('authorId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final posts = snap.docs.map((d) => Post.fromJson(d.data())).toList();
          posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return posts;
        });
  }

  // ─── DELETE POST ─────────────────────────────────────────────────────
  /// Binu-bura ang post document at mga associated storage media sa posts/{postId}.
  Future<void> deletePost(String postId) async {
    // Delete storage objects under posts/{postId}
    try {
      final refBase = _storage.ref().child('posts').child(postId);
      // List all children and delete them (supports nested files)
      final listResult = await refBase.listAll();
      for (final item in listResult.items) {
        try {
          await item.delete();
        } catch (_) {}
      }
      for (final prefix in listResult.prefixes) {
        // recursively delete items under prefixes
        final subList = await prefix.listAll();
        for (final it in subList.items) {
          try {
            await it.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('PostService.deletePost: storage cleanup failed: $e');
    }

    // Delete the Firestore document
    try {
      await _db.collection('posts').doc(postId).delete();
    } catch (e) {
      debugPrint('PostService.deletePost: firestore delete failed: $e');
      rethrow;
    }
  }

  // ─── POST REACTIONS ───────────────────────────────────────────────────
  /// Toggle ng reaction sa post (isang reaction lang per user per post).
  /// Kapag nag-react ulit ng same reaction, tatanggalin. Kapag ibang reaction, papalitan.
  Future<void> toggleReaction(
    String postId,
    String reaction,
    String userId,
  ) async {
    debugPrint(
      'PostService: toggling reaction $reaction on post $postId by $userId',
    );
    final docRef = _db.collection('posts').doc(postId);
    bool reactionAdded = false;
    String? postOwnerId;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        debugPrint('PostService: post $postId not found for reaction');
        return;
      }
      final data = Map<String, dynamic>.from(snap.data() ?? {});
      postOwnerId = data['authorId'] as String?;
      final reactions =
          (data['reactions'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, List<String>.from(v as List)),
          ) ??
          {};
      // Check kung naka-react na ang user ng same reaction (toggle-off scenario)
      final existingList = reactions[reaction];
      final wasReacted =
          existingList != null && (existingList as List).contains(userId);
      // Tanggalin muna ang user sa LAHAT ng ibang reactions (isang reaction lang per post)
      for (final key in reactions.keys.toList()) {
        reactions[key]?.remove(userId);
      }
      if (!wasReacted) {
        final list = reactions[reaction] ?? <String>[];
        list.add(userId);
        reactions[reaction] = list;
        reactionAdded = true;
      }
      tx.update(docRef, {'reactions': reactions});
    });
    debugPrint(
      'PostService: reaction toggled successfully (added=$reactionAdded)',
    );

    // I-notify ang post owner kapag may nag-ADD ng reaction (hindi kapag toggle-off)
    if (reactionAdded && postOwnerId != null && postOwnerId != userId) {
      try {
        final userDoc = await _db.collection('users').doc(userId).get();
        final userName =
            (userDoc.data()?['name'] as String?)?.isNotEmpty == true
            ? userDoc.data()!['name'] as String
            : (userDoc.data()?['email'] as String?) ?? 'Someone';
        await NotificationService.instance.showNotification(
          userId: postOwnerId!,
          title: 'Someone reacted to your post!',
          body: '$userName reacted "$reaction" to your post.',
          type: 'reaction',
        );
      } catch (e) {
        debugPrint('PostService: reaction notification failed (non-fatal): $e');
      }
    }
  }

  // ─── ADD COMMENT ─────────────────────────────────────────────────────
  /// Nagdadagdag ng bagong comment sa isang post.
  /// Ina-increment din ang commentsCount sa post document.
  Future<void> addComment(
    String postId,
    String authorId,
    String authorEmail,
    String text,
  ) async {
    debugPrint('PostService: adding comment to post $postId by $authorEmail');
    final commentsRef = _db
        .collection('posts')
        .doc(postId)
        .collection('comments');
    final doc = commentsRef.doc();
    final comment = Comment(
      id: doc.id,
      authorId: authorId,
      author: authorEmail,
      text: text,
      ts: DateTime.now().toIso8601String(),
    );
    await doc.set(comment.toJson());
    // Increment comment count (best-effort — hindi pa-fail ang comment kung magka-error dito)
    try {
      await _db.collection('posts').doc(postId).update({
        'commentsCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('PostService: commentsCount increment failed (non-fatal): $e');
    }
    debugPrint('PostService: comment added successfully');

    // I-notify ang post owner kung may ibang nag-comment
    try {
      final postSnap = await _db.collection('posts').doc(postId).get();
      final postData = postSnap.data();
      if (postData != null && postData['authorId'] != null && postData['authorId'] != authorId) {
        await NotificationService.instance.showNotification(
          userId: postData['authorId'],
          title: 'New comment on your post!',
          body: '$authorEmail commented: "$text"',
          type: 'comment',
        );
      }
    } catch (e) {
      debugPrint('PostService: comment notification failed (non-fatal): $e');
    }
  }

  /// Placeholder para sa share via share_plus (handled sa UI layer).
  Future<void> sharePost(String postId) async {
    // Leaving implementation to UI layer using share_plus; placeholder here
    return;
  }

  // ─── SAVED POSTS ─────────────────────────────────────────────────────
  /// Chinechecheck kung naka-save na ba ang post ng user.
  Future<bool> isSaved(String postId, String userId) async {
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('saved')
        .doc(postId)
        .get();
    return doc.exists;
  }

  /// Toggle ng save/unsave ng post.
  /// Kung naka-save na, burahin; kung hindi pa, i-save.
  Future<void> toggleSave(String postId, String userId) async {
    final docRef = _db
        .collection('users')
        .doc(userId)
        .collection('saved')
        .doc(postId);
    final snap = await docRef.get();
    if (snap.exists) {
      await docRef.delete();
    } else {
      await docRef.set({'savedAt': DateTime.now().toIso8601String()});
    }
  }
}
