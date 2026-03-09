import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'services/auth_service.dart';

import 'services/post_service.dart';

import 'screens/login_screen.dart';

import 'screens/register_screen.dart';

import 'screens/profile_screen.dart';

import 'screens/edit_profile_screen.dart';

import 'screens/create_post_screen.dart';
import 'screens/bible_screen.dart';
import 'services/bible_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseOk = false;

  try {
    // Try to initialize Firebase with generated options where available.

    FirebaseOptions? options;

    try {
      options = DefaultFirebaseOptions.currentPlatform;
    } on UnsupportedError catch (e) {
      // Default options not configured for this platform.

      // ignore: avoid_print

      print('DefaultFirebaseOptions not configured: $e');

      options = null;
    }

    if (options != null) {
      // Log minimal option info for debugging

      // ignore: avoid_print

      print(
        'Firebase options found for platform. projectId=${options.projectId} appId=${options.appId}',
      );

      await Firebase.initializeApp(options: options);

      // ignore: avoid_print

      print('Firebase.initializeApp succeeded');

      firebaseOk = true;
    } else {
      // If no options are available, avoid calling initializeApp without config

      // because that yields configuration-not-found on some platforms.

      // ignore: avoid_print

      print(
        'Skipping Firebase.initializeApp: no DefaultFirebaseOptions for this platform.',
      );

      firebaseOk = false;
    }
  } catch (e) {
    // Initialization failed. Continue without Firebase so UI can load.

    // ignore: avoid_print

    print('Firebase initialization failed: $e');

    firebaseOk = false;
  }

  if (firebaseOk) {
    await AuthService.instance.init();

    await PostService.instance.init();
  }

  runApp(const FaithConnectApp());
}

class FaithConnectApp extends StatelessWidget {
  const FaithConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FaithConnect',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4AF37),

          brightness: Brightness.light,

          surface: Colors.white,

          primary: const Color(0xFFD4AF37),

          onPrimary: Colors.white,

