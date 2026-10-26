import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// The complete playback guide: six chapters of concepts, presets, tuning,
/// audio and symptom checks. Pure documentation — nothing here writes state.
Future<void> showPlayerGuide(BuildContext context) =>
    showDsDialog<void>(context: context, builder: (context) => const _PlayerGuideDialog());

/// mpv's official manual, the external link in the guide's intro card.
final Uri _mpvManual = Uri.parse('https://mpv.io/manual/');

final class _GuideEntry {
  const _GuideEntry({
    required this.title,
    required this.body,
    this.badge,
    this.onlyOn,
    this.mono = false,
  });

  final String title;
  final String body;

  /// A short capability tag (`hwdec`, `vo`, `ao`).
  final String? badge;

  /// The row only applies on this platform; it stays readable elsewhere with
  /// a tag instead of being hidden.
  final TargetPlatform? onlyOn;

  /// The heading is an mpv switch, so it renders in monospace.
  final bool mono;
}

final class _GuideChapter {
  const _GuideChapter({required this.icon, required this.title, required this.entries});

  final DsIconData icon;
  final String title;
  final List<_GuideEntry> entries;
}

final class _PlayerGuideDialog extends StatelessWidget {
  const _PlayerGuideDialog();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final chapters = _chapters(t);
    return DsDialog(
      title: Text(t.settings.playerGuideTitle),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Text(t.settings.playerGuideSubtitle, style: theme.typography.small.copyWith(color: colors.textMuted)),
          DsListSection(
            children: [
              DsListRow(
                leading: const DsIcon(DsIcons.bookOpenText),
                title: Text(t.settings.playerGuideManualTitle),
                description: Text(t.settings.playerGuideManualHint),
                trailing: const DsIcon(DsIcons.externalLink, size: 16),
                onPressed: () => unawaited(launchUrl(_mpvManual, mode: LaunchMode.externalApplication)),
              ),
            ],
          ),
          Text(t.settings.playerGuideIntro, style: theme.typography.small.copyWith(color: colors.textMuted)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s8,
                children: [
                  for (var i = 0; i < chapters.length; i++)
                    _GuideChapterTile(chapter: chapters[i], initiallyOpen: i == 0),
                ],
              ),
            ),
          ),
        ],
      ),
      style: const DsDialogStyle(width: 640),
      actions: [
        DsButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.common.close)),
      ],
    );
  }

  static List<_GuideChapter> _chapters(Translations t) {
    final s = t.settings;
    return [
      _GuideChapter(
        icon: DsIcons.school,
        title: s.playerGuideChapterConcepts,
        entries: [
          _GuideEntry(
            title: s.playerGuideEntryHardwareSwitchTitle,
            body: s.playerGuideEntryHardwareSwitchBody,
          ),
          _GuideEntry(
            title: s.playerGuideEntryHwdecTitle,
            body: s.playerGuideEntryHwdecBody,
            badge: s.playerGuideBadgeHwdec,
            mono: true,
          ),
          _GuideEntry(
            title: s.playerGuideEntryVoTitle,
            body: s.playerGuideEntryVoBody,
            badge: s.playerGuideBadgeVo,
            mono: true,
          ),
          _GuideEntry(
            title: s.playerGuideEntryAoTitle,
            body: s.playerGuideEntryAoBody,
            badge: s.playerGuideBadgeAo,
            mono: true,
          ),
        ],
      ),
      _GuideChapter(
        icon: DsIcons.wandSparkles,
        title: s.playerGuideChapterPresets,
        entries: [
          _GuideEntry(
            title: s.playerGuideEntryPresetDefaultTitle,
            body: s.playerGuideEntryPresetDefaultBody,
          ),
          _GuideEntry(
            title: s.playerGuideEntryPresetAndroidCompatTitle,
            body: s.playerGuideEntryPresetAndroidCompatBody,
            onlyOn: TargetPlatform.android,
          ),
          _GuideEntry(
            title: s.playerGuideEntryPresetRtxSrTitle,
            body: s.playerGuideEntryPresetRtxSrBody,
            onlyOn: TargetPlatform.windows,
          ),
          _GuideEntry(
            title: s.playerGuideEntryPresetLowEndTitle,
            body: s.playerGuideEntryPresetLowEndBody,
          ),
          _GuideEntry(
            title: s.playerGuideEntryPresetWeakNetworkTitle,
            body: s.playerGuideEntryPresetWeakNetworkBody,
          ),
          _GuideEntry(
            title: s.playerGuideEntryPresetLowLatencyTitle,
            body: s.playerGuideEntryPresetLowLatencyBody,
          ),
        ],
      ),
      _GuideChapter(
        icon: DsIcons.slidersHorizontal,
        title: s.playerGuideChapterPictureSync,
        entries: [
          _GuideEntry(
            title: s.playerGuideEntryVideoSyncTitle,
            body: s.playerGuideEntryVideoSyncBody,
            mono: true,
          ),
          _GuideEntry(
            title: s.playerGuideEntryInterpolationTitle,
            body: s.playerGuideEntryInterpolationBody,
            mono: true,
          ),
          _GuideEntry(
            title: s.playerGuideEntryScaleTitle,
            body: s.playerGuideEntryScaleBody,
            mono: true,
          ),
          _GuideEntry(
            title: s.playerGuideEntryDeinterlaceTitle,
            body: s.playerGuideEntryDeinterlaceBody,
            mono: true,
          ),
        ],
      ),
      _GuideChapter(
        icon: DsIcons.hd,
        title: s.playerGuideChapterQuality,
        entries: [
          _GuideEntry(
            title: s.playerGuideEntryRtxSuperResolutionTitle,
            body: s.playerGuideEntryRtxSuperResolutionBody,
            onlyOn: TargetPlatform.windows,
          ),
          _GuideEntry(
            title: s.playerGuideEntryDanmakuLoadTitle,
            body: s.playerGuideEntryDanmakuLoadBody,
          ),
          _GuideEntry(
            title: s.playerGuideEntryHwdecCodecsTitle,
            body: s.playerGuideEntryHwdecCodecsBody,
            badge: s.playerGuideBadgeHwdec,
            mono: true,
          ),
        ],
      ),
      _GuideChapter(
        icon: DsIcons.volumeUp,
        title: s.playerGuideChapterAudio,
        entries: [
          _GuideEntry(
            title: s.playerGuideEntryAudioExclusiveTitle,
            body: s.playerGuideEntryAudioExclusiveBody,
            onlyOn: TargetPlatform.windows,
            mono: true,
          ),
          _GuideEntry(
            title: s.playerGuideEntryAoAdviceTitle,
            body: s.playerGuideEntryAoAdviceBody,
            badge: s.playerGuideBadgeAo,
          ),
        ],
      ),
      _GuideChapter(
        icon: DsIcons.stethoscope,
        title: s.playerGuideChapterSymptoms,
        entries: [
          _GuideEntry(
            title: s.playerGuideEntrySymGlitchTitle,
            body: s.playerGuideEntrySymGlitchBody,
          ),
          _GuideEntry(
            title: s.playerGuideEntrySymBlurryTitle,
            body: s.playerGuideEntrySymBlurryBody,
          ),
          _GuideEntry(
            title: s.playerGuideEntrySymFanTitle,
            body: s.playerGuideEntrySymFanBody,
          ),
          _GuideEntry(
            title: s.playerGuideEntrySymBufferingTitle,
            body: s.playerGuideEntrySymBufferingBody,
          ),
          _GuideEntry(
            title: s.playerGuideEntrySymLatencyTitle,
            body: s.playerGuideEntrySymLatencyBody,
          ),
          _GuideEntry(
            title: s.playerGuideEntrySymNoVideoTitle,
            body: s.playerGuideEntrySymNoVideoBody,
          ),
        ],
      ),
    ];
  }
}

