// ─────────────────────────────────────────────────────────────────────────────
// BIBLE SERVICE — Ang service na ito ang nag-ha-handle ng lahat ng
// Bible-related operations sa app tulad ng:
//   • Pag-load ng iba't ibang Bible translations (ASV, Ang Biblia, KJV, etc.)
//   • Pag-search ng mga verses
//   • Daily encouraging verse
//   • Pag-save at pag-highlight ng mga verses
//   • Bible notes at folders
//   • Heart/like system para sa daily verse
//
// Gumagamit ito ng local assets (SQL at JSON files) para sa Bible data
// at SharedPreferences para sa saved verses, highlights, at notes.
// Firestore ang gamit para sa daily verse heart counts.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL — BibleVerse
// Ito ang model class para sa isang Bible verse.
// Nag-ho-hold ng book, chapter, verse number, at text ng verse.
// ─────────────────────────────────────────────────────────────────────────────

class BibleVerse {
  final int id;        // Unique ID ng verse
  final int book;      // Book number (1-66)
  final int chapter;   // Chapter number
  final int verse;     // Verse number
  final String text;   // Ang mismong text ng verse
  final String language; // Language/version ID (e.g., 'en', 'tl', 'kjv')

  const BibleVerse({
    required this.id,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.language,
  });

  /// Kinukuha ang pangalan ng book base sa book number at language.
  String get bookName {
    final list = BibleService.bookNamesFor(language);
    if (book >= 1 && book <= list.length) return list[book - 1];
    return 'Book $book';
  }

  String get reference => '$bookName $chapter:$verse'; // Full reference (e.g., "Genesis 1:1")
  String get translationLabel => BibleService.translationLabelFor(language); // Label ng translation

  /// Tinatanggal ang MySQL paragraph marker mula sa verse text
  /// para malinis ang display sa UI.
  String get displayText =>
      text.replaceAll('\u00b6 ', '').replaceAll('\u00b6', '').trim();
}

/// Data model para sa Bible version info — nag-ho-hold ng metadata
/// tulad ng ID, label, asset path, at kung available ba ang version.
class BibleVersionInfo {
  const BibleVersionInfo({
    required this.id,
    required this.label,
    required this.assetPath,
    required this.assetType,
    this.usesTagalogBookNames = false,
    this.isAvailable = true,
    this.isPartial = false,
  });

  final String id;
  final String label;
  final String assetPath;
  final String assetType;
  final bool usesTagalogBookNames;
  final bool isAvailable;
  final bool isPartial;
}

// ─────────────────────────────────────────────────────────────────────────────
// BIBLE SERVICE CLASS
// In-memory, pure Dart service na gumagana sa LAHAT ng platforms (kasama Web).
// Singleton pattern — isang instance lang sa buong app (BibleService.instance).
//
// Ang Bible data ay naka-load sa memory mula sa local assets (SQL at JSON).
// Hindi gumagamit ng external database para sa Bible text mismo.
// ─────────────────────────────────────────────────────────────────────────────

class BibleService {
  // Private constructor at singleton instance.
  BibleService._();
  static final BibleService instance = BibleService._();

