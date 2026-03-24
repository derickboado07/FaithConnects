import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/music_player_service.dart';
import '../services/metronome_service.dart';

// ═══════════════════════════════════════════════════════════════════════
//  MUSIC SCREEN — Moises-style worship music experience
// ═══════════════════════════════════════════════════════════════════════

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});
  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 0; // 0=Songs, 1=Setlists, 2=Tools
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _filter = 'All'; // All, Recent, Favorites

  // Setlist state (in-memory)
  final List<_Setlist> _setlists = [];

  MusicPlayerService get _svc => MusicPlayerService.instance;

  List<Song> get _filteredSongs {
    List<Song> songs = MusicPlayerService.allSongs;
    if (_filter == 'Favorites') {
      songs = songs.where((s) => _svc.isFavorite(s.title)).toList();
    }
    if (_searchQuery.isEmpty) return songs;
    final q = _searchQuery.toLowerCase();
    return songs
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _svc.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _svc.removeListener(_rebuild);
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Add song via file picker ──
  Future<void> _addSong() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final filePath = file.path;
    if (filePath == null) return;

    final rawName = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    if (!mounted) return;
    final titleCtrl = TextEditingController(text: rawName);
    final artistCtrl = TextEditingController(text: 'Unknown Artist');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: t.colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Add Song',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: t.colorScheme.onSurface)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                    labelText: 'Song Title',
                    labelStyle: TextStyle(color: t.hintColor))),
            const SizedBox(height: 12),
            TextField(
                controller: artistCtrl,
                decoration: InputDecoration(
                    labelText: 'Artist',
                    labelStyle: TextStyle(color: t.hintColor))),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: t.hintColor))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final title = titleCtrl.text.trim();
    final artist = artistCtrl.text.trim();
    if (title.isEmpty) return;
    _svc.addSong(Song(
        title: title,
        artist: artist.isNotEmpty ? artist : 'Unknown Artist',
        assetPath: filePath,
        isUserAdded: true));
  }

  // ── Show add/record bottom sheet ──
  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddOptionsSheet(
        onAddFile: () {
          Navigator.pop(ctx);
          _addSong();
        },
        onRecord: () {
          Navigator.pop(ctx);
          _showRecordSheet();
        },
      ),
    );
  }

  void _showRecordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RecordSheet(),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettingsSheet(service: _svc),
    );
  }

  void _showSongDetail(Song song, int index) {
    _svc.playSong(song, index, _filteredSongs);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SongDetailSheet(service: _svc),
    );
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    final gold = const Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top header ──
            _buildHeader(theme, isDark, gold),
            // ── Tab bar ──
            _buildTabBar(theme, isDark, gold),
            // ── Content ──
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _buildSongsTab(theme, isDark),
                  _buildSetlistsTab(theme, isDark, gold),
                  _buildToolsTab(theme, isDark, gold),
                ],
              ),
            ),
          ],
        ),
      ),
      // ── FAB ──
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton(
              onPressed: _showAddOptions,
              backgroundColor: gold,
              elevation: 8,
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            )
          : null,
    );
  }

  // ═══ HEADER ═══
  Widget _buildHeader(ThemeData theme, bool isDark, Color gold) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Worship Music',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: 2),
                Text('Your sacred playlist',
                    style: TextStyle(
                        color: theme.hintColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // Record button
          _HeaderIconBtn(
            icon: Icons.mic_rounded,
            tooltip: 'Record',
            isDark: isDark,
            onTap: _showRecordSheet,
          ),
          const SizedBox(width: 8),
          // Settings
          _HeaderIconBtn(
            icon: Icons.tune_rounded,
            tooltip: 'Settings',
            isDark: isDark,
            onTap: _showSettings,
          ),
        ],
      ),
    );
  }

  // ═══ TAB BAR ═══
  Widget _buildTabBar(ThemeData theme, bool isDark, Color gold) {
    final tabs = ['Songs', 'Setlists', 'Tools'];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? Colors.white
                        : theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 1: SONGS LIBRARY
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSongsTab(ThemeData theme, bool isDark) {
    final currentSong = _svc.currentSong;
    final isPlaying = _svc.isPlaying;

    return Column(
      children: [
        // ── Search bar ──
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHighest
                : const Color(0xFFF2EDE3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search songs or artist...',
              hintStyle: TextStyle(color: theme.hintColor, fontSize: 14),
              prefixIcon:
                  Icon(Icons.search_rounded, color: theme.hintColor, size: 22),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () => setState(() {
                        _searchQuery = '';
                        _searchCtrl.clear();
                      }),
                      child: Icon(Icons.close_rounded,
                          color: theme.hintColor, size: 18),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        // ── Filter chips ──
        _buildFilterChips(theme, isDark),
        // ── Song list ──
        Expanded(
          child: _filteredSongs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.music_off_rounded,
                          size: 56,
                          color: theme.hintColor.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text('No songs found',
                          style: TextStyle(
                              fontSize: 16,
                              color: theme.hintColor,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Text('Try a different search or add songs',
                          style: TextStyle(
                              fontSize: 13,
                              color:
                                  theme.hintColor.withValues(alpha: 0.6))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: _filteredSongs.length,
                  itemBuilder: (_, i) {
                    final song = _filteredSongs[i];
                    final isCurrent = currentSong?.title == song.title &&
                        currentSong?.artist == song.artist;
                    return _SongTile(
                      song: song,
                      isPlaying: isCurrent && isPlaying,
                      isSelected: isCurrent,
                      isFavorite: _svc.isFavorite(song.title),
                      onTap: () => _showSongDetail(song, i),
                      onFavorite: () =>
                          setState(() => _svc.toggleFavorite(song.title)),
                      onRemove: song.isUserAdded
                          ? () => _confirmRemoveSong(song)
                          : null,
                    );
                  },
                ),
        ),
        // ── Mini now-playing bar ──
        if (_svc.currentSong != null) _buildMiniPlayer(theme, isDark),
      ],
    );
  }

  Widget _buildFilterChips(ThemeData theme, bool isDark) {
    final filters = ['All', 'Favorites'];
    final gold = const Color(0xFFD4AF37);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: filters.map((f) {
          final active = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: active
                      ? gold.withValues(alpha: 0.15)
                      : isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? gold.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Text(f,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                        color: active
                            ? gold
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.6))),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMiniPlayer(ThemeData theme, bool isDark) {
    final song = _svc.currentSong!;
    final playing = _svc.isPlaying;
    final gold = const Color(0xFFD4AF37);
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _SongDetailSheet(service: _svc),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest
              : const Color(0xFFF5F0E8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Progress ring + album art
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      value: _svc.progress,
                      strokeWidth: 2.5,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(gold),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [gold, const Color(0xFFF5E6B3)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.music_note_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(song.title,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(song.artist,
                      style: TextStyle(fontSize: 11.5, color: theme.hintColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              onPressed: _svc.playPrevious,
              icon: Icon(Icons.skip_previous_rounded,
                  color: theme.iconTheme.color, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            GestureDetector(
              onTap: () => _svc.togglePlayPause(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [gold, const Color(0xFFE8C95A)]),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 22),
              ),
            ),
            IconButton(
              onPressed: _svc.playNext,
              icon: Icon(Icons.skip_next_rounded,
                  color: theme.iconTheme.color, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveSong(Song song) {
    showDialog(
      context: context,
      builder: (ctx) {
        final t = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: t.colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Remove Song',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: t.colorScheme.onSurface)),
          content: Text('Remove "${song.title}" from your library?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: t.hintColor))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                _svc.removeSong(song);
                Navigator.pop(ctx);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 2: SETLISTS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSetlistsTab(ThemeData theme, bool isDark, Color gold) {
    return Column(
      children: [
        // Create setlist button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: GestureDetector(
            onTap: _createSetlist,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                    color: gold.withValues(alpha: 0.5), width: 1.5),
                borderRadius: BorderRadius.circular(14),
                color: gold.withValues(alpha: 0.06),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: gold, size: 20),
                  const SizedBox(width: 6),
                  Text('Create Setlist',
                      style: TextStyle(
                          color: gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: _setlists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.queue_music_rounded,
                          size: 56,
                          color: theme.hintColor.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('No setlists yet',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: theme.hintColor)),
                      const SizedBox(height: 6),
                      Text('Create a setlist to organize your songs',
                          style: TextStyle(
                              fontSize: 13,
                              color:
                                  theme.hintColor.withValues(alpha: 0.6))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: _setlists.length,
                  itemBuilder: (_, i) =>
                      _buildSetlistCard(_setlists[i], theme, isDark, gold),
                ),
        ),
      ],
    );
  }

  Widget _buildSetlistCard(
      _Setlist setlist, ThemeData theme, bool isDark, Color gold) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [gold, const Color(0xFFE8C95A)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              const Icon(Icons.queue_music_rounded, color: Colors.white, size: 22),
        ),
        title: Text(setlist.name,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: theme.colorScheme.onSurface)),
        subtitle: Text('${setlist.songIndices.length} songs',
            style: TextStyle(fontSize: 12, color: theme.hintColor)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.add_rounded, color: gold, size: 22),
              onPressed: () => _addSongsToSetlist(setlist),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: theme.hintColor, size: 20),
              onPressed: () => setState(() => _setlists.remove(setlist)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
        children: [
          if (setlist.songIndices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No songs in this setlist',
                  style: TextStyle(color: theme.hintColor, fontSize: 13)),
            ),
          ...setlist.songIndices.map((idx) {
            if (idx >= MusicPlayerService.allSongs.length) {
              return const SizedBox.shrink();
            }
            final song = MusicPlayerService.allSongs[idx];
            return ListTile(
              dense: true,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFE8D5B7), Color(0xFFD4C4A8)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.music_note_rounded,
                    color: Colors.white, size: 16),
              ),
              title: Text(song.title,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface)),
              subtitle: Text(song.artist,
                  style: TextStyle(fontSize: 11.5, color: theme.hintColor)),
              trailing: IconButton(
                icon: Icon(Icons.close_rounded,
                    color: theme.hintColor, size: 16),
                onPressed: () => setState(
                    () => setlist.songIndices.remove(idx)),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              onTap: () => _showSongDetail(song, idx),
            );
          }),
          // Play setlist button
          if (setlist.songIndices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _playSetlist(setlist),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Play Setlist'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _createSetlist() async {
    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: t.colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('New Setlist',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: t.colorScheme.onSurface)),
          content: TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                  hintText: 'Setlist name',
                  hintStyle: TextStyle(color: t.hintColor))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: t.hintColor))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _setlists.add(_Setlist(
          name: name,
          songIndices: [],
          createdAt: DateTime.now()));
    });
  }

  void _addSongsToSetlist(_Setlist setlist) async {
    final allSongs = MusicPlayerService.allSongs;
    final selected = Set<int>.from(setlist.songIndices);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          final t = Theme.of(ctx);
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.7,
            decoration: BoxDecoration(
              color: t.scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: t.hintColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text('Add Songs',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: t.colorScheme.onSurface)),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => setlist.songIndices
                            ..clear()
                            ..addAll(selected));
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8)),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: allSongs.length,
                    itemBuilder: (_, i) {
                      final song = allSongs[i];
                      final checked = selected.contains(i);
                      return CheckboxListTile(
                        value: checked,
                        activeColor: const Color(0xFFD4AF37),
                        onChanged: (v) {
                          setSt(() {
                            if (v == true) {
                              selected.add(i);
                            } else {
                              selected.remove(i);
                            }
                          });
                        },
                        secondary: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              Color(0xFFE8D5B7),
                              Color(0xFFD4C4A8)
                            ]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.music_note_rounded,
                              color: Colors.white, size: 18),
                        ),
                        title: Text(song.title,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: t.colorScheme.onSurface)),
                        subtitle: Text(song.artist,
                            style: TextStyle(
                                fontSize: 12, color: t.hintColor)),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _playSetlist(_Setlist setlist) {
    if (setlist.songIndices.isEmpty) return;
    final allSongs = MusicPlayerService.allSongs;
    final playlist =
        setlist.songIndices.where((i) => i < allSongs.length).map((i) => allSongs[i]).toList();
    if (playlist.isEmpty) return;
    _svc.playSong(playlist[0], 0, playlist);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SongDetailSheet(service: _svc),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 3: TOOLS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildToolsTab(ThemeData theme, bool isDark, Color gold) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('Practice Tools',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface)),
          ),
          // Metronome card
          _buildToolCard(
            theme: theme,
            isDark: isDark,
            gold: gold,
            icon: Icons.timer_rounded,
            title: 'Metronome',
            subtitle: 'Keep time with adjustable BPM',
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const _MetronomeSheet(),
            ),
          ),
          // Key Transposer card
          _buildToolCard(
            theme: theme,
            isDark: isDark,
            gold: gold,
            icon: Icons.music_note_rounded,
            title: 'Key Transposer',
            subtitle: 'Transpose chords to any key',
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const _KeyTransposerSheet(),
            ),
          ),
          // Chord chart card
          _buildToolCard(
            theme: theme,
            isDark: isDark,
            gold: gold,
            icon: Icons.grid_view_rounded,
            title: 'Chord Chart',
            subtitle: 'View chords for worship songs',
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const _ChordChartSheet(),
            ),
          ),
          // Lyrics viewer card
          _buildToolCard(
            theme: theme,
            isDark: isDark,
            gold: gold,
            icon: Icons.lyrics_rounded,
            title: 'Lyrics',
            subtitle: 'View and add song lyrics',
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const _LyricsSheet(),
            ),
          ),
          // Speed trainer card
          _buildToolCard(
            theme: theme,
            isDark: isDark,
            gold: gold,
            icon: Icons.speed_rounded,
            title: 'Speed Trainer',
            subtitle: 'Adjust playback speed for practice',
            onTap: () {
              if (_svc.currentSong == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Play a song first to adjust speed')));
                return;
              }
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => _SpeedTrainerSheet(service: _svc),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required ThemeData theme,
    required bool isDark,
    required Color gold,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest
              : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient:
                    LinearGradient(colors: [gold, const Color(0xFFE8C95A)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12.5, color: theme.hintColor)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.hintColor, size: 22),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  SONG TILE
// ═══════════════════════════════════════════════════════════════════════
class _SongTile extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final bool isSelected;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback? onRemove;

  const _SongTile({
    required this.song,
    required this.isPlaying,
    required this.isSelected,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gold = const Color(0xFFD4AF37);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? gold.withValues(alpha: 0.1)
              : isDark
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelected
                  ? gold.withValues(alpha: 0.3)
                  : theme.dividerColor),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Album art
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSelected
                      ? [gold, const Color(0xFFE8C95A)]
                      : [const Color(0xFFE8D5B7), const Color(0xFFD4C4A8)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.music_note_rounded,
                      color: Colors.white, size: 24),
                  if (isPlaying)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.equalizer_rounded,
                          color: Colors.white, size: 22),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? gold
                              : theme.colorScheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(song.artist,
                      style: TextStyle(fontSize: 12.5, color: theme.hintColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Favorite button
            GestureDetector(
              onTap: onFavorite,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite ? gold : theme.hintColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Play button
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? gold
                    : isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isSelected ? Colors.white : theme.hintColor,
                size: 20,
              ),
            ),
            // Remove button (user-added songs only)
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded,
                      color: theme.hintColor, size: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  HEADER ICON BUTTON
// ═══════════════════════════════════════════════════════════════════════
class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;
  const _HeaderIconBtn(
      {required this.icon,
      required this.tooltip,
      required this.isDark,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: theme.hintColor, size: 20),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  ADD OPTIONS BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════
class _AddOptionsSheet extends StatelessWidget {
  final VoidCallback onAddFile;
  final VoidCallback onRecord;
  const _AddOptionsSheet(
      {required this.onAddFile, required this.onRecord});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gold = const Color(0xFFD4AF37);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.hintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Add Music',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 20),
          _AddOptionTile(
            icon: Icons.folder_open_rounded,
            title: 'Import from Files',
            subtitle: 'Add audio files from your device',
            isDark: isDark,
            gold: gold,
            onTap: onAddFile,
          ),
          const SizedBox(height: 10),
          _AddOptionTile(
            icon: Icons.mic_rounded,
            title: 'Record Audio',
            subtitle: 'Record live audio with your microphone',
            isDark: isDark,
            gold: gold,
            onTap: onRecord,
          ),
        ],
      ),
    );
  }
}

