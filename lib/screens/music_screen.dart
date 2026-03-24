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
  bool _playerExpanded = false;

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
    if (mounted) setState(() => _playerExpanded = true);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentSong = _service.currentSong;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Worship Music',
          style: TextStyle(color: cs.onSurface, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (currentSong != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: _SpeedSelector(
                  currentRate: _service.playbackRate,
                  onChanged: (r) => _service.setPlaybackRate(r),
                  mini: true,
                ),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final scale = (constraints.maxWidth.clamp(320.0, 1200.0) / 420.0);

        final listColumn = Column(children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Search songs...',
                hintStyle: TextStyle(color: Theme.of(context).hintColor),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).hintColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: _filteredSongs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_off, size: 64 * scale, color: Theme.of(context).hintColor),
                        const SizedBox(height: 16),
                        Text('No songs found',
                            style: TextStyle(fontSize: 16 * scale, color: cs.onSurface.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text('Try a different search term',
                            style: TextStyle(fontSize: 13 * scale, color: Theme.of(context).hintColor)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 220),
                    itemCount: _filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = _filteredSongs[index];
                      final isCurrent = currentSong?.title == song.title && currentSong?.artist == song.artist;
                      return _SongTile(
                        song: song,
                        isPlaying: isCurrent && _service.isPlaying,
                        isSelected: isCurrent,
                        onTap: () async => await _playSong(song, index),
                        scale: scale,
                      );
                    },
                  ),
          ),
        ]);

        final nowPlaying = currentSong == null
            ? const SizedBox.shrink()
            : _NowPlayingPanel(
                service: _service,
                scale: scale,
                expanded: _playerExpanded || isWide,
                onToggleExpand: () => setState(() => _playerExpanded = !_playerExpanded),
                fmtDuration: _fmt,
              );

        if (isWide) {
          return Row(children: [
            Expanded(flex: 3, child: listColumn),
            Container(
              width: constraints.maxWidth * 0.38,
              color: Theme.of(context).cardColor,
              child: currentSong != null
                  ? _NowPlayingPanel(
                      service: _service,
                      scale: scale,
                      expanded: true,
                      onToggleExpand: null,
                      fmtDuration: _fmt,
                    )
                  : Center(
                      child: Text('Select a song to play',
                          style: TextStyle(fontSize: 16 * scale, color: Theme.of(context).hintColor)),
                    ),
            ),
          ]);
        }

        return Column(children: [Expanded(child: listColumn), nowPlaying]);
      }),
    );
  }
}

class _NowPlayingPanel extends StatelessWidget {
  final MusicPlayerService service;
  final double scale;
  final bool expanded;
  final VoidCallback? onToggleExpand;
  final String Function(Duration) fmtDuration;

