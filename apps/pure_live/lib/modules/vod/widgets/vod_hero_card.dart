import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// The deep band under the featured cover's lower half, so the title, the
/// figures and the play verb keep their contrast over a bright picture — the
/// room cover's scrim carried up to a full-width banner.
const LinearGradient kVodHeroScrim = LinearGradient(
  begin: AlignmentDirectional.bottomCenter,
  end: AlignmentDirectional.topCenter,
  colors: [Color(0xE6000000), Color(0x99000000), Color(0x00000000)],
  stops: [0.0, 0.4, 0.85],
);

/// The ink on the featured cover: pure white for the title, a softened white
/// for the figures — the cover chips' ink family at a banner's sizes.
const Color _inkOnCover = Color(0xFFFFFFFF);
const Color _inkOnCoverMuted = Color(0xCCFFFFFF);

/// The recommend feed's featured head: the feed's first archive at the page's
/// full width, its cover under a deep scrim carrying the title, the figures
/// and the play verb — the station's own banner for the tab the platform
/// draws for this viewer. The narrow page keeps the plain grid: two columns
/// under a 44 head have no room for a banner, and the phone mocks none.
final class VodHeroCard extends StatelessWidget {
  /// The hero for [video]; [onOpen] opens its page — the whole banner and
  /// the play verb read the same archive.
  const VodHeroCard({required this.video, required this.onOpen, super.key});

  /// The archive featured.
  final VodVideo video;

  /// Opens the archive.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final t = context.t;
    final plays = switch (video.playCount) {
      final value? when value > 0 => AudienceFormat.format(value),
      _ => null,
    };
    final danmaku = switch (video.danmakuCount) {
      final value? when value > 0 => AudienceFormat.format(value),
      _ => null,
    };
    final uploader = (video.uploader ?? '').trim();
    return DsPressable(
      semanticLabel: video.title,
      onPressed: onOpen,
      builder: (context, states, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(theme.radii.card),
          child: SizedBox(
            height: 240,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _cover(context),
                // The scrim only darkens; the press target is the whole
                // banner and the button rides above it.
                const Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(decoration: BoxDecoration(gradient: kVodHeroScrim)),
                  ),
                ),
                PositionedDirectional(
                  start: DsSpace.s20,
                  end: DsSpace.s20,
                  bottom: DsSpace.s16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.title.copyWith(color: _inkOnCover),
                      ),
                      if (uploader.isNotEmpty || plays != null || danmaku != null) ...[
                        const SizedBox(height: DsSpace.s6),
                        _HeroMeta(uploader: uploader, plays: plays, danmaku: danmaku),
                      ],
                      const SizedBox(height: DsSpace.s12),
                      DsButton(
                        variant: DsButtonVariant.primary,
                        size: DsSize.sm,
                        leading: const DsIcon(DsIcons.play, size: 16),
                        onPressed: onOpen,
                        child: Text(t.vod.playNow),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cover(BuildContext context) {
    final fallback = CoverFallback(title: video.title, padding: const EdgeInsets.all(DsSpace.s8));
    final url = video.coverUrl;
    if (url == null || url.isEmpty) return fallback;
    return DsImage(
      image: cachedImage(url, policy: ImageCachePolicies.videoCover),
      semanticLabel: video.title,
      fallback: fallback,
    );
  }
}

/// The featured cover's figure line: the uploader, then the play and danmaku
/// counts, separated by middots like the reference's own banner.
final class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.uploader, required this.plays, required this.danmaku});

  final String uploader;
  final String? plays;
  final String? danmaku;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final style = theme.typography.caption.copyWith(color: _inkOnCoverMuted);
    final pieces = <Widget>[
      if (uploader.isNotEmpty) Text(uploader, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      if (plays != null) _figure(DsIcons.play, plays!, style),
      if (danmaku != null) _figure(DsIcons.captions, danmaku!, style),
    ];
    return Row(
      children: [
        for (final (index, piece) in pieces.indexed) ...[
          if (index > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.s6),
              child: Text('·', style: style),
            ),
          piece,
        ],
      ],
    );
  }

  Widget _figure(DsIconData icon, String label, TextStyle style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DsIcon(icon, size: 12, color: _inkOnCoverMuted),
        const SizedBox(width: DsSpace.s3),
        Text(label, style: style),
      ],
    );
  }
}