  // Naka-store sa memory ang mga parsed Bible verses.
  List<BibleVerse>? _en;  // English (ASV) translation
  List<BibleVerse>? _tl;  // Tagalog (Ang Biblia) translation
  // Map para sa mga extra/additional translations (KJV, NIV, etc.)
  final Map<String, List<BibleVerse>> _extraTranslations = {};
  // Registry ng lahat ng available Bible versions. Ang key ay ang version ID
  // (e.g., 'en', 'tl', 'kjv') at ang value ay ang BibleVersionInfo na may
  // metadata tungkol sa version (label, asset path, etc.).
  final Map<String, BibleVersionInfo> _versionRegistry = {
    'en': const BibleVersionInfo(
      id: 'en',
      label: 'ASV',
      assetPath: 'lib/Bible/EN-English/asv.sql',
      assetType: 'sql',
    ),
    'tl': const BibleVersionInfo(
      id: 'tl',
      label: 'Ang Biblia',
      assetPath: 'lib/Bible/TL-Wikang_Tagalog/tagab.sql',
      assetType: 'sql',
      usesTagalogBookNames: true,
    ),
    'amp': const BibleVersionInfo(
      id: 'amp',
      label: 'AMP',
      assetPath: 'lib/Bible/AMP/AMP_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'akjv': const BibleVersionInfo(
      id: 'akjv',
      label: 'AKJV',
      assetPath: 'lib/Bible/AKJV/AKJV_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'brg': const BibleVersionInfo(
      id: 'brg',
      label: 'BRG',
      assetPath: 'lib/Bible/BRG/BRG_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'csb': const BibleVersionInfo(
      id: 'csb',
      label: 'CSB',
      assetPath: 'lib/Bible/CSB/CSB_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'ehv': const BibleVersionInfo(
      id: 'ehv',
      label: 'EHV',
      assetPath: 'lib/Bible/EHV/EHV_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'esv': const BibleVersionInfo(
      id: 'esv',
      label: 'ESV',
      assetPath: 'lib/Bible/ESV/ESV_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'esvuk': const BibleVersionInfo(
      id: 'esvuk',
      label: 'ESVUK',
      assetPath: 'lib/Bible/ESVUK/ESVUK_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'gnv': const BibleVersionInfo(
      id: 'gnv',
      label: 'GNV',
      assetPath: 'lib/Bible/GNV/GNV_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'gw': const BibleVersionInfo(
      id: 'gw',
      label: 'GW',
      assetPath: 'lib/Bible/GW/GW_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'isv': const BibleVersionInfo(
      id: 'isv',
      label: 'ISV',
      assetPath: 'lib/Bible/ISV/ISV_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'jub': const BibleVersionInfo(
      id: 'jub',
      label: 'JUB',
      assetPath: 'lib/Bible/JUB/JUB_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'kjv': const BibleVersionInfo(
      id: 'kjv',
      label: 'KJV',
      assetPath: 'lib/Bible/KJV/KJV_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'kj21': const BibleVersionInfo(
      id: 'kj21',
      label: 'KJ21',
      assetPath: 'lib/Bible/KJ21/KJ21_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'leb': const BibleVersionInfo(
      id: 'leb',
      label: 'LEB',
      assetPath: 'lib/Bible/LEB/LEB_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'mev': const BibleVersionInfo(
      id: 'mev',
      label: 'MEV',
      assetPath: 'lib/Bible/MEV/MEV_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'nasb': const BibleVersionInfo(
      id: 'nasb',
      label: 'NASB',
      assetPath: 'lib/Bible/NASB/NASB_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'nasb1995': const BibleVersionInfo(
      id: 'nasb1995',
      label: 'NASB1995',
      assetPath: 'lib/Bible/NASB1995/NASB1995_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'net': const BibleVersionInfo(
      id: 'net',
      label: 'NET',
      assetPath: 'lib/Bible/NET/NET_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'niv': const BibleVersionInfo(
      id: 'niv',
      label: 'NIV',
      assetPath: 'lib/Bible/NIV/NIV_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'nivuk': const BibleVersionInfo(
      id: 'nivuk',
      label: 'NIVUK',
      assetPath: 'lib/Bible/NIVUK/NIVUK_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'nkjv': const BibleVersionInfo(
      id: 'nkjv',
      label: 'NKJV',
      assetPath: 'lib/Bible/NKJV/NKJV_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'nlt': const BibleVersionInfo(
      id: 'nlt',
      label: 'NLT',
      assetPath: 'lib/Bible/NLT/NLT_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'nlv': const BibleVersionInfo(
      id: 'nlv',
      label: 'NLV',
      assetPath: 'lib/Bible/NLV/NLV_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'nmb': const BibleVersionInfo(
      id: 'nmb',
      label: 'NMB*',
      assetPath: 'lib/Bible/NMB/NMB_bible.json',
      assetType: 'json',
      isAvailable: false,
      isPartial: true,
    ),
    'nog': const BibleVersionInfo(
      id: 'nog',
      label: 'NOG',
      assetPath: 'lib/Bible/NOG/NOG_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'nrsv': const BibleVersionInfo(
      id: 'nrsv',
      label: 'NRSV',
      assetPath: 'lib/Bible/NRSV/NRSV_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'nrsvue': const BibleVersionInfo(
      id: 'nrsvue',
      label: 'NRSVUE',
      assetPath: 'lib/Bible/NRSVUE/NRSVUE_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'web': const BibleVersionInfo(
      id: 'web',
      label: 'WEB',
      assetPath: 'lib/Bible/WEB/WEB_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'ylt': const BibleVersionInfo(
      id: 'ylt',
      label: 'YLT',
      assetPath: 'lib/Bible/YLT/YLT_bible.json',
      assetType: 'json',
      isAvailable: false,
    ),
    'rva': const BibleVersionInfo(
      id: 'rva',
      label: 'RVA*',
      assetPath: 'lib/Bible/RVA/RVA_bible.json',
      assetType: 'json',
      isAvailable: false,
      isPartial: true,
    ),
  };
  Future<void>? _initFuture;     // Cache para sa init() future — para hindi mag-load ulit
  Future<void>? _discoverFuture;  // Cache para sa discover versions future

