import 'dart:ui';
import 'package:flutter/material.dart';
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
  final double scale;

  const _SongTile({
    required this.song,
    required this.isPlaying,
    required this.isSelected,
    required this.onTap,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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

class _FullPlayerSheet extends StatelessWidget {
  final MusicPlayerService service;

  const _FullPlayerSheet({required this.service});

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.of(context).size.height;
    final sw = MediaQuery.of(context).size.width;
    final albumSize = (sw * 0.62).clamp(180.0, 280.0);

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final song = service.currentSong;
        if (song == null) return const SizedBox.shrink();
        final playing = service.isPlaying;
        final pos = service.position;
        final dur = service.duration;
        final prog = service.progress;
        final playlist = service.playlist;
        final nextIndex = service.currentIndex + 1;
        final nextSong = nextIndex < playlist.length ? playlist[nextIndex] : null;

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: sh * 0.92),
          child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFBF8F0), Color(0xFFF3E9CF), Color(0xFFEDE0BE)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Stack(
            children: [
              // Decorative blurred circles — give glassmorphism something to blur
              Positioned(
                top: -50, right: -70,
                child: _DecorCircle(size: 260, color: const Color(0xFFD4AF37).withOpacity(0.22)),
              ),
              Positioned(
                bottom: 90, left: -90,
                child: _DecorCircle(size: 300, color: const Color(0xFFE8C85A).withOpacity(0.14)),
              ),
              Positioned(
                top: 210, left: -50,
                child: _DecorCircle(size: 180, color: const Color(0xFFD4AF37).withOpacity(0.09)),
              ),

              // Scrollable main content
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                children: [
                  // ── Drag handle
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCBB99),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Header row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CircleBtn(
                          icon: Icons.keyboard_arrow_down_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Text(
                          'NOW PLAYING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB8A070),
                            letterSpacing: 1.5,
                          ),
                        ),
                        _CircleBtn(icon: Icons.more_horiz_rounded, onTap: () {}),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),

                  // ── Album art — large, rounded, golden glow shadow
                  Container(
                    width: albumSize,
                    height: albumSize,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD4AF37), Color(0xFFEDC85A), Color(0xFFF5E6B3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withOpacity(0.52),
                          blurRadius: 52,
                          offset: const Offset(0, 20),
                          spreadRadius: -8,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.09),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.album_rounded,
                        color: Colors.white.withOpacity(0.85),
                        size: albumSize * 0.38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Song title + artist + heart
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A1A1A),
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                song.artist,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  color: Color(0xFF888888),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.25)),
                          ),
                          child: const Icon(Icons.favorite_border_rounded, color: Color(0xFFD4AF37), size: 21),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Seek slider + time labels
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFFD4AF37),
                            inactiveTrackColor: const Color(0xFFE2D5B0),
                            thumbColor: const Color(0xFFD4AF37),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            trackHeight: 3.5,
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                            overlayColor: const Color(0xFFD4AF37).withOpacity(0.18),
                          ),
                          child: Slider(
                            value: prog.clamp(0.0, 1.0),
                            onChanged: (v) {
                              if (dur.inMilliseconds > 0) {
                                service.seekTo(Duration(
                                  milliseconds: (v * dur.inMilliseconds).round(),
                                ));
                              }
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_fmt(pos), style: const TextStyle(fontSize: 11.5, color: Color(0xFF999999))),
                              Text(_fmt(dur), style: const TextStyle(fontSize: 11.5, color: Color(0xFF999999))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Glassmorphism controls bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.48),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.white.withOpacity(0.75), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD4AF37).withOpacity(0.10),
                                blurRadius: 24,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _GlassControlBtn(icon: Icons.skip_previous_rounded, onTap: service.playPrevious),
                              GestureDetector(
                                onTap: () async => await service.togglePlayPause(),
                                child: Container(
                                  width: 70, height: 70,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFD4AF37), Color(0xFFEDC85A)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD4AF37).withOpacity(0.58),
                                        blurRadius: 26,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                ),
                              ),
                              _GlassControlBtn(icon: Icons.skip_next_rounded, onTap: service.playNext),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Up Next glassmorphism peek card
                  if (nextSong != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.38),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.65), width: 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFE8D095), Color(0xFFD4C070)],
                                    ),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Icon(Icons.album_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'UP NEXT',
                                        style: TextStyle(fontSize: 10, color: Color(0xFFAA9955), fontWeight: FontWeight.w700, letterSpacing: 1.2),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(nextSong.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2C2C2C)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(nextSong.artist, style: const TextStyle(fontSize: 11.5, color: Color(0xFF888888)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.queue_music_rounded, color: Color(0xFFD4AF37), size: 22),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),   // SingleChildScrollView
            ],
          ),
        ),
        );  // ConstrainedBox
      },
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
  final VoidCallback onTap;
  const _GlassControlBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54, height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.55),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.7)),
        ),
        child: Icon(icon, size: 30, color: const Color(0xFF5C5C5C)),
      ),
    );
  }
}