  const _NowPlayingPanel({
    required this.service,
    required this.scale,
    required this.expanded,
    required this.onToggleExpand,
    required this.fmtDuration,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final song = service.currentSong;
    if (song == null) return const SizedBox.shrink();

    final position = service.position;
    final duration = service.duration;
    final progress = duration.inMilliseconds > 0 ? position.inMilliseconds / duration.inMilliseconds : 0.0;

    if (!expanded) {
      return GestureDetector(
        onTap: onToggleExpand,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, -3))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 2,
              backgroundColor: Theme.of(context).dividerColor,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16 * scale, 10 * scale, 8 * scale, 10 * scale),
              child: Row(children: [
                SongAlbumArt(size: 44 * scale, song: song),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(song.title,
                        style: TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.w600, color: cs.onSurface),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(song.artist,
                        style: TextStyle(fontSize: 11 * scale, color: Theme.of(context).hintColor),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                IconButton(onPressed: service.playPrevious, icon: Icon(Icons.skip_previous_rounded, color: cs.onSurface), iconSize: 24 * scale),
                _PlayButton(isPlaying: service.isPlaying, size: 40 * scale, onTap: () => service.togglePlayPause()),
                IconButton(onPressed: service.playNext, icon: Icon(Icons.skip_next_rounded, color: cs.onSurface), iconSize: 24 * scale),
              ]),
            ),
          ]),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 16 * scale),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (onToggleExpand != null)
              GestureDetector(
                onTap: onToggleExpand,
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              SongAlbumArt(size: 56 * scale, song: song),
              SizedBox(width: 14 * scale),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(song.title,
                      style: TextStyle(fontSize: 15 * scale, fontWeight: FontWeight.w700, color: cs.onSurface),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 3 * scale),
                  Text(song.artist,
                      style: TextStyle(fontSize: 13 * scale, color: Theme.of(context).hintColor),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              _SpeedSelector(currentRate: service.playbackRate, onChanged: (r) => service.setPlaybackRate(r), mini: false),
            ]),
            SizedBox(height: 14 * scale),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFD4AF37),
                inactiveTrackColor: Theme.of(context).dividerColor,
                thumbColor: const Color(0xFFD4AF37),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                trackHeight: 3,
              ),
              child: Slider(
                min: 0,
                max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                value: position.inMilliseconds.toDouble().clamp(
                    0.0, duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0),
                onChanged: (v) => service.seek(Duration(milliseconds: v.toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(fmtDuration(position), style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                Text(fmtDuration(duration), style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
              ]),
            ),
            SizedBox(height: 8 * scale),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(onPressed: service.playPrevious, icon: Icon(Icons.skip_previous_rounded, color: cs.onSurface, size: 32 * scale)),
              SizedBox(width: 12 * scale),
              _PlayButton(isPlaying: service.isPlaying, size: 56 * scale, onTap: () => service.togglePlayPause()),
              SizedBox(width: 12 * scale),
              IconButton(onPressed: service.playNext, icon: Icon(Icons.skip_next_rounded, color: cs.onSurface, size: 32 * scale)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _SpeedSelector extends StatelessWidget {
  final double currentRate;
  final ValueChanged<double> onChanged;
  final bool mini;

  const _SpeedSelector({required this.currentRate, required this.onChanged, this.mini = true});

  static const _rates = [1.0, 2.0, 3.0, 4.0];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (mini) {
      final idx = _rates.indexOf(currentRate);
      final next = _rates[(idx < 0 ? 0 : idx + 1) % _rates.length];
      return GestureDetector(
        onTap: () => onChanged(next),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
          ),
          child: Text(
            '${currentRate == currentRate.truncateToDouble() ? currentRate.toInt() : currentRate}x',
            style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _rates.map((r) {
        final active = currentRate == r;
        return GestureDetector(
          onTap: () => onChanged(r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFD4AF37) : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? const Color(0xFFD4AF37) : Theme.of(context).dividerColor),
            ),
            child: Text(
              '${r == r.truncateToDouble() ? r.toInt() : r}x',
              style: TextStyle(color: active ? Colors.black : cs.onSurface, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final double size;
  final VoidCallback onTap;

  const _PlayButton({required this.isPlaying, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFFE8C95A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: size * 0.48),
      ),
    );
  }
}

class SongAlbumArt extends StatelessWidget {
  final double size;
  final Song? song;
  const SongAlbumArt({required this.size, this.song});

  // Per-artist colour palette and icon
  static const _themes = <String, SongArtistTheme>{
    'CCF Exalt Worship': SongArtistTheme(
      colors: [Color(0xFF003A8C), Color(0xFF0055CC)],
      icon: Icons.church,
      label: 'CCF',
    ),
    'Exalt Worship': SongArtistTheme(
      colors: [Color(0xFF4A0072), Color(0xFF8E24AA)],
      icon: Icons.church,
      label: 'EW',
    ),
    'CeCe Winans': SongArtistTheme(
      colors: [Color(0xFF7B3F00), Color(0xFFD4670A)],
      icon: Icons.mic,
      label: 'CW',
    ),
    'Hillsong Worship': SongArtistTheme(
      colors: [Color(0xFF880E4F), Color(0xFFC2185B)],
      icon: Icons.music_note,
      label: 'HW',
    ),
    'Hillsong': SongArtistTheme(
      colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
      icon: Icons.music_note,
      label: 'HS',
    ),
    'Hillsong Chapel': SongArtistTheme(
      colors: [Color(0xFF311B92), Color(0xFF5E35B1)],
      icon: Icons.church,
      label: 'HC',
    ),
    'Citipointe Worship': SongArtistTheme(
      colors: [Color(0xFF004D40), Color(0xFF00897B)],
      icon: Icons.music_note,
      label: 'CW',
    ),
    'Jessell Dawn Mahinay': SongArtistTheme(
      colors: [Color(0xFF880E4F), Color(0xFFE91E63)],
      icon: Icons.favorite,
      label: 'JD',
    ),
    'Musikatha': SongArtistTheme(
      colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
      icon: Icons.queue_music,
      label: 'MK',
    ),
    'Elevation Worship': SongArtistTheme(
      colors: [Color(0xFF1B1B2F), Color(0xFF3A3A5C)],
      icon: Icons.music_note,
      label: 'ELV',
    ),
  };

  static const _default = SongArtistTheme(
    colors: [Color(0xFFD4AF37), Color(0xFFF5E6B3)],
    icon: Icons.album,
    label: '♪',
  );

  @override
  Widget build(BuildContext context) {
    final theme = (song != null ? _themes[song!.artist] : null) ?? _default;
    final radius = BorderRadius.circular(size * 0.2);

    // If the song has albumArt, try to show the asset image.
    if (song?.albumArt != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          song!.albumArt!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildGradient(theme, radius),
        ),
      );
    }

    return _buildGradient(theme, radius);
  }

  Widget _buildGradient(SongArtistTheme theme, BorderRadius radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(theme.icon, color: Colors.white.withValues(alpha: 0.9), size: size * 0.32),
          SizedBox(height: size * 0.04),
          Text(
            theme.label,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class SongArtistTheme {
  final List<Color> colors;
  final IconData icon;
  final String label;
  const SongArtistTheme({required this.colors, required this.icon, required this.label});
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
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 5 * scale),
        padding: EdgeInsets.all(12 * scale),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37).withValues(alpha: 0.12) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37).withValues(alpha: 0.35) : Theme.of(context).dividerColor,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Stack(alignment: Alignment.center, children: [
            SongAlbumArt(size: 48 * scale, song: song),
            if (isPlaying)
              Container(
                width: 48 * scale, height: 48 * scale,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(48 * scale * 0.2)),
                child: Icon(Icons.equalizer, color: Colors.white, size: 20 * scale),
              ),
          ]),
          SizedBox(width: 14 * scale),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                song.title,
                style: TextStyle(
                  fontSize: 14 * scale, fontWeight: FontWeight.w600,
                  color: isSelected ? const Color(0xFFD4AF37) : cs.onSurface,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4 * scale),
              Text(song.artist, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Container(
            width: 34 * scale, height: 34 * scale,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFD4AF37) : cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: isSelected ? Colors.white : Theme.of(context).hintColor,
              size: 18 * scale,
            ),
          ),
        ]),
      ),
    );
  }
}