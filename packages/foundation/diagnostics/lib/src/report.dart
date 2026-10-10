// Module: lib/src/report.dart
// Purpose: Assembles a size-budgeted diagnostics report that says what it left out.
// Author: liuchuancong
// Created: 2026-10-11
//
// A report is sent through a channel with a limit - an Issue body, an email, a paste - and the naive one either
// exceeds it or silently stops mid-stack. Both are worse than no report: the first fails to send, the second
// reads like the trace ended where the buffer did. So budgets are per section and overall, the middle of a long
// section is what gets cut (the first line names the failure and the last one shows where it stopped), and every
// cut is written into the output as a count.

import 'dart:convert';

import 'redaction.dart';

/// The default overall size of a report, in bytes: under the limit of every transport this app has.
const int kReportTotalBudgetBytes = 64 * 1024;

/// The default per-section size, in bytes.
const int kReportSectionBudgetBytes = 8 * 1024;

/// One block of lines inside a report.
final class ReportSection {
  const ReportSection({required this.title, required this.lines, this.omittedLines = 0, this.omittedBytes = 0});

  final String title;
  final List<String> lines;

  /// Lines removed to meet a budget. Zero means this section arrived whole.
  final int omittedLines;
  final int omittedBytes;

  bool get isTruncated => omittedLines > 0 || omittedBytes > 0;

  String render() {
    final buffer = StringBuffer('# $title\n');
    for (final line in lines) {
      buffer.write('$line\n');
    }
    if (isTruncated) {
      buffer.write('… $omittedLines lines ($omittedBytes bytes) omitted to fit the section budget\n');
    }
    return buffer.toString();
  }
}

/// Collects sections and renders a report that fits.
final class DiagnosticReportBuilder {
  DiagnosticReportBuilder({
    this.title = 'Diagnostics report',
    this.totalBudgetBytes = kReportTotalBudgetBytes,
    this.sectionBudgetBytes = kReportSectionBudgetBytes,
    List<RedactionRule>? redactions,
    this.headRatio = 0.4,
  }) : _redactions = redactions ?? kDefaultRedactions,
       _sections = <ReportSection>[];

  final String title;
  final int totalBudgetBytes;
  final int sectionBudgetBytes;
  final List<RedactionRule> _redactions;

  /// How much of a cut section's budget goes to its beginning; the rest goes to its end.
  final double headRatio;

  final List<ReportSection> _sections;
  final Map<String, String> _header = <String, String>{};
  final Set<String> _redactionHits = <String>{};

  /// Key-value lines above the sections: version, platform, session id.
  void putHeader(String key, Object? value) {
    if (value == null) {
      return;
    }
    _header[key] = _scrub('$value');
  }

  /// Adds a section from lines.
  void addSection(String title, Iterable<String> lines) {
    _sections.add(_build(title, lines.map(_scrub)));
  }

  /// Adds a section from one blob of text, split on newlines.
  void addText(String title, String text) {
    addSection(title, const LineSplitter().convert(_scrub(text)));
  }

  /// Adds a section only when it is not empty, which is how a report skips a subsystem with nothing to say
  /// instead of printing a heading and a dash.
  void addSectionIfNotEmpty(String title, Iterable<String> lines) {
    final material = lines.where((line) => line.trim().isNotEmpty).toList(growable: false);
    if (material.isNotEmpty) {
      addSection(title, material);
    }
  }

  /// Section titles in insertion order, which is the order they will render in.
  List<String> get sectionTitles => _sections.map((section) => section.title).toList(growable: false);

  /// Every section, after their individual budgets were applied.
  List<ReportSection> get sections => List<ReportSection>.unmodifiable(_sections);

  /// Which redaction rule classes matched anything. A report that scrubbed something says so, because "the
  /// value is absent" and "the value was hidden" are different facts for whoever reads it.
  List<String> get redactedRules => _redactionHits.toList(growable: false);