  bool get isInitialized => _en != null || _tl != null; // True kung may naka-load na translation

  /// Kinukuha ang list ng book names depende sa version.
  /// Kung Tagalog, gagamitin ang tagalogBookNames. Kung English, bookNames.
  static List<String> bookNamesFor(String versionId) {
    return versionId == 'tl' ? tagalogBookNames : bookNames;
  }

  static bool isTagalogVersion(String versionId) => versionId == 'tl';

  static String translationLabelFor(String versionId) {
    if (versionId == 'tl') {
      return 'Ang Biblia';
    }
    if (versionId == 'en') {
      return 'ASV';
    }
    return versionId.toUpperCase();
  }

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

  // Tagalog book names (Genesis hanggang Apocalipsis)
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
  // Mga methods na magagamit ng ibang parts ng app.

  /// I-load ang English at Tagalog translations sa memory.
  /// Sa unang call, matatagalan kasi binabasa ang assets.
  /// Sa mga susunod na calls, instantly nag-re-return kasi naka-cache na.
  Future<void> init() {
    // Return cached future so concurrent callers all await the same work.
    // On error, the future is cleared so the next call retries.
    _initFuture ??= _doInit().catchError((dynamic e) {
      _initFuture = null; // allow retry
      throw e;
    });
    return _initFuture!;
  }

  /// Kinukuha ang list ng lahat ng available Bible versions na naka-discover
  /// na sa assets. Naka-sort by priority (English at Tagalog muna).
  Future<List<BibleVersionInfo>> getAvailableVersions({AssetBundle? bundle}) async {
    await _discoverVersions(bundle: bundle);
    final versions = _versionRegistry.values
        .where((v) => v.isAvailable && !v.isPartial)
        .toList()
      ..sort((a, b) {
        if (a.id == 'en') return -1;
        if (b.id == 'en') return 1;
        if (a.id == 'tl') return -1;
        if (b.id == 'tl') return 1;
        return a.label.compareTo(b.label);
      });
    return versions;
  }

  /// Sine-ensure na naka-load na ang specific Bible version sa memory.
  /// Kung hindi pa, ilo-load mula sa assets.
  Future<void> ensureVersionLoaded(String language, {AssetBundle? bundle}) async {
    await _discoverVersions(bundle: bundle);
    if (_versesFor(language) != null) {
      return;
    }
    if (language == 'en' || language == 'tl') {
      await init();
      return;
    }
    final info = _versionRegistry[language];
    if (info == null) {
      throw StateError('Unknown Bible version: $language');
    }
    if (info.assetType == 'json') {
      _extraTranslations[language] =
          await _loadJsonAsset(info.assetPath, language, bundle: bundle);
      return;
    }
    _extraTranslations[language] = await _loadAsset(info.assetPath, language);
  }

