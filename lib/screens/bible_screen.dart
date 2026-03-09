import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/bible_service.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BIBLE SCREEN  (Book list → Chapter grid → Verse reader)
// ─────────────────────────────────────────────────────────────────────────────

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  String _language = 'en';
  bool _loading = true;
  String? _error;
  String _bookListFilter = 'all';

  // Search state
  bool _searchActive = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _testamentFilter = 'all'; // 'all' | 'ot' | 'nt'
  List<BibleVerse>? _searchResults;
  bool _searching = false;

  static const _gold = Color(0xFFD4AF37);
  static const _bg = Color(0xFF1A1A2E);
  static const _card = Color(0xFF16213E);
  static const _border = Color(0xFF2D2D44);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await BibleService.instance.init();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _toggleLanguage() =>
      setState(() => _language = _language == 'en' ? 'tl' : 'en');

  void _openSearch() => setState(() {
    _searchActive = true;
    _searchResults = null;
    _searchCtrl.clear();
  });

  void _closeSearch() => setState(() {
    _searchActive = false;
    _searchResults = null;
    _searching = false;
    _searchCtrl.clear();
  });

  Future<void> _runSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final results = await BibleService.instance.searchVerses(
      q,
      language: _language,
      testament: _testamentFilter == 'all' ? null : _testamentFilter,
    );
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_searchActive) _buildSearchBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: Row(
        children: [
          if (_searchActive)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _closeSearch,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            const Text(
              'Bible',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          const Spacer(),
          if (!_searchActive) ...[
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white70),
              onPressed: _loading ? null : _openSearch,
              tooltip: 'Search verses',
            ),
            const SizedBox(width: 4),
          ],
          _LangToggle(current: _language, onToggle: _toggleLanguage),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: _language == 'tl'
                  ? 'Hanapin ang talata o salita…'
                  : 'Search verses or keywords…',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white38,
                size: 20,
              ),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white38,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchResults = null);
                      },
                    )
                  : null,
              filled: true,
              fillColor: _bg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) {
              setState(() {});
              _runSearch(v);
            },
            onSubmitted: _runSearch,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: _language == 'tl' ? 'Lahat' : 'All Books',
                  selected: _testamentFilter == 'all',
                  onTap: () {
                    setState(() => _testamentFilter = 'all');
                    _runSearch(_searchCtrl.text);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: _language == 'tl' ? 'Lumang Tipan' : 'Old Testament',
                  selected: _testamentFilter == 'ot',
                  onTap: () {
                    setState(() => _testamentFilter = 'ot');
                    _runSearch(_searchCtrl.text);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: _language == 'tl' ? 'Bagong Tipan' : 'New Testament',
                  selected: _testamentFilter == 'nt',
                  onTap: () {
                    setState(() => _testamentFilter = 'nt');
                    _runSearch(_searchCtrl.text);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _gold),
            const SizedBox(height: 20),
            Text(
              BibleService.instance.isInitialized
                  ? 'Loading…'
                  : _language == 'tl'
                  ? 'Nilo-load ang Biblia…\n(Unang beses lang ito)'
                  : 'Building Bible database…\n(First launch only)',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 52,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load Bible',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _init,
              ),
            ],
          ),
        ),
      );
    }

    if (_searchActive) {
      if (_searching) {
        return const Center(child: CircularProgressIndicator(color: _gold));
      }
      if (_searchResults == null) {
        return Center(
          child: Text(
            _language == 'tl'
                ? 'I-type ang salita o talata upang hanapin.'
                : 'Type a word or verse reference to search.',
            style: const TextStyle(color: Colors.white38, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        );
      }
      if (_searchResults!.isEmpty) {
        return Center(
          child: Text(
            _language == 'tl' ? 'Walang nahanap.' : 'No results found.',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        );
      }
      return _SearchResultsView(results: _searchResults!, language: _language);
    }

    return _BookListView(
      language: _language,
      selectedTestament: _bookListFilter,
      onChanged: (value) => setState(() => _bookListFilter = value),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search results list
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResultsView extends StatelessWidget {
  final List<BibleVerse> results;
  final String language;
  const _SearchResultsView({required this.results, required this.language});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      itemCount: results.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
              '${results.length} result${results.length == 1 ? '' : 's'}',
              style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12),
            ),
          );
        }
        final v = results[i - 1];
        return _SearchVerseTile(verse: v);
      },
    );
  }
}

