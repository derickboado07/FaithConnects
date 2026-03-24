import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MetronomeService extends ChangeNotifier {
  MetronomeService._();
  static final instance = MetronomeService._();

  // Use a pool of players to handle rapid successive clicks without overlap issues.
  static const _poolSize = 4;
  final List<AudioPlayer> _pool =
      List.generate(_poolSize, (_) => AudioPlayer());
  int _poolIdx = 0;

  int _bpm = 120;
  int _beatsPerMeasure = 4;
  int _noteValue = 4;
  bool _isPlaying = false;
  int _currentBeat = 0;
  Timer? _timer;

  // Cached sources
  Source? _clickSrc;
  Source? _accentSrc;

  int get bpm => _bpm;
  int get beatsPerMeasure => _beatsPerMeasure;
  int get noteValue => _noteValue;
  bool get isPlaying => _isPlaying;
  int get currentBeat => _currentBeat;

  void setBpm(int v) {
    _bpm = v.clamp(30, 300);
    if (_isPlaying) _restart();
    notifyListeners();
  }

  void setTimeSignature(int beats, int note) {
    _beatsPerMeasure = beats;
    _noteValue = note;
    _currentBeat = 0;
    notifyListeners();
  }

  void tapTempo(List<DateTime> taps) {
    if (taps.length < 2) return;
    int total = 0;
    int count = 0;
    final recent = taps.length > 6 ? taps.sublist(taps.length - 6) : taps;
    for (int i = 1; i < recent.length; i++) {
      total += recent[i].difference(recent[i - 1]).inMilliseconds;
      count++;
    }
    if (count > 0 && total > 0) {
      setBpm((60000 / (total / count)).round().clamp(30, 300));
    }
  }

  void toggle() => _isPlaying ? stop() : start();

  void start() {
    _buildSources();
    _isPlaying = true;
    _currentBeat = 0;
    _tick();
    _startTimer();
    notifyListeners();
  }

  void stop() {
    _isPlaying = false;
    _timer?.cancel();
    _timer = null;
    _currentBeat = 0;
    for (final p in _pool) {
      p.stop();
    }
    notifyListeners();
  }

  void _restart() {
    _timer?.cancel();
    _startTimer();
  }

  void _startTimer() {
    final ms = (60000.0 / _bpm).round();
    _timer = Timer.periodic(Duration(milliseconds: ms), (_) => _tick());
  }

  void _tick() {
    _currentBeat++;
    if (_currentBeat > _beatsPerMeasure) _currentBeat = 1;
    _playClick(_currentBeat == 1);
    notifyListeners();
  }

  /// Build audio sources once. On web, BytesSource is not reliable so we use
  /// a base64 data-URI via UrlSource. On native, BytesSource works fine.
  void _buildSources() {
    if (_clickSrc != null) return;
    final clickWav = _genWav(880.0, 25, 0.7);
    final accentWav = _genWav(1320.0, 30, 0.9);

    if (kIsWeb) {
      // Encode as data URIs that WebAudio can decode
      final clickB64 = base64Encode(clickWav);
      final accentB64 = base64Encode(accentWav);
      _clickSrc = UrlSource('data:audio/wav;base64,$clickB64');
      _accentSrc = UrlSource('data:audio/wav;base64,$accentB64');
    } else {
      _clickSrc = BytesSource(clickWav, mimeType: 'audio/wav');
      _accentSrc = BytesSource(accentWav, mimeType: 'audio/wav');
    }
  }

  void _playClick(bool accent) {
    final src = accent ? _accentSrc : _clickSrc;
    if (src == null) {
      HapticFeedback.lightImpact();
      return;
    }
    try {
      // Round-robin through the player pool to avoid single-player contention
      final player = _pool[_poolIdx % _poolSize];
      _poolIdx++;
      player.play(src);
    } catch (_) {
      HapticFeedback.lightImpact();
    }
  }

  /// Generate a short sine-wave WAV click in memory.
  Uint8List _genWav(double freq, int ms, double vol) {
    const sr = 44100;
    final n = (sr * ms / 1000).round();
    final data = ByteData(44 + n * 2);
    _w(data, 0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    _w(data, 8, 'WAVE');
    _w(data, 12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, sr, Endian.little);
    data.setUint32(28, sr * 2, Endian.little); // byte rate
    data.setUint16(32, 2, Endian.little);  // block align
    data.setUint16(34, 16, Endian.little); // bits per sample
    _w(data, 36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final t = i / sr;
      final env = 1.0 - (i / n); // linear decay
      final s = (sin(2 * pi * freq * t) * 32767 * env * vol)
          .round()
          .clamp(-32768, 32767);
      data.setInt16(44 + i * 2, s, Endian.little);
    }
    return data.buffer.asUint8List();
  }

  void _w(ByteData d, int o, String s) {
    for (int i = 0; i < s.length; i++) {
      d.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final p in _pool) {
      p.dispose();
    }
    super.dispose();
  }
}