          secondary: const Color(0xFFF5E6B3),
        ),

        scaffoldBackgroundColor: Colors.white,

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,

          elevation: 0,

          scrolledUnderElevation: 0,

          iconTheme: IconThemeData(color: Color(0xFF5C5C5C)),

          titleTextStyle: TextStyle(
            color: Color(0xFF2C2C2C),

            fontSize: 22,

            fontWeight: FontWeight.bold,
          ),
        ),

        cardTheme: CardThemeData(
          elevation: 2,

          shadowColor: Colors.grey.withValues(alpha: 0.15),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          color: Colors.white,
        ),

        iconTheme: const IconThemeData(color: Color(0xFF5C5C5C)),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFAF9F6),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
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
            borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
          ),
          labelStyle: const TextStyle(color: Color(0xFF888888)),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFD4AF37),
            side: const BorderSide(color: Color(0xFFD4AF37)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFD4AF37)),
        ),

        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: const Color(0xFFD4AF37),
        ),

        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
        ),

        bottomSheetTheme: const BottomSheetThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),

        dividerTheme: const DividerThemeData(
          color: Color(0xFFF0F0F0),
          thickness: 0.8,
        ),

        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),

      routes: {
        '/login': (_) => const LoginScreen(),

        '/register': (_) => const RegisterScreen(),

        '/profile': (_) => const ProfileScreen(),

        '/edit_profile': (_) => const EditProfileScreen(),

        '/create_post': (_) => const CreatePostScreen(),
      },

      home: ValueListenableBuilder(
        valueListenable: AuthService.instance.currentUser,

        builder: (context, value, _) {
          if (value == null) return const LoginScreen();

          return const HomePage();
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  Widget _buildFeed() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // TOP APP BAR
          const TopAppBarSection(),

          // DAILY VERSE SECTION
          const DailyVerseSection(),

          const SizedBox(height: 16),

          // CREATE POST SECTION
          const CreatePostSection(),

          const SizedBox(height: 16),

          // FEED POSTS SECTION
          const FeedPostsSection(),

          const SizedBox(height: 16),

          // REELS PREVIEW SECTION
          const ReelsPreviewSection(),

          const SizedBox(height: 16),

          // MARKETPLACE PREVIEW SECTION
          const MarketplacePreviewSection(),

          const SizedBox(height: 16),

          // MUSIC SECTION
          const MusicSection(),

          const SizedBox(height: 16),

          // PROFILE PREVIEW SECTION
          const ProfilePreviewSection(),

          const SizedBox(height: 80), // Space for bottom nav
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _buildFeed(),

      // placeholders for Reels, Bible, Market, Music
      const Center(child: Text('Reels')),

      const BibleScreen(),

      const Center(child: Text('Market')),

      const Center(child: Text('Music')),

      const ProfileScreen(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],

      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,

        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ============================================

// TOP APP BAR SECTION

// ============================================

class TopAppBarSection extends StatelessWidget {
  const TopAppBarSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

      child: Row(
        children: [
          // App Logo - Cross inspired
          Container(
            width: 40,

            height: 40,

            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFFF5E6B3)],

                begin: Alignment.topLeft,

                end: Alignment.bottomRight,
              ),

              borderRadius: BorderRadius.circular(12),

              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3),

                  blurRadius: 8,

                  offset: const Offset(0, 2),
                ),
              ],
            ),

            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),

          const SizedBox(width: 12),

          // App Name
          const Text(
            'FaithConnect',

            style: TextStyle(
              fontSize: 22,

              fontWeight: FontWeight.bold,

              color: Color(0xFF2C2C2C),

              letterSpacing: 0.5,
            ),
          ),

          const Spacer(),

          // Icons
          _buildIconButton(context, Icons.search),

          _buildIconButton(context, Icons.notifications_outlined),

          _buildIconButton(context, Icons.message_outlined),
        ],
      ),
    );
  }

  Widget _buildIconButton(BuildContext context, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(left: 4),

      child: IconButton(
        onPressed: icon == Icons.message_outlined
            ? () => Navigator.pushNamed(context, '/login')
            : null,

        icon: Icon(icon, size: 22),

        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF5F5F5),

          padding: const EdgeInsets.all(10),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ============================================

// DAILY VERSE SECTION

// ============================================

// Daily gradient themes – cycles through by day-of-week.
const List<List<Color>> _verseGradients = [
  [Color(0xFF8B2FC9), Color(0xFF3A1078)], // Sunday    – royal purple
  [Color(0xFFB5451B), Color(0xFF6E2510)], // Monday    – warm terracotta
  [Color(0xFF0F4C75), Color(0xFF1B262C)], // Tuesday   – deep ocean
  [Color(0xFF2D6A4F), Color(0xFF1B4332)], // Wednesday – forest green
  [Color(0xFFB98B2D), Color(0xFF7A5B10)], // Thursday  – golden amber
  [Color(0xFF1D3461), Color(0xFF5E3384)], // Friday    – midnight violet
  [Color(0xFF6B2D5E), Color(0xFF3A1042)], // Saturday  – deep rose
];

class DailyVerseSection extends StatefulWidget {
  const DailyVerseSection({super.key});

  @override
  State<DailyVerseSection> createState() => _DailyVerseSectionState();
}

class _DailyVerseSectionState extends State<DailyVerseSection> {
  String _language = 'en';
  BibleVerse? _verse;
  bool _loading = true;
  bool _liked = false;
  bool _sharingToFeed = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadVerse();
  }

  Future<void> _loadVerse() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final v = await BibleService.instance.getDailyVerse(language: _language);
      if (mounted)
        setState(() {
          _verse = v;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
    }
  }

  void _switchLanguage(String lang) {
    if (_language == lang) return;
    setState(() => _language = lang);
    _loadVerse();
  }

  Future<void> _shareDailyVerseToFeed() async {
    if (_verse == null || _sharingToFeed) return;
    final user = AuthService.instance.currentUser.value;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to post the daily verse.')),
      );
      return;
    }

    setState(() => _sharingToFeed = true);
    try {
      final content =
          'Daily Verse\n\n${_verse!.reference}\n"${_verse!.displayText}"\n\n- ${_verse!.translationLabel}';
      await PostService.instance.addPost(
        user.id,
        user.email,
        content,
        authorAvatarUrl: user.avatarUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily verse posted to your feed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to post daily verse: $e')));
    } finally {
      if (mounted) setState(() => _sharingToFeed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekday = DateTime.now().weekday % 7;
    final gradient = _verseGradients[weekday];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.4, -0.5),
                    radius: 1.2,
                    colors: [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Verse of the Day',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Spacer(),
                      _buildLangToggle(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (!_loading && _verse != null)
                    Text(
                      '${_verse!.reference} · ${_verse!.translationLabel}',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: CircularProgressIndicator(
                          color: Colors.white54,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else if (_verse == null)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 6),
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white38,
                          size: 26,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _loadError != null
                              ? 'Bible database is loading…\nSwitch language to retry.'
                              : 'Verse not available.',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  else
                    Text(
                      '"${_verse!.displayText}"',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _actionIcon(
                        _liked ? Icons.favorite : Icons.favorite_border,
                        _liked ? Colors.redAccent : Colors.white,
                        () => setState(() => _liked = !_liked),
                      ),
                      const SizedBox(width: 14),
                      _actionIcon(
                        Icons.chat_bubble_outline,
                        Colors.white,
                        () {},
                      ),
                      const SizedBox(width: 14),
                      _actionIcon(
                        _sharingToFeed
                            ? Icons.hourglass_top
                            : Icons.share_outlined,
                        Colors.white,
                        _shareDailyVerseToFeed,
                      ),
                      const Spacer(),
                      _actionTextBtn('More', Icons.more_horiz, () {}),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLangToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LangBtn(
            label: 'EN',
            active: _language == 'en',
            onTap: () => _switchLanguage('en'),
          ),
          const SizedBox(width: 2),
          _LangBtn(
            label: 'TL',
            active: _language == 'tl',
            onTap: () => _switchLanguage('tl'),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _actionTextBtn(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _LangBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black87 : Colors.white60,
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ============================================

// CREATE POST SECTION

// ============================================

class CreatePostSection extends StatelessWidget {
  const CreatePostSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/create_post'),

      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(16),

          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),

              blurRadius: 10,

              offset: const Offset(0, 2),
            ),
          ],
        ),

        child: Row(
          children: [
            // Profile Avatar
            ValueListenableBuilder(
              valueListenable: AuthService.instance.currentUser,

              builder: (_, user, __) {
                return Container(
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
                      color: const Color(0xFFD4AF37),

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
                      : const Icon(Icons.person, color: Colors.white, size: 24),
                );
              },
            ),

            const SizedBox(width: 12),

            // Placeholder text
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,

                  vertical: 13,
                ),

                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),

                  borderRadius: BorderRadius.circular(24),

                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),

                child: const Text(
                  'Share your testimony...',

                  style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14.5),
                ),
              ),
            ),

            const SizedBox(width: 10),

            Container(
              padding: const EdgeInsets.all(10),

              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.1),

                borderRadius: BorderRadius.circular(12),
              ),

              child: const Icon(
                Icons.photo_camera_outlined,

                color: Color(0xFFD4AF37),

                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreatePostIconsRow extends StatelessWidget {
  const CreatePostIconsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),

            blurRadius: 10,

            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,

        children: [
          _buildPostIcon(Icons.photo_library_outlined, 'Photo'),

          _buildPostIcon(Icons.videocam_outlined, 'Video'),

          _buildPostIcon(Icons.music_note_outlined, 'Music'),

          _buildPostIcon(Icons.pan_tool_outlined, 'Prayer'),
        ],
      ),
    );
  }

  Widget _buildPostIcon(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,

      children: [
        Container(
          padding: const EdgeInsets.all(12),

          decoration: BoxDecoration(
            color: const Color(0xFFF5E6B3).withValues(alpha: 0.3),

            borderRadius: BorderRadius.circular(12),
          ),

          child: Icon(icon, color: const Color(0xFFD4AF37), size: 24),
        ),

        const SizedBox(height: 4),

        Text(
          label,

          style: const TextStyle(
            fontSize: 11,

            color: Color(0xFF666666),

            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ============================================

// REACTION DATA

// ============================================

class _ReactionInfo {
  final String key;

  final String label;

  final IconData icon;

  final Color color;

  const _ReactionInfo(this.key, this.label, this.icon, this.color);
}

const List<_ReactionInfo> _reactions = [
  _ReactionInfo('amen', 'Amen', Icons.thumb_up, Color(0xFFD4AF37)),

  _ReactionInfo('pray', 'Pray', Icons.pan_tool, Color(0xFF8B9DC3)),

  _ReactionInfo('worship', 'Worship', Icons.music_note, Color(0xFF9ACD32)),

  _ReactionInfo('love', 'Love', Icons.favorite, Color(0xFFE57373)),
];

// ============================================

// FEED POSTS SECTION

// ============================================

class FeedPostsSection extends StatefulWidget {
  const FeedPostsSection({super.key});

  @override
  State<FeedPostsSection> createState() => _FeedPostsSectionState();
}

class _FeedPostsSectionState extends State<FeedPostsSection> {
  @override
  void initState() {
    super.initState();

    // Real-time feed handled by StreamBuilder in build.
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Post>>(
      stream: PostService.instance.streamFeed(),

      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),

            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD4AF37),

                strokeWidth: 2,
              ),
            ),
          );
        }

        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),

            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Icon(
                    Icons.cloud_off_outlined,

                    size: 48,

                    color: Color(0xFFCCCCCC),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Could not load posts',

                    style: TextStyle(color: Color(0xFF888888), fontSize: 15),
                  ),
                ],
              ),
            ),
          );
        }

        final posts = snap.data ?? [];

        if (posts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),

            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  Container(
                    width: 70,

                    height: 70,

                    decoration: BoxDecoration(
                      color: const Color(0xFFF5E6B3).withValues(alpha: 0.4),

                      shape: BoxShape.circle,
                    ),

                    child: const Icon(
                      Icons.article_outlined,

                      size: 36,

                      color: Color(0xFFD4AF37),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'No posts yet',

                    style: TextStyle(
                      fontSize: 16,

                      fontWeight: FontWeight.w600,

                      color: Color(0xFF444444),
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'Be the first to share your testimony!',

                    style: TextStyle(color: Color(0xFF888888), fontSize: 13),

                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: posts
              .map((post) => PostCard(post: post, onRefresh: () {}))
              .toList(),
        );
      },
    );
  }
}