  String render() {
    var body = StringBuffer();
    body.write('# $title\n');
    for (final entry in _header.entries) {
      body.write('${entry.key}: ${entry.value}\n');
    }
    if (_redactionHits.isNotEmpty) {
      body.write('redacted: ${_redactionHits.toList()..sort()}\n');
    }
    body.write('\n');

    final kept = <ReportSection>[];
    var used = utf8.encode(body.toString()).length;
    for (final section in _sections) {
      final cost = utf8.encode(section.render()).length;
      if (used + cost > totalBudgetBytes) {
        // The first section is never dropped: a report that lost its own headline error is not a report.
        if (kept.isEmpty) {
          final room = (totalBudgetBytes - used).clamp(0, sectionBudgetBytes);
          final trimmed = _cutToFit(section.lines, room);
          kept.add(
            ReportSection(
              title: section.title,
              lines: trimmed,
              omittedLines: section.lines.length - trimmed.length,
              omittedBytes: _linesBytes(section.lines) - _linesBytes(trimmed),
            ),
          );
          used = totalBudgetBytes;
        } else {
          kept.add(
            ReportSection(
              title: 'truncated',
              lines: <String>[
                '${_sections.length - kept.length} further section(s) left out to stay under '
                    '$totalBudgetBytes bytes',
              ],
              omittedBytes: _sections
                  .skip(kept.length - 1)
                  .fold(0, (sum, section) => sum + utf8.encode(section.render()).length),
            ),
          );
          used = totalBudgetBytes;
        }
        break;
      }
      kept.add(section);
      used += cost;
    }

    for (final section in kept) {
      body.write('\n');
      body.write(section.render());
    }
    return body.toString();
  }

  int get renderedBytes => utf8.encode(render()).length;

  /// True when anything at all was cut, section-wise or line-wise.
  bool get isPartial {
    if (_sections.any((section) => section.isTruncated)) {
      return true;
    }
    return _sections.any((section) => section.title == 'truncated');
  }

  void clear() {
    _sections.clear();
    _header.clear();
    _redactionHits.clear();
  }

  ReportSection _build(String title, Iterable<String> lines) {
    final all = lines.toList(growable: false);
    final cost = _linesBytes(all);
    if (cost <= sectionBudgetBytes) {
      return ReportSection(title: title, lines: all);
    }
    final kept = _keepHeadAndTail(all, sectionBudgetBytes);
    return ReportSection(
      title: title,
      lines: kept.lines,
      omittedLines: all.length - kept.lines.length,
      omittedBytes: cost - kept.bytes,
    );
  }

  /// Keeps the beginning and the end of a long section, dropping its middle.
  List<String> _cutToFit(List<String> lines, int budget) => _keepHeadAndTail(lines, budget).lines;

  _Kept _keepHeadAndTail(List<String> lines, int budget) {
    if (budget <= 0 || lines.isEmpty) {
      return const _Kept(<String>[], 0);
    }
    final kept = <String>[];
    var used = 0;
    final headTarget = (lines.length * headRatio).floor().clamp(1, lines.length);
    for (var index = 0; index < headTarget; index++) {
      final line = lines[index];
      final cost = _lineBytes(line);
      if (used + cost > budget ~/ 2) {
        break;
      }
      kept.add(line);
      used += cost;
    }
    final tail = <String>[];
    for (var index = lines.length - 1; index >= headTarget; index--) {
      final line = lines[index];
      final cost = _lineBytes(line);
      if (used + cost > budget) {
        break;
      }
      tail.insert(0, line);
      used += cost;
    }
    return _Kept(<String>[...kept, ...tail], used);
  }

  static int _linesBytes(List<String> lines) => lines.fold(0, (sum, line) => sum + _lineBytes(line));

  static int _lineBytes(String line) => utf8.encode(line).length + 1;

  String _scrub(String text) {
    final report = scrub(text, rules: _redactions);
    _redactionHits.addAll(report.appliedRules);
    return report.text;
  }
}

/// A line selection and what it costs.
final class _Kept {
  const _Kept(this.lines, this.bytes);

  final List<String> lines;
  final int bytes;
}
