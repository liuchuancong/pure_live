import 'package:flutter/material.dart';
import 'package:live_uikit/live_uikit.dart';

/// The update notes' markdown, rendered lightly (3.x `MarkdownText`):
/// headings, bullets, numbered lists, rules and paragraphs, with inline
/// **bold** and `code` markers stripped. Everything else shows as plain
/// text.
///
/// A trimmed port of the reference's renderer — no markdown widget
/// dependency; release notes rarely need richer structure.
final class MarkdownText extends StatelessWidget {
  /// Shows [data].
  const new(this.data, {super.key});

  /// The markdown source.
  final String data;

  static final RegExp _heading = RegExp(r'^(#{1,6})\s+(.*)$');
  static final RegExp _bullet = RegExp(r'^(\s*)[-*+]\s+(.*)$');
  static final RegExp _numbered = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$');
  static final RegExp _rule = RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = data.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SelectionArea(child: Text(_inline(paragraph.join(' ')))),
          ),
        );
        paragraph.clear();
      }
    }

    for (final line in lines) {
      final trimmed = line.trim();
      final heading = _heading.firstMatch(trimmed);
      final bullet = _bullet.firstMatch(line);
      final numbered = _numbered.firstMatch(line);
      if (_rule.hasMatch(trimmed)) {
        flushParagraph();
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(height: 1, color: LiveTheme.of(context).colors.border),
          ),
        );
      } else if (heading != null) {
        flushParagraph();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              _inline(heading.group(2) ?? ''),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 16 - heading.group(1)!.length.toDouble(),
              ),
            ),
          ),
        );
      } else if (bullet != null || numbered != null) {
        flushParagraph();
        final marker = bullet != null ? '•' : '${numbered!.group(2)}.';
        final text = bullet?.group(2) ?? numbered!.group(3)!;
        widgets.add(
          Padding(padding: const EdgeInsets.only(left: 16, bottom: 2), child: Text('$marker  ${_inline(text)}')),
        );
      } else if (trimmed.isEmpty) {
        flushParagraph();
      } else {
        paragraph.add(trimmed);
      }
    }
    flushParagraph();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widgets);
  }

  /// The inline pass: **bold** and `code` markers fold away — release
  /// notes rarely need richer inline spans.
  static String _inline(String text) => text.replaceAll('**', '').replaceAll('`', '');
}