  // ── Curated encouraging verse references (book, chapter, verse) ────────────
  // These are well-known uplifting, comforting, and faith-building verses.
  static const List<List<int>> _encouragingRefs = [
    [23, 41, 10], // Isaiah 41:10
    [24, 29, 11], // Jeremiah 29:11
    [19, 23, 1],  // Psalms 23:1
    [19, 23, 4],  // Psalms 23:4
    [19, 46, 1],  // Psalms 46:1
    [19, 27, 1],  // Psalms 27:1
    [19, 34, 18], // Psalms 34:18
    [19, 37, 4],  // Psalms 37:4
    [19, 55, 22], // Psalms 55:22
    [19, 56, 3],  // Psalms 56:3
    [19, 91, 1],  // Psalms 91:1
    [19, 91, 2],  // Psalms 91:2
    [19, 118, 24],// Psalms 118:24
    [19, 119, 105],// Psalms 119:105
    [19, 121, 1], // Psalms 121:1
    [19, 121, 2], // Psalms 121:2
    [19, 138, 8], // Psalms 138:8
    [19, 139, 14],// Psalms 139:14
    [19, 145, 18],// Psalms 145:18
    [20, 3, 5],   // Proverbs 3:5
    [20, 3, 6],   // Proverbs 3:6
    [20, 18, 10], // Proverbs 18:10
    [23, 40, 31], // Isaiah 40:31
    [23, 43, 2],  // Isaiah 43:2
    [23, 54, 17], // Isaiah 54:17
    [24, 17, 7],  // Jeremiah 17:7
    [25, 3, 22],  // Lamentations 3:22
    [25, 3, 23],  // Lamentations 3:23
    [40, 5, 14],  // Matthew 5:14
    [40, 6, 33],  // Matthew 6:33
    [40, 6, 34],  // Matthew 6:34
    [40, 7, 7],   // Matthew 7:7
    [40, 11, 28], // Matthew 11:28
    [40, 11, 29], // Matthew 11:29
    [40, 17, 20], // Matthew 17:20
    [43, 3, 16],  // John 3:16
    [43, 8, 12],  // John 8:12
    [43, 10, 10], // John 10:10
    [43, 14, 1],  // John 14:1
    [43, 14, 27], // John 14:27
    [43, 15, 13], // John 15:13
    [43, 16, 33], // John 16:33
    [45, 5, 8],   // Romans 5:8
    [45, 8, 18],  // Romans 8:18
    [45, 8, 28],  // Romans 8:28
    [45, 8, 31],  // Romans 8:31
    [45, 8, 37],  // Romans 8:37
    [45, 8, 38],  // Romans 8:38
    [45, 8, 39],  // Romans 8:39
    [45, 12, 12], // Romans 12:12
    [45, 15, 13], // Romans 15:13
    [46, 10, 13], // 1 Corinthians 10:13
    [46, 16, 13], // 1 Corinthians 16:13
    [47, 4, 16],  // 2 Corinthians 4:16
    [47, 4, 17],  // 2 Corinthians 4:17
    [47, 5, 7],   // 2 Corinthians 5:7
    [47, 12, 9],  // 2 Corinthians 12:9
    [48, 6, 9],   // Galatians 6:9
    [49, 2, 10],  // Ephesians 2:10
    [49, 3, 20],  // Ephesians 3:20
    [49, 6, 10],  // Ephesians 6:10
    [50, 1, 6],   // Philippians 1:6
    [50, 4, 6],   // Philippians 4:6
    [50, 4, 7],   // Philippians 4:7
    [50, 4, 8],   // Philippians 4:8
    [50, 4, 13],  // Philippians 4:13
    [50, 4, 19],  // Philippians 4:19
    [51, 3, 23],  // Colossians 3:23
    [55, 1, 7],   // 2 Timothy 1:7
    [58, 4, 16],  // Hebrews 4:16
    [58, 10, 35], // Hebrews 10:35
    [58, 11, 1],  // Hebrews 11:1
    [58, 11, 6],  // Hebrews 11:6
    [58, 12, 1],  // Hebrews 12:1
    [58, 12, 2],  // Hebrews 12:2
    [58, 13, 5],  // Hebrews 13:5
    [58, 13, 6],  // Hebrews 13:6
    [59, 1, 2],   // James 1:2
    [59, 1, 3],   // James 1:3
    [59, 1, 5],   // James 1:5
    [59, 1, 12],  // James 1:12
    [59, 4, 8],   // James 4:8
    [60, 5, 7],   // 1 Peter 5:7
    [60, 5, 10],  // 1 Peter 5:10
    [62, 4, 4],   // 1 John 4:4
    [62, 4, 18],  // 1 John 4:18
    [62, 5, 14],  // 1 John 5:14
    [66, 3, 20],  // Revelation 3:20
    [66, 21, 4],  // Revelation 21:4
    [5, 31, 6],   // Deuteronomy 31:6
    [5, 31, 8],   // Deuteronomy 31:8
    [6, 1, 9],    // Joshua 1:9
    [4, 6, 24],   // Numbers 6:24
    [4, 6, 25],   // Numbers 6:25
    [4, 6, 26],   // Numbers 6:26
    [19, 30, 5],  // Psalms 30:5
    [19, 46, 10], // Psalms 46:10
    [19, 62, 1],  // Psalms 62:1
    [19, 73, 26], // Psalms 73:26
    [19, 94, 19], // Psalms 94:19
    [19, 147, 3], // Psalms 147:3
    [23, 26, 3],  // Isaiah 26:3
    [23, 41, 13], // Isaiah 41:13
    [33, 7, 8],   // Micah 7:8
    [36, 3, 17],  // Zephaniah 3:17
    [42, 1, 37],  // Luke 1:37
    [43, 1, 5],   // John 1:5
  ];