// ============================================

// POST CARD

// ============================================

class PostCard extends StatefulWidget {
  final Post post;

  final VoidCallback onRefresh;

  const PostCard({super.key, required this.post, required this.onRefresh});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _showReactionPicker = false;

  bool _busy = false;

  bool _saved = false;

  @override
  void initState() {
    super.initState();

    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final user = AuthService.instance.currentUser.value;

    if (user == null) return;

    try {
      final saved = await PostService.instance.isSaved(widget.post.id, user.id);

      if (mounted) setState(() => _saved = saved);
    } catch (_) {}
  }

  String? get _myReaction {
    final user = AuthService.instance.currentUser.value;

    if (user == null) return null;

    for (final entry in widget.post.reactions.entries) {
      if (entry.value.contains(user.id)) return entry.key;
    }

    return null;
  }

  int get _totalReactions {
    int total = 0;

    for (final v in widget.post.reactions.values) {
      total += v.length;
    }

    return total;
  }

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts);

      final diff = DateTime.now().difference(dt);

      if (diff.inMinutes < 1) return 'Just now';

      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';

      if (diff.inHours < 24) return '${diff.inHours}h ago';

      if (diff.inDays < 7) return '${diff.inDays}d ago';

      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return ts;
    }
  }

  Future<void> _react(String key) async {
    if (_busy) return;

    final user = AuthService.instance.currentUser.value;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to react'),

          backgroundColor: Color(0xFFD4AF37),
        ),
      );

      return;
    }

    setState(() {
      _busy = true;

      _showReactionPicker = false;
    });

    try {
      await PostService.instance.toggleReaction(widget.post.id, key, user.id);

      widget.onRefresh();
    } catch (_) {}

    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toggleSave() async {
    if (_busy) return;

    final user = AuthService.instance.currentUser.value;

    if (user == null) return;

    setState(() {
      _busy = true;

      _saved = !_saved;
    });

    try {
      await PostService.instance.toggleSave(widget.post.id, user.id);
    } catch (_) {
      if (mounted) setState(() => _saved = !_saved);
    }

    if (mounted) setState(() => _busy = false);
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (_) =>
          CommentsSheet(post: widget.post, onCommentAdded: widget.onRefresh),
    );
  }

  void _share() {
    showModalBottomSheet(
      context: context,

      backgroundColor: Colors.transparent,

      isScrollControlled: true,

      builder: (_) => ShareSheet(post: widget.post),
    );
  }

  Widget _authorInitial() {
    final name = widget.post.authorEmail.contains('@')
        ? widget.post.authorEmail.split('@').first
        : widget.post.authorEmail;

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      color: const Color(0xFFE8D5B7),

      child: Center(
        child: Text(
          initial,

          style: const TextStyle(
            fontSize: 18,

            fontWeight: FontWeight.bold,

            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myReaction = _myReaction;

    final totalReactions = _totalReactions;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,

      onTap: () {
        if (_showReactionPicker) setState(() => _showReactionPicker = false);
      },

      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(16),

          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),

              blurRadius: 12,

              offset: const Offset(0, 3),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 6, 0),

              child: Row(
                children: [
                  Container(
                    width: 44,

                    height: 44,

                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8D5B7), Color(0xFFD4C4A8)],

                        begin: Alignment.topLeft,

                        end: Alignment.bottomRight,
                      ),

                      shape: BoxShape.circle,

                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.35),

                        width: 1.5,
                      ),
                    ),

                    child: ClipOval(
                      child: widget.post.authorAvatarUrl.isNotEmpty
                          ? Image.network(
                              widget.post.authorAvatarUrl,

                              fit: BoxFit.cover,

                              errorBuilder: (_, __, ___) => _authorInitial(),
                            )
                          : _authorInitial(),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          widget.post.authorEmail.contains('@')
                              ? widget.post.authorEmail.split('@').first
                              : widget.post.authorEmail,

                          style: const TextStyle(
                            fontWeight: FontWeight.bold,

                            fontSize: 14.5,

                            color: Color(0xFF2C2C2C),
                          ),
                        ),

                        const SizedBox(height: 1),

                        Text(
                          _formatTimestamp(widget.post.timestamp),

                          style: const TextStyle(
                            color: Color(0xFF999999),

                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Builder(
                    builder: (ctx) {
                      final user = AuthService.instance.currentUser.value;

                      final isOwner =
                          user != null && user.id == widget.post.authorId;

                      return PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_horiz,

                          color: Color(0xFFAAAAAA),
                        ),

                        onSelected: (v) async {
                          if (v == 'delete') {
                            final ok = await showDialog<bool>(
                              context: ctx,

                              builder: (_) => AlertDialog(
                                title: const Text('Delete post?'),

                                content: const Text('This cannot be undone.'),

                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),

                                    child: const Text('Cancel'),
                                  ),

                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),

                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (ok == true) {
                              try {
                                await PostService.instance.deletePost(
                                  widget.post.id,
                                );

                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Post deleted'),

                                    backgroundColor: Color(0xFFD4AF37),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to delete post'),

                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          }
                        },

                        itemBuilder: (_) => [
                          if (isOwner)
                            const PopupMenuItem(
                              value: 'delete',

                              child: Text('Delete'),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // â”€â”€ Content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (widget.post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Text(
                  widget.post.content,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.55,
                    color: Color(0xFF3A3A3A),
                  ),
                ),
              ),

            // Shared post card (embedded original post)
            if (widget.post.isSharedPost)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: _SharedPostPreview(
                  authorEmail: widget.post.sharedAuthorEmail ?? '',
                  authorAvatarUrl: widget.post.sharedAuthorAvatarUrl ?? '',
                  content: widget.post.sharedContent ?? '',
                  mediaUrl: widget.post.sharedMediaUrl,
                  mediaType: widget.post.sharedMediaType,
                ),
              ),

            // Media (only for non-shared posts)
            if (!widget.post.isSharedPost &&
                widget.post.mediaUrl != null &&
                widget.post.mediaUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Image.network(
                    widget.post.mediaUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

            // â”€â”€ Reaction Summary â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (totalReactions > 0 || widget.post.comments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),

                child: Row(
                  children: [
                    if (totalReactions > 0) ...[
                      ...widget.post.reactions.entries
                          .where((e) => e.value.isNotEmpty)
                          .take(3)
                          .map((entry) {
                            final rd = _reactions.firstWhere(
                              (r) => r.key == entry.key,

                              orElse: () => _reactions[0],
                            );

                            return Container(
                              margin: const EdgeInsets.only(right: 1),

                              padding: const EdgeInsets.all(3),

                              decoration: BoxDecoration(
                                color: rd.color.withValues(alpha: 0.15),

                                shape: BoxShape.circle,
                              ),

                              child: Icon(rd.icon, size: 12, color: rd.color),
                            );
                          }),

                      const SizedBox(width: 5),

                      Text(
                        '$totalReactions',

                        style: const TextStyle(
                          fontSize: 12,

                          color: Color(0xFF888888),
                        ),
                      ),
                    ],

                    const Spacer(),

                    if (widget.post.comments.isNotEmpty)
                      Text(
                        '${widget.post.comments.length} comment${widget.post.comments.length != 1 ? 's' : ''}',

                        style: const TextStyle(
                          fontSize: 12,

                          color: Color(0xFF888888),
                        ),
                      ),
                  ],
                ),
              ),

            // â”€â”€ Divider â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 0),

              child: Divider(
                height: 1,

                thickness: 0.8,

                color: Color(0xFFEEEEEE),
              ),
            ),

            // â”€â”€ Reaction picker + Action row â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // Reaction picker (slides in above actions)
                  if (_showReactionPicker)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),

                      child: _ReactionPickerBubble(
                        myReaction: myReaction,

                        onReact: _react,
                      ),
                    ),

                  // Actions row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,

                    children: [
                      _ReactButton(
                        myReaction: myReaction,

                        onTap: () => setState(
                          () => _showReactionPicker = !_showReactionPicker,
                        ),
                      ),

                      _ActionButton(
                        icon: Icons.chat_bubble_outline_rounded,

                        label: 'Comment',

                        onTap: _openComments,
                      ),

                      _ActionButton(
                        icon: Icons.share_outlined,

                        label: 'Share',

                        onTap: _share,
                      ),

                      _ActionButton(
                        icon: _saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,

                        label: 'Save',

                        color: _saved ? const Color(0xFFD4AF37) : null,

                        onTap: _toggleSave,
                      ),
                    ],
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

