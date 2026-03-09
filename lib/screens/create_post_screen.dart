import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _captionCtrl = TextEditingController();
  XFile? _media;
  Uint8List? _mediaBytes;
  String? _mediaType;
  bool _submitting = false;
  final ImagePicker _picker = ImagePicker();

  static const _gold = Color(0xFFD4AF37);
  static const _goldLight = Color(0xFFF5E6B3);

  @override
  void initState() {
    super.initState();
    _captionCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  bool get _canShare =>
      !_submitting && (_media != null || _captionCtrl.text.trim().isNotEmpty);

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  // 10 MB limit for images, 100 MB for videos (must match storage.rules).
  static const int _maxImageBytes = 10 * 1024 * 1024;
  static const int _maxVideoBytes = 100 * 1024 * 1024;

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        if (!mounted) return;
        _showSnack('Image is too large. Maximum size is 10 MB.');
        return;
      }
      setState(() {
        _media = file;
        _mediaBytes = bytes;
        _mediaType = 'image';
      });
    } catch (_) {
      if (!mounted) return;
      _showSnack('Failed to pick image');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        if (bytes.length > _maxVideoBytes) {
          if (!mounted) return;
          _showSnack('Video is too large. Maximum size is 100 MB.');
          return;
        }
        setState(() {
          _media = file;
          _mediaBytes = bytes;
          _mediaType = 'video';
        });
      } else {
        // On mobile, check file size via path before reading all bytes.
        final fileSize = await file.length();
        if (fileSize > _maxVideoBytes) {
          if (!mounted) return;
          _showSnack('Video is too large. Maximum size is 100 MB.');
          return;
        }
        setState(() {
          _media = file;
          _mediaBytes = null;
          _mediaType = 'video';
        });
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack('Failed to pick video');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _gold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_canShare) return;
    final user = AuthService.instance.currentUser.value;
    if (user == null) {
      _showSnack('You must be logged in to post');
      return;
    }
    setState(() => _submitting = true);
    try {
      // Use already-read bytes when available; otherwise fall back to path (mobile).
      await PostService.instance.addPost(
        user.id,
        user.email,
        _captionCtrl.text.trim(),
        authorAvatarUrl: user.avatarUrl,
        mediaBytes: _mediaBytes,
        mediaFilename: _mediaBytes != null ? _media!.name : null,
        mediaPath: _mediaBytes == null ? _media?.path : null,
        mediaType: _mediaType,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      // Extract a readable message from FirebaseException, Exception, or any other error.
      String msg;
      if (e is Exception) {
        msg = e.toString().replaceAll(RegExp(r'^.*Exception:\s*'), '').trim();
      } else {
        msg = e.toString().trim();
      }
      // Strip the ugly boxed-future wrapper if present.
      if (msg.contains('Dart exception thrown from converted Future')) {
        msg = 'Upload failed. Check your connection and try again.';
      }
      _showSnack(
        msg.isNotEmpty ? msg : 'Failed to share post. Please try again.',
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser.value;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF444444)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Post',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C2C2C),
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _submitting
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _gold,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _canShare ? _submit : null,
                    style: TextButton.styleFrom(
                      backgroundColor: _canShare ? _gold : _goldLight,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white60,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      'Share',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEEEEEE)),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Author header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8D5B7), Color(0xFFD4C4A8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: _gold.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: user?.avatarUrl.isNotEmpty == true
                        ? ClipOval(
                            child: Image.network(
                              user!.avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name.isNotEmpty == true
                            ? user!.name
                            : (user?.email ?? 'You'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF2C2C2C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _goldLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _gold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.public, size: 11, color: _gold),
                            SizedBox(width: 4),
                            Text(
                              'Everyone',
                              style: TextStyle(
                                fontSize: 11,
                                color: _gold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Caption input ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _captionCtrl,
                maxLines: 6,
                minLines: 3,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2C2C2C),
                  height: 1.5,
                ),
                decoration: const InputDecoration(
                  hintText: 'Share your testimony, prayer or blessing...',
                  hintStyle: TextStyle(
                    color: Color(0xFFBBBBBB),
                    fontSize: 15.5,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            // ── Media preview ─────────────────────────────────────────
            if (_media != null) ...[
              const SizedBox(height: 8),
              Stack(
                children: [
                  _mediaType == 'image'
                      ? ClipRRect(
                          borderRadius: BorderRadius.zero,
                          child: _mediaBytes != null
                              ? Image.memory(
                                  _mediaBytes!,
                                  height: 260,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : const SizedBox.shrink(),
                        )
                      : Container(
                          height: 200,
                          width: double.infinity,
                          color: const Color(0xFF1A1A2E),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.videocam_rounded,
                                color: Colors.white70,
                                size: 52,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _media!.name,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _media = null;
                        _mediaType = null;
                        _mediaBytes = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ── Divider ───────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Divider(height: 1, color: Color(0xFFEEEEEE)),
            ),

            // ── Media picker row ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              child: Row(
                children: [
                  _MediaPickerButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Photo',
                    color: const Color(0xFF64B5F6),
                    onTap: _pickImage,
                  ),
                  const SizedBox(width: 10),
                  _MediaPickerButton(
                    icon: Icons.videocam_outlined,
                    label: 'Video',
                    color: const Color(0xFF9ACD32),
                    onTap: _pickVideo,
                  ),
                  const SizedBox(width: 10),
                  _MediaPickerButton(
                    icon: Icons.pan_tool_outlined,
                    label: 'Prayer',
                    color: const Color(0xFF8B9DC3),
                    onTap: () {
                      _captionCtrl.text += _captionCtrl.text.isEmpty
                          ? '🙏 Praying for... '
                          : '\n🙏 Praying for... ';
                      _captionCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: _captionCtrl.text.length),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _MediaPickerButton(
                    icon: Icons.tag_outlined,
                    label: 'Tag',
                    color: _gold,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MediaPickerButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