  /// Deterministic daily encouraging verse — nagbabago bawat araw.
  /// Pumipili mula sa curated list ng ~110 uplifting verses.
  /// Ang same verse ang makikita ng lahat ng users sa isang araw.
  Future<BibleVerse?> getDailyVerse({String language = 'en', AssetBundle? bundle}) async {
    await ensureVersionLoaded(language, bundle: bundle);
    final verses = _versesFor(language);
    if (verses == null || verses.isEmpty) return null;
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    final idx = (dayOfYear * 83 + now.year * 7) % _encouragingRefs.length;
    final ref = _encouragingRefs[idx];
    // Find exact match in loaded verses
    final match = verses.where(
      (v) => v.book == ref[0] && v.chapter == ref[1] && v.verse == ref[2],
    );
    if (match.isNotEmpty) return match.first;
    // Fallback: try next encouraging ref
    for (int i = 1; i < _encouragingRefs.length; i++) {
      final fallback = _encouragingRefs[(idx + i) % _encouragingRefs.length];
      final fb = verses.where(
        (v) => v.book == fallback[0] && v.chapter == fallback[1] && v.verse == fallback[2],
      );
      if (fb.isNotEmpty) return fb.first;
    }
    return null;
  }

  /// Nagha-hanap ng verses sa lahat ng books (o sa Old/New Testament lang).
  /// [testament]: 'ot' = Old Testament (books 1-39),
  ///              'nt' = New Testament (books 40-66),
  ///              null  = Lahat ng books.
  /// Case-insensitive ang search.
  Future<List<BibleVerse>> searchVerses(
    String query, {
    String language = 'en',
    String? testament, // 'ot' | 'nt' | null
    int limit = 200,
    AssetBundle? bundle,
  }) async {
    await ensureVersionLoaded(language, bundle: bundle);
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

  /// Kinukuha ang lahat ng verses sa isang specific book at chapter,
  /// naka-sort by verse number.
  Future<List<BibleVerse>> getChapterVerses(
    int book,
    int chapter, {
    String language = 'en',
    AssetBundle? bundle,
  }) async {
    await ensureVersionLoaded(language, bundle: bundle);
    final verses = _versesFor(language);
    if (verses == null) return [];
    return verses.where((v) => v.book == book && v.chapter == chapter).toList();
  }

  /// Kinukuha kung ilan ang chapters sa isang book.
  Future<int> getChapterCount(int book, {String language = 'en', AssetBundle? bundle}) async {
    await ensureVersionLoaded(language, bundle: bundle);
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

  /// Chine-check kung naka-save na ba ang isang verse.
  Future<bool> isVerseSaved(BibleVerse v) async {
    final keys = await _getSavedKeys();
    return keys.contains(_verseKey(v));
  }

  /// Sine-save ang isang verse sa favorites list.
  Future<void> saveVerse(BibleVerse v) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList(_savedPrefKey) ?? [];
    final key = _verseKey(v);
    if (!keys.contains(key)) {
      keys.add(key);
      await prefs.setStringList(_savedPrefKey, keys);
    }
  }

  /// Tinatanggal ang isang verse mula sa favorites list.
  Future<void> unsaveVerse(BibleVerse v) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList(_savedPrefKey) ?? [];
    keys.remove(_verseKey(v));
    await prefs.setStringList(_savedPrefKey, keys);
  }

