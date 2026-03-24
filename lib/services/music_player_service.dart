import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Song {
  final String title;
  final String artist;
  final String assetPath;
  /// Local asset path for album art, e.g. 'assets/album_art/ccf.jpg'.
  /// When null the UI shows a per-artist gradient placeholder.
  final String? albumArt;

  const Song({
    required this.title,
    required this.artist,
    required this.assetPath,
    this.albumArt,
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
  double _playbackRate = 1.0;

  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  int get currentIndex => _currentIndex;
  Duration get position => _position;
  Duration get duration => _duration;
  double get playbackRate => _playbackRate;

  static const allSongs = <Song>[
    Song(
      title: 'Amazing God',
      artist: 'CCF Exalt Worship',
      assetPath: 'songs/Amazing God  Lyrics and Chords  CCF Exalt Worship.mp3',
      albumArt: 'assets/album_art/ccf_exalt_worship.jpg',
    ),
    Song(
      title: 'By Your Love',
      artist: 'Exalt Worship',
      assetPath: 'songs/By Your Love  Lyric Video  Exalt Worship.mp3',
      albumArt: 'assets/album_art/exalt_worship.jpg',
    ),
    Song(
      title: 'Goodness of God',
      artist: 'CeCe Winans',
      assetPath: 'songs/CeCe Winans - Goodness of God  [Lyrics Gospel Songs] - Matt Redman, Gerald, Casting Crowns.mp3',
      albumArt: 'assets/album_art/cece_winans.jpg',
    ),
    Song(
      title: 'Goodness of God',
      artist: 'Hillsong Worship',
      assetPath: 'songs/Goodness Of God - Hillsong Worship Songs, New Christian Worship Music 2025.mp3',
      albumArt: 'assets/album_art/hillsong_worship.jpg',
    ),
    Song(
      title: 'Into The Deep',
      artist: 'Citipointe Worship',
      assetPath: 'songs/Into The Deep - Citipointe Worship  Chardon Lewis - Official Lyric Video.mp3',
      albumArt: 'assets/album_art/citipointe_worship.jpg',
    ),
    Song(
      title: 'Lord I Offer My Life',
      artist: 'Jessell Dawn Mahinay',
      assetPath: 'songs/Lord I Offer My LifeJessell Dawn Mahinay (Lyrics).mp3',
      albumArt: 'assets/album_art/jessell_dawn_mahinay.jpg',
    ),
    Song(
      title: 'No Other Like Jesus',
      artist: 'CCF Exalt Worship',
      assetPath: 'songs/No Other Like Jesus  Lyrics and Chords  CCF Exalt Worship.mp3',
      albumArt: 'assets/album_art/ccf_exalt_worship.jpg',
    ),
    Song(
      title: 'One Way Jesus',
      artist: 'Hillsong',
      assetPath: 'songs/One Way Jesus (Lyrics)  Hillsong.mp3',
      albumArt: 'assets/album_art/hillsong.jpg',
    ),
    Song(
      title: 'Pupurihin Ka Sa Awit',
      artist: 'Musikatha',
      assetPath: 'songs/Pupurihin Ka Sa Awit - Musikatha (Lyrics).mp3',
      albumArt: 'assets/album_art/musikatha.jpg',
    ),
    Song(
      title: 'Trust In God',
      artist: 'Elevation Worship',
      assetPath: 'songs/Trust In God (feat. Chris Brown)  Official Lyric Video  Elevation Worship.mp3',
      albumArt: 'assets/album_art/elevation_worship.jpg',
    ),
    Song(
      title: 'Wala Kang Katulad',
      artist: 'Musikatha',
      assetPath: 'songs/WALA KANG KATULAD - Musikatha ( Lyric Video).mp3',
      albumArt: 'assets/album_art/musikatha.jpg',
    ),
    Song(
      title: 'Worthy',
      artist: 'Elevation Worship',
      assetPath: 'songs/Worthy - Elevation Worship ( lyric video).mp3',
      albumArt: 'assets/album_art/elevation_worship.jpg',
    ),
    Song(
      title: 'Worthy Is The Lamb',
      artist: 'Hillsong Chapel',
      assetPath: 'songs/Worthy Is The Lamb  Hillsong Chapel.mp3',
      albumArt: 'assets/album_art/hillsong_chapel.jpg',
    ),
  ];

  Future<void> playSong(Song song, int index, List<Song> playlist) async {
    _currentSong = song;
    _currentIndex = index;
    _playlist = playlist;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
    try {
      await _player.stop();
      if (kIsWeb) {
        // Flutter's service worker does not handle HTTP range requests, so
        // the <audio> element fails with MEDIA_ERR_SRC_NOT_SUPPORTED (Code 4)
        // when using a URL source. Loading the bytes via rootBundle bypasses
        // the service worker entirely and creates a Blob URL instead.
        final byteData = await rootBundle.load(song.assetPath);
        final bytes = byteData.buffer.asUint8List();
        await _player.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
      } else {
        await _player.play(AssetSource(song.assetPath));
      }
      // Re-apply playback rate after each new song
      if (_playbackRate != 1.0) {
        await _player.setPlaybackRate(_playbackRate);
      }
    } catch (e) {
      debugPrint('MusicPlayerService: error playing ${song.assetPath}: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setPlaybackRate(double rate) async {
    _playbackRate = rate;
    try {
      await _player.setPlaybackRate(rate);
    } catch (e) {
      debugPrint('MusicPlayerService: error setting playback rate: $e');
    }
    notifyListeners();
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

  void _autoPlayNext() {
    if (_playlist.isNotEmpty && _currentIndex < _playlist.length - 1) {
      playSong(_playlist[_currentIndex + 1], _currentIndex + 1, _playlist);
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
}
