import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFF5E6B3);

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _bioCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _dobCtrl = TextEditingController();
  String _gender = '';
  DateTime? _selectedDob;
  String _avatarPath = '';
  Uint8List? _avatarBytes;
  String _avatarFilename = '';
  String _bannerPath = '';
  Uint8List? _bannerBytes;
  String _bannerFilename = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser.value;
    if (user != null) {
      _nameCtrl.text = user.name;
      _bioCtrl.text = user.bio;
      _phoneCtrl.text = user.phone;
      _gender = user.gender;
      if (user.dob != null) {
        _dobCtrl.text = user.dob!;
        try {
          _selectedDob = DateTime.parse(user.dob!);
        } catch (_) {}
      }
      _avatarPath = user.avatarUrl;
      _bannerPath = user.bannerUrl;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context, null),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final source = choice == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _avatarBytes = bytes;
          _avatarFilename = picked.name;
          _avatarPath = '';
        });
      } else {
        setState(() {
          _avatarPath = picked.path;
          _avatarBytes = null;
          _avatarFilename = '';
        });
      }
    }
  }

  Future<void> _pickBanner() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _bannerBytes = bytes;
          _bannerFilename = picked.name;
          _bannerPath = '';
        });
      } else {
        setState(() {
          _bannerPath = picked.path;
          _bannerBytes = null;
          _bannerFilename = '';
        });
      }
    }
  }

  Future<void> _save() async {
    final user = AuthService.instance.currentUser.value;
    if (user == null) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await AuthService.instance.updateProfile(
      email: user.email,
      name: _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      gender: _gender,
      dob: _selectedDob?.toIso8601String().split('T').first,
      avatarPath: _avatarBytes == null ? _avatarPath : null,
      avatarBytes: _avatarBytes,
      avatarFilename: _avatarFilename.isNotEmpty ? _avatarFilename : null,
      bannerPath: _bannerBytes == null ? _bannerPath : null,
      bannerBytes: _bannerBytes,
      bannerFilename: _bannerFilename.isNotEmpty ? _bannerFilename : null,
    );
    setState(() => _loading = false);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _gold,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            // ── Cover photo ───────────────────────────────────────────
            GestureDetector(
              onTap: _pickBanner,
              child: Stack(
                children: [
                  Container(
                    height: 150,
                    width: double.infinity,
                    color: const Color(0xFFEEEEEE),
                    child: _bannerPath.isNotEmpty
                        ? _bannerPath.startsWith('http')
                              ? Image.network(
                                  _bannerPath,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                )
                              : Image.file(
                                  File(_bannerPath),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                )
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_gold, _goldLight],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.landscape,
                                size: 56,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Edit Cover',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Avatar ────────────────────────────────────────────────
            Transform.translate(
              offset: const Offset(16, -40),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          color: const Color(0xFFE8D5B7),
                        ),
                        child: ClipOval(
                          child: _avatarPath.isNotEmpty
                              ? _avatarPath.startsWith('http')
                                    ? Image.network(
                                        _avatarPath,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _initials(),
                                      )
                                    : Image.file(
                                        File(_avatarPath),
                                        fit: BoxFit.cover,
                                      )
                              : _initials(),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: _pickAvatar,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: _gold,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: _pickAvatar,
                    icon: const Icon(
                      Icons.edit_rounded,
                      size: 15,
                      color: _gold,
                    ),
                    label: const Text(
                      'Change Photo',
                      style: TextStyle(color: _gold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            // ── Form fields ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _field(
                    _nameCtrl,
                    'Full name',
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _phoneCtrl,
                    'Cellphone number',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _gender.isEmpty ? null : _gender,
                    decoration: _dec('Gender'),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _gender = v ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dobCtrl,
                    readOnly: true,
                    decoration: _dec('Date of birth'),
                    onTap: () async {
                      final now = DateTime.now();
                      final initial =
                          _selectedDob ??
                          DateTime(now.year - 18, now.month, now.day);
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: DateTime(1900),
                        lastDate: now,
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDob = picked;
                          _dobCtrl.text =
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(_bioCtrl, 'Bio', maxLines: 3),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _goldLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initials() {
    final name = _nameCtrl.text;
    return Container(
      color: const Color(0xFFE8D5B7),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF888888), fontSize: 14),
    filled: true,
    fillColor: const Color(0xFFFAF9F6),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _gold, width: 1.5),
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _dec(label),
      validator: validator,
    );
  }
}