class _SearchVerseTile extends StatelessWidget {
  final BibleVerse verse;
  const _SearchVerseTile({required this.verse});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showVerseActions(context, verse),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    verse.reference,
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _VerseActionButtons(verse: verse),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              verse.displayText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Book list (66 books split into OT / NT)
// ─────────────────────────────────────────────────────────────────────────────

class _BookListView extends StatelessWidget {
  final String language;
  final String selectedTestament;
  final ValueChanged<String> onChanged;

  const _BookListView({
    required this.language,
    required this.selectedTestament,
    required this.onChanged,
  });

  static const int _otCount = 39;

  @override
  Widget build(BuildContext context) {
    final names = language == 'tl'
        ? BibleService.tagalogBookNames
        : BibleService.bookNames;

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: language == 'tl' ? 'Lahat ng Aklat' : 'All Books',
                  selected: selectedTestament == 'all',
                  onTap: () => onChanged('all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: language == 'tl' ? 'Lumang Tipan' : 'Old Testament',
                  selected: selectedTestament == 'ot',
                  onTap: () => onChanged('ot'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: language == 'tl' ? 'Bagong Tipan' : 'New Testament',
                  selected: selectedTestament == 'nt',
                  onTap: () => onChanged('nt'),
                ),
              ],
            ),
          ),
        ),
        if (selectedTestament != 'nt') ...[
          _sectionHeader(
            language == 'tl' ? 'LUMANG TIPAN' : 'OLD TESTAMENT',
            _otCount,
          ),
          for (int i = 0; i < _otCount; i++)
            _BookTile(bookNum: i + 1, bookName: names[i], language: language),
        ],
        if (selectedTestament == 'all') const SizedBox(height: 8),
        if (selectedTestament != 'ot') ...[
          _sectionHeader(
            language == 'tl' ? 'BAGONG TIPAN' : 'NEW TESTAMENT',
            names.length - _otCount,
          ),
          for (int i = _otCount; i < names.length; i++)
            _BookTile(bookNum: i + 1, bookName: names[i], language: language),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count books',
              style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final int bookNum;
  final String bookName;
  final String language;

  const _BookTile({
    required this.bookNum,
    required this.bookName,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BibleChaptersScreen(
            bookNum: bookNum,
            bookName: bookName,
            language: language,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$bookNum',
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                bookName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF5A5A7A), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chapter grid
// ─────────────────────────────────────────────────────────────────────────────

class BibleChaptersScreen extends StatefulWidget {
  final int bookNum;
  final String bookName;
  final String language;

  const BibleChaptersScreen({
    super.key,
    required this.bookNum,
    required this.bookName,
    required this.language,
  });

  @override
  State<BibleChaptersScreen> createState() => _BibleChaptersScreenState();
}

class _BibleChaptersScreenState extends State<BibleChaptersScreen> {
  late String _language;
  int? _chapterCount;

  @override
  void initState() {
    super.initState();
    _language = widget.language;
    _loadChapterCount();
  }

  Future<void> _loadChapterCount() async {
    final c = await BibleService.instance.getChapterCount(
      widget.bookNum,
      language: _language,
    );
    if (mounted) setState(() => _chapterCount = c);
  }

  void _toggleLanguage() {
    setState(() {
      _language = _language == 'en' ? 'tl' : 'en';
      _chapterCount = null;
    });
    _loadChapterCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.bookName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _LangToggle(current: _language, onToggle: _toggleLanguage),
          ),
        ],
      ),
      body: _chapterCount == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _language == 'tl'
                        ? 'Pumili ng Kabanata'
                        : 'Select a Chapter',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.1,
                          ),
                      itemCount: _chapterCount,
                      itemBuilder: (context, index) {
                        final chap = index + 1;
                        return InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BibleVersesScreen(
                                bookNum: widget.bookNum,
                                bookName: widget.bookName,
                                chapter: chap,
                                totalChapters: _chapterCount!,
                                language: _language,
                              ),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF16213E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF2D2D44),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$chap',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Verses reader
// ─────────────────────────────────────────────────────────────────────────────

class BibleVersesScreen extends StatefulWidget {
  final int bookNum;
  final String bookName;
  final int chapter;
  final int totalChapters;
  final String language;

  const BibleVersesScreen({
    super.key,
    required this.bookNum,
    required this.bookName,
    required this.chapter,
    required this.totalChapters,
    required this.language,
  });

  @override
  State<BibleVersesScreen> createState() => _BibleVersesScreenState();
}

class _BibleVersesScreenState extends State<BibleVersesScreen> {
  late String _language;
  late int _chapter;
  List<BibleVerse>? _verses;
  bool _loading = true;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _language = widget.language;
    _chapter = widget.chapter;
    _loadVerses();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadVerses() async {
    setState(() {
      _loading = true;
      _verses = null;
    });
    final v = await BibleService.instance.getChapterVerses(
      widget.bookNum,
      _chapter,
      language: _language,
    );
    if (mounted)
      setState(() {
        _verses = v;
        _loading = false;
      });
    // Scroll to top whenever chapter changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _toggleLanguage() {
    setState(() => _language = _language == 'en' ? 'tl' : 'en');
    _loadVerses();
  }

  void _prevChapter() {
    if (_chapter <= 1) return;
    setState(() => _chapter--);
    _loadVerses();
  }

  void _nextChapter() {
    if (_chapter >= widget.totalChapters) return;
    setState(() => _chapter++);
    _loadVerses();
  }

  @override
  Widget build(BuildContext context) {
    final bookName = _language == 'tl'
        ? BibleService.tagalogBookNames[widget.bookNum - 1]
        : BibleService.bookNames[widget.bookNum - 1];

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '$bookName $_chapter',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          _LangToggle(current: _language, onToggle: _toggleLanguage),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: const Color(0xFF16213E),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Previous chapter
                _ChapterNavBtn(
                  label: _chapter > 1 ? '< Ch ${_chapter - 1}' : '',
                  enabled: _chapter > 1,
                  onTap: _prevChapter,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_language == 'tl' ? 'Kabanata' : 'Chapter'} $_chapter / ${widget.totalChapters}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                // Next chapter
                _ChapterNavBtn(
                  label: _chapter < widget.totalChapters
                      ? 'Ch ${_chapter + 1} >'
                      : '',
                  enabled: _chapter < widget.totalChapters,
                  onTap: _nextChapter,
                  alignRight: true,
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            )
          : _buildVerseList(bookName),
    );
  }

  Widget _buildVerseList(String bookName) {
    final verses = _verses ?? [];
    if (verses.isEmpty) {
      return const Center(
        child: Text(
          'No verses found.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: verses.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: Text(
              '$bookName — Chapter $_chapter\n'
              '(${verses.first.translationLabel})',
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          );
        }
        final v = verses[index - 1];
        return _VerseTile(verse: v);
      },
    );
  }
}

