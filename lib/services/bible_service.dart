import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class BibleVerse {
  final int id;
  final int book;
  final int chapter;
  final int verse;
  final String text;
  final String language;

  const BibleVerse({
    required this.id,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.language,
  });

  String get bookName {
    final list = language == 'tl'
        ? BibleService.tagalogBookNames
        : BibleService.bookNames;
    if (book >= 1 && book <= list.length) return list[book - 1];
    return 'Book $book';
  }

  String get reference => '$bookName $chapter:$verse';
  String get translationLabel => language == 'tl' ? 'Ang Biblia' : 'ASV';

  /// Strip MySQL paragraph marker.
  String get displayText =>
      text.replaceAll('\u00b6 ', '').replaceAll('\u00b6', '').trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE  (in-memory, pure Dart, works on ALL platforms including Web)
// ─────────────────────────────────────────────────────────────────────────────

class BibleService {
  BibleService._();
  static final BibleService instance = BibleService._();

  List<BibleVerse>? _en;
  List<BibleVerse>? _tl;
  Future<void>? _initFuture;

  bool get isInitialized => _en != null && _tl != null;

  // ── Book name tables ────────────────────────────────────────────────────────
  static const List<String> bookNames = [
    'Genesis',
    'Exodus',
    'Leviticus',
    'Numbers',
    'Deuteronomy',
    'Joshua',
    'Judges',
    'Ruth',
    '1 Samuel',
    '2 Samuel',
    '1 Kings',
    '2 Kings',
    '1 Chronicles',
    '2 Chronicles',
    'Ezra',
    'Nehemiah',
    'Esther',
    'Job',
    'Psalms',
    'Proverbs',
    'Ecclesiastes',
    'Song of Solomon',
    'Isaiah',
    'Jeremiah',
    'Lamentations',
    'Ezekiel',
    'Daniel',
    'Hosea',
    'Joel',
    'Amos',
    'Obadiah',
    'Jonah',
    'Micah',
    'Nahum',
    'Habakkuk',
    'Zephaniah',
    'Haggai',
    'Zechariah',
    'Malachi',
    'Matthew',
    'Mark',
    'Luke',
    'John',
    'Acts',
    'Romans',
    '1 Corinthians',
    '2 Corinthians',
    'Galatians',
    'Ephesians',
    'Philippians',
    'Colossians',
    '1 Thessalonians',
    '2 Thessalonians',
    '1 Timothy',
    '2 Timothy',
    'Titus',
    'Philemon',
    'Hebrews',
    'James',
    '1 Peter',
    '2 Peter',
    '1 John',
    '2 John',
    '3 John',
    'Jude',
    'Revelation',
  ];

  static const List<String> tagalogBookNames = [
    'Genesis',
    'Exodo',
    'Levitico',
    'Mga Bilang',
    'Deuteronomio',
    'Josue',
    'Mga Hukom',
    'Ruth',
    '1 Samuel',
    '2 Samuel',
    '1 Mga Hari',
    '2 Mga Hari',
    '1 Mga Cronica',
    '2 Mga Cronica',
    'Ezra',
    'Nehemias',
    'Esther',
    'Job',
    'Mga Awit',
    'Mga Kawikaan',
    'Eclesiastes',
    'Awit ng mga Awit',
    'Isaias',
    'Jeremias',
    'Panaghoy',
    'Ezekiel',
    'Daniel',
    'Oseas',
    'Joel',
    'Amos',
    'Abdias',
    'Jonas',
    'Micheas',
    'Nahum',
    'Habacuc',
    'Sofonias',
    'Hageo',
    'Zacharias',
    'Malaquias',
    'Mateo',
    'Marcos',
    'Lucas',
    'Juan',
    'Mga Gawa',
    'Mga Romano',
    '1 Mga Corinto',
    '2 Mga Corinto',
    'Mga Galacia',
    'Mga Efeso',
    'Mga Filipos',
    'Mga Colosas',
    '1 Mga Tesalonica',
    '2 Mga Tesalonica',
    '1 Timoteo',
    '2 Timoteo',
    'Tito',
    'Filemon',
    'Mga Hebreo',
    'Santiago',
    '1 Pedro',
    '2 Pedro',
    '1 Juan',
    '2 Juan',
    '3 Juan',
    'Judas',
    'Apocalipsis',
  ];

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Load both translation assets into memory.
  /// On first call this may take a few seconds; subsequent calls return instantly.
  Future<void> init() {
    // Return cached future so concurrent callers all await the same work.
    // On error, the future is cleared so the next call retries.
    _initFuture ??= _doInit().catchError((dynamic e) {
      _initFuture = null; // allow retry
      throw e;
    });
    return _initFuture!;
  }

  /// Deterministic daily verse — changes each calendar day.
  Future<BibleVerse?> getDailyVerse({String language = 'en'}) async {
    await init();
    final verses = _versesFor(language);
    if (verses == null || verses.isEmpty) return null;
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    final idx = (dayOfYear * 83 + now.year * 7) % verses.length;
    return verses[idx];
  }

  /// Search verses across all books (or within a Testament filter).
  /// [testament]: 'ot' = Old Testament (books 1-39),
  ///              'nt' = New Testament (books 40-66),
  ///              null  = All books.
  Future<List<BibleVerse>> searchVerses(
    String query, {
    String language = 'en',
    String? testament, // 'ot' | 'nt' | null
    int limit = 200,
  }) async {
    await init();
    final verses = _versesFor(language);
    if (verses == null || query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    final results = <BibleVerse>[];
    for (final v in verses) {
      if (testament == 'ot' && v.book > 39) continue;
      if (testament == 'nt' && v.book <= 39) continue;
      if (v.displayText.toLowerCase().contains(q) ||
          v.reference.toLowerCase().contains(q)) {
        results.add(v);
        if (results.length >= limit) break;
      }
    }
    return results;
  }

  /// All verses in a given book / chapter, sorted by verse number.
  Future<List<BibleVerse>> getChapterVerses(
    int book,
    int chapter, {
    String language = 'en',
  }) async {
    await init();
    final verses = _versesFor(language);
    if (verses == null) return [];
    return verses.where((v) => v.book == book && v.chapter == chapter).toList();
  }

  /// Number of chapters in a book.
  Future<int> getChapterCount(int book, {String language = 'en'}) async {
    await init();
    final verses = _versesFor(language);
    if (verses == null) return 1;
    int max = 0;
    for (final v in verses) {
      if (v.book == book && v.chapter > max) max = v.chapter;
    }
    return max > 0 ? max : 1;
  }

  // ── Saved Verses ────────────────────────────────────────────────────────────
  // Keys are stored as "<lang>|<book>|<chapter>|<verse>" in SharedPreferences.

  static const _savedPrefKey = 'saved_bible_verses';

  Future<List<String>> _getSavedKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_savedPrefKey) ?? [];
  }

  String _verseKey(BibleVerse v) =>
      '${v.language}|${v.book}|${v.chapter}|${v.verse}';

  Future<bool> isVerseSaved(BibleVerse v) async {
    final keys = await _getSavedKeys();
    return keys.contains(_verseKey(v));
  }

  Future<void> saveVerse(BibleVerse v) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList(_savedPrefKey) ?? [];
    final key = _verseKey(v);
    if (!keys.contains(key)) {
      keys.add(key);
      await prefs.setStringList(_savedPrefKey, keys);
    }
  }

  Future<void> unsaveVerse(BibleVerse v) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList(_savedPrefKey) ?? [];
    keys.remove(_verseKey(v));
    await prefs.setStringList(_savedPrefKey, keys);
  }

  Future<List<BibleVerse>> getSavedVerses({String language = 'en'}) async {
    await init();
    final keys = await _getSavedKeys();
    final verses = _versesFor(language) ?? [];
    final results = <BibleVerse>[];
    for (final k in keys) {
      final parts = k.split('|');
      if (parts.length < 4) continue;
      final lang = parts[0];
      if (lang != language) continue;
      final book = int.tryParse(parts[1]);
      final chapter = int.tryParse(parts[2]);
      final verse = int.tryParse(parts[3]);
      if (book == null || chapter == null || verse == null) continue;
      final match = verses.where(
        (v) => v.book == book && v.chapter == chapter && v.verse == verse,
      );
      if (match.isNotEmpty) results.add(match.first);
    }
    return results;
  }

  // ── Internals ───────────────────────────────────────────────────────────────

  List<BibleVerse>? _versesFor(String language) => language == 'tl' ? _tl : _en;

  Future<void> _doInit() async {
    // Load both translation in parallel.
    final results = await Future.wait([
      _loadAsset('lib/Bible/EN-English/asv.sql', 'en'),
      _loadAsset('lib/Bible/TL-Wikang_Tagalog/tagab.sql', 'tl'),
    ]);
    _en = results[0];
    _tl = results[1];
  }

  /// Load a SQL dump asset and parse all INSERT rows.
  /// Yields to the event loop every 500 lines so the UI stays responsive.
  Future<List<BibleVerse>> _loadAsset(String assetPath, String language) async {
    final content = await rootBundle.loadString(assetPath);
    return _parseLines(content, language);
  }

  Future<List<BibleVerse>> _parseLines(String content, String language) async {
    // Matches: VALUES ('id', 'book', 'chapter', 'verse', 'text');
    final re = RegExp(
      r"VALUES \('(\d+)', '(\d+)', '(\d+)', '(\d+)', '(.+)'\);",
    );
    final lines = content.split('\n');
    final result = <BibleVerse>[];

    for (int i = 0; i < lines.length; i++) {
      final l = lines[i].trim();
      if (l.startsWith('INSERT')) {
        final m = re.firstMatch(l);
        if (m != null) {
          result.add(
            BibleVerse(
              id: int.parse(m.group(1)!),
              book: int.parse(m.group(2)!),
              chapter: int.parse(m.group(3)!),
              verse: int.parse(m.group(4)!),
              text: m.group(5)!.replaceAll(r"\'", "'"),
              language: language,
            ),
          );
        }
      }
      // Yield to event loop every 500 lines – keeps the spinner animated.
      if (i % 500 == 0) await Future.delayed(Duration.zero);
    }
    return result;
  }
}