final class _GuideChapterTile extends StatefulWidget {
  const _GuideChapterTile({required this.chapter, required this.initiallyOpen});

  final _GuideChapter chapter;
  final bool initiallyOpen;

  @override
  State<_GuideChapterTile> createState() => _GuideChapterTileState();
}

final class _GuideChapterTileState extends State<_GuideChapterTile> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return DsListSection(
      children: [
        DsListRow(
          leading: DsIcon(widget.chapter.icon),
          title: Text(widget.chapter.title, style: theme.typography.bodyStrong),
          trailing: DsIcon(_open ? DsIcons.chevronUp : DsIcons.chevronDown, size: 16),
          onPressed: () => setState(() => _open = !_open),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s12,
              children: [
                for (final entry in widget.chapter.entries) _GuideEntryView(entry: entry),
              ],
            ),
          ),
      ],
    );
  }
}

final class _GuideEntryView extends StatelessWidget {
  const _GuideEntryView({required this.entry});

  final _GuideEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final tags = [
      if (entry.badge != null) entry.badge!,
      if (entry.onlyOn == TargetPlatform.android) t.settings.playerGuidePlatformAndroid,
      if (entry.onlyOn == TargetPlatform.windows) t.settings.playerGuidePlatformWindows,
    ];
    final titleStyle = entry.mono
        ? theme.typography.labelStrong.copyWith(fontFamily: 'monospace', color: colors.accentText)
        : theme.typography.bodyStrong;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s6,
      children: [
        Wrap(
          spacing: DsSpace.s8,
          runSpacing: DsSpace.s4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (entry.mono)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.accentTint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: Text(entry.title, style: titleStyle),
                ),
              )
            else
              Text(entry.title, style: titleStyle),
            for (final tag in tags)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.borderChip),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  child: Text(tag, style: theme.typography.caption.copyWith(color: colors.textMuted)),
                ),
              ),
          ],
        ),
        Text(entry.body, style: theme.typography.small.copyWith(color: colors.textMuted, height: 1.55)),
      ],
    );
  }
}