  /// Kinukuha ang lahat ng saved verses para sa isang language/version.
  Future<List<BibleVerse>> getSavedVerses({String language = 'en', AssetBundle? bundle}) async {
    await ensureVersionLoaded(language, bundle: bundle);
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
  // Mga internal/private methods para sa pag-load at pag-parse ng Bible data.

  /// Kinukuha ang naka-load na verses para sa isang language/version.
  List<BibleVerse>? _versesFor(String language) {
    if (language == 'tl') {
      return _tl;
    }
    if (language == 'en') {
      return _en;
    }
    return _extraTranslations[language];
  }

  /// Dini-discover ang mga available Bible versions mula sa app assets.
  /// Hinahanap ang mga JSON files na naka-match sa pattern at iri-register.
  Future<void> _discoverVersions({AssetBundle? bundle}) {
    _discoverFuture ??= _doDiscoverVersions(bundle: bundle);
    return _discoverFuture!;
  }

  Future<void> _doDiscoverVersions({AssetBundle? bundle}) async {
    final assetBundle = bundle ?? rootBundle;
    final manifest = await AssetManifest.loadFromAssetBundle(assetBundle);
    final assetPaths = manifest.listAssets();
    final jsonRegex = RegExp(r'^lib/Bible/([^/]+)/([^/]+)_bible\.json$');
    for (final assetPath in assetPaths) {
      final match = jsonRegex.firstMatch(assetPath);
      if (match == null) {
        continue;
      }
      final rawId = match.group(2)!.toLowerCase();
      final existing = _versionRegistry[rawId];
      if (existing != null) {
        if (!existing.isAvailable) {
          _versionRegistry[rawId] = BibleVersionInfo(
            id: existing.id,
            label: existing.label,
            assetPath: assetPath,
            assetType: existing.assetType,
            usesTagalogBookNames: existing.usesTagalogBookNames,
            isAvailable: true,
            isPartial: existing.isPartial,
          );
        }
        continue;
      }
      _versionRegistry[rawId] = BibleVersionInfo(
        id: rawId,
        label: rawId.toUpperCase(),
        assetPath: assetPath,
        assetType: 'json',
        isAvailable: true,
      );
    }
  }

  /// Ilo-load ang English (ASV) at Tagalog (Ang Biblia) translations
  /// mula sa SQL asset files. Sabay-sabay (parallel) ang loading
  /// para mas mabilis.
  Future<void> _doInit() async {
    // Load both translations in parallel, with individual error handling.
    final results = await Future.wait([
      _loadAsset('lib/Bible/EN-English/asv.sql', 'en').catchError((dynamic _) => <BibleVerse>[]),
      _loadAsset('lib/Bible/TL-Wikang_Tagalog/tagab.sql', 'tl').catchError((dynamic _) => <BibleVerse>[]),
    ]);
    _en = results[0].isNotEmpty ? results[0] : null;
    _tl = results[1].isNotEmpty ? results[1] : null;
    // If English failed, don't block — other versions may still work.
    if (_en == null && _tl == null) {
      throw StateError(
        'Failed to load any Bible translation. '
        'Check that lib/Bible/EN-English/asv.sql and '
        'lib/Bible/TL-Wikang_Tagalog/tagab.sql are valid assets.',
      );
    }
  }

  /// Nag-lo-load ng SQL dump asset at pine-parse ang lahat ng INSERT rows.
  /// Nag-yi-yield sa event loop tuwing 500 lines para hindi mag-freeze ang UI.
  Future<List<BibleVerse>> _loadAsset(String assetPath, String language) async {
    final content = await rootBundle.loadString(assetPath);
    return _parseLines(content, language);
  }

  /// Nag-lo-load ng JSON Bible asset at kino-convert sa list ng BibleVerse.
  /// Ginagamit para sa mga extra translations (KJV, NIV, etc.)
  Future<List<BibleVerse>> _loadJsonAsset(
    String assetPath,
    String language, {
    AssetBundle? bundle,
  }) async {
    final content = await (bundle ?? rootBundle).loadString(assetPath);
    final decoded = json.decode(content) as Map<String, dynamic>;
    final result = <BibleVerse>[];
    var id = 1;
    for (var bookIndex = 0; bookIndex < bookNames.length; bookIndex++) {
      final bookName = bookNames[bookIndex];
      final chapters = _resolveJsonBook(decoded, bookName);
      if (chapters is! Map<String, dynamic>) {
        continue;
      }
      final chapterEntries = chapters.entries.toList()
        ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
      for (final chapterEntry in chapterEntries) {
        final chapter = int.tryParse(chapterEntry.key);
        if (chapter == null || chapterEntry.value is! Map<String, dynamic>) {
          continue;
        }
        final verses = chapterEntry.value as Map<String, dynamic>;
        final verseEntries = verses.entries.toList()
          ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
        for (final verseEntry in verseEntries) {
          final verse = int.tryParse(verseEntry.key);
          if (verse == null) {
            continue;
          }
          result.add(
            BibleVerse(
              id: id++,
              book: bookIndex + 1,
              chapter: chapter,
              verse: verse,
              text: verseEntry.value.toString().trim(),
              language: language,
            ),
          );
        }
      }
    }
    return result;
  }

  /// Helper na nagha-hanap ng book data sa JSON gamit ang book name.
  /// May support sa aliases (e.g., 'Psalms' -> 'Psalm', 'Song of Solomon' -> 'Song of Songs').
  dynamic _resolveJsonBook(Map<String, dynamic> decoded, String bookName) {
    final direct = decoded[bookName];
    if (direct != null) {
      return direct;
    }
    const aliases = {
      'Psalms': ['Psalm'],
      'Song of Solomon': ['Song Of Solomon', 'Song of Songs'],
      '1 Samuel': ['I Samuel'],
      '2 Samuel': ['II Samuel'],
      '1 Kings': ['I Kings'],
      '2 Kings': ['II Kings'],
      '1 Chronicles': ['I Chronicles'],
      '2 Chronicles': ['II Chronicles'],
      '1 Corinthians': ['I Corinthians'],
      '2 Corinthians': ['II Corinthians'],
      '1 Thessalonians': ['I Thessalonians'],
      '2 Thessalonians': ['II Thessalonians'],
      '1 Timothy': ['I Timothy'],
      '2 Timothy': ['II Timothy'],
      '1 Peter': ['I Peter'],
      '2 Peter': ['II Peter'],
      '1 John': ['I John'],
      '2 John': ['II John'],
      '3 John': ['III John'],
    };
    for (final alias in aliases[bookName] ?? const <String>[]) {
      final value = decoded[alias];
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  /// Pine-parse ang SQL content line by line para i-extract ang Bible verses.
  /// Hinahanap ang INSERT statements at kino-convert sa BibleVerse objects.
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

  // ── Daily Verse Heart Count (Firestore) ──────────────────────────────────
  // Stored in Firestore: daily_verse_hearts/{date}
  // Document has: { hearts: int, users: [uid, ...] }

  static final _firestore = FirebaseFirestore.instance;

  String _dailyVerseDocId() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Real-time stream ng heart count para sa daily verse ngayong araw.
  Stream<int> dailyVerseHeartCountStream() {
    final docId = _dailyVerseDocId();
    return _firestore
        .collection('daily_verse_hearts')
        .doc(docId)
        .snapshots()
        .map((snap) => (snap.data()?['hearts'] as int?) ?? 0);
  }

  /// Chine-check kung nag-heart na ba ang user sa daily verse ngayong araw.
  Future<bool> hasUserHeartedDailyVerse(String uid) async {
    final docId = _dailyVerseDocId();
    final snap =
        await _firestore.collection('daily_verse_hearts').doc(docId).get();
    final users = List<String>.from(snap.data()?['users'] ?? []);
    return users.contains(uid);
  }

  /// Toggle heart para sa daily verse ngayong araw.
  /// Kung nag-heart na, ita-tanggal. Kung hindi pa, ila-lagay.
  /// Returns true kung nag-heart, false kung inalis.
  Future<bool> toggleDailyVerseHeart(String uid) async {
    final docId = _dailyVerseDocId();
    final ref = _firestore.collection('daily_verse_hearts').doc(docId);
    return _firestore.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {'hearts': 0, 'users': []};
      final users = List<String>.from(data['users'] ?? []);
      int hearts = (data['hearts'] as int?) ?? 0;
      if (users.contains(uid)) {
        users.remove(uid);
        hearts = (hearts - 1).clamp(0, 999999);
        tx.set(ref, {'hearts': hearts, 'users': users});
        return false;
      } else {
        users.add(uid);
        hearts += 1;
        tx.set(ref, {'hearts': hearts, 'users': users});
        return true;
      }
    });
  }

  // ── Verse Highlights (SharedPreferences) ─────────────────────────────────
  // Key format: "highlight_<lang>_<book>_<chapter>_<verse>" → color hex string

  static const _highlightPrefix = 'highlight_';

  String _highlightKey(String lang, int book, int chapter, int verse) =>
      '$_highlightPrefix${lang}_${book}_${chapter}_$verse';

  /// Kinukuha ang lahat ng highlights sa isang chapter.
  /// Returns map ng verseNum → colorHex.
  Future<Map<int, String>> getChapterHighlights(
    int book, int chapter, {String language = 'en',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '${_highlightPrefix}${language}_${book}_${chapter}_';
    final result = <int, String>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(prefix)) {
        final verseNum = int.tryParse(key.substring(prefix.length));
        if (verseNum != null) {
          result[verseNum] = prefs.getString(key) ?? '';
        }
      }
    }
    return result;
  }

