import 'package:flutter/material.dart';

import '../services/bible_service.dart';

const _gold = Color(0xFFD4AF37);

Color _bg(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF1A1A2E) : const Color(0xFFF5F5FA);
Color _card(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF16213E) : Colors.white;
Color _border(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF2D2D44) : const Color(0xFFE0E0E0);
Color _onBg(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A2E);
Color _onBgSub(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF555555);
Color _onBgHint(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF777777);
Color _onBgMuted(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF999999);
Color _onBgFaint(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? Colors.white24 : const Color(0xFFBDBDBD);

class BibleNotesScreen extends StatefulWidget {
  const BibleNotesScreen({super.key});

  @override
  State<BibleNotesScreen> createState() => _BibleNotesScreenState();
}

class _BibleNotesScreenState extends State<BibleNotesScreen> {

  List<Map<String, dynamic>> _notes = [];
  List<String> _folders = ['General'];
  String? _activeFolder;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await BibleService.instance.getNotes();
    final folders = await BibleService.instance.getNoteFolders();
    if (!mounted) {
      return;
    }
    setState(() {
      _notes = notes;
      _folders = folders;
      _loading = false;
    });
  }

  int _folderCount(String folder) {
    return _notes.where((note) => note['folder'] == folder).length;
  }

  List<Map<String, dynamic>> get _activeFolderNotes {
    if (_activeFolder == null) {
      return _notes;
    }
    return _notes.where((note) => note['folder'] == _activeFolder).toList();
  }

  Future<void> _addFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card(context),
        title: Text(
          'New Folder',
          style: TextStyle(color: _onBg(context)),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: _onBg(context)),
          decoration: InputDecoration(
            hintText: 'Folder name',
            hintStyle: TextStyle(color: _onBgMuted(context)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _onBgFaint(context)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _gold),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _onBgHint(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create', style: TextStyle(color: _gold)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) {
      return;
    }
    await BibleService.instance.addNoteFolder(name);
    await _load();
  }

  Future<void> _deleteFolder(String folder) async {
    if (folder == 'General') {
      return;
    }
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card(context),
        title: Text(
          'Delete Folder',
          style: TextStyle(color: _onBg(context)),
        ),
        content: Text(
          'Delete "$folder"? Notes in this folder will be moved to General.',
          style: TextStyle(color: _onBgSub(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _onBgHint(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (shouldDelete != true) {
      return;
    }
    await BibleService.instance.deleteNoteFolder(folder);
    if (_activeFolder == folder) {
      _activeFolder = null;
    }
    await _load();
  }

  Future<void> _openEditor({
    Map<String, dynamic>? existing,
    String? folder,
    String? initialTitle,
    String? initialVerseRef,
  }) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BibleNoteEditorScreen(
          note: existing,
          folders: _folders,
          initialFolder: folder,
          initialTitle: initialTitle,
          initialVerseRef: initialVerseRef,
        ),
      ),
    );
    if (result == true) {
      await _load();
    }
  }

  Future<void> _deleteNote(String id) async {
    await BibleService.instance.deleteNote(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _activeFolder == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _activeFolder != null) {
          setState(() => _activeFolder = null);
        }
      },
      child: Scaffold(
        backgroundColor: _bg(context),
        appBar: AppBar(
          backgroundColor: _bg(context),
          iconTheme: IconThemeData(color: _onBg(context)),
          leading: _activeFolder != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _activeFolder = null),
                )
              : null,
          title: Text(
            _activeFolder == null ? 'Bible Notes' : _activeFolder!,
            style: TextStyle(color: _onBg(context), fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined, color: _gold),
              onPressed: _addFolder,
              tooltip: 'New Folder',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: _gold,
          onPressed: () => _openEditor(folder: _activeFolder ?? 'General'),
          child: const Icon(Icons.add, color: Colors.black),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _gold))
            : (_activeFolder == null ? _buildFolderBrowser() : _buildFolderNotes()),
      ),
    );
  }

  Widget _buildFolderBrowser() {
    final recentNotes = _notes.take(5).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Text(
          'Folders',
          style: TextStyle(
            color: _onBg(context),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _folders.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, index) {
            final folder = _folders[index];
            return _FolderCard(
              folder: folder,
              count: _folderCount(folder),
              onTap: () => setState(() => _activeFolder = folder),
              onDelete: folder == 'General' ? null : () => _deleteFolder(folder),
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'Recent Notes',
              style: TextStyle(
                color: _onBg(context),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${_notes.length}',
              style: TextStyle(color: _onBgMuted(context)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recentNotes.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _card(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border(context)),
            ),
            child: Column(
              children: [
                Icon(Icons.note_alt_outlined, color: _onBgFaint(context), size: 48),
                const SizedBox(height: 10),
                Text(
                  'No notes yet. Tap + to create one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _onBgHint(context), fontSize: 14),
                ),
              ],
            ),
          )
        else
          ...recentNotes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NoteTile(
                note: note,
                onTap: () => _openEditor(existing: note),
                onDelete: () => _deleteNote(note['id'] as String),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFolderNotes() {
    final notes = _activeFolderNotes;
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.folder_open, color: _gold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activeFolder!,
                      style: TextStyle(
                        color: _onBg(context),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${notes.length} note${notes.length == 1 ? '' : 's'}',
                      style: TextStyle(color: _onBgHint(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_activeFolder != 'General')
                IconButton(
                  icon: Icon(Icons.delete_outline, color: _onBgHint(context)),
                  onPressed: () => _deleteFolder(_activeFolder!),
                ),
            ],
          ),
        ),
        Expanded(
          child: notes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_copy_outlined, color: _onBgFaint(context), size: 56),
                        const SizedBox(height: 12),
                        Text(
                          'No notes in this folder.',
                          style: TextStyle(color: _onBgSub(context), fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Open a folder from the main notes view or tap + to add one here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _onBgMuted(context), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NoteTile(
                        note: note,
                        onTap: () => _openEditor(existing: note),
                        onDelete: () => _deleteNote(note['id'] as String),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.folder,
    required this.count,
    required this.onTap,
    this.onDelete,
  });

  final String folder;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: _card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.folder, color: _gold),
                  ),
                  const Spacer(),
                  if (onDelete != null)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz, color: _onBgMuted(context)),
                      color: _card(context),
                      onSelected: (value) {
                        if (value == 'delete') {
                          onDelete!.call();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Delete folder', style: TextStyle(color: _onBg(context))),
                        ),
                      ],
                    ),
                ],
              ),
              const Spacer(),
              Text(
                folder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _onBg(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count note${count == 1 ? '' : 's'}',
                style: TextStyle(color: _onBgHint(context), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = (note['title'] as String?)?.trim().isNotEmpty == true
        ? note['title'] as String
        : 'Untitled';
    final content = note['content'] as String? ?? '';
    final folder = note['folder'] as String? ?? 'General';
    final verseRef = note['verseRef'] as String? ?? '';
    final createdAt = note['createdAt'] as String? ?? '';
    String dateLabel = '';
    final date = DateTime.tryParse(createdAt);
    if (date != null) {
      dateLabel = '${date.month}/${date.day}/${date.year}';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: _card(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _onBg(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, color: _onBgMuted(context), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              if (verseRef.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  verseRef,
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _NotePreview(
                text: content,
                maxLines: 4,
                emptyLabel: 'No note content.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.folder_outlined, size: 14, color: _onBgMuted(context)),
                  const SizedBox(width: 4),
                  Text(folder, style: TextStyle(color: _onBgMuted(context), fontSize: 12)),
                  const Spacer(),
                  if (dateLabel.isNotEmpty)
                    Text(dateLabel, style: TextStyle(color: _onBgFaint(context), fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BibleNoteEditorScreen extends StatefulWidget {
  const BibleNoteEditorScreen({
    super.key,
    this.note,
    required this.folders,
    this.initialFolder,
    this.initialTitle,
    this.initialVerseRef,
  });

  final Map<String, dynamic>? note;
  final List<String> folders;
  final String? initialFolder;
  final String? initialTitle;
  final String? initialVerseRef;

  @override
  State<BibleNoteEditorScreen> createState() => _BibleNoteEditorScreenState();
}

class _BibleNoteEditorScreenState extends State<BibleNoteEditorScreen> {

  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late String _folder;
  bool _saving = false;
  bool _previewMode = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
      text: widget.note?['title'] as String? ?? widget.initialTitle ?? '',
    );
    _contentCtrl = TextEditingController(
      text: widget.note?['content'] as String? ?? '',
    );
    _folder = widget.note?['folder'] as String? ?? widget.initialFolder ?? widget.folders.first;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    final verseRef = widget.note?['verseRef'] as String? ?? widget.initialVerseRef ?? '';
    if (title.isEmpty && content.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    if (_isEditing) {
      await BibleService.instance.updateNote(
        widget.note!['id'] as String,
        title: title.isEmpty ? 'Untitled' : title,
        content: content,
        folder: _folder,
      );
    } else {
      await BibleService.instance.addNote(
        title: title.isEmpty ? 'Untitled' : title,
        content: content,
        folder: _folder,
        verseRef: verseRef.isEmpty ? null : verseRef,
      );
    }
    if (!mounted) {
      return;
    }
    Navigator.pop(context, true);
  }

  void _wrapSelection(String prefix, [String suffix = '']) {
    final selection = _contentCtrl.selection;
    final text = _contentCtrl.text;
    if (!selection.isValid) {
      final next = '$text$prefix$suffix';
      _contentCtrl.value = _contentCtrl.value.copyWith(
        text: next,
        selection: TextSelection.collapsed(offset: next.length - suffix.length),
      );
      return;
    }
    final start = selection.start;
    final end = selection.end;
    final selectedText = text.substring(start, end);
    final replacement = '$prefix$selectedText$suffix';
    final updated = text.replaceRange(start, end, replacement);
    _contentCtrl.value = _contentCtrl.value.copyWith(
      text: updated,
      selection: TextSelection(
        baseOffset: start + prefix.length,
        extentOffset: start + prefix.length + selectedText.length,
      ),
    );
  }

  void _prefixCurrentLine(String prefix) {
    final selection = _contentCtrl.selection;
    final text = _contentCtrl.text;
    final cursor = selection.isValid ? selection.start : text.length;
    final lineStart = text.lastIndexOf('\n', cursor <= 0 ? 0 : cursor - 1) + 1;
    final updated = text.replaceRange(lineStart, lineStart, prefix);
    final delta = prefix.length;
    _contentCtrl.value = _contentCtrl.value.copyWith(
      text: updated,
      selection: TextSelection.collapsed(offset: cursor + delta),
    );
  }

  Future<void> _pickColor() async {
    const colors = <String, Color>{
      'FFD700': Color(0xFFFFD700),
      'FF9800': Color(0xFFFF9800),
      '4CAF50': Color(0xFF4CAF50),
      '42A5F5': Color(0xFF42A5F5),
      '9C27B0': Color(0xFF9C27B0),
      'E91E63': Color(0xFFE91E63),
      'F44336': Color(0xFFF44336),
      'FFFFFF': Color(0xFFFFFFFF),
    };
    final hex = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: colors.entries
                .map(
                  (entry) => InkWell(
                    onTap: () => Navigator.pop(context, entry.key),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: entry.value,
                        shape: BoxShape.circle,
                        border: Border.all(color: _onBgFaint(context)),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (hex == null) {
      return;
    }
    _wrapSelection('[color=#$hex]', '[/color]');
  }

  @override
  Widget build(BuildContext context) {
    final verseRef = widget.note?['verseRef'] as String? ?? widget.initialVerseRef ?? '';
    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        backgroundColor: _bg(context),
        iconTheme: IconThemeData(color: _onBg(context)),
        title: Text(
          _isEditing ? 'Edit Note' : 'New Note',
          style: TextStyle(color: _onBg(context), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _previewMode = !_previewMode),
            icon: Icon(_previewMode ? Icons.edit_outlined : Icons.visibility_outlined),
            tooltip: _previewMode ? 'Edit' : 'Preview',
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
                  )
                : const Text('Save', style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (verseRef.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_outlined, color: _gold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      verseRef,
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _card(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _border(context)),
                  ),
                  child: TextField(
                    controller: _titleCtrl,
                    style: TextStyle(
                      color: _onBg(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: 'The title of this note is about...',
                      hintStyle: TextStyle(color: _onBgMuted(context)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _card(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_outlined, size: 16, color: _onBgMuted(context)),
                      const SizedBox(width: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _folder,
                          dropdownColor: _card(context),
                          style: TextStyle(color: _onBgSub(context), fontSize: 13),
                          items: widget.folders
                              .map((folder) => DropdownMenuItem<String>(
                                    value: folder,
                                    child: Text(folder, style: TextStyle(color: _onBg(context))),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _folder = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _EditorToolbar(
                  onH1: () => _prefixCurrentLine('# '),
                  onH2: () => _prefixCurrentLine('## '),
                  onH3: () => _prefixCurrentLine('### '),
                  onBold: () => _wrapSelection('**', '**'),
                  onItalic: () => _wrapSelection('*', '*'),
                  onBullet: () => _prefixCurrentLine('- '),
                  onNumber: () => _prefixCurrentLine('1. '),
                  onColor: _pickColor,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _card(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _gold.withValues(alpha: 0.45)),
                ),
                child: _previewMode
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _NotePreview(
                          text: _contentCtrl.text,
                          emptyLabel: 'Preview will appear here.',
                        ),
                      )
                    : TextField(
                        controller: _contentCtrl,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: TextStyle(
                          color: _onBg(context),
                          fontSize: 15,
                          height: 1.7,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Write your note here. Use the toolbar for H1/H2/H3, color, bullets, and numbering.',
                          hintStyle: TextStyle(color: _onBgFaint(context)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(20),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.onH1,
    required this.onH2,
    required this.onH3,
    required this.onBold,
    required this.onItalic,
    required this.onBullet,
    required this.onNumber,
    required this.onColor,
  });

  final VoidCallback onH1;
  final VoidCallback onH2;
  final VoidCallback onH3;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onBullet;
  final VoidCallback onNumber;
  final VoidCallback onColor;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ToolbarButton(label: 'H1', onTap: onH1),
          _ToolbarButton(label: 'H2', onTap: onH2),
          _ToolbarButton(label: 'H3', onTap: onH3),
          _ToolbarButton(label: 'B', onTap: onBold, bold: true),
          _ToolbarButton(label: 'I', onTap: onItalic, italic: true),
          _ToolbarButton(icon: Icons.format_list_bulleted, onTap: onBullet),
          _ToolbarButton(icon: Icons.format_list_numbered, onTap: onNumber),
          _ToolbarButton(icon: Icons.format_color_text, onTap: onColor),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    this.label,
    this.icon,
    required this.onTap,
    this.bold = false,
    this.italic = false,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool bold;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border(context)),
          ),
          child: icon != null
              ? Icon(icon, color: _onBgSub(context), size: 18)
              : Text(
                  label!,
                  style: TextStyle(
                    color: _onBg(context),
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
        ),
      ),
    );
  }
}

class _NotePreview extends StatelessWidget {
  const _NotePreview({
    required this.text,
    this.maxLines,
    required this.emptyLabel,
  });

  final String text;
  final int? maxLines;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return Text(
        emptyLabel,
        style: TextStyle(color: _onBgFaint(context), fontSize: 14),
      );
    }
    final lines = text.split('\n');
    final children = <Widget>[];
    for (final line in lines) {
      children.add(_buildLine(line, context));
      children.add(const SizedBox(height: 6));
    }
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    if (maxLines == null) {
      return content;
    }
    return DefaultTextStyle.merge(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      child: content,
    );
  }

  Widget _buildLine(String rawLine, BuildContext context) {
    final line = rawLine.trimRight();
    double fontSize = 14;
    FontWeight fontWeight = FontWeight.w400;
    String content = line;

    if (line.startsWith('### ')) {
      fontSize = 18;
      fontWeight = FontWeight.w700;
      content = line.substring(4);
    } else if (line.startsWith('## ')) {
      fontSize = 20;
      fontWeight = FontWeight.w700;
      content = line.substring(3);
    } else if (line.startsWith('# ')) {
      fontSize = 24;
      fontWeight = FontWeight.w800;
      content = line.substring(2);
    }

    final bulletPrefix = content.startsWith('- ') ? '• ' : '';
    final numberMatch = RegExp(r'^(\d+)\.\s').firstMatch(content);
    if (content.startsWith('- ')) {
      content = content.substring(2);
    } else if (numberMatch != null) {
      content = content.substring(numberMatch.group(0)!.length);
    }

    return RichText(
      text: TextSpan(
        children: [
          if (bulletPrefix.isNotEmpty)
            TextSpan(
              text: '• ',
              style: TextStyle(color: _onBgSub(context), fontSize: 14, fontWeight: FontWeight.w700),
            ),
          if (numberMatch != null)
            TextSpan(
              text: '${numberMatch.group(1)}. ',
              style: TextStyle(color: _onBgSub(context), fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ..._inlineSpans(content, context: context, fontSize: fontSize, fontWeight: fontWeight),
        ],
      ),
    );
  }

  List<InlineSpan> _inlineSpans(
    String text, {
    required BuildContext context,
    required double fontSize,
    required FontWeight fontWeight,
  }) {
    final spans = <InlineSpan>[];
    int index = 0;
    while (index < text.length) {
      final colorStart = text.indexOf('[color=#', index);
      final boldStart = text.indexOf('**', index);
      final italicStart = text.indexOf('*', index);

      final candidates = <int>[colorStart, boldStart, italicStart]
          .where((value) => value >= 0)
          .toList()
        ..sort();
      if (candidates.isEmpty) {
        spans.add(_plainSpan(text.substring(index), context, fontSize, fontWeight));
        break;
      }

      final next = candidates.first;
      if (next > index) {
        spans.add(_plainSpan(text.substring(index, next), context, fontSize, fontWeight));
      }

      if (next == colorStart) {
        final tagEnd = text.indexOf(']', colorStart);
        final closeTag = text.indexOf('[/color]', tagEnd + 1);
        if (tagEnd < 0 || closeTag < 0) {
          spans.add(_plainSpan(text.substring(colorStart), context, fontSize, fontWeight));
          break;
        }
        final hex = text.substring(colorStart + 8, tagEnd);
        final inner = text.substring(tagEnd + 1, closeTag);
        spans.add(
          TextSpan(
            text: inner,
            style: TextStyle(
              color: _parseHexColor(hex),
              fontSize: fontSize,
              fontWeight: fontWeight,
              height: 1.6,
            ),
          ),
        );
        index = closeTag + 8;
        continue;
      }

      if (next == boldStart) {
        final close = text.indexOf('**', boldStart + 2);
        if (close < 0) {
          spans.add(_plainSpan(text.substring(boldStart), context, fontSize, fontWeight));
          break;
        }
        final inner = text.substring(boldStart + 2, close);
        spans.add(
          TextSpan(
            text: inner,
            style: TextStyle(
              color: _onBg(context),
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1.6,
            ),
          ),
        );
        index = close + 2;
        continue;
      }

      final close = text.indexOf('*', italicStart + 1);
      if (close < 0) {
        spans.add(_plainSpan(text.substring(italicStart), context, fontSize, fontWeight));
        break;
      }
      final inner = text.substring(italicStart + 1, close);
      spans.add(
        TextSpan(
          text: inner,
          style: TextStyle(
            color: _onBg(context),
            fontSize: fontSize,
            fontWeight: fontWeight,
            fontStyle: FontStyle.italic,
            height: 1.6,
          ),
        ),
      );
      index = close + 1;
    }
    return spans;
  }

  TextSpan _plainSpan(String text, BuildContext context, double fontSize, FontWeight fontWeight) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: _onBgSub(context),
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: 1.6,
      ),
    );
  }

  Color _parseHexColor(String hex) {
    final clean = hex.replaceAll('#', '').toUpperCase();
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
    return Colors.white;
  }
}
