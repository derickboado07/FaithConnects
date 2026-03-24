import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum RepeatMode { none, all, one }

class Song {
  final String title;
  final String artist;
  final String assetPath;
  /// true when the song was picked from the device, not bundled as an asset
  final bool isUserAdded;

  const Song({
    required this.title,
    required this.artist,
    required this.assetPath,
    this.isUserAdded = false,
  });
}

class MusicPlayerService extends ChangeNotifier {
  MusicPlayerService._() {
    _player.onPlayerComplete.listen((_) => _autoPlayNext());
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });
    _player.onPositionChanged.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    _player.onDurationChanged.listen((dur) {
      _duration = dur;
      notifyListeners();
    });
  }

  static final instance = MusicPlayerService._();

  final AudioPlayer _player = AudioPlayer();
  Song? _currentSong;
  bool _isPlaying = false;
  int _currentIndex = 0;
  List<Song> _playlist = const [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  int get currentIndex => _currentIndex;
  List<Song> get playlist => List.unmodifiable(_playlist);
  Duration get position => _position;
  Duration get duration => _duration;
  double get progress =>
      _duration.inMilliseconds > 0
          ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

  static final _songs = <Song>[
    Song(
      title: 'Amazing God',
      artist: 'CCF Exalt Worship',
      assetPath: 'songs/Amazing God  Lyrics and Chords  CCF Exalt Worship.mp3',
    ),
    Song(
      title: 'By Your Love',
      artist: 'Exalt Worship',
      assetPath: 'songs/By Your Love  Lyric Video  Exalt Worship.mp3',
    ),
    Song(
      title: 'Goodness of God',
      artist: 'CeCe Winans',
      assetPath:
          'songs/CeCe Winans - Goodness of God  [Lyrics Gospel Songs] - Matt Redman, Gerald, Casting Crowns.mp3',
    ),
    Song(
      title: 'Goodness of God',
      artist: 'Hillsong Worship',
      assetPath:
          'songs/Goodness Of God - Hillsong Worship Songs, New Christian Worship Music 2025.mp3',
    ),
    Song(
      title: 'Into The Deep',
      artist: 'Citipointe Worship',
      assetPath:
          'songs/Into The Deep - Citipointe Worship  Chardon Lewis - Official Lyric Video.mp3',
    ),
    Song(
      title: 'Lord I Offer My Life',
      artist: 'Jessell Dawn Mahinay',
      assetPath: 'songs/Lord I Offer My LifeJessell Dawn Mahinay (Lyrics).mp3',
    ),
    Song(
      title: 'No Other Like Jesus',
      artist: 'CCF Exalt Worship',
      assetPath:
          'songs/No Other Like Jesus  Lyrics and Chords  CCF Exalt Worship.mp3',
    ),
    Song(
      title: 'One Way Jesus',
      artist: 'Hillsong',
      assetPath: 'songs/One Way Jesus (Lyrics)  Hillsong.mp3',
    ),
    Song(
      title: 'Pupurihin Ka Sa Awit',
      artist: 'Musikatha',
      assetPath: 'songs/Pupurihin Ka Sa Awit - Musikatha (Lyrics).mp3',
    ),
    Song(
      title: 'Trust In God',
      artist: 'Elevation Worship',
      assetPath:
          'songs/Trust In God (feat. Chris Brown)  Official Lyric Video  Elevation Worship.mp3',
    ),
    Song(
      title: 'Wala Kang Katulad',
      artist: 'Musikatha',
      assetPath: 'songs/WALA KANG KATULAD - Musikatha ( Lyric Video).mp3',
    ),
    Song(
      title: 'Worthy',
      artist: 'Elevation Worship',
      assetPath: 'songs/Worthy - Elevation Worship ( lyric video).mp3',
    ),
    Song(
      title: 'Worthy Is The Lamb',
      artist: 'Hillsong Chapel',
      assetPath: 'songs/Worthy Is The Lamb  Hillsong Chapel.mp3',
    ),
  ];

  static List<Song> get allSongs => List.unmodifiable(_songs);

  void addSong(Song song) {
    _songs.add(song);
    notifyListeners();
  }

  void removeSong(Song song) {
    _songs.remove(song);
    notifyListeners();
  }

  Future<void> playSong(Song song, int index, List<Song> playlist) async {
    _currentSong = song;
    _currentIndex = index;
    _playlist = playlist;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
    try {
      await _player.stop();
      if (song.isUserAdded) {
        // User-added song — play from device file path or URL
        if (kIsWeb) {
          await _player.play(UrlSource(song.assetPath));
        } else {
          await _player.play(DeviceFileSource(song.assetPath));
        }
      } else if (kIsWeb) {
        final byteData = await rootBundle.load(song.assetPath);
        final bytes = byteData.buffer.asUint8List();
        await _player.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
      } else {
        await _player.play(AssetSource(song.assetPath));
      }
    } catch (e) {
      debugPrint('MusicPlayerService: error playing ${song.assetPath}: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (_currentSong == null) return;
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.resume();
      }
    } catch (e) {
      debugPrint('MusicPlayerService: error toggling play/pause: $e');
    }
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  void _autoPlayNext() {
    if (_repeatMode == RepeatMode.one && _currentSong != null) {
      // Repeat the same song
      playSong(_currentSong!, _currentIndex, _playlist);
      return;
    }

    if (_shuffle && _playlist.length > 1) {
      final rng = DateTime.now().millisecondsSinceEpoch;
      int nextIdx;
      do {
        nextIdx = rng % _playlist.length;
      } while (nextIdx == _currentIndex && _playlist.length > 1);
      playSong(_playlist[nextIdx], nextIdx, _playlist);
      return;
    }

    if (_currentIndex < _playlist.length - 1) {
      playSong(_playlist[_currentIndex + 1], _currentIndex + 1, _playlist);
    } else if (_repeatMode == RepeatMode.all && _playlist.isNotEmpty) {
      // Wrap around to the beginning
      playSong(_playlist[0], 0, _playlist);
    } else {
      _isPlaying = false;
      notifyListeners();
    }
  }

  void playNext() {
    if (_playlist.isNotEmpty && _currentIndex < _playlist.length - 1) {
      playSong(_playlist[_currentIndex + 1], _currentIndex + 1, _playlist);
    }
  }

  void playPrevious() {
    if (_playlist.isNotEmpty && _currentIndex > 0) {
      playSong(_playlist[_currentIndex - 1], _currentIndex - 1, _playlist);
    }
  }

  // ── Playback speed ──
  double _speed = 1.0;
  double get speed => _speed;

  Future<void> setSpeed(double s) async {
    _speed = s.clamp(0.25, 2.0);
    await _player.setPlaybackRate(_speed);
    notifyListeners();
  }

  // ── Loop / Shuffle ──
  RepeatMode _repeatMode = RepeatMode.none;
  bool _shuffle = false;

  RepeatMode get repeatMode => _repeatMode;
  bool get isShuffling => _shuffle;

  void cycleRepeat() {
    switch (_repeatMode) {
      case RepeatMode.none:
        _repeatMode = RepeatMode.all;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
      case RepeatMode.one:
        _repeatMode = RepeatMode.none;
    }
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    notifyListeners();
  }

  // ── Favorites ──
  final Set<String> _favorites = {};
  Set<String> get favorites => Set.unmodifiable(_favorites);

  bool isFavorite(String title) => _favorites.contains(title);
  void toggleFavorite(String title) {
    if (_favorites.contains(title)) {
      _favorites.remove(title);
    } else {
      _favorites.add(title);
    }
    notifyListeners();
  }
}
