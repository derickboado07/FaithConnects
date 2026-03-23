import 'package:flutter/material.dart';
import '../services/presence_service.dart';

/// A dialog that allows users to set or edit their personal note/status.
/// Includes faith-based suggestions.
class SetNoteDialog extends StatefulWidget {
  final String currentNote;

  const SetNoteDialog({super.key, this.currentNote = ''});

  /// Shows the dialog and returns the new note if saved, or null if cancelled.
  static Future<String?> show(BuildContext context, {String currentNote = ''}) {
    return showDialog<String>(
      context: context,
      builder: (_) => SetNoteDialog(currentNote: currentNote),
    );
  }

  @override
  State<SetNoteDialog> createState() => _SetNoteDialogState();
}

class _SetNoteDialogState extends State<SetNoteDialog> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentNote);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await PresenceService.instance.setNote(_ctrl.text.trim());
      if (mounted) Navigator.pop(context, _ctrl.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save note: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.edit_note, color: Color(0xFFD4AF37)),
          SizedBox(width: 8),
          Text('Set Your Note'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            maxLength: 100,
            decoration: const InputDecoration(
              hintText: 'Share what\'s on your heart...',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          const Text(
            'Suggestions:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF888888),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: PresenceService.faithNoteSuggestions.map((s) {
              return InkWell(
                onTap: () => _ctrl.text = s,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5E6B3).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(s, style: const TextStyle(fontSize: 12)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_ctrl.text.isNotEmpty)
          TextButton(
            onPressed: _saving
                ? null
                : () async {
                    _ctrl.clear();
                    await _save();
                  },
            child: const Text('Clear Note'),
          ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
