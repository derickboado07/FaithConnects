import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Comment {
  final String id;
  final String author;
  final String text;
  final String ts;

  Comment({
    required this.id,
    required this.author,
    required this.text,
    required this.ts,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'author': author,
    'text': text,
    'ts': ts,
  };

  static Comment fromJson(Map<String, dynamic> j) =>
      Comment(id: j['id'], author: j['author'], text: j['text'], ts: j['ts']);
}

class Post {
  final String id;
  final String authorId;
  final String authorEmail;
  final String authorAvatarUrl;
  final String content;
  final String timestamp;
  final String? mediaUrl;
  final String? mediaType; // 'image' or 'video' or null
  final Map<String, List<String>>
  reactions; // reaction -> list of user ids/emails
  final List<Comment> comments;

  // Shared post fields (populated when this post is a share of another)
  final String? sharedPostId;
  final String? sharedAuthorEmail;
  final String? sharedAuthorAvatarUrl;
  final String? sharedContent;
  final String? sharedMediaUrl;
  final String? sharedMediaType;

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
    this.sharedPostId,
    this.sharedAuthorEmail,
    this.sharedAuthorAvatarUrl,
    this.sharedContent,
    this.sharedMediaUrl,
    this.sharedMediaType,
  }) : reactions = reactions ?? {},
       comments = comments ?? [];

  bool get isSharedPost => sharedPostId != null;

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
  );
}

class PostService {
  PostService._internal();
  static final PostService instance = PostService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Simple per-user upload quota to limit uploads and avoid unexpected overage.
  // Tracks uploads per rolling window (defaults to daily). Uses collection
  // `upload_quotas/{uid}` with fields: `count` (int) and `windowStart` (Timestamp).
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

  Future<void> init() async {
    // Nothing to cache locally; Firestore will be used.
    return;
  }

  Future<List<Post>> fetchFeed({int limit = 50}) async {
    final snap = await _db
        .collection('posts')
        .orderBy('ts', descending: true)
        .limit(limit)
        .get();
    final posts = snap.docs.map((d) => Post.fromJson(d.data())).toList();

    // Batch-fetch author avatars for posts that don't have one stored yet.
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

    // Load comments and apply cached avatars.
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

  /// Real-time stream of feed posts.
  Stream<List<Post>> streamFeed({int limit = 50}) {
    return _db
        .collection('posts')
        .orderBy('ts', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Post.fromJson(d.data())).toList());
  }

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

  // Upload media either from a local file path (mobile/desktop) or from
  // raw bytes (web). If [data] is provided it will be uploaded using
  // [filename], otherwise [localPath] is used.
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
    // Enforce per-user quota to avoid accidental overage. Throws if limit exceeded.
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

  /// Creates a new post that is a share of [originalPost].
  /// [content] is the sharer's optional caption.
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
  }

  Future<List<Comment>> _loadCommentsForPost(String postId) async {
    final snap = await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('ts')
        .get();
    return snap.docs.map((d) => Comment.fromJson(d.data())).toList();
  }

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

  /// Real-time stream of posts for a specific user.
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

  /// Delete a post document and any associated storage media under posts/{postId}
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

  Future<void> toggleReaction(
    String postId,
    String reaction,
    String userId,
  ) async {
    debugPrint(
      'PostService: toggling reaction $reaction on post $postId by $userId',
    );
    final docRef = _db.collection('posts').doc(postId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        debugPrint('PostService: post $postId not found for reaction');
        return;
      }
      final data = Map<String, dynamic>.from(snap.data() ?? {});
      final reactions =
          (data['reactions'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, List<String>.from(v as List)),
          ) ??
          {};
      // Remove user from ALL other reactions first (one reaction per post)
      for (final key in reactions.keys.toList()) {
        reactions[key]?.remove(userId);
      }
      final list = reactions[reaction] ?? <String>[];
      if (data['reactions'] != null) {
        final existing = (data['reactions'] as Map<String, dynamic>)[reaction];
        final wasReacted =
            existing != null && (existing as List).contains(userId);
        if (!wasReacted) list.add(userId);
        // if was already reacted, we already removed it above (toggle off)
      } else {
        list.add(userId);
      }
      reactions[reaction] = list;
      tx.update(docRef, {'reactions': reactions});
    });
    debugPrint('PostService: reaction toggled successfully');
  }

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
      author: authorEmail,
      text: text,
      ts: DateTime.now().toIso8601String(),
    );
    await doc.set(comment.toJson());
    // Increment comment count (best-effort — don't fail the comment if this fails)
    try {
      await _db.collection('posts').doc(postId).update({
        'commentsCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('PostService: commentsCount increment failed (non-fatal): $e');
    }
    debugPrint('PostService: comment added successfully');
  }

  Future<void> sharePost(String postId) async {
    // Leaving implementation to UI layer using share_plus; placeholder here
    return;
  }

  Future<bool> isSaved(String postId, String userId) async {
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('saved')
        .doc(postId)
        .get();
    return doc.exists;
  }

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
