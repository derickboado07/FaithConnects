import 'package:flutter/material.dart';

/// A small, local rule-based suggestion bar that offers encouraging,
/// Christ-centered message suggestions and safe quick-reactions.
class MessageSuggestionBar extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String)? onInsert;

  const MessageSuggestionBar({
    super.key,
    required this.controller,
    this.onInsert,
  });

  @override
  State<MessageSuggestionBar> createState() => _MessageSuggestionBarState();
}

class _MessageSuggestionBarState extends State<MessageSuggestionBar> {
  List<String> _suggestions = [];

  static const List<String> _quickReactions = [
    '🙏 Praying for you',
    '❤️ Amen',
    '🙌 Praise God',
    '✨ Stay strong',
    '📖 God is with you',
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _computeSuggestions();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => _computeSuggestions();

  void _computeSuggestions() {
    final t = widget.controller.text.toLowerCase();
    final List<String> s = [];

    if (t.isEmpty) {
      // gentle starters when no input
      s.addAll([
        'Hi — how can I pray for you? 🙏',
        'Thinking of you — sending prayers and love. ❤️',
      ]);
    } else {
      if (t.contains('tired') ||
          t.contains('exhaust') ||
          t.contains('burnout')) {
        s.addAll([
          'Praying for strength for you. God is with you always ❤️',
          'I’m so sorry you’re tired — I’ll pray for rest and renewal. 🙏',
        ]);
      }
      if (t.contains('stressed') ||
          t.contains('anx') ||
          t.contains('worried')) {
        s.addAll([
          'I’m praying that God gives you peace and clarity. 🕊️',
          'Stay strong — God walks with you through this. ✨',
        ]);
      }
      if (t.contains('sad') || t.contains('down') || t.contains('lonely')) {
        s.addAll([
          'You’re not alone — praying for comfort and hope. 🙏',
          'Holding you in prayer and believing for brighter days. ❤️',
        ]);
      }
      if (t.contains('thanks') || t.contains('thank')) {
        s.add('That’s wonderful — praise God! 🙌');
      }
      // fallback gentle encouragement
      if (s.isEmpty) {
        s.add('I’m praying for you — how can I help? 🙏');
      }
    }

    setState(() => _suggestions = s.take(3).toList());
  }

  Widget _buildChip(String t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: GestureDetector(
        onTap: () {
          widget.controller.text = t;
          widget.controller.selection = TextSelection.collapsed(
            offset: t.length,
          );
          if (widget.onInsert != null) widget.onInsert!(t);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
              ),
            ],
          ),
          child: Text(t, style: const TextStyle(fontSize: 13)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_suggestions.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _suggestions.map(_buildChip).toList()),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickReactions.map((r) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8, top: 6),
                  child: GestureDetector(
                    onTap: () {
                      widget.controller.text = r;
                      widget.controller.selection = TextSelection.collapsed(
                        offset: r.length,
                      );
                      if (widget.onInsert != null) widget.onInsert!(r);
                    },
                    child: Chip(label: Text(r), backgroundColor: Colors.white),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