class _VerseTile extends StatelessWidget {
  final BibleVerse verse;
  const _VerseTile({required this.verse});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showVerseActions(context, verse),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: RichText(
          text: TextSpan(
            children: [
              // Verse number badge
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${verse.verse}',
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              TextSpan(
                text: verse.displayText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.65,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Verse action buttons (copy / save) — used in search results
// ─────────────────────────────────────────────────────────────────────────────

class _VerseActionButtons extends StatefulWidget {
  final BibleVerse verse;
  const _VerseActionButtons({required this.verse});

  @override
  State<_VerseActionButtons> createState() => _VerseActionButtonsState();
}

class _VerseActionButtonsState extends State<_VerseActionButtons> {
  bool _saved = false;
  bool _loadingSave = true;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final s = await BibleService.instance.isVerseSaved(widget.verse);
    if (mounted)
      setState(() {
        _saved = s;
        _loadingSave = false;
      });
  }

  Future<void> _toggleSave() async {
    if (_saved) {
      await BibleService.instance.unsaveVerse(widget.verse);
    } else {
      await BibleService.instance.saveVerse(widget.verse);
    }
    if (mounted) setState(() => _saved = !_saved);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _saved
                ? '${widget.verse.reference} saved'
                : '${widget.verse.reference} removed',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF16213E),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _copyVerse() {
    final text = '${widget.verse.reference}\n"${widget.verse.displayText}"';
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied: ${widget.verse.reference}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF16213E),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.copy, size: 18, color: Colors.white54),
          onPressed: _copyVerse,
          tooltip: 'Copy',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30),
        ),
        if (_loadingSave)
          const SizedBox(
            width: 30,
            height: 18,
            child: Center(
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Color(0xFFD4AF37),
                ),
              ),
            ),
          )
        else
          IconButton(
            icon: Icon(
              _saved ? Icons.bookmark : Icons.bookmark_border,
              size: 18,
              color: _saved ? const Color(0xFFD4AF37) : Colors.white54,
            ),
            onPressed: _toggleSave,
            tooltip: _saved ? 'Remove from saved' : 'Save verse',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Verse actions bottom sheet (shown on long-press)
// ─────────────────────────────────────────────────────────────────────────────

void _showVerseActions(BuildContext context, BibleVerse verse) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF16213E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _VerseActionsSheet(verse: verse),
  );
}

