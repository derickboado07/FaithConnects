// ═══════════════════════════════════════════════════════════════════════════
// CREATE POST SCREEN — Screen para gumawa ng bagong community post.
// May caption/text field, image/video upload (mula gallery o camera),
// hashtag tagging, at submission sa PostService.
// Supports both mobile (File) at web (Uint8List bytes) media.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _captionCtrl = TextEditingController(); // Caption/text ng post
  XFile? _media;                  // Napiling media file (mobile)
  Uint8List? _mediaBytes;         // Bytes ng media (web)
  String? _mediaType;             // 'image' o 'video'
  bool _submitting = false;       // True habang nag-su-submit ang post
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

  final List<String> _tags = [];   // Mga hashtag na naka-attach sa post

  bool get _canShare =>            // True kung pwede nang mag-submit (may content)
      !_submitting && (_media != null || _captionCtrl.text.trim().isNotEmpty);

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  // 10 MB limit para sa images, 100 MB para sa videos (dapat match ang storage.rules).
  static const int _maxImageBytes = 10 * 1024 * 1024;
  static const int _maxVideoBytes = 100 * 1024 * 1024;

  /// Pumipili ng image mula sa gallery (mobile: ImagePicker, web: file bytes).
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

  /// Pumipili ng video mula sa gallery (mobile: ImagePicker, web: file bytes).
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

  /// Nagpapakita ng hashtag dialog para magdagdag ng tags sa post.
  void _showTagDialog() {
    final tagCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add a Tag',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tagCtrl,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addTag(tagCtrl, ctx),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Z0-9_]'),
                    ),
                  ],
                  decoration: InputDecoration(
                    prefixText: '# ',
                    prefixStyle: TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    hintText: 'faith, blessing, prayer...',
                    hintStyle: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4)),
                    filled: true,
                    fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _gold.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _addTag(tagCtrl, ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Add Tag',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Nagdadagdag ng hashtag sa listahan (after validation at dedup).
  void _addTag(TextEditingController tagCtrl, BuildContext ctx) {
    final tag = tagCtrl.text.trim();
    if (tag.isEmpty) return;
    final hashTag = '#$tag';
    final current = _captionCtrl.text;
    _captionCtrl.text = current.isEmpty ? hashTag : '$current $hashTag';
    _captionCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _captionCtrl.text.length),
    );
    setState(() => _tags.add(hashTag));
    Navigator.pop(ctx);
  }

  /// Helper para magpakita ng SnackBar message.
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

  /// Nag-va-validate ng form at nag-su-submit ng bagong post via PostService.
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Post',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Theme.of(context).dividerColor),
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
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
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Share your testimony, prayer or blessing...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Divider(height: 1, color: Theme.of(context).dividerColor),
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
                    onTap: _showTagDialog,
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