// â”€â”€â”€ React Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ReactButton extends StatelessWidget {
  final String? myReaction;

  final VoidCallback onTap;

  const _ReactButton({required this.myReaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = myReaction != null
        ? _reactions.firstWhere(
            (r) => r.key == myReaction,

            orElse: () => _reactions[0],
          )
        : null;

    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(8),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),

        child: Row(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(
              active?.icon ?? Icons.thumb_up_outlined,

              size: 19,

              color: active?.color ?? const Color(0xFF888888),
            ),

            const SizedBox(width: 5),

            Text(
              active?.label ?? 'React',

              style: TextStyle(
                fontSize: 13,

                fontWeight: active != null ? FontWeight.w600 : FontWeight.w500,

                color: active?.color ?? const Color(0xFF888888),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€ Generic Action Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ActionButton extends StatelessWidget {
  final IconData icon;

  final String label;

  final VoidCallback onTap;

  final Color? color;

  const _ActionButton({
    required this.icon,

    required this.label,

    required this.onTap,

    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF888888);

    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(8),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),

        child: Row(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(icon, size: 19, color: c),

            const SizedBox(width: 5),

            Text(
              label,

              style: TextStyle(
                fontSize: 13,

                color: c,

                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€ Reaction Picker Bubble â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

// ─── Shared Post Preview Card ─────────────────────────────────────────────────
/// Shows the embedded original post inside a share post card.
class SharedPostPreview extends StatelessWidget {
  final String authorEmail;
  final String authorAvatarUrl;
  final String content;
  final String? mediaUrl;
  final String? mediaType;

  const SharedPostPreview({
    super.key,
    required this.authorEmail,
    required this.authorAvatarUrl,
    required this.content,
    this.mediaUrl,
    this.mediaType,
  });

  @override
  Widget build(BuildContext context) {
    final authorName = authorEmail.contains('@')
        ? authorEmail.split('@').first
        : authorEmail;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDDDDD)),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF8F8F8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Original author header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE8D5B7),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: authorAvatarUrl.isNotEmpty
                        ? Image.network(
                            authorAvatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallback(authorName),
                          )
                        : _fallback(authorName),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  authorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
              ],
            ),
          ),
          // Content
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                content,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF444444),
                  height: 1.45,
                ),
              ),
            ),
          // Image
          if (mediaUrl != null && mediaUrl!.isNotEmpty && mediaType == 'image')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                child: Image.network(
                  mediaUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _fallback(String name) {
    return Container(
      color: const Color(0xFFE8D5B7),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// Alias used inside PostCard / _ProfilePostCard (keeps their usage clean)
typedef _SharedPostPreview = SharedPostPreview;

class _ReactionPickerBubble extends StatelessWidget {
  final String? myReaction;

  final ValueChanged<String> onReact;

  const _ReactionPickerBubble({
    required this.myReaction,

    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,

      borderRadius: BorderRadius.circular(40),

      shadowColor: Colors.black.withValues(alpha: 0.15),

      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(40),

          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),

        child: Row(
          mainAxisSize: MainAxisSize.min,

          children: _reactions.map((r) {
            final isActive = myReaction == r.key;

            return GestureDetector(
              onTap: () => onReact(r.key),

              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),

                margin: const EdgeInsets.symmetric(horizontal: 3),

                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),

                decoration: BoxDecoration(
                  color: isActive
                      ? r.color.withValues(alpha: 0.15)
                      : Colors.transparent,

                  borderRadius: BorderRadius.circular(24),

                  border: isActive
                      ? Border.all(color: r.color.withValues(alpha: 0.4))
                      : null,
                ),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Icon(r.icon, size: 24, color: r.color),

                    const SizedBox(height: 3),

                    Text(
                      r.label,

                      style: TextStyle(
                        fontSize: 10,

                        color: r.color,

                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// â”€â”€â”€ Comments Bottom Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class CommentsSheet extends StatefulWidget {
  final Post post;

  final VoidCallback onCommentAdded;

  const CommentsSheet({
    super.key,

    required this.post,

    required this.onCommentAdded,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _ctrl = TextEditingController();

  bool _submitting = false;

  List<Comment> _comments = [];

  @override
  void initState() {
    super.initState();

    _comments = List.from(widget.post.comments);
  }

  @override
  void dispose() {
    _ctrl.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();

    if (text.isEmpty) return;

    final user = AuthService.instance.currentUser.value;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in to comment')));

      return;
    }

    setState(() => _submitting = true);

    _ctrl.clear();

    try {
      await PostService.instance.addComment(
        widget.post.id,

        user.id,

        user.email,

        text,
      );

      widget.onCommentAdded();

      final updated = await PostService.instance.getById(widget.post.id);

      if (mounted && updated != null) {
        setState(() => _comments = updated.comments);
      }
    } catch (_) {}

    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,

      decoration: const BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),

      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),

            width: 38,

            height: 4,

            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),

              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

            child: Row(
              children: [
                const Text(
                  'Comments',

                  style: TextStyle(
                    fontSize: 17,

                    fontWeight: FontWeight.bold,

                    color: Color(0xFF2C2C2C),
                  ),
                ),

                const Spacer(),

                if (_comments.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,

                      vertical: 3,
                    ),

                    decoration: BoxDecoration(
                      color: const Color(0xFFF5E6B3).withValues(alpha: 0.5),

                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Text(
                      '${_comments.length}',

                      style: const TextStyle(
                        fontSize: 12,

                        fontWeight: FontWeight.w600,

                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // Comments list
          Expanded(
            child: _comments.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,

                          size: 48,

                          color: Color(0xFFDDDDDD),
                        ),

                        SizedBox(height: 12),

                        Text(
                          'No comments yet',

                          style: TextStyle(
                            fontSize: 15,

                            color: Color(0xFF888888),

                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        SizedBox(height: 4),

                        Text(
                          'Be the first to comment!',

                          style: TextStyle(
                            color: Color(0xFFAAAAAA),

                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,

                      vertical: 8,
                    ),

                    itemCount: _comments.length,

                    itemBuilder: (_, i) {
                      final c = _comments[i];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),

                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Container(
                              width: 34,

                              height: 34,

                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFE8D5B7),

                                    Color(0xFFD4C4A8),
                                  ],
                                ),

                                shape: BoxShape.circle,
                              ),

                              child: const Icon(
                                Icons.person,

                                color: Colors.white,

                                size: 18,
                              ),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  12,

                                  8,

                                  12,

                                  10,
                                ),

                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F8F8),

                                  borderRadius: BorderRadius.circular(14),
                                ),

                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [
                                    Text(
                                      c.author.contains('@')
                                          ? c.author.split('@').first
                                          : c.author,

                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,

                                        fontSize: 13,

                                        color: Color(0xFF2C2C2C),
                                      ),
                                    ),

                                    const SizedBox(height: 3),

                                    Text(
                                      c.text,

                                      style: const TextStyle(
                                        fontSize: 13.5,

                                        color: Color(0xFF444444),

                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Input
          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset),

            child: Row(
              children: [
                Container(
                  width: 34,

                  height: 34,

                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE8D5B7), Color(0xFFD4C4A8)],
                    ),

                    shape: BoxShape.circle,
                  ),

                  child: const Icon(
                    Icons.person,

                    color: Colors.white,

                    size: 18,
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: TextField(
                    controller: _ctrl,

                    textInputAction: TextInputAction.send,

                    onSubmitted: (_) => _submit(),

                    style: const TextStyle(
                      fontSize: 14,

                      color: Color(0xFF2C2C2C),
                    ),

                    decoration: InputDecoration(
                      hintText: 'Write a comment...',

                      hintStyle: const TextStyle(
                        color: Color(0xFFAAAAAA),

                        fontSize: 14,
                      ),

                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,

                        vertical: 10,
                      ),

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),

                        borderSide: BorderSide.none,
                      ),

                      filled: true,

                      fillColor: const Color(0xFFF4F4F4),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                _submitting
                    ? const SizedBox(
                        width: 36,

                        height: 36,

                        child: CircularProgressIndicator(
                          strokeWidth: 2,

                          color: Color(0xFFD4AF37),
                        ),
                      )
                    : GestureDetector(
                        onTap: _submit,

                        child: Container(
                          width: 36,

                          height: 36,

                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFD4AF37), Color(0xFFE8C95A)],

                              begin: Alignment.topLeft,

                              end: Alignment.bottomRight,
                            ),

                            shape: BoxShape.circle,
                          ),

                          child: const Icon(
                            Icons.send_rounded,

                            color: Colors.white,

                            size: 17,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Share Sheet (Facebook-style) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class ShareSheet extends StatefulWidget {
  final Post post;

  const ShareSheet({super.key, required this.post});

  @override
  State<ShareSheet> createState() => ShareSheetState();
}

class ShareSheetState extends State<ShareSheet> {
  final TextEditingController _thoughtCtrl = TextEditingController();

  bool _sharing = false;

  @override
  void dispose() {
    _thoughtCtrl.dispose();

    super.dispose();
  }

  Future<void> _shareToFeed() async {
    final user = AuthService.instance.currentUser.value;

    if (user == null) {
      Navigator.pop(context);

      return;
    }

    setState(() => _sharing = true);

    final thought = _thoughtCtrl.text.trim();

    try {
      await PostService.instance.addSharedPost(
        authorId: user.id,

        authorEmail: user.email,

        authorAvatarUrl: user.avatarUrl,

        content: thought,

        originalPost: widget.post,
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 18),

              SizedBox(width: 8),

              Text('Shared to your feed!'),
            ],
          ),

          backgroundColor: const Color(0xFFD4AF37),

          behavior: SnackBarBehavior.floating,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _copyLink() async {
    final link = 'https://faithconnect.page.link/post/${widget.post.id}';

    await Clipboard.setData(ClipboardData(text: link));

    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.link, color: Colors.white, size: 18),

            SizedBox(width: 8),

            Text('Link copied to clipboard'),
          ],
        ),

        backgroundColor: const Color(0xFF64B5F6),

        behavior: SnackBarBehavior.floating,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authorName = widget.post.authorEmail.contains('@')
        ? widget.post.authorEmail.split('@').first
        : widget.post.authorEmail;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),

      decoration: const BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),

            width: 38,

            height: 4,

            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),

              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),

            child: Row(
              children: [
                Text(
                  'Share Post',

                  style: TextStyle(
                    fontSize: 17,

                    fontWeight: FontWeight.bold,

                    color: Color(0xFF2C2C2C),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // Share-to-feed section (like FB "Share now" with thought)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // User header
                Row(
                  children: [
                    ValueListenableBuilder(
                      valueListenable: AuthService.instance.currentUser,

                      builder: (_, user, __) => Container(
                        width: 38,

                        height: 38,

                        decoration: BoxDecoration(
                          shape: BoxShape.circle,

                          color: const Color(0xFFE8D5B7),

                          border: Border.all(
                            color: const Color(
                              0xFFD4AF37,
                            ).withValues(alpha: 0.4),
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

                                    size: 20,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.person,

                                color: Colors.white,

                                size: 20,
                              ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          AuthService
                                      .instance
                                      .currentUser
                                      .value
                                      ?.name
                                      .isNotEmpty ==
                                  true
                              ? AuthService.instance.currentUser.value!.name
                              : (AuthService
                                        .instance
                                        .currentUser
                                        .value
                                        ?.email ??
                                    ''),

                          style: const TextStyle(
                            fontWeight: FontWeight.bold,

                            fontSize: 14,

                            color: Color(0xFF2C2C2C),
                          ),
                        ),

                        Container(
                          margin: const EdgeInsets.only(top: 2),

                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,

                            vertical: 1,
                          ),

                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF5E6B3,
                            ).withValues(alpha: 0.5),

                            borderRadius: BorderRadius.circular(6),

                            border: Border.all(
                              color: const Color(
                                0xFFD4AF37,
                              ).withValues(alpha: 0.4),
                            ),
                          ),

                          child: const Row(
                            mainAxisSize: MainAxisSize.min,

                            children: [
                              Icon(
                                Icons.public,

                                size: 10,

                                color: Color(0xFFD4AF37),
                              ),

                              SizedBox(width: 3),

                              Text(
                                'Everyone',

                                style: TextStyle(
                                  fontSize: 10,

                                  color: Color(0xFFD4AF37),

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

                const SizedBox(height: 10),

                // Optional thought
                TextField(
                  controller: _thoughtCtrl,

                  maxLines: 3,

                  minLines: 1,

                  style: const TextStyle(
                    fontSize: 15,

                    color: Color(0xFF2C2C2C),
                  ),

                  decoration: const InputDecoration(
                    hintText: 'Say something about this...',

                    hintStyle: TextStyle(
                      color: Color(0xFFBBBBBB),

                      fontSize: 15,
                    ),

                    border: InputBorder.none,

                    contentPadding: EdgeInsets.zero,
                  ),
                ),

                const SizedBox(height: 10),

                // Original post preview
                Container(
                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFEEEEEE)),

                    borderRadius: BorderRadius.circular(10),

                    color: const Color(0xFFFAFAFA),
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,

                            height: 28,

                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,

                              color: Color(0xFFE8D5B7),
                            ),

                            child: const Icon(
                              Icons.person,

                              size: 16,

                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(width: 8),

                          Text(
                            authorName,

                            style: const TextStyle(
                              fontWeight: FontWeight.bold,

                              fontSize: 13,

                              color: Color(0xFF2C2C2C),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text(
                        widget.post.content.length > 100
                            ? '${widget.post.content.substring(0, 100)}â€¦'
                            : widget.post.content,

                        style: const TextStyle(
                          fontSize: 13,

                          color: Color(0xFF555555),

                          height: 1.4,
                        ),
                      ),

                      if (widget.post.mediaUrl != null &&
                          widget.post.mediaUrl!.isNotEmpty &&
                          widget.post.mediaType == 'image') ...[
                        const SizedBox(height: 8),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),

                          child: Image.network(
                            widget.post.mediaUrl!,

                            height: 100,

                            width: double.infinity,

                            fit: BoxFit.cover,

                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Share to feed button
                SizedBox(
                  width: double.infinity,

                  child: _sharing
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFD4AF37),

                            strokeWidth: 2,
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _shareToFeed,

                          icon: const Icon(Icons.share_rounded, size: 18),

                          label: const Text(
                            'Share to Feed',

                            style: TextStyle(
                              fontSize: 15,

                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),

                            foregroundColor: Colors.white,

                            padding: const EdgeInsets.symmetric(vertical: 13),

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),

                            elevation: 0,
                          ),
                        ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // Other share options
          _ShareOption(
            icon: Icons.link_rounded,

            iconColor: const Color(0xFF64B5F6),

            label: 'Copy link',

            subtitle: 'Copy the post link to clipboard',

            onTap: _copyLink,
          ),

          _ShareOption(
            icon: Icons.messenger_outline_rounded,

            iconColor: const Color(0xFF8B9DC3),

            label: 'Send in message',

            subtitle: 'Share privately with a friend',

            onTap: () {
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Messaging coming soon')),
              );
            },
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;

  final Color iconColor;

  final String label;

  final String subtitle;

  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,

    required this.iconColor,

    required this.label,

    required this.subtitle,

    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

        child: Row(
          children: [
            Container(
              width: 44,

              height: 44,

              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),

                shape: BoxShape.circle,
              ),

              child: Icon(icon, color: iconColor, size: 22),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    label,

                    style: const TextStyle(
                      fontSize: 14,

                      fontWeight: FontWeight.w600,

                      color: Color(0xFF2C2C2C),
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    subtitle,

                    style: const TextStyle(
                      fontSize: 12,

                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================

// REELS PREVIEW SECTION

// ============================================

class ReelsPreviewSection extends StatelessWidget {
  const ReelsPreviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),

          child: Row(
            children: [
              const Text(
                'Reels',

                style: TextStyle(
                  fontSize: 18,

                  fontWeight: FontWeight.bold,

                  color: Color(0xFF2C2C2C),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD4AF37),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                ),
                child: const Text(
                  'See All',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 200,

          child: ListView.builder(
            scrollDirection: Axis.horizontal,

            padding: const EdgeInsets.symmetric(horizontal: 12),

            itemCount: 5,

            itemBuilder: (context, index) {
              return _buildReelThumbnail(index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReelThumbnail(int index) {
    final colors = [
      const Color(0xFFF5E6B3),

      const Color(0xFFE8D5B7),

      const Color(0xFFD4C4A8),

      const Color(0xFFC9B896),

      const Color(0xFFDEC9A3),
    ];

    final names = [
      '@sarah_worship',

      '@pastor_john',

      '@grace_ministries',

      '@faith_talks',

      '@bible_study',
    ];

    return Container(
      width: 120,

      margin: const EdgeInsets.symmetric(horizontal: 4),

      decoration: BoxDecoration(
        color: colors[index % colors.length],

        borderRadius: BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),

            blurRadius: 8,

            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Stack(
        children: [
          // Thumbnail
          Center(
            child: Icon(
              Icons.play_circle_outline,

              size: 50,

              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),

          // Username overlay
          Positioned(
            bottom: 12,

            left: 8,

            right: 8,

            child: Text(
              names[index],

              style: const TextStyle(
                color: Colors.white,

                fontSize: 11,

                fontWeight: FontWeight.w600,

                shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
              ),

              maxLines: 1,

              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Amen icon overlay
          Positioned(
            top: 8,

            right: 8,

            child: Container(
              padding: const EdgeInsets.all(4),

              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),

                borderRadius: BorderRadius.circular(12),
              ),

              child: const Icon(
                Icons.thumb_up,

                size: 14,

                color: Color(0xFFD4AF37),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================

// MARKETPLACE PREVIEW SECTION

// ============================================

class MarketplacePreviewSection extends StatelessWidget {
  const MarketplacePreviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),

          child: Row(
            children: [
              const Text(
                'Marketplace',

                style: TextStyle(
                  fontSize: 18,

                  fontWeight: FontWeight.bold,

                  color: Color(0xFF2C2C2C),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD4AF37),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                ),
                child: const Text(
                  'See All',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),

          child: GridView.count(
            shrinkWrap: true,

            physics: const NeverScrollableScrollPhysics(),

            crossAxisCount: 2,

            crossAxisSpacing: 12,

            mainAxisSpacing: 12,

            childAspectRatio: 0.75,

            children: [
              _buildProductCard(
                'Christian T-Shirt',

                'â‚±150.00',

                'assets/Christian T-shrit.webp',
              ),

              _buildProductCard(
                'Bible Cover',

                'â‚±200.00',

                'assets/Bible cover.jpg',
              ),

              _buildProductCard(
                'Worship Journal',

                'â‚±179.00',

                'assets/worship journal.webp',
              ),

              _buildProductCard(
                'Prayer Beads',

                'â‚±100.00',

                'assets/prayerbeeds.webp',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(String title, String price, String imagePath) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),

            blurRadius: 10,

            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // Product Image
          Container(
            height: 100,

            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),

              image: DecorationImage(
                image: AssetImage(imagePath),

                fit: BoxFit.cover,
              ),
            ),
          ),

          // Product Info
          Padding(
            padding: const EdgeInsets.all(12),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: const TextStyle(
                    fontSize: 13,

                    fontWeight: FontWeight.w600,

                    color: Color(0xFF333333),
                  ),

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                Text(
                  price,

                  style: const TextStyle(
                    fontSize: 15,

                    fontWeight: FontWeight.bold,

                    color: Color(0xFFD4AF37),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,

                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),

                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.1),

                      borderRadius: BorderRadius.circular(8),

                      border: Border.all(color: const Color(0xFFD4AF37)),
                    ),

                    child: const Text(
                      'View',

                      textAlign: TextAlign.center,

                      style: TextStyle(
                        fontSize: 12,

                        fontWeight: FontWeight.w600,

                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================

// MUSIC SECTION

// ============================================

class MusicSection extends StatelessWidget {
  const MusicSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),

          child: Row(
            children: [
              const Text(
                'Worship Music',

                style: TextStyle(
                  fontSize: 18,

                  fontWeight: FontWeight.bold,

                  color: Color(0xFF2C2C2C),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD4AF37),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                ),
                child: const Text(
                  'See All',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 160,

          child: ListView.builder(
            scrollDirection: Axis.horizontal,

            padding: const EdgeInsets.symmetric(horizontal: 12),

            itemCount: 5,

            itemBuilder: (context, index) {
              return _buildMusicCard(index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMusicCard(int index) {
    final titles = [
      'Goodness of God',

      'Way Maker',

      'Great Are You Lord',

      'What A Beautiful Name',

      'Holy Spirit',
    ];

    final artists = [
      'Bethel Music',

      'Sinach',

      'Leeland',

      'Hillsong Worship',

      'Bryan & Katie Torwalt',
    ];

    final colors = [
      const Color(0xFFD4AF37),

      const Color(0xFFC9B896),

      const Color(0xFFB8A57A),

      const Color(0xFFA68B5B),

      const Color(0xFF8B7355),
    ];

    return Container(
      width: 120,

      margin: const EdgeInsets.symmetric(horizontal: 4),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),

            blurRadius: 10,

            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // Album Image
          Container(
            height: 100,

            decoration: BoxDecoration(
              color: colors[index % colors.length],

              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),

            child: Stack(
              children: [
                const Center(
                  child: Icon(Icons.album, size: 50, color: Colors.white),
                ),

                Positioned(
                  bottom: 8,

                  right: 8,

                  child: Container(
                    padding: const EdgeInsets.all(6),

                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),

                      shape: BoxShape.circle,

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),

                          blurRadius: 4,
                        ),
                      ],
                    ),

                    child: const Icon(
                      Icons.play_arrow,

                      size: 16,

                      color: Color(0xFFD4AF37),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Song Info
          Padding(
            padding: const EdgeInsets.all(10),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  titles[index],

                  style: const TextStyle(
                    fontSize: 12,

                    fontWeight: FontWeight.w600,

                    color: Color(0xFF333333),
                  ),

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 2),

                Text(
                  artists[index],

                  style: const TextStyle(
                    fontSize: 10,

                    color: Color(0xFF999999),
                  ),

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================

// PROFILE PREVIEW SECTION

// ============================================

class ProfilePreviewSection extends StatelessWidget {
  const ProfilePreviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),

            blurRadius: 15,

            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        children: [
          // Cover Photo
          Container(
            height: 100,

            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFFF5E6B3)],

                begin: Alignment.topLeft,

                end: Alignment.bottomRight,
              ),

              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),

            child: const Center(
              child: Icon(Icons.landscape, size: 40, color: Colors.white),
            ),
          ),

          // Profile Info
          Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              children: [
                // Profile Picture
                Transform.translate(
                  offset: const Offset(0, -30),

                  child: Container(
                    padding: const EdgeInsets.all(4),

                    decoration: BoxDecoration(
                      color: Colors.white,

                      shape: BoxShape.circle,

                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.3),

                          blurRadius: 10,
                        ),
                      ],
                    ),

                    child: Container(
                      width: 70,

                      height: 70,

                      decoration: BoxDecoration(
                        shape: BoxShape.circle,

                        border: Border.all(
                          color: const Color(0xFF64B5F6),

                          width: 3,
                        ),
                      ),

                      child: ClipOval(
                        child: Image.asset(
                          'assets/Profile.jpg',

                          fit: BoxFit.cover,

                          width: 70,

                          height: 70,
                        ),
                      ),
                    ),
                  ),
                ),

                Transform.translate(
                  offset: const Offset(0, -20),

                  child: Column(
                    children: [
                      const Text(
                        'Mark Frederick Boado',

                        style: TextStyle(
                          fontSize: 18,

                          fontWeight: FontWeight.bold,

                          color: Color(0xFF333333),
                        ),
                      ),

                      const SizedBox(height: 4),

                      const Text(
                        'Child of God â€¢ Worship Leader',

                        style: TextStyle(
                          fontSize: 13,

                          color: Color(0xFF888888),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Sharing my faith journey one post at a time âœï¸',

                        textAlign: TextAlign.center,

                        style: TextStyle(
                          fontSize: 13,

                          color: Color(0xFF666666),

                          fontStyle: FontStyle.italic,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          _StatColumn(number: '2.5K', label: 'Followers'),

                          Container(
                            height: 30,

                            width: 1,

                            margin: const EdgeInsets.symmetric(horizontal: 20),

                            color: const Color(0xFFE0E0E0),
                          ),

                          _StatColumn(number: '890', label: 'Following'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String number;

  final String label;

  const _StatColumn({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          number,

          style: const TextStyle(
            fontSize: 16,

            fontWeight: FontWeight.bold,

            color: Color(0xFF333333),
          ),
        ),

        Text(
          label,

          style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
        ),
      ],
    );
  }
}

// ============================================

// BOTTOM NAVIGATION BAR

// ============================================

class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  final ValueChanged<int> onTap;

  const BottomNavBar({super.key, this.currentIndex = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,

        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.12),

            blurRadius: 16,

            offset: const Offset(0, -4),
          ),
        ],
      ),

      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,

            children: [
              _buildNavItem(context, Icons.home_rounded, 'Home', 0),

              _buildNavItem(
                context,
                Icons.play_circle_outline_rounded,
                'Reels',
                1,
              ),

              _buildNavItem(context, Icons.auto_stories_rounded, 'Bible', 2),

              _buildNavItem(context, Icons.storefront_rounded, 'Market', 3),

              _buildNavItem(context, Icons.music_note_rounded, 'Music', 4),

              _buildNavItem(context, Icons.person_rounded, 'Profile', 5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,

    IconData icon,

    String label,

    int idx,
  ) {
    final isActive = idx == currentIndex;

    return InkWell(
      onTap: () => onTap(idx),

      borderRadius: BorderRadius.circular(14),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFD4AF37).withValues(alpha: 0.12)
              : Colors.transparent,

          borderRadius: BorderRadius.circular(14),
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(
              icon,

              size: 24,

              color: isActive
                  ? const Color(0xFFD4AF37)
                  : const Color(0xFF999999),
            ),

            const SizedBox(height: 3),

            Text(
              label,

              style: TextStyle(
                fontSize: 10,

                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,

                color: isActive
                    ? const Color(0xFFD4AF37)
                    : const Color(0xFF999999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
