import 'dart:io';

import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:pure_live/core/index.dart';

/// The player manual: concepts, every setting and what it does, organized in
/// collapsible chapters. Pure documentation — nothing here mutates state.
///
/// The chapter table is a compile-time constant on purpose: it is content, not
/// configuration, and rebuilding ~40 rows on every frame of the scroll view
/// bought nothing. What it holds now is only the row ids and how each row
/// renders; the wording lives in the locale bundles, so the manual can be
/// reworded without touching Dart and can no longer show Chinese prose inside
/// the English UI.
class PlayerGuidePage extends StatefulWidget {
  const PlayerGuidePage({super.key});

  @override
  State<PlayerGuidePage> createState() => _PlayerGuidePageState();
}

enum _GuidePlatform {
  android,
  windows;

  String get nameKey => 'player_guide_platform_$name';

  bool get isCurrent => switch (this) {
    _GuidePlatform.android => Platform.isAndroid,
    _GuidePlatform.windows => Platform.isWindows,
  };
}

class _GuideEntry {
  const _GuideEntry(this.id, {this.badge, this.onlyOn, this.mono = false});

  /// Stable identity of the row; its title and body keys derive from it.
  final String id;

  /// A short capability tag (`hwdec`, `vo`, `ao`).
  final String? badge;

  /// The row only applies on this platform; the chapter then shows it as a tag
  /// on every other platform instead of hiding it.
  final _GuidePlatform? onlyOn;

  /// Render the heading in monospace, because it is an mpv switch and not a
  /// phrase. Declared rather than sniffed from the text: the English title of a
  /// row may well read as a phrase while the row still documents one switch.
  final bool mono;

  String get titleKey => 'player_guide_entry_${id}_title';
  String get bodyKey => 'player_guide_entry_${id}_body';
  String get badgeKey => 'player_guide_badge_$badge';
}

class _GuideChapter {
  const _GuideChapter(this.icon, this.id, this.entries);

  final IconData icon;
  final String id;
  final List<_GuideEntry> entries;

  String get titleKey => 'player_guide_chapter_$id';
}

const List<_GuideChapter> _guideChapters = [
  _GuideChapter(Icons.school_rounded, 'concepts', [
    _GuideEntry('hardware_switch'),
    _GuideEntry('hwdec', badge: 'hwdec', mono: true),
    _GuideEntry('vo', badge: 'vo', mono: true),
    _GuideEntry('ao', badge: 'ao', mono: true),
  ]),
  _GuideChapter(Icons.auto_fix_high_rounded, 'presets', [
    _GuideEntry('preset_default'),
    _GuideEntry('preset_android_compat', onlyOn: _GuidePlatform.android),
    _GuideEntry('preset_rtx_sr', onlyOn: _GuidePlatform.windows),
    _GuideEntry('preset_low_end'),
    _GuideEntry('preset_weak_network'),
    _GuideEntry('preset_low_latency'),
  ]),
  _GuideChapter(Icons.tune_rounded, 'picture_sync', [
    _GuideEntry('video_sync', badge: 'vo', mono: true),
    _GuideEntry('interpolation', mono: true),
    _GuideEntry('scale', mono: true),
    _GuideEntry('deinterlace', mono: true),
  ]),
  _GuideChapter(Icons.hd_rounded, 'quality', [
    _GuideEntry('rtx_super_resolution', onlyOn: _GuidePlatform.windows),
    _GuideEntry('danmaku_limit'),
    _GuideEntry('hwdec_codecs', badge: 'hwdec', mono: true),
  ]),
  _GuideChapter(Icons.volume_up_rounded, 'audio', [
    _GuideEntry('audio_exclusive', onlyOn: _GuidePlatform.windows, mono: true),
    _GuideEntry('ao_advice', badge: 'ao'),
  ]),
  _GuideChapter(Icons.healing_rounded, 'symptoms', [
    _GuideEntry('sym_glitch'),
    _GuideEntry('sym_blurry'),
    _GuideEntry('sym_fan'),
    _GuideEntry('sym_buffering'),
    _GuideEntry('sym_latency'),
    _GuideEntry('sym_no_video'),
  ]),
];

class _PlayerGuidePageState extends State<PlayerGuidePage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n('player_guide_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _buildIntroCard(context, theme),
          for (var i = 0; i < _guideChapters.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              clipBehavior: Clip.antiAlias,
              // ExpansionTile paints a rule above and below the open panel; the
              // chapter cards already separate the sections, so both go.
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: PageStorageKey('guide-$i'),
                  initiallyExpanded: i == 0,
                  leading: Icon(_guideChapters[i].icon, color: theme.colorScheme.primary, size: 24),
                  title: Text(i18n(_guideChapters[i].titleKey), style: theme.textTheme.titleMedium),
                  subtitle: Text(
                    i18n('player_guide_entries', args: {'count': _guideChapters[i].entries.length.toString()}),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  children: [for (final entry in _guideChapters[i].entries) _GuideEntryView(entry: entry)],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The manual link and the reading order in one row: two stacked cards used
  /// to push the first chapter below the fold on a laptop window.
  Widget _buildIntroCard(BuildContext context, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => launchUrlString('https://mpv.io/manual/', mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.menu_book_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i18n('player_guide_manual_title'), style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      i18n('player_guide_manual_hint'),
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5, color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              const Icon(Remix.arrow_right_s_line, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// One manual row. `mono` rows render their heading inside a monospace chip;
/// every other heading is a phrase and renders plainly — long labels inside a
/// tiny monospace chip were unreadable.
class _GuideEntryView extends StatelessWidget {
  const _GuideEntryView({required this.entry});

  final _GuideEntry entry;

  List<String> get _tags {
    final onlyOn = entry.onlyOn;
    return [
      if (entry.badge != null) i18n(entry.badgeKey),
      // A platform-only row is still worth reading elsewhere, so it is labelled
      // rather than hidden.
      if (onlyOn != null && !onlyOn.isCurrent) i18n(onlyOn.nameKey),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = _tags;
    final title = Text(
      i18n(entry.titleKey),
      style: entry.mono
          ? theme.textTheme.labelLarge?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onPrimaryContainer,
            )
          : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );

    return SizedBox(
      // ExpansionTile lays its children out in a centered Column, so a row
      // narrower than the panel would otherwise float to the middle.
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (entry.mono)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: title,
                  )
                else
                  title,
                for (final tag in tags)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(tag, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(i18n(entry.bodyKey), style: theme.textTheme.bodyLarge?.copyWith(height: 1.65)),
          ],
        ),
      ),
    );
  }
}