class _VerseActionsSheet extends StatefulWidget {
  final BibleVerse verse;
  const _VerseActionsSheet({required this.verse});

  @override
  State<_VerseActionsSheet> createState() => _VerseActionsSheetState();
}

class _VerseActionsSheetState extends State<_VerseActionsSheet> {
  bool _saved = false;
  bool _loadingSave = true;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final s = await BibleService.instance.isVerseSaved(widget.verse);
    if (mounted)
      setState(() {
        _saved = s;
        _loadingSave = false;
      });
  }

  String _buildVerseText() =>
      '${widget.verse.reference}\n"${widget.verse.displayText}"';

  void _copyVerse() {
    Clipboard.setData(ClipboardData(text: _buildVerseText()));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied: ${widget.verse.reference}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleSave() async {
    if (_saved) {
      await BibleService.instance.unsaveVerse(widget.verse);
      if (mounted) setState(() => _saved = false);
    } else {
      await BibleService.instance.saveVerse(widget.verse);
      if (mounted) setState(() => _saved = true);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _saved
                ? '${widget.verse.reference} saved'
                : '${widget.verse.reference} removed',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1A1A2E),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareToFeed() async {
    setState(() => _sharing = true);
    try {
      final user = AuthService.instance.currentUser.value;
      if (user == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please log in to share.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Color(0xFF1A1A2E),
          ),
        );
        return;
      }
      final postContent =
          '📖 ${widget.verse.reference}\n\n"${widget.verse.displayText}"\n\n— ${widget.verse.translationLabel}';
      await PostService.instance.addPost(
        user.id,
        user.email,
        postContent,
        authorAvatarUrl: user.avatarUrl,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Shared to your newsfeed!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Color(0xFF1A1A2E),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sharing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to share: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF5A5A7A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              widget.verse.reference,
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '"${widget.verse.displayText}"',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF2D2D44)),
            _ActionRow(
              icon: Icons.copy,
              label: 'Copy verse',
              onTap: _copyVerse,
            ),
            _ActionRow(
              icon: _loadingSave
                  ? Icons.hourglass_empty
                  : (_saved ? Icons.bookmark : Icons.bookmark_border),
              iconColor: _saved ? const Color(0xFFD4AF37) : null,
              label: _saved ? 'Remove from saved' : 'Save verse',
              onTap: _loadingSave ? null : _toggleSave,
            ),
            _ActionRow(
              icon: _sharing ? Icons.hourglass_top : Icons.send_outlined,
              label: _sharing ? 'Sharing…' : 'Share to Newsfeed',
              onTap: _sharing ? null : _shareToFeed,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? Colors.white70, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? Colors.white38 : Colors.white,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily Verse Card  (exported — use in Home/Profile screens)
// ─────────────────────────────────────────────────────────────────────────────

class DailyVerseCard extends StatefulWidget {
  final String language;
  const DailyVerseCard({super.key, this.language = 'en'});

  @override
  State<DailyVerseCard> createState() => _DailyVerseCardState();
}

class _DailyVerseCardState extends State<DailyVerseCard> {
  BibleVerse? _verse;
  bool _loading = true;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await BibleService.instance.getDailyVerse(
      language: widget.language,
    );
    if (mounted)
      setState(() {
        _verse = v;
        _loading = false;
      });
  }

  Future<void> _shareToFeed() async {
    if (_verse == null) return;
    setState(() => _sharing = true);
    try {
      final user = AuthService.instance.currentUser.value;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please log in to share.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Color(0xFF1A1A2E),
          ),
        );
        return;
      }
      final postContent =
          '✨ Daily Verse — ${_verse!.reference}\n\n"${_verse!.displayText}"\n\n— ${_verse!.translationLabel}';
      await PostService.instance.addPost(
        user.id,
        user.email,
        postContent,
        authorAvatarUrl: user.avatarUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Daily verse shared to your newsfeed!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Color(0xFF16213E),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to share: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _copyVerse() {
    if (_verse == null) return;
    final text = '${_verse!.reference}\n"${_verse!.displayText}"';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied: ${_verse!.reference}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF16213E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFD4AF37),
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (_verse == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_stories,
                color: Color(0xFFD4AF37),
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'Daily Verse',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                _verse!.reference,
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '"${_verse!.displayText}"',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: _copyVerse,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.copy, size: 14, color: Colors.white54),
                      SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _sharing ? null : _shareToFeed,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_sharing)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Color(0xFFD4AF37),
                          ),
                        )
                      else
                        const Icon(
                          Icons.send_outlined,
                          size: 14,
                          color: Color(0xFFD4AF37),
                        ),
                      const SizedBox(width: 4),
                      const Text(
                        'Share to Feed',
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Saved Verses Screen  (navigate to this from a bookmark icon / profile)
// ─────────────────────────────────────────────────────────────────────────────

class SavedVersesScreen extends StatefulWidget {
  final String language;
  const SavedVersesScreen({super.key, this.language = 'en'});

  @override
  State<SavedVersesScreen> createState() => _SavedVersesScreenState();
}

class _SavedVersesScreenState extends State<SavedVersesScreen> {
  List<BibleVerse>? _verses;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final verses = await BibleService.instance.getSavedVerses(
      language: widget.language,
    );
    if (mounted)
      setState(() {
        _verses = verses;
        _loading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Saved Verses',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            )
          : (_verses == null || _verses!.isEmpty)
          ? const Center(
              child: Text(
                'No saved verses yet.\nLong-press any verse to save it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              itemCount: _verses!.length,
              itemBuilder: (ctx, i) {
                final v = _verses![i];
                return _SavedVerseTile(
                  verse: v,
                  onUnsaved: () => setState(() => _verses!.removeAt(i)),
                );
              },
            ),
    );
  }
}

class _SavedVerseTile extends StatelessWidget {
  final BibleVerse verse;
  final VoidCallback onUnsaved;
  const _SavedVerseTile({required this.verse, required this.onUnsaved});

  void _copy(BuildContext context) {
    final text = '${verse.reference}\n"${verse.displayText}"';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied: ${verse.reference}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF16213E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _unsave(BuildContext context) async {
    await BibleService.instance.unsaveVerse(verse);
    onUnsaved();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  verse.reference,
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18, color: Colors.white54),
                onPressed: () => _copy(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30),
              ),
              IconButton(
                icon: const Icon(
                  Icons.bookmark,
                  size: 18,
                  color: Color(0xFFD4AF37),
                ),
                onPressed: () => _unsave(context),
                tooltip: 'Remove',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            verse.displayText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chip
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD4AF37) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFD4AF37) : const Color(0xFF2D2D44),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _LangToggle extends StatelessWidget {
  final String current;
  final VoidCallback onToggle;

  const _LangToggle({required this.current, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D44),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LangChip(label: 'EN', active: current == 'en'),
            const SizedBox(width: 2),
            _LangChip(label: 'TL', active: current == 'tl'),
          ],
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool active;
  const _LangChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFD4AF37) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.black : Colors.white54,
          fontSize: 12,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _ChapterNavBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool alignRight;

  const _ChapterNavBtn({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox(width: 80);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD4AF37),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
