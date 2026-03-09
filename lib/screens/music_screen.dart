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

  @override
  Widget build(BuildContext context) {
    final currentSong = _service.currentSong;
    final isPlaying = _service.isPlaying;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Worship Music',
          style: TextStyle(
            color: Color(0xFF2C2C2C),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF5C5C5C)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final base = constraints.maxWidth.clamp(320.0, 1200.0);
          final scale = base / 420.0;

          Widget searchBar = Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(
                hintText: 'Search songs...',
                hintStyle: TextStyle(color: Color(0xFF888888)),
                prefixIcon: Icon(Icons.search, color: Color(0xFF888888)),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      padding: const EdgeInsets.only(bottom: 100),
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
              : Container(
                  padding: EdgeInsets.fromLTRB(
                      16 * scale, 12 * scale, 16 * scale, 12 * scale),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      )
                    ],
                  ),
                  child: SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        height: 3 * scale,
                        margin: EdgeInsets.only(bottom: 12 * scale),
                        child: LinearProgressIndicator(
                          value: isPlaying ? 0.4 : 0,
                          backgroundColor: const Color(0xFFE8E8E8),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFD4AF37)),
                        ),
                      ),
                      Row(children: [
                        Container(
                          width: 50 * scale,
                          height: 50 * scale,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD4AF37), Color(0xFFF5E6B3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10 * scale),
                          ),
                          child: const Icon(Icons.album,
                              color: Colors.white, size: 28),
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
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2C2C2C),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2 * scale),
                              Text(
                                currentSong.artist,
                                style: TextStyle(
                                    fontSize: 12 * scale,
                                    color: const Color(0xFF888888)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            onPressed: _service.playPrevious,
                            icon: const Icon(Icons.skip_previous_rounded),
                            iconSize: 28 * scale,
                            color: const Color(0xFF5C5C5C),
                          ),
                          GestureDetector(
                            onTap: () async =>
                                await _service.togglePlayPause(),
                            child: Container(
                              width: 44 * scale,
                              height: 44 * scale,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFD4AF37),
                                    Color(0xFFE8C95A)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 26 * scale,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _service.playNext,
                            icon: const Icon(Icons.skip_next_rounded),
                            iconSize: 28 * scale,
                            color: const Color(0xFF5C5C5C),
                          ),
                        ]),
                      ]),
                    ]),
                  ),
                );

          if (isWide) {
            return Row(children: [
              Expanded(flex: 3, child: listColumn),
              Container(
                width: constraints.maxWidth * 0.38,
                padding: const EdgeInsets.all(16),
                color: Colors.white,
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
    return InkWell(
      onTap: onTap,
      child: Container(
        margin:
            EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 6 * scale),
        padding: EdgeInsets.all(12 * scale),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFD4AF37).withValues(alpha: 0.3)
                : const Color(0xFFEEEEEE),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(children: [
          Container(
            width: 54 * scale,
            height: 54 * scale,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSelected
                    ? [const Color(0xFFD4AF37), const Color(0xFFE8C95A)]
                    : [const Color(0xFFE8D5B7), const Color(0xFFD4C4A8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(alignment: Alignment.center, children: [
              const Icon(Icons.album, color: Colors.white, size: 28),
              if (isPlaying)
                Container(
                  width: 54 * scale,
                  height: 54 * scale,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.equalizer,
                      color: Colors.white, size: 24),
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
                    fontSize: 14.5 * scale,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFFD4AF37)
                        : const Color(0xFF2C2C2C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4 * scale),
                Text(
                  song.artist,
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF888888)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            width: 36 * scale,
            height: 36 * scale,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFD4AF37)
                  : const Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: isSelected ? Colors.white : const Color(0xFF888888),
              size: 20 * scale,
            ),
          ),
        ]),
      ),
    );
  }
}