class _AddOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final Color gold;
  final VoidCallback onTap;
  const _AddOptionTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.isDark,
      required this.gold,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient:
                    LinearGradient(colors: [gold, const Color(0xFFE8C95A)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12.5, color: theme.hintColor)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.hintColor),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  RECORD SHEET
// ═══════════════════════════════════════════════════════════════════════
class _RecordSheet extends StatefulWidget {
  const _RecordSheet();
  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  int _seconds = 0;
  Timer? _timer;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    if (_isRecording) {
      // Stop recording
      setState(() {
        _isRecording = false;
        _timer?.cancel();
        _pulseCtrl.stop();
        _pulseCtrl.reset();
      });
      // Show save dialog AFTER setState completes
      _showSaveDialog();
    } else {
      // Start recording
      setState(() {
        _isRecording = true;
        _seconds = 0;
        _pulseCtrl.repeat(reverse: true);
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() => _seconds++);
        });
      });
    }
  }

  void _showSaveDialog() async {
    final titleCtrl = TextEditingController(text: 'Recording ${DateTime.now().millisecondsSinceEpoch ~/ 1000}');
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: t.colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Save Recording',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: t.colorScheme.onSurface)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Recording: ${_formatTime(_seconds)}',
                style: TextStyle(color: t.hintColor)),
            const SizedBox(height: 12),
            TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: t.hintColor))),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Discard', style: TextStyle(color: Colors.red[400]))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recording saved: ${titleCtrl.text}'),
          backgroundColor: const Color(0xFFD4AF37),
        ),
      );
      Navigator.pop(context);
    }
  }

  String _formatTime(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = const Color(0xFFD4AF37);
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.hintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Record Audio',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text(
              _isRecording ? 'Recording in progress...' : 'Tap to start recording',
              style: TextStyle(fontSize: 13, color: theme.hintColor)),
          const Spacer(),
          // Timer
          Text(_formatTime(_seconds),
              style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: _isRecording ? gold : theme.hintColor,
                  letterSpacing: 2)),
          const SizedBox(height: 8),
          // Waveform animation
          if (_isRecording)
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, w1) => SizedBox(
                height: 40,
                width: 200,
                child: CustomPaint(
                  painter: _WaveformPainter(
                    value: _pulseCtrl.value,
                    color: gold,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 40),
          const Spacer(),
          // Record button
          GestureDetector(
            onTap: _toggleRecording,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, w2) {
                final scale = _isRecording
                    ? 1.0 + _pulseCtrl.value * 0.08
                    : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : gold,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? Colors.red : gold)
                              .withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isRecording ? 'Tap to stop' : 'Tap to record',
            style: TextStyle(fontSize: 13, color: theme.hintColor),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  SONG DETAIL BOTTOM SHEET — Player + Chords + Lyrics + Transposer
// ═══════════════════════════════════════════════════════════════════════
class _SongDetailSheet extends StatefulWidget {
  final MusicPlayerService service;
  const _SongDetailSheet({required this.service});
  @override
  State<_SongDetailSheet> createState() => _SongDetailSheetState();
}

class _SongDetailSheetState extends State<_SongDetailSheet>
    with SingleTickerProviderStateMixin {
  int _detailTab = 0; // 0=Player, 1=Chords, 2=Lyrics
  int _transposeOffset = 0;
  late AnimationController _eqCtrl;

  MusicPlayerService get _s => widget.service;

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _s.addListener(_rebuild);
    _eqCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _s.removeListener(_rebuild);
    _eqCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gold = const Color(0xFFD4AF37);
    final sh = MediaQuery.of(context).size.height;
    final sw = MediaQuery.of(context).size.width;
    final albumSize = (sw * 0.5).clamp(160.0, 260.0);

    final song = _s.currentSong;
    if (song == null) return const SizedBox.shrink();
    final playing = _s.isPlaying;
    if (playing && !_eqCtrl.isAnimating) _eqCtrl.repeat(reverse: true);
    if (!playing && _eqCtrl.isAnimating) _eqCtrl.stop();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: sh * 0.92),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFF1A1A1A),
                    const Color(0xFF1E1A10),
                    const Color(0xFF251E0E),
                  ]
                : [
                    const Color(0xFFFCF9F2),
                    const Color(0xFFF6EDDA),
                    const Color(0xFFE8D6AA),
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: theme.hintColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: theme.hintColor, size: 24),
                      ),
                    ),
                    const Spacer(),
                    Text('NOW PLAYING',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: gold.withValues(alpha: 0.8),
                            letterSpacing: 2)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _s.toggleFavorite(song.title),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _s.isFavorite(song.title)
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: _s.isFavorite(song.title)
                              ? gold
                              : theme.hintColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Album art
              Container(
                width: albumSize,
                height: albumSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    colors: [gold, const Color(0xFFECC544), const Color(0xFFF5E6B3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: gold.withValues(alpha: 0.4),
                        blurRadius: 50,
                        offset: const Offset(0, 20)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                          width: albumSize * 0.6,
                          height: albumSize * 0.6,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15)))),
                      Icon(Icons.music_note_rounded,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: albumSize * 0.25),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Song info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Text(song.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Text(song.artist,
                        style: TextStyle(
                            fontSize: 14,
                            color: gold.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Seek slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: gold,
                        inactiveTrackColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFFE5D9BB),
                        thumbColor: gold,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 7),
                        trackHeight: 3.5,
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 16),
                        overlayColor: gold.withValues(alpha: 0.12),
                      ),
                      child: Slider(
                        value: _s.progress.clamp(0.0, 1.0),
                        onChanged: (v) {
                          if (_s.duration.inMilliseconds > 0) {
                            _s.seekTo(Duration(
                                milliseconds:
                                    (v * _s.duration.inMilliseconds).round()));
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(_s.position),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: gold.withValues(alpha: 0.7))),
                          Text(_fmt(_s.duration),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: gold.withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Shuffle button
                    GestureDetector(
                      onTap: () {
                        _s.toggleShuffle();
                        setState(() {});
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _s.isShuffling
                              ? gold.withValues(alpha: 0.2)
                              : isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shuffle_rounded,
                            size: 22,
                            color: _s.isShuffling
                                ? gold
                                : Theme.of(context).iconTheme.color),
                      ),
                    ),
                    _ControlBtn(
                        icon: Icons.skip_previous_rounded,
                        size: 32,
                        isDark: isDark,
                        onTap: _s.playPrevious),
                    // Main play button
                    GestureDetector(
                      onTap: () => _s.togglePlayPause(),
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [gold, const Color(0xFFECC544)]),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: gold.withValues(alpha: 0.5),
                                blurRadius: 24,
                                offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36),
                      ),
                    ),
                    _ControlBtn(
                        icon: Icons.skip_next_rounded,
                        size: 32,
                        isDark: isDark,
                        onTap: _s.playNext),
                    // Repeat button
                    GestureDetector(
                      onTap: () {
                        _s.cycleRepeat();
                        setState(() {});
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _s.repeatMode != RepeatMode.none
                              ? gold.withValues(alpha: 0.2)
                              : isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              _s.repeatMode == RepeatMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              size: 22,
                              color: _s.repeatMode != RepeatMode.none
                                  ? gold
                                  : Theme.of(context).iconTheme.color,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Detail tabs: Player | Chords | Lyrics
              _buildDetailTabs(theme, isDark, gold),
              const SizedBox(height: 12),
              // Tab content
              _buildDetailContent(theme, isDark, gold, song),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTabs(ThemeData theme, bool isDark, Color gold) {
    final tabs = ['Player', 'Chords', 'Lyrics'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _detailTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _detailTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? Colors.white
                        : theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDetailContent(
      ThemeData theme, bool isDark, Color gold, Song song) {
    switch (_detailTab) {
      case 1:
        return _buildChordsView(theme, isDark, gold, song);
      case 2:
        return _buildLyricsView(theme, isDark, gold, song);
      default:
        return _buildPlayerExtras(theme, isDark, gold, song);
    }
  }

  // ── Player extras: Speed, Up Next ──
  Widget _buildPlayerExtras(
      ThemeData theme, bool isDark, Color gold, Song song) {
    final playlist = _s.playlist;
    final nextIdx = _s.currentIndex + 1;
    final nextSong = nextIdx < playlist.length ? playlist[nextIdx] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speed control
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.speed_rounded, color: gold, size: 18),
                    const SizedBox(width: 8),
                    Text('Playback Speed',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface)),
                    const Spacer(),
                    Text('${_s.speed.toStringAsFixed(2)}x',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: gold)),
                  ],
                ),
                const SizedBox(height: 10),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: gold,
                    inactiveTrackColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    thumbColor: gold,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    min: 0.25,
                    max: 2.0,
                    divisions: 7,
                    value: _s.speed,
                    onChanged: (v) => _s.setSpeed(v),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0.25x',
                        style: TextStyle(
                            fontSize: 10, color: theme.hintColor)),
                    Text('2.0x',
                        style: TextStyle(
                            fontSize: 10, color: theme.hintColor)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Up Next
          if (nextSong != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [const Color(0xFFE8D095), const Color(0xFFD4C070)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.music_note_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('UP NEXT',
                            style: TextStyle(
                                fontSize: 9,
                                color: gold.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 2),
                        Text(nextSong.title,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(nextSong.artist,
                            style: TextStyle(
                                fontSize: 11, color: theme.hintColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.queue_music_rounded,
                      color: gold, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Chords view ──
  Widget _buildChordsView(
      ThemeData theme, bool isDark, Color gold, Song song) {
    final chords = _sampleChords[song.title] ?? _defaultChords;
    final transposedChords = chords
        .map((c) => _transposeChordLine(c, _transposeOffset))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key transposer inline
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.music_note_rounded, color: gold, size: 18),
                const SizedBox(width: 8),
                Text('Key',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface)),
                const Spacer(),
                GestureDetector(
                  onTap: () =>
                      setState(() => _transposeOffset = (_transposeOffset - 1) % 12),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.remove_rounded, color: gold, size: 18),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _transposeOffset == 0
                        ? 'Original'
                        : '${_transposeOffset > 0 ? '+' : ''}$_transposeOffset',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: gold),
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      setState(() => _transposeOffset = (_transposeOffset + 1) % 12),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add_rounded, color: gold, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Chord chart
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: transposedChords.map((line) {
                final isSection = line.startsWith('[');
                return Padding(
                  padding: EdgeInsets.only(
                      top: isSection ? 12 : 2, bottom: 2),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: isSection ? 12 : 15,
                      fontWeight:
                          isSection ? FontWeight.w700 : FontWeight.w600,
                      color: isSection
                          ? gold
                          : theme.colorScheme.onSurface,
                      fontFamily: 'monospace',
                      letterSpacing: isSection ? 1 : 0.5,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Lyrics view ──
  Widget _buildLyricsView(
      ThemeData theme, bool isDark, Color gold, Song song) {
    final lyrics = _sampleLyrics[song.title] ?? 'No lyrics available.\n\nTap edit to add lyrics for this song.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lyrics_rounded, color: gold, size: 18),
                const SizedBox(width: 8),
                Text('Lyrics',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              lyrics,
              style: TextStyle(
                fontSize: 14,
                height: 1.8,
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  METRONOME SHEET
// ═══════════════════════════════════════════════════════════════════════
class _MetronomeSheet extends StatefulWidget {
  const _MetronomeSheet();
  @override
  State<_MetronomeSheet> createState() => _MetronomeSheetState();
}

class _MetronomeSheetState extends State<_MetronomeSheet> {
  final MetronomeService _met = MetronomeService.instance;
  final List<DateTime> _tapTimes = [];

  @override
  void initState() {
    super.initState();
    _met.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _met.removeListener(_rebuild);
    super.dispose();
  }

  void _onTapTempo() {
    final now = DateTime.now();
    // Reset if too long since last tap
    if (_tapTimes.isNotEmpty &&
        now.difference(_tapTimes.last).inSeconds > 2) {
      _tapTimes.clear();
    }
    _tapTimes.add(now);
    _met.tapTempo(_tapTimes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gold = const Color(0xFFD4AF37);
    final sh = MediaQuery.of(context).size.height;

    return Container(
      height: sh * 0.7,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.hintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Metronome',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 24),
          // BPM display
          Text('${_met.bpm}',
              style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w200,
                  color: _met.isPlaying ? gold : theme.colorScheme.onSurface,
                  letterSpacing: -2)),
          Text('BPM',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.hintColor,
                  letterSpacing: 1.5)),
          const SizedBox(height: 20),
          // Beat indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_met.beatsPerMeasure, (i) {
              final active = _met.isPlaying && _met.currentBeat == i + 1;
              final isDownbeat = i == 0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: active ? 28 : 22,
                  height: active ? 28 : 22,
                  decoration: BoxDecoration(
                    color: active
                        ? (isDownbeat ? gold : gold.withValues(alpha: 0.7))
                        : isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    boxShadow: active
                        ? [
                            BoxShadow(
                                color: gold.withValues(alpha: 0.5),
                                blurRadius: 12)
                          ]
                        : [],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          // BPM slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: gold,
                inactiveTrackColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                thumbColor: gold,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                trackHeight: 4,
              ),
              child: Slider(
                min: 30,
                max: 300,
                value: _met.bpm.toDouble(),
                onChanged: (v) => _met.setBpm(v.round()),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('30',
                  style:
                      TextStyle(fontSize: 11, color: theme.hintColor)),
              const SizedBox(width: 180),
              Text('300',
                  style:
                      TextStyle(fontSize: 11, color: theme.hintColor)),
            ],
          ),
          const SizedBox(height: 16),
          // Time signature selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Time: ',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface)),
              _TimeSignatureChip(
                  label: '2/4',
                  active: _met.beatsPerMeasure == 2,
                  gold: gold,
                  isDark: isDark,
                  onTap: () => _met.setTimeSignature(2, 4)),
              _TimeSignatureChip(
                  label: '3/4',
                  active: _met.beatsPerMeasure == 3,
                  gold: gold,
                  isDark: isDark,
                  onTap: () => _met.setTimeSignature(3, 4)),
              _TimeSignatureChip(
                  label: '4/4',
                  active: _met.beatsPerMeasure == 4,
                  gold: gold,
                  isDark: isDark,
                  onTap: () => _met.setTimeSignature(4, 4)),
              _TimeSignatureChip(
                  label: '6/8',
                  active: _met.beatsPerMeasure == 6,
                  gold: gold,
                  isDark: isDark,
                  onTap: () => _met.setTimeSignature(6, 8)),
            ],
          ),
          const Spacer(),
          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Tap tempo
              GestureDetector(
                onTap: _onTapTempo,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_rounded,
                          color: theme.hintColor, size: 20),
                      Text('TAP',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: theme.hintColor)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 28),
              // Play/stop
              GestureDetector(
                onTap: () => _met.toggle(),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [gold, const Color(0xFFECC544)]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: gold.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Icon(
                    _met.isPlaying
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(width: 28),
              // Reset
              GestureDetector(
                onTap: () {
                  _met.stop();
                  _met.setBpm(120);
                  _tapTimes.clear();
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.refresh_rounded,
                      color: theme.hintColor, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _TimeSignatureChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color gold;
  final bool isDark;
  final VoidCallback onTap;
  const _TimeSignatureChip(
      {required this.label,
      required this.active,
      required this.gold,
      required this.isDark,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? gold
                : isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? Colors.white
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6))),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  KEY TRANSPOSER SHEET (standalone tool)
// ═══════════════════════════════════════════════════════════════════════
class _KeyTransposerSheet extends StatefulWidget {
  const _KeyTransposerSheet();
  @override
  State<_KeyTransposerSheet> createState() => _KeyTransposerSheetState();
}

class _KeyTransposerSheetState extends State<_KeyTransposerSheet> {
  int _offset = 0;
  late final TextEditingController _chordsCtrl;

  @override
  void initState() {
    super.initState();
    _chordsCtrl = TextEditingController(
        text: 'G  D  Em  C\nAm  Em  F  C\nG  D/F#  Em  C  G');
  }

  @override
  void dispose() {
    _chordsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gold = const Color(0xFFD4AF37);
    final sh = MediaQuery.of(context).size.height;

    final transposed = _chordsCtrl.text
        .split('\n')
        .map((line) => _transposeChordLine(line, _offset))
        .join('\n');

    return Container(
      height: sh * 0.75,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.hintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Key Transposer',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 20),
          // Transpose controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _offset = (_offset - 1) % 12;
                  if (_offset < 0) _offset += 12;
                }),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.remove_rounded, color: gold, size: 22),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      _offset == 0
                          ? 'Original'
                          : '${_offset > 6 ? '-${12 - _offset}' : '+$_offset'} semitones',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: gold),
                    ),
                    const SizedBox(height: 2),
                    Text('Transpose',
                        style: TextStyle(
                            fontSize: 11, color: theme.hintColor)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _offset = (_offset + 1) % 12),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.add_rounded, color: gold, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Reset button
          TextButton(
            onPressed: () => setState(() => _offset = 0),
            child: Text('Reset to Original',
                style: TextStyle(
                    color: theme.hintColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 8),
          // Input chords
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              maxLines: 3,
              controller: _chordsCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Enter chords',
                labelStyle: TextStyle(color: theme.hintColor),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.dividerColor)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: gold, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Transposed output
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: gold.withValues(alpha: 0.3)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.music_note_rounded, color: gold, size: 16),
                        const SizedBox(width: 6),
                        Text('Transposed',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: gold)),
                        const Spacer(),
                        if (_offset != 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_offset > 6 ? '-${12 - _offset}' : '+$_offset'} st',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: gold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(transposed,
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.8,
                            color: theme.colorScheme.onSurface)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  CHORD CHART SHEET
// ═══════════════════════════════════════════════════════════════════════
class _ChordChartSheet extends StatefulWidget {
  const _ChordChartSheet();
  @override
  State<_ChordChartSheet> createState() => _ChordChartSheetState();
}

class _ChordChartSheetState extends State<_ChordChartSheet> {
  String? _selectedSong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = const Color(0xFFD4AF37);
    final sh = MediaQuery.of(context).size.height;
    final isDark = theme.brightness == Brightness.dark;

    final songsWithChords = _sampleChords.keys.toList();

    return Container(
      height: sh * 0.75,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.hintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Chord Charts',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 16),
          // Song selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: songsWithChords.map((title) {
                final active = _selectedSong == title;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSong = title),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? gold
                          : isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active
                              ? gold
                              : theme.dividerColor),
                    ),
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color: active
                                ? Colors.white
                                : theme.colorScheme.onSurface)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Chord display
          Expanded(
            child: _selectedSong == null
                ? Center(
                    child: Text('Select a song to view chords',
                        style: TextStyle(
                            color: theme.hintColor, fontSize: 14)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            (_sampleChords[_selectedSong!] ?? []).map((line) {
                          final isSection = line.startsWith('[');
                          return Padding(
                            padding: EdgeInsets.only(
                                top: isSection ? 12 : 2, bottom: 2),
                            child: Text(line,
                                style: TextStyle(
                                    fontSize: isSection ? 12 : 15,
                                    fontWeight: isSection
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isSection
                                        ? gold
                                        : theme.colorScheme.onSurface,
                                    fontFamily: 'monospace',
                                    letterSpacing:
                                        isSection ? 1 : 0.5)),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  LYRICS SHEET
// ═══════════════════════════════════════════════════════════════════════
class _LyricsSheet extends StatefulWidget {
  const _LyricsSheet();
  @override
  State<_LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<_LyricsSheet> {
  String? _selectedSong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gold = const Color(0xFFD4AF37);
    final sh = MediaQuery.of(context).size.height;

    final songsWithLyrics = _sampleLyrics.keys.toList();

    return Container(
      height: sh * 0.75,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.hintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Song Lyrics',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 16),
          // Song selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: songsWithLyrics.map((title) {
                final active = _selectedSong == title;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSong = title),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? gold
                          : isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active
                              ? gold
                              : theme.dividerColor),
                    ),
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color: active
                                ? Colors.white
                                : theme.colorScheme.onSurface)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _selectedSong == null
                ? Center(
                    child: Text('Select a song to view lyrics',
                        style: TextStyle(
                            color: theme.hintColor, fontSize: 14)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Text(
                        _sampleLyrics[_selectedSong!] ?? '',
                        style: TextStyle(
                            fontSize: 14,
                            height: 1.8,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.8)),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  SETTINGS SHEET
// ═══════════════════════════════════════════════════════════════════════
class _SettingsSheet extends StatefulWidget {
  final MusicPlayerService service;
  const _SettingsSheet({required this.service});
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  MusicPlayerService get _s => widget.service;

  @override
  void initState() {
    super.initState();
    _s.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _s.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gold = const Color(0xFFD4AF37);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: theme.hintColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text('Music Settings',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded,
                        color: theme.hintColor, size: 22),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // ── Playback section ──
          _SettingsSectionHeader(title: 'Playback', isDark: isDark),
          // Repeat mode
          _SettingsTile(
            icon: _s.repeatMode == RepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            gold: gold,
            isDark: isDark,
            title: 'Repeat',
            subtitle: switch (_s.repeatMode) {
              RepeatMode.none => 'Off',
              RepeatMode.all => 'Repeat All',
              RepeatMode.one => 'Repeat One',
            },
            trailing: GestureDetector(
              onTap: () {
                _s.cycleRepeat();
                setState(() {});
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _s.repeatMode != RepeatMode.none
                      ? gold.withValues(alpha: 0.15)
                      : isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  switch (_s.repeatMode) {
                    RepeatMode.none => 'Off',
                    RepeatMode.all => 'All',
                    RepeatMode.one => 'One',
                  },
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _s.repeatMode != RepeatMode.none
                          ? gold
                          : theme.hintColor),
                ),
              ),
            ),
          ),
          // Shuffle
          _SettingsTile(
            icon: Icons.shuffle_rounded,
            gold: gold,
            isDark: isDark,
            title: 'Shuffle',
            subtitle: _s.isShuffling ? 'On' : 'Off',
            trailing: Switch(
              value: _s.isShuffling,
              onChanged: (_) {
                _s.toggleShuffle();
                setState(() {});
              },
              activeTrackColor: gold,
            ),
          ),
          // Playback speed
          _SettingsTile(
            icon: Icons.speed_rounded,
            gold: gold,
            isDark: isDark,
            title: 'Playback Speed',
            subtitle: '${_s.speed.toStringAsFixed(2)}x',
            trailing: SizedBox(
              width: 130,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: gold,
                  inactiveTrackColor: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                  thumbColor: gold,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  trackHeight: 3,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  min: 0.25,
                  max: 2.0,
                  divisions: 7,
                  value: _s.speed,
                  onChanged: (v) => _s.setSpeed(v),
                ),
              ),
            ),
          ),
          // ── About section ──
          _SettingsSectionHeader(title: 'About', isDark: isDark),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            gold: gold,
            isDark: isDark,
            title: 'Version',
            subtitle: 'FaithConnects 1.0.0',
            trailing: null,
          ),
          const SizedBox(height: 8),
        ],
        ),
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SettingsSectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Row(
        children: [
          Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: theme.hintColor,
                  letterSpacing: 1.2)),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
                thickness: 1,
                color: theme.dividerColor),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color gold;
  final bool isDark;
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _SettingsTile({
    required this.icon,
    required this.gold,
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: gold, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface)),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12, color: theme.hintColor)),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  SPEED TRAINER SHEET
// ═══════════════════════════════════════════════════════════════════════
class _SpeedTrainerSheet extends StatefulWidget {
  final MusicPlayerService service;
  const _SpeedTrainerSheet({required this.service});
  @override
  State<_SpeedTrainerSheet> createState() => _SpeedTrainerSheetState();
}

class _SpeedTrainerSheetState extends State<_SpeedTrainerSheet> {
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.service.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gold = const Color(0xFFD4AF37);
    final svc = widget.service;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.hintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Speed Trainer',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          if (svc.currentSong != null)
            Text('Playing: ${svc.currentSong!.title}',
                style: TextStyle(fontSize: 13, color: theme.hintColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          const SizedBox(height: 24),
          // Speed display
          Text('${svc.speed.toStringAsFixed(2)}x',
              style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: gold)),
          const SizedBox(height: 20),
          // Speed slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: gold,
              inactiveTrackColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              thumbColor: gold,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
              trackHeight: 4,
            ),
            child: Slider(
              min: 0.25,
              max: 2.0,
              divisions: 7,
              value: svc.speed,
              onChanged: (v) => svc.setSpeed(v),
            ),
          ),
          const SizedBox(height: 8),
          // Preset buttons
          Wrap(
            spacing: 8,
            children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
              final active = (svc.speed - s).abs() < 0.01;
              return GestureDetector(
                onTap: () => svc.setSpeed(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? gold
                        : isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('${s}x',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: active
                              ? Colors.white
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6))),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  CONTROL BUTTON (used in full player)
// ═══════════════════════════════════════════════════════════════════════
class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool isDark;
  final VoidCallback onTap;
  const _ControlBtn(
      {required this.icon,
      required this.size,
      required this.isDark,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size + 18,
        height: size + 18,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size, color: theme.iconTheme.color),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  WAVEFORM PAINTER (recording animation)
// ═══════════════════════════════════════════════════════════════════════
class _WaveformPainter extends CustomPainter {
  final double value;
  final Color color;
  _WaveformPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final rng = Random(42);
    const bars = 24;
    final gap = size.width / bars;
    for (int i = 0; i < bars; i++) {
      final base = rng.nextDouble() * 0.5 + 0.2;
      final animated = base + sin(value * pi * 2 + i * 0.3) * 0.3;
      final h = size.height * animated.clamp(0.1, 1.0);
      final x = gap * i + gap / 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.value != value;
}

// ═══════════════════════════════════════════════════════════════════════
//  SETLIST MODEL
// ═══════════════════════════════════════════════════════════════════════
class _Setlist {
  final String name;
  final List<int> songIndices;
  final DateTime createdAt;
  _Setlist(
      {required this.name,
      required this.songIndices,
      required this.createdAt});
}

// ═══════════════════════════════════════════════════════════════════════
//  CHORD TRANSPOSITION LOGIC
// ═══════════════════════════════════════════════════════════════════════
const _notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
const _flatNotes = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'];

String _transposeNote(String note, int semitones) {
  if (semitones == 0) return note;
  String root;
  if (note.length > 1 && (note[1] == '#' || note[1] == 'b')) {
    root = note.substring(0, 2);
  } else if (note.isNotEmpty) {
    root = note[0];
  } else {
    return note;
  }
  int idx = _notes.indexOf(root);
  if (idx == -1) idx = _flatNotes.indexOf(root);
  if (idx == -1) return note;
  int newIdx = (idx + semitones) % 12;
  if (newIdx < 0) newIdx += 12;
  return _notes[newIdx];
}

String _transposeChord(String chord, int semitones) {
  if (semitones == 0 || chord.isEmpty) return chord;
  // Handle slash chords like D/F#
  if (chord.contains('/')) {
    final parts = chord.split('/');
    return '${_transposeChord(parts[0], semitones)}/${_transposeChord(parts[1], semitones)}';
  }
  final regex = RegExp(r'^([A-G][#b]?)(.*)$');
  final match = regex.firstMatch(chord);
  if (match == null) return chord;
  final root = match.group(1)!;
  final quality = match.group(2) ?? '';
  return _transposeNote(root, semitones) + quality;
}

String _transposeChordLine(String line, int semitones) {
  if (semitones == 0 || line.startsWith('[')) return line;
  // Split by whitespace, transpose each chord-like token
  return line.split(RegExp(r'(\s+)')).map((token) {
    if (token.trim().isEmpty) return token;
    if (RegExp(r'^[A-G]').hasMatch(token)) {
      return _transposeChord(token, semitones);
    }
    return token;
  }).join('');
}

// ═══════════════════════════════════════════════════════════════════════
//  SAMPLE DATA — Chords & Lyrics for worship songs
// ═══════════════════════════════════════════════════════════════════════
const _defaultChords = [
  '[Verse]',
  'G  D  Em  C',
  'G  D  C',
  '[Chorus]',
  'Em  C  G  D',
  'C  G  D',
];

const Map<String, List<String>> _sampleChords = {
  'Amazing God': [
    '[Intro]',
    'G  D  Em  C',
    '[Verse 1]',
    'G          D',
    'Em         C',
    'G          D          C',
    '[Chorus]',
    'G    D/F#   Em   C',
    'G    D      C',
    'G    D/F#   Em   C',
    'Am   D      G',
  ],
  'Goodness of God': [
    '[Verse 1]',
    'C          G',
    'Am         F',
    'C          G',
    'Am         F',
    '[Chorus]',
    'C       G       Am      F',
    'C       G       F',
    'Am      G       F',
    'C       G       Am      F',
  ],
  'One Way Jesus': [
    '[Verse]',
    'E          B',
    'C#m        A',
    '[Chorus]',
    'E     B     C#m    A',
    'E     B     A',
    'E     B     C#m    A',
    'E     B     A      E',
  ],
  'Trust In God': [
    '[Verse]',
    'Bb         F',
    'Gm         Eb',
    '[Chorus]',
    'Bb    F     Gm     Eb',
    'Bb    F     Eb',
    'Gm    F     Eb',
    'Bb    F     Gm     Eb',
  ],
  'Worthy': [
    '[Verse]',
    'D          A',
    'Bm         G',
    '[Chorus]',
    'D     A     Bm     G',
    'D     A     G',
    'Bm    A     G      D',
  ],
  'Worthy Is The Lamb': [
    '[Verse]',
    'G          D/F#',
    'Em         C',
    '[Chorus]',
    'G     D     Em     C',
    'G     D     C      G',
    'Am    D     G',
  ],
  'By Your Love': [
    '[Verse]',
    'A          E',
    'F#m        D',
    '[Chorus]',
    'A     E     F#m    D',
    'A     E     D',
    'F#m   E     D      A',
  ],
};

const Map<String, String> _sampleLyrics = {
  'Amazing God': '''Amazing God, how great You are
You reign above the morning star
With all my heart I sing to You
Lord of all, I worship You

Amazing God, how great You are
Creator King, how great You are
We lift our voices high
And praise Your holy name

You are amazing God
You are amazing God
We stand in awe of who You are
Amazing God''',
  'Goodness of God': '''I love You, Lord
Oh Your mercy never failed me
All my days, I've been held in Your hands
From the moment that I wake up
Until I lay my head
Oh, I will sing of the goodness of God

All my life You have been faithful
All my life You have been so, so good
With every breath that I am able
Oh, I will sing of the goodness of God

I love Your voice
You have led me through the fire
And in darkest night You are close like no other
I've known You as a Father
I've known You as a Friend
And I have lived in the goodness of God''',
  'One Way Jesus': '''I lay my life down at Your feet
You're the only one I need
I turn to You and You are always there
In troubled times it's You I seek
I put You first that's all I need
I humble all I am all to You

One way, Jesus
You're the only one that I could live for
One way, Jesus
You're the only one that I could live for''',
  'Trust In God': '''No turn unstoned, no bridge unburned
Not a lesson left unlearned
I've made mistakes but He still wants me
No stone unturned, no chapter closed
Not a victory without a loss
I've learned from them all

Even when it's hard to trust You
Even when it costs me everything
I choose to trust You
I choose to trust You, God
I trust in Your name
Trust in Your word
Trust in God''',
  'Worthy': '''Worthy is the Lamb who was slain
Holy, holy is He
Sing a new song to Him who sits on
Heaven's mercy seat

Holy, holy, holy is the Lord God Almighty
Who was and is and is to come
With all creation I sing praise to the King of kings
You are my everything and I will adore You

Worthy, worthy, worthy
You are worthy, God''',
  'Worthy Is The Lamb': '''Thank You for the cross, Lord
Thank You for the price You paid
Bearing all my sin and shame
In love You came and gave amazing grace

Thank You for this love, Lord
Thank You for the nail-pierced hands
Washed me in Your cleansing flow
Now all I know, Your forgiveness and embrace

Worthy is the Lamb seated on the throne
Crown You now with many crowns
You reign victorious
High and lifted up, Jesus, Son of God
The Darling of heaven crucified
Worthy is the Lamb, worthy is the Lamb''',
  'By Your Love': '''By Your love, we are made whole
By Your grace, we are restored
Every chain is broken here
In Your presence, all our fear
Is washed away, is washed away

By Your love, we find our way
By Your light, we see the day
Every shadow has to flee
In Your name, we are set free
We are free, we are free

So we lift our voices high
And we worship You tonight
All the glory, all the praise
To the One who saves''',
};