  /// Ini-set o ini-update ang highlight color ng isang verse.
  Future<void> highlightVerse(
    int book, int chapter, int verse, String colorHex, {String language = 'en',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_highlightKey(language, book, chapter, verse), colorHex);
  }

  /// Tinatanggal ang highlight mula sa isang verse.
  Future<void> removeHighlight(
    int book, int chapter, int verse, {String language = 'en',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_highlightKey(language, book, chapter, verse));
  }

  /// Kinukuha ang lahat ng highlighted verses sa lahat ng chapters.
  Future<List<Map<String, dynamic>>> getAllHighlights({String language = 'en', AssetBundle? bundle}) async {
    await ensureVersionLoaded(language, bundle: bundle);
    final prefs = await SharedPreferences.getInstance();
    final prefix = '${_highlightPrefix}${language}_';
    final results = <Map<String, dynamic>>[];
    final verses = _versesFor(language) ?? [];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final parts = key.substring(prefix.length).split('_');
      if (parts.length != 3) continue;
      final book = int.tryParse(parts[0]);
      final chapter = int.tryParse(parts[1]);
      final verse = int.tryParse(parts[2]);
      if (book == null || chapter == null || verse == null) continue;
      final colorHex = prefs.getString(key) ?? '';
      final match = verses.where(
        (v) => v.book == book && v.chapter == chapter && v.verse == verse,
      );
      if (match.isNotEmpty) {
        results.add({
          'verse': match.first,
          'color': colorHex,
        });
      }
    }
    return results;
  }

  // ── Bible Notes (SharedPreferences, JSON) ────────────────────────────────
  // Notes are stored as a JSON string in SharedPreferences.
  // Structure: List of { id, title, content, folder, createdAt, verseRef }

  static const _notesPrefKey = 'bible_notes';
  static const _foldersPrefKey = 'bible_note_folders';

  /// Kinukuha ang lahat ng Bible notes ng user.
  Future<List<Map<String, dynamic>>> getNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notesPrefKey);
    if (raw == null || raw.isEmpty) return [];
    return List<Map<String, dynamic>>.from(json.decode(raw));
  }

  Future<void> _saveNotes(List<Map<String, dynamic>> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notesPrefKey, json.encode(notes));
  }

  /// Nag-da-dagdag ng bagong Bible note.
  Future<void> addNote({
    required String title,
    required String content,
    String folder = 'General',
    String? verseRef,
  }) async {
    final notes = await getNotes();
    notes.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'content': content,
      'folder': folder,
      'createdAt': DateTime.now().toIso8601String(),
      'verseRef': verseRef ?? '',
    });
    await _saveNotes(notes);
  }

  /// Ini-update ang existing Bible note (title, content, o folder).
  Future<void> updateNote(String id, {String? title, String? content, String? folder}) async {
    final notes = await getNotes();
    final idx = notes.indexWhere((n) => n['id'] == id);
    if (idx == -1) return;
    if (title != null) notes[idx]['title'] = title;
    if (content != null) notes[idx]['content'] = content;
    if (folder != null) notes[idx]['folder'] = folder;
    await _saveNotes(notes);
  }

  /// Tinatanggal ang isang Bible note.
  Future<void> deleteNote(String id) async {
    final notes = await getNotes();
    notes.removeWhere((n) => n['id'] == id);
    await _saveNotes(notes);
  }

  // ── Note Folders ──────────────────────────────────────────────────────────
  // Para sa pag-organize ng Bible notes sa mga folders.

  /// Kinukuha ang lahat ng note folders. Default ay 'General'.
  Future<List<String>> getNoteFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final folders = prefs.getStringList(_foldersPrefKey);
    if (folders == null || folders.isEmpty) return ['General'];
    return folders;
  }

  /// Nag-da-dagdag ng bagong note folder.
  Future<void> addNoteFolder(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final folders = prefs.getStringList(_foldersPrefKey) ?? ['General'];
    if (!folders.contains(name)) {
      folders.add(name);
      await prefs.setStringList(_foldersPrefKey, folders);
    }
  }

  /// Tinatanggal ang isang note folder. Ang mga notes sa deleted folder
  /// ay imo-move sa 'General' folder. Hindi pwedeng i-delete ang 'General'.
  Future<void> deleteNoteFolder(String name) async {
    if (name == 'General') return; // can't delete default
    final prefs = await SharedPreferences.getInstance();
    final folders = prefs.getStringList(_foldersPrefKey) ?? ['General'];
    folders.remove(name);
    await prefs.setStringList(_foldersPrefKey, folders);
    // Move notes in deleted folder to General
    final notes = await getNotes();
    for (final n in notes) {
      if (n['folder'] == name) n['folder'] = 'General';
    }
    await _saveNotes(notes);
  }

  /// Nire-rename ang isang note folder. Hindi pwedeng i-rename ang 'General'.
  /// Awtomatikong inu-update ang folder name sa lahat ng notes na nandoon.
  Future<void> renameNoteFolder(String oldName, String newName) async {
    if (oldName == 'General') return;
    final prefs = await SharedPreferences.getInstance();
    final folders = prefs.getStringList(_foldersPrefKey) ?? ['General'];
    final idx = folders.indexOf(oldName);
    if (idx != -1) {
      folders[idx] = newName;
      await prefs.setStringList(_foldersPrefKey, folders);
    }
    // Update notes in the folder
    final notes = await getNotes();
    for (final n in notes) {
      if (n['folder'] == oldName) n['folder'] = newName;
    }
    await _saveNotes(notes);
  }
}
