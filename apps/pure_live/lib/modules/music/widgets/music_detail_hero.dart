import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/shared/shared.dart'
    show CoverFallback, DetailHeroBackdrop, HeroPlayDisc, LiveWindow, cachedImage;

/// The module's one detail head — playlist, album, artist and chart alike —
/// drawn once instead of four near-copies: the cover blown up and blurred
/// into the block's own backdrop, the name and its facts on top of it, and
/// one large play disc anchoring the verbs.
///
/// The reference (网易云) reads as "the record leads"; a 72px square on a
/// flat canvas read as a settings row. The backdrop is only a tint — the
/// scrim holds every word on it readable.
final class MusicDetailHero extends StatelessWidget {
  /// Draws the head.
  const MusicDetailHero({
    required this.coverUri,
    required this.fallbackTitle,
    required this.title,
    this.subtitle,
    this.facts = const <String>[],
    this.description,
    this.onPlayAll,
    this.playSemanticLabel,
    this.actions = const <Widget>[],
    this.roundCover = false,
    super.key,
  });

  /// The cover picture, blurred behind and shown small in front.
  final Uri? coverUri;

  /// What the fallback tile names when no cover came.
  final String fallbackTitle;

  /// The head's name.
  final String title;

  /// A line above the facts — the artist link, a creator row.
  final Widget? subtitle;

  /// The plain figures (N 首 · 时长), joined with the module's separator.
  final List<String> facts;

  /// The record's own words, at most two lines.
  final String? description;

  /// The big disc's verb; without one the head shows no disc.
  final VoidCallback? onPlayAll;

  /// The disc's screen-reader label.
  final String? playSemanticLabel;

  /// The verbs beside the disc — random, download, collect.
  final List<Widget> actions;

  /// Draws the cover as a circle (the artist's page) rather than a tile.
  final bool roundCover;

  /// The cover's side, by the width the head has.
  static double coverSizeFor(double width) => width >= 720
      ? 148
      : width >= 440
      ? 116
      : 92;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
      child: DetailHeroBackdrop(
        coverImage: coverUri == null ? null : cachedImage(coverUri.toString(), policy: ImageCachePolicies.albumCover),
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.s20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = coverSizeFor(constraints.maxWidth);
              final cover = ClipRRect(
                borderRadius: BorderRadius.circular(roundCover ? 999 : 16),
                child: SizedBox.square(
                  dimension: size,
                  child: coverUri == null
                      ? CoverFallback(title: fallbackTitle)
                      : DsImage(
                          image: cachedImage(coverUri.toString(), policy: ImageCachePolicies.albumCover),
                          width: size,
                          height: size,
                          semanticLabel: title,
                          fallback: CoverFallback(title: fallbackTitle),
                        ),
                ),
              );
              return Row(
                spacing: DsSpace.s20,
                children: [
                  if (!roundCover)
                    DecoratedBox(
                      decoration: DsBoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        shadows: [
                          DsShadow(color: colors.overlay, blur: DsSpace.s24, offset: const Offset(0, DsSpace.s8)),
                        ],
                      ),
                      child: cover,
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: DsSpace.s6,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.heading.copyWith(color: colors.text),
                        ),
                        ?subtitle,
                        if (facts.isNotEmpty)
                          Text(
                            facts.where((part) => part.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.caption.copyWith(color: colors.textMuted),
                          ),
                        if (description case final text? when text.isNotEmpty)
                          Text(
                            text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.caption.copyWith(color: colors.textSubtle, height: 1.45),
                          ),
                        if (onPlayAll != null || actions.isNotEmpty) ...[
                          const SizedBox(height: DsSpace.s4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: DsSpace.s8,
                            runSpacing: DsSpace.s8,
                            children: [
                              if (onPlayAll != null)
                                HeroPlayDisc(onPressed: onPlayAll, semanticLabel: playSemanticLabel),
                              ...actions,
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The track whose cover a head borrows when the record itself names none.
audio.MusicTrack? heroCoverTrack(List<audio.MusicTrack> tracks) => tracks.firstOrNull;
