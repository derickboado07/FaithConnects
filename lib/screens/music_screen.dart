import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class Song {
  final String title;
  final String artist;
  final String assetPath;

  const Song({required this.title, required this.artist, required this.assetPath});
}

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Song? _currentSong;
  bool _isPlaying = false;
  int _currentIndex = 0;
  late final AudioPlayer _audioPlayer;

  static const List<Song> _allSongs = [
    Song(title: 'Amazing God', artist: 'CCF Exalt Worship', assetPath: 'songs/Amazing God  Lyrics and Chords  CCF Exalt Worship.mp3'),
    Song(title: 'By Your Love', artist: 'Exalt Worship', assetPath: 'songs/By Your Love  Lyric Video  Exalt Worship.mp3'),
    Song(title: 'Goodness of God', artist: 'CeCe Winans', assetPath: 'songs/CeCe Winans - Goodness of God  [Lyrics Gospel Songs] - Matt Redman, Gerald, Casting Crowns.mp3'),
    Song(title: 'Goodness of God', artist: 'Hillsong Worship', assetPath: 'songs/Goodness Of God - Hillsong Worship Songs, New Christian Worship Music 2025.mp3'),
    Song(title: 'Into The Deep', artist: 'Citipointe Worship', assetPath: 'songs/Into The Deep - Citipointe Worship  Chardon Lewis - Official Lyric Video.mp3'),
    Song(title: 'Lord I Offer My Life', artist: 'Jessell Dawn Mahinay', assetPath: 'songs/Lord I Offer My LifeJessell Dawn Mahinay (Lyrics).mp3'),
    Song(title: 'No Other Like Jesus', artist: 'CCF Exalt Worship', assetPath: 'songs/No Other Like Jesus  Lyrics and Chords  CCF Exalt Worship.mp3'),
    Song(title: 'One Way Jesus', artist: 'Hillsong', assetPath: 'songs/One Way Jesus (Lyrics)  Hillsong.mp3'),
    Song(title: 'Pupurihin Ka Sa Awit', artist: 'Musikatha', assetPath: 'songs/Pupurihin Ka Sa Awit - Musikatha (Lyrics).mp3'),
    Song(title: 'Trust In God', artist: 'Elevation Worship', assetPath: 'songs/Trust In God (feat. Chris Brown)  Official Lyric Video  Elevation Worship.mp3'),
    Song(title: 'Wala Kang Katulad', artist: 'Musikatha', assetPath: 'songs/WALA KANG KATULAD - Musikatha ( Lyric Video).mp3'),
    Song(title: 'Worthy', artist: 'Elevation Worship', assetPath: 'songs/Worthy - Elevation Worship ( lyric video).mp3'),
    Song(title: 'Worthy Is The Lamb', artist: 'Hillsong Chapel', assetPath: 'songs/Worthy Is The Lamb  Hillsong Chapel.mp3'),
  ];

  List<Song> get _filteredSongs {
    if (_searchQuery.isEmpty) return _allSongs;
    final q = _searchQuery.toLowerCase();
    return _allSongs.where((s) => s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _audio_playerInit();
  }

  void _audio_playerInit() {
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((_) => _playNext());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSong(Song song, int index) async {
    setState(() {
      _currentSong = song;
      _currentIndex = index;
    });
    try {
      await _audioPlayer.stop();
      if (kIsWeb) {
        final url = Uri.encodeFull('/assets/${song.assetPath}');
        // ignore: avoid_print
        print('Playing web asset URL: $url');
        await _audioPlayer.play(UrlSource(url));
      } else {
        await _audioPlayer.play(AssetSource(song.assetPath));
      }
      setState(() => _isPlaying = true);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error playing ${song.assetPath}: $e\n$st');
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _togglePlayPause() async {
    if (_currentSong == null) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        try {
          await _audioPlayer.resume();
        } catch (_) {
          await _audioPlayer.play(AssetSource(_currentSong!.assetPath));
        }
        setState(() => _isPlaying = true);
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('Error toggling play/pause: $e\n$st');
      setState(() => _isPlaying = false);
    }
  }

  void _playNext() {
    if (_currentIndex < _filteredSongs.length - 1) {
      _playSong(_filteredSongs[_currentIndex + 1], _currentIndex + 1);
    }
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      _playSong(_filteredSongs[_currentIndex - 1], _currentIndex - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Worship Music', style: TextStyle(color: Color(0xFF2C2C2C), fontSize: 22, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF5C5C5C)), onPressed: () => Navigator.pop(context)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final base = constraints.maxWidth.clamp(320.0, 1200.0);
          final scale = base / 420.0;

          Widget searchBar = Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFAF9F6), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE8E8E8))),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(hintText: 'Search songs...', hintStyle: TextStyle(color: Color(0xFF888888)), prefixIcon: Icon(Icons.search, color: Color(0xFF888888)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
            ),
          );

          Widget listColumn = Column(children: [
            searchBar,
            Expanded(
              child: _filteredSongs.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.music_off, size: 64 * scale, color: Colors.grey[300]), const SizedBox(height: 16), Text('No songs found', style: TextStyle(fontSize: 16 * scale, color: Colors.grey[600], fontWeight: FontWeight.w500)), const SizedBox(height: 8), Text('Try a different search term', style: TextStyle(fontSize: 13 * scale, color: Colors.grey[400]))]))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: _filteredSongs.length,
                      itemBuilder: (context, index) {
                        final song = _filteredSongs[index];
                        final isCurrent = _currentSong?.title == song.title && _currentSong?.artist == song.artist;
                        return _SongTile(song: song, isPlaying: isCurrent && _isPlaying, isSelected: isCurrent, onTap: () async => await _playSong(song, index), scale: scale);
                      },
                    ),
            ),
          ]);

          Widget nowPlaying = _currentSong == null
              ? const SizedBox.shrink()
              : Container(
                  padding: EdgeInsets.fromLTRB(16 * scale, 12 * scale, 16 * scale, 12 * scale),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, -4))]),
                  child: SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(height: 3 * scale, margin: EdgeInsets.only(bottom: 12 * scale), child: LinearProgressIndicator(value: _isPlaying ? 0.4 : 0, backgroundColor: const Color(0xFFE8E8E8), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)))),
                      Row(children: [
                        Container(width: 50 * scale, height: 50 * scale, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFF5E6B3)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(10 * scale)), child: const Icon(Icons.album, color: Colors.white, size: 28)),
                        SizedBox(width: 12 * scale),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_currentSong!.title, style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w600, color: const Color(0xFF2C2C2C)), maxLines: 1, overflow: TextOverflow.ellipsis), SizedBox(height: 2 * scale), Text(_currentSong!.artist, style: TextStyle(fontSize: 12 * scale, color: const Color(0xFF888888)), maxLines: 1, overflow: TextOverflow.ellipsis)])),
                        Row(mainAxisSize: MainAxisSize.min, children: [IconButton(onPressed: _playPrevious, icon: const Icon(Icons.skip_previous_rounded), iconSize: 28 * scale, color: const Color(0xFF5C5C5C)), GestureDetector(onTap: () async => await _togglePlayPause(), child: Container(width: 44 * scale, height: 44 * scale, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFE8C95A)], begin: Alignment.topLeft, end: Alignment.bottomRight), shape: BoxShape.circle), child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 26 * scale))), IconButton(onPressed: _playNext, icon: const Icon(Icons.skip_next_rounded), iconSize: 28 * scale, color: const Color(0xFF5C5C5C))])
                      ])
                    ])),
                );

          if (isWide) {
            return Row(children: [Expanded(flex: 3, child: listColumn), Container(width: constraints.maxWidth * 0.38, padding: const EdgeInsets.all(16), color: Colors.white, child: Column(children: [if (_currentSong != null) ...[Container(width: 220 * scale, height: 220 * scale, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFF5E6B3)]), borderRadius: BorderRadius.circular(12 * scale)), child: const Icon(Icons.album, color: Colors.white, size: 72)), const SizedBox(height: 18), Text(_currentSong!.title, style: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text(_currentSong!.artist, style: TextStyle(fontSize: 16 * scale, color: Colors.grey[600])), const Spacer(), nowPlaying] else ...[const Spacer(), Text('Select a song to play', style: TextStyle(fontSize: 16 * scale, color: Colors.grey[500])), const Spacer()]]))]);
          }

          return Column(children: [Expanded(child: listColumn), nowPlaying]);
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

  const _SongTile({required this.song, required this.isPlaying, required this.isSelected, required this.onTap, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 6 * scale),
        padding: EdgeInsets.all(12 * scale),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFFD4AF37).withValues(alpha: 0.1) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isSelected ? const Color(0xFFD4AF37).withValues(alpha: 0.3) : const Color(0xFFEEEEEE)), boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(width: 54 * scale, height: 54 * scale, decoration: BoxDecoration(gradient: LinearGradient(colors: isSelected ? [const Color(0xFFD4AF37), const Color(0xFFE8C95A)] : [const Color(0xFFE8D5B7), const Color(0xFFD4C4A8)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(10)), child: Stack(alignment: Alignment.center, children: [const Icon(Icons.album, color: Colors.white, size: 28), if (isPlaying) Container(width: 54 * scale, height: 54 * scale, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.equalizer, color: Colors.white, size: 24))])),
          SizedBox(width: 14 * scale),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(song.title, style: TextStyle(fontSize: 14.5 * scale, fontWeight: FontWeight.w600, color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF2C2C2C)), maxLines: 1, overflow: TextOverflow.ellipsis), SizedBox(height: 4 * scale), Text(song.artist, style: const TextStyle(fontSize: 12.5, color: Color(0xFF888888)), maxLines: 1, overflow: TextOverflow.ellipsis)])),
          Container(width: 36 * scale, height: 36 * scale, decoration: BoxDecoration(color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFFF5F5F5), shape: BoxShape.circle), child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: isSelected ? Colors.white : const Color(0xFF888888), size: 20 * scale))
        ]),
      ),
    );
  }
}
