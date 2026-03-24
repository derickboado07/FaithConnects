// ─────────────────────────────────────────────────────────────────────────────
// MUSIC PLAYER SERVICE — Ang service na ito ang nag-ha-handle ng
// music playback sa app. Mga responsibilidad:
//   • Pag-play ng worship songs (bundled bilang assets)
//   • Play/Pause/Next/Previous controls
//   • Playlist management
//   • Pag-track ng current position at duration
//   • Auto-play next song kapag natapos ang current
//   • Support para sa user-added songs mula sa device
//
// Gumagamit ng audioplayers package para sa music playback.
// Extends ChangeNotifier para awtomatikong mag-update ang UI
// kapag nagbago ang state (playing, position, etc.).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum RepeatMode { none, all, one }

class Song {
  final String title;       // Pangalan ng song
  final String artist;      // Artist ng song
  final String assetPath;   // Path sa asset file o device file
  /// True kapag pinili ng user mula sa device niya, hindi bundled asset.
  final bool isUserAdded;

  const Song({
    required this.title,
    required this.artist,
    required this.assetPath,
    this.isUserAdded = false,
  });
}

/// Main music player service — extends ChangeNotifier para awtomatikong
/// mag-update ang UI kapag nagbago ang playing state, position, o duration.
/// Singleton pattern — isang instance lang (MusicPlayerService.instance).
class MusicPlayerService extends ChangeNotifier {
  // Private constructor — dito naka-setup ang mga listeners sa AudioPlayer.
  MusicPlayerService._() {
    // Kapag natapos ang current song, auto-play ang next.
    _player.onPlayerComplete.listen((_) => _autoPlayNext());
    // Kapag nagbago ang player state (playing/paused), i-update ang UI.
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });
    // Kapag nagbago ang current position ng song, i-update ang progress bar.
    _player.onPositionChanged.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    // Kapag na-determine na ang total duration ng song.
    _player.onDurationChanged.listen((dur) {
      _duration = dur;
      notifyListeners();
    });
  }

  static final instance = MusicPlayerService._(); // Singleton instance

  final AudioPlayer _player = AudioPlayer();  // AudioPlayer instance para sa playback
  Song? _currentSong;                          // Kasalukuyang pinapatugtog na song
  bool _isPlaying = false;                     // True kung tumutugtog ngayon
  int _currentIndex = 0;                       // Index ng current song sa playlist
  List<Song> _playlist = const [];             // Kasalukuyang playlist
  Duration _position = Duration.zero;           // Kasalukuyang position sa song
  Duration _duration = Duration.zero;           // Total duration ng song

  // Mga public getters para ma-access ng UI ang state.
  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  int get currentIndex => _currentIndex;
  List<Song> get playlist => List.unmodifiable(_playlist);
  Duration get position => _position;
  Duration get duration => _duration;
  // Progress value (0.0 to 1.0) para sa progress bar/slider.
  double get progress =>
      _duration.inMilliseconds > 0
          ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

  // Lista ng mga bundled worship songs na kasama sa app.
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

  static List<Song> get allSongs => List.unmodifiable(_songs); // Read-only copy ng songs

  /// Nagda-dagdag ng user-added song sa playlist.
  void addSong(Song song) {
    _songs.add(song);
    notifyListeners();
  }

  /// Tinatanggal ang isang song mula sa playlist.
  void removeSong(Song song) {
    _songs.remove(song);
    notifyListeners();
  }

  /// Nagpa-play ng specific song. Ini-set ang current song, index, at playlist.
  /// Nag-ha-handle ng both bundled assets at user-added (device) files.
  /// Sa web, ilo-load mula sa rootBundle bilang bytes.
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

  /// Toggle play/pause — kung tumutugtog, i-pause; kung naka-pause, i-resume.
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

  /// Mag-seek sa specific position sa song (ginagamit ng slider/progress bar).
  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  /// Auto-play ng next song kapag natapos ang current. Private method.
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

  /// Mag-play ng next song sa playlist (manual skip).
  void playNext() {
    if (_playlist.isNotEmpty && _currentIndex < _playlist.length - 1) {
      playSong(_playlist[_currentIndex + 1], _currentIndex + 1, _playlist);
    }
  }

  /// Mag-play ng previous song sa playlist.
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
