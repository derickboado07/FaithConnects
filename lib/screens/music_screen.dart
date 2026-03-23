import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/music_player_service.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  MusicPlayerService get _service => MusicPlayerService.instance;

  List<Song> get _filteredSongs {
    if (_searchQuery.isEmpty) return MusicPlayerService.allSongs;
    final q = _searchQuery.toLowerCase();
    return MusicPlayerService.allSongs
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _playSong(Song song, int index) async {
    await _service.playSong(song, index, _filteredSongs);
  }

  Future<void> _addSong() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final filePath = file.path;
    if (filePath == null) return;

    // Derive a default title from the filename (strip extension)
    final rawName = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');

    if (!mounted) return;
    final titleCtrl = TextEditingController(text: rawName);
    final artistCtrl = TextEditingController(text: 'Unknown Artist');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFBF8F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Add Song', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2A2015))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Song Title', labelStyle: TextStyle(color: Color(0xFFB8A070))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: artistCtrl,
              decoration: const InputDecoration(labelText: 'Artist', labelStyle: TextStyle(color: Color(0xFFB8A070))),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF999999))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final title = titleCtrl.text.trim();
    final artist = artistCtrl.text.trim();
    if (title.isEmpty) return;

    _service.addSong(Song(
      title: title,
      artist: artist.isNotEmpty ? artist : 'Unknown Artist',
      assetPath: filePath,
      isUserAdded: true,
    ));
  }

  void _confirmRemoveSong(Song song) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFBF8F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Remove Song', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2A2015))),
        content: Text('Remove "${song.title}" from your library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF999999))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              _service.removeSong(song);
              Navigator.pop(ctx);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = _service.currentSong;
    final isPlaying = _service.isPlaying;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Worship Music',
              style: TextStyle(
                color: Color(0xFF2A2015),
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Your sacred playlist',
              style: TextStyle(
                color: Color(0xFFB8A070),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: _addSong,
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.50), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0E8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.white.withOpacity(0.9), blurRadius: 8, offset: const Offset(-3, -3)),
                  BoxShadow(color: const Color(0xFFD4C4A0).withOpacity(0.55), blurRadius: 8, offset: const Offset(3, 3)),
                ],
              ),
              child: const Icon(Icons.tune_rounded, color: Color(0xFFB8A070), size: 20),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final base = constraints.maxWidth.clamp(320.0, 1200.0);
          final scale = base / 420.0;

          Widget searchBar = Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFEADF),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                // inner-shadow illusion: dark inset bottom-right
                BoxShadow(color: const Color(0xFFCDBF9A).withOpacity(0.60), blurRadius: 8, offset: const Offset(4, 4)),
                // inner-shadow illusion: light inset top-left
                const BoxShadow(color: Colors.white, blurRadius: 8, offset: Offset(-4, -4)),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 14, color: Color(0xFF2A2015)),
              decoration: InputDecoration(
                hintText: 'Search songs or artist...',
                hintStyle: const TextStyle(color: Color(0xFFB8A88A), fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFB8A070), size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () => setState(() { _searchQuery = ''; _searchController.clear(); }),
                        child: const Icon(Icons.close_rounded, color: Color(0xFFB8A070), size: 18),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              ),
            ),
          );

          Widget listColumn = Column(children: [
            searchBar,
            Expanded(
              child: _filteredSongs.isEmpty
                  ? Center(
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_off,
                            size: 64 * scale, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No songs found',
                            style: TextStyle(
                                fontSize: 16 * scale,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text('Try a different search term',
                            style: TextStyle(
                                fontSize: 13 * scale, color: Colors.grey[400]))
                      ],
                    ))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: _filteredSongs.length,
                      itemBuilder: (context, index) {
                        final song = _filteredSongs[index];
                        final isCurrent = currentSong?.title == song.title &&
                            currentSong?.artist == song.artist;
                        return _SongTile(
                          song: song,
                          isPlaying: isCurrent && isPlaying,
                          isSelected: isCurrent,
                          onTap: () async => await _playSong(song, index),
                          onLongPress: song.isUserAdded ? () => _confirmRemoveSong(song) : null,
                          scale: scale,
                        );
                      },
                    ),
            ),
          ]);

          Widget nowPlaying = currentSong == null
              ? const SizedBox.shrink()
              : GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => _FullPlayerSheet(service: _service),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: EdgeInsets.fromLTRB(14 * scale, 10 * scale, 10 * scale, 10 * scale),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F0E8).withOpacity(0.72),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: Colors.white.withOpacity(0.80), width: 1.2),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.18), blurRadius: 24, offset: const Offset(0, 6)),
                              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // thin gold progress line
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _service.progress,
                                  backgroundColor: const Color(0xFFDDD3BA),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                                  minHeight: 3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  // album thumb
                                  Container(
                                    width: 46 * scale,
                                    height: 46 * scale,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFD4AF37), Color(0xFFEDCF6A)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.45), blurRadius: 12, offset: const Offset(0, 4)),
                                      ],
                                    ),
                                    child: const Icon(Icons.album_rounded, color: Colors.white, size: 24),
                                  ),
                                  SizedBox(width: 12 * scale),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentSong.title,
                                          style: TextStyle(
                                            fontSize: 14 * scale,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF2A2015),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          currentSong.artist,
                                          style: TextStyle(fontSize: 11.5 * scale, color: const Color(0xFFB8A070)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // controls
                                  _SoftIconBtn(
                                    icon: Icons.skip_previous_rounded,
                                    size: 22 * scale,
                                    onTap: _service.playPrevious,
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () async => await _service.togglePlayPause(),
                                    child: Container(
                                      width: 44 * scale,
                                      height: 44 * scale,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFD4AF37), Color(0xFFEDCF6A)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.50), blurRadius: 14, offset: const Offset(0, 5)),
                                        ],
                                      ),
                                      child: Icon(
                                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 24 * scale,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _SoftIconBtn(
                                    icon: Icons.skip_next_rounded,
                                    size: 22 * scale,
                                    onTap: _service.playNext,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );

          if (isWide) {
            return Row(children: [
              Expanded(flex: 3, child: listColumn),
              Container(
                width: constraints.maxWidth * 0.38,
                padding: const EdgeInsets.all(16),
                color: const Color(0xFFF5F0E8),
                child: Column(children: [
                  if (currentSong != null) ...[
                    Container(
                      width: 220 * scale,
                      height: 220 * scale,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFD4AF37), Color(0xFFF5E6B3)]),
                        borderRadius: BorderRadius.circular(12 * scale),
                      ),
                      child: const Icon(Icons.album,
                          color: Colors.white, size: 72),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      currentSong.title,
                      style: TextStyle(
                          fontSize: 20 * scale, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentSong.artist,
                      style: TextStyle(
                          fontSize: 16 * scale, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    nowPlaying,
                  ] else ...[
                    const Spacer(),
                    Text(
                      'Select a song to play',
                      style: TextStyle(
                          fontSize: 16 * scale, color: Colors.grey[500]),
                    ),
                    const Spacer(),
                  ]
                ]),
              ),
            ]);
          }

          return Column(
              children: [Expanded(child: listColumn), nowPlaying]);
        },
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double scale;

  const _SongTile({
    required this.song,
    required this.isPlaying,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 7 * scale),
        padding: EdgeInsets.all(13 * scale),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFBF7EE) : const Color(0xFFF5F0E8),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  // selected: golden outer glow
                  BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.38), blurRadius: 20, offset: const Offset(0, 6), spreadRadius: -2),
                  const BoxShadow(color: Colors.white, blurRadius: 10, offset: Offset(-4, -4)),
                  BoxShadow(color: const Color(0xFFCDBF9A).withOpacity(0.55), blurRadius: 10, offset: const Offset(4, 4)),
                ]
              : [
                  // normal: subtle soft-UI glow
                  const BoxShadow(color: Colors.white, blurRadius: 10, offset: Offset(-4, -4)),
                  BoxShadow(color: const Color(0xFFCDBF9A).withOpacity(0.45), blurRadius: 10, offset: const Offset(4, 4)),
                ],
        ),
        child: Row(children: [
          // Album art bubble
          Container(
            width: 52 * scale,
            height: 52 * scale,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSelected
                    ? [const Color(0xFFD4AF37), const Color(0xFFEDCF6A)]
                    : [const Color(0xFFE8D5A8), const Color(0xFFCFBD8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: (isSelected ? const Color(0xFFD4AF37) : const Color(0xFFCFBD8A)).withOpacity(0.40),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(alignment: Alignment.center, children: [
              Icon(Icons.album_rounded, color: Colors.white.withOpacity(0.9), size: 27),
              if (isPlaying)
                Container(
                  width: 52 * scale,
                  height: 52 * scale,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.equalizer_rounded, color: Colors.white, size: 22),
                ),
            ]),
          ),
          SizedBox(width: 14 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: TextStyle(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? const Color(0xFFC4960A) : const Color(0xFF2A2015),
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 3 * scale),
                Text(
                  song.artist,
                  style: TextStyle(fontSize: 12 * scale, color: const Color(0xFFB8A070), fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 8 * scale),
          // play button — soft UI circle
          Container(
            width: 38 * scale,
            height: 38 * scale,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFFF5F0E8),
              shape: BoxShape.circle,
              boxShadow: isSelected
                  ? [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.55), blurRadius: 14, offset: const Offset(0, 5))]
                  : [
                      const BoxShadow(color: Colors.white, blurRadius: 6, offset: Offset(-2, -2)),
                      BoxShadow(color: const Color(0xFFCDBF9A).withOpacity(0.50), blurRadius: 6, offset: const Offset(2, 2)),
                    ],
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: isSelected ? Colors.white : const Color(0xFFB8A070),
              size: 20 * scale,
            ),
          ),
        ]),
      ),
    );
  }
}

