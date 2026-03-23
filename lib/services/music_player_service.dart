import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Song {
  final String title;
  final String artist;
  final String assetPath;

  const Song({
    required this.title,
    required this.artist,
    required this.assetPath,
  });
}

class MusicPlayerService extends ChangeNotifier {
  MusicPlayerService._() {
    _player.onPlayerComplete.listen((_) => _autoPlayNext());
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });
  }

  static final instance = MusicPlayerService._();

  final AudioPlayer _player = AudioPlayer();
  Song? _currentSong;
  bool _isPlaying = false;
  int _currentIndex = 0;
  List<Song> _playlist = const [];

  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  int get currentIndex => _currentIndex;

  static const allSongs = <Song>[
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

  Future<void> playSong(Song song, int index, List<Song> playlist) async {
    _currentSong = song;
    _currentIndex = index;
    _playlist = playlist;
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