// Soft-UI icon button used in the mini now-playing bar
class _SoftIconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  const _SoftIconBtn({required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size + 16,
        height: size + 16,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0E8).withOpacity(0.70),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF7A6840), size: size),
      ),
    );
  }
}

// ============================================================
// FULL PLAYER — high-fidelity glassmorphism bottom sheet
// ============================================================

class _FullPlayerSheet extends StatefulWidget {
  final MusicPlayerService service;
  const _FullPlayerSheet({required this.service});

  @override
  State<_FullPlayerSheet> createState() => _FullPlayerSheetState();
}

class _FullPlayerSheetState extends State<_FullPlayerSheet>
    with SingleTickerProviderStateMixin {
  bool _liked = false;
  late final AnimationController _eqCtrl;

  MusicPlayerService get _s => widget.service;

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _eqCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _eqCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.of(context).size.height;
    final sw = MediaQuery.of(context).size.width;
    final albumSize = (sw * 0.65).clamp(200.0, 310.0);

    return ListenableBuilder(
      listenable: _s,
      builder: (context, _) {
        final song = _s.currentSong;
        if (song == null) return const SizedBox.shrink();
        final playing = _s.isPlaying;
        final pos = _s.position;
        final dur = _s.duration;
        final prog = _s.progress;
        final playlist = _s.playlist;
        final nextIndex = _s.currentIndex + 1;
        final nextSong =
            nextIndex < playlist.length ? playlist[nextIndex] : null;

        // keep eq animation in sync with playback
        if (playing && !_eqCtrl.isAnimating) _eqCtrl.repeat(reverse: true);
        if (!playing && _eqCtrl.isAnimating) _eqCtrl.stop();

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: sh * 0.94),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFCF9F2),
                  Color(0xFFF6EDDA),
                  Color(0xFFF0E3C4),
                  Color(0xFFE8D6AA),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.35, 0.7, 1.0],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(36)),
              child: Stack(
                children: [
                  // ── Organic background shapes
                  ..._buildOrganicShapes(sw, sh),

                  // ── Main scrollable content
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      children: [
                        // ── Drag handle
                        const SizedBox(height: 14),
                        Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCCBB99).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Header
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              _SoftCircleBtn(
                                icon: Icons.keyboard_arrow_down_rounded,
                                onTap: () => Navigator.pop(context),
                              ),
                              Column(
                                children: const [
                                  Text(
                                    'NOW PLAYING',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFB8A070),
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Worship Collection',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFCBB88A),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              _SoftCircleBtn(
                                icon: Icons.share_rounded,
                                onTap: () {},
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // ── Album art — large, rounded, glowing
                        Center(
                          child: Container(
                            width: albumSize,
                            height: albumSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFD4AF37),
                                  Color(0xFFECC544),
                                  Color(0xFFF5E6B3),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD4AF37)
                                      .withOpacity(0.50),
                                  blurRadius: 60,
                                  offset: const Offset(0, 24),
                                  spreadRadius: -10,
                                ),
                                BoxShadow(
                                  color: const Color(0xFFD4AF37)
                                      .withOpacity(0.25),
                                  blurRadius: 100,
                                  offset: const Offset(0, 40),
                                  spreadRadius: -20,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // subtle vinyl ring pattern
                                  Container(
                                    width: albumSize * 0.72,
                                    height: albumSize * 0.72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white
                                            .withOpacity(0.18),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: albumSize * 0.52,
                                    height: albumSize * 0.52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white
                                            .withOpacity(0.12),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  // center disc
                                  Container(
                                    width: albumSize * 0.28,
                                    height: albumSize * 0.28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white
                                          .withOpacity(0.30),
                                    ),
                                    child: Icon(
                                      Icons.music_note_rounded,
                                      color: Colors.white
                                          .withOpacity(0.90),
                                      size: albumSize * 0.14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Song info row
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            children: [
                              Text(
                                song.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A1408),
                                  height: 1.15,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                song.artist,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFAA9560),
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Heart + Equalizer row
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 56),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              // Heart button
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _liked = !_liked),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 250),
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: _liked
                                        ? const Color(0xFFD4AF37)
                                            .withOpacity(0.18)
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFD4AF37)
                                          .withOpacity(
                                              _liked ? 0.50 : 0.30),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    _liked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: const Color(0xFFD4AF37),
                                    size: 22,
                                  ),
                                ),
                              ),
                              // Animated EQ waveform
                              SizedBox(
                                width: 46,
                                height: 46,
                                child: AnimatedBuilder(
                                  animation: _eqCtrl,
                                  builder: (context, _) {
                                    return CustomPaint(
                                      painter: _EqWavePainter(
                                        value: _eqCtrl.value,
                                        active: playing,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Seek slider
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            children: [
                              SliderTheme(
                                data:
                                    SliderTheme.of(context).copyWith(
                                  activeTrackColor:
                                      const Color(0xFFD4AF37),
                                  inactiveTrackColor:
                                      const Color(0xFFE5D9BB),
                                  thumbColor:
                                      const Color(0xFFD4AF37),
                                  thumbShape:
                                      const RoundSliderThumbShape(
                                          enabledThumbRadius: 7),
                                  trackHeight: 3.5,
                                  overlayShape:
                                      const RoundSliderOverlayShape(
                                          overlayRadius: 18),
                                  overlayColor:
                                      const Color(0xFFD4AF37)
                                          .withOpacity(0.15),
                                ),
                                child: Slider(
                                  value: prog.clamp(0.0, 1.0),
                                  onChanged: (v) {
                                    if (dur.inMilliseconds > 0) {
                                      _s.seekTo(Duration(
                                        milliseconds:
                                            (v * dur.inMilliseconds)
                                                .round(),
                                      ));
                                    }
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_fmt(pos),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFAA9560))),
                                    Text(_fmt(dur),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFAA9560))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ── Glassmorphism controls
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(36),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                  sigmaX: 28, sigmaY: 28),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 18),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.42),
                                  borderRadius:
                                      BorderRadius.circular(36),
                                  border: Border.all(
                                    color:
                                        Colors.white.withOpacity(0.80),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD4AF37)
                                          .withOpacity(0.08),
                                      blurRadius: 30,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _GlassControlBtn(
                                      icon: Icons.shuffle_rounded,
                                      size: 22,
                                      onTap: () {},
                                    ),
                                    _GlassControlBtn(
                                      icon:
                                          Icons.skip_previous_rounded,
                                      size: 32,
                                      onTap: _s.playPrevious,
                                    ),
                                    // Main play button
                                    GestureDetector(
                                      onTap: () async =>
                                          await _s.togglePlayPause(),
                                      child: Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          gradient:
                                              const LinearGradient(
                                            colors: [
                                              Color(0xFFD4AF37),
                                              Color(0xFFECC544),
                                            ],
                                            begin: Alignment.topLeft,
                                            end:
                                                Alignment.bottomRight,
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  const Color(
                                                          0xFFD4AF37)
                                                      .withOpacity(
                                                          0.55),
                                              blurRadius: 28,
                                              offset:
                                                  const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          playing
                                              ? Icons.pause_rounded
                                              : Icons
                                                  .play_arrow_rounded,
                                          color: Colors.white,
                                          size: 38,
                                        ),
                                      ),
                                    ),
                                    _GlassControlBtn(
                                      icon: Icons.skip_next_rounded,
                                      size: 32,
                                      onTap: _s.playNext,
                                    ),
                                    _GlassControlBtn(
                                      icon: Icons.repeat_rounded,
                                      size: 22,
                                      onTap: () {},
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ── Up Next peek card
                        if (nextSong != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                    sigmaX: 16, sigmaY: 16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withOpacity(0.35),
                                    borderRadius:
                                        BorderRadius.circular(22),
                                    border: Border.all(
                                      color: Colors.white
                                          .withOpacity(0.60),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          gradient:
                                              const LinearGradient(
                                            colors: [
                                              Color(0xFFE8D095),
                                              Color(0xFFD4C070),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(
                                                  13),
                                        ),
                                        child: const Icon(
                                            Icons.album_rounded,
                                            color: Colors.white,
                                            size: 23),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                          children: [
                                            const Text(
                                              'UP NEXT',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                color:
                                                    Color(0xFFAA9955),
                                                fontWeight:
                                                    FontWeight.w800,
                                                letterSpacing: 1.4,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              nextSong.title,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight:
                                                    FontWeight.w700,
                                                color:
                                                    Color(0xFF2A2015),
                                              ),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow
                                                      .ellipsis,
                                            ),
                                            Text(
                                              nextSong.artist,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color:
                                                    Color(0xFFAA9560),
                                              ),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow
                                                      .ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.queue_music_rounded,
                                        color: Color(0xFFD4AF37),
                                        size: 22,
                                      ),
                                    ],
                                  ),
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
          ),
        );
      },
    );
  }

  /// Soft organic background shapes
  List<Widget> _buildOrganicShapes(double sw, double sh) {
    return [
      // top-right large blob
      Positioned(
        top: -80, right: -100,
        child: Container(
          width: 320, height: 320,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFD4AF37).withOpacity(0.18),
                const Color(0xFFD4AF37).withOpacity(0.0),
              ],
            ),
          ),
        ),
      ),
      // left mid wave
      Positioned(
        top: sh * 0.28, left: -130,
        child: Container(
          width: 280, height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFECC544).withOpacity(0.14),
                const Color(0xFFECC544).withOpacity(0.0),
              ],
            ),
          ),
        ),
      ),
      // bottom-right accent
      Positioned(
        bottom: 40, right: -80,
        child: Container(
          width: 240, height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFD4AF37).withOpacity(0.10),
                const Color(0xFFD4AF37).withOpacity(0.0),
              ],
            ),
          ),
        ),
      ),
      // bottom-left warmth
      Positioned(
        bottom: 160, left: -70,
        child: Container(
          width: 200, height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFF5E2A0).withOpacity(0.18),
                const Color(0xFFF5E2A0).withOpacity(0.0),
              ],
            ),
          ),
        ),
      ),
      // top-left subtle haze
      Positioned(
        top: 100, left: -40,
        child: Container(
          width: 160, height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFD4AF37).withOpacity(0.07),
                const Color(0xFFD4AF37).withOpacity(0.0),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  Animated equalizer waveform painter
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _EqWavePainter extends CustomPainter {
  final double value;
  final bool active;
  _EqWavePainter({required this.value, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = active ? const Color(0xFFD4AF37) : const Color(0xFFCBB88A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2;

    const bars = 5;
    final gap = size.width / (bars + 1);
    // Each bar has a phase-offset so they animate differently
    for (int i = 0; i < bars; i++) {
      final phase = (value + i * 0.22) % 1.0;
      final h = active
          ? size.height * (0.25 + 0.55 * _wave(phase))
          : size.height * 0.18;
      final x = gap * (i + 1);
      final y1 = size.height / 2 - h / 2;
      final y2 = size.height / 2 + h / 2;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  double _wave(double t) => (t < 0.5 ? t * 2 : 2 - t * 2);

  @override
  bool shouldRepaint(covariant _EqWavePainter old) =>
      old.value != value || old.active != active;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  Soft-UI circle button (header)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _SoftCircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SoftCircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0E8),
          shape: BoxShape.circle,
          boxShadow: [
            const BoxShadow(
              color: Colors.white,
              blurRadius: 8,
              offset: Offset(-3, -3),
            ),
            BoxShadow(
              color: const Color(0xFFCDBF9A).withOpacity(0.55),
              blurRadius: 8,
              offset: const Offset(3, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 24, color: const Color(0xFFAA9560)),
      ),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _DecorCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.50),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 26, color: const Color(0xFF5C5C5C)),
      ),
    );
  }
}

class _GlassControlBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  const _GlassControlBtn({required this.icon, this.size = 30, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size + 20, height: size + 20,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.7)),
        ),
        child: Icon(icon, size: size, color: const Color(0xFF5C5C5C)),
      ),
    );
  }
}

