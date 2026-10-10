// Module: lib/src/poster_card.dart
// Purpose: The poster card used by every content grid: cover, one-line title, optional subtitle, tap target.
// Author: liuchuancong
// Created: 2026-10-10
//
// The card is where the token set earns its keep: a grid tile is the most repeated element in the app, and
// its width, corner and label size used to be picked by whichever feature built it. [width] is now honoured
// (it was declared and ignored, so a caller who passed it got a silently different layout than one who did
// not), and the label uses the readable-size floor instead of whichever TextTheme the active style builds.

import 'package:flutter/material.dart';

import 'package:pure_live_design/pure_live_design.dart';

import 'tokens_theme.dart';

/// A poster card. [onTap] is caller-owned navigation; the card renders cover, title and subtitle and nothing
/// else.
final class PosterCard extends StatelessWidget {
  const PosterCard({required this.title, this.subtitle, this.cover, this.onTap, this.width, super.key});

  final String title;
  final String? subtitle;
  final String? cover;
  final VoidCallback? onTap;

  /// The tile width. Null lets the grid decide, which is what a `SliverGrid` with a delegate does.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.designTokens;
    final label = Padding(
      padding: EdgeInsets.all(tokens.gapBetween(ControlKind.chip)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: tokens.typeSize(TypeRole.bodyMedium)),
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                // A poster subtitle is exactly the text that goes unreadable at a distance: it is smaller
                // than the title and sits over a busy cover.
                fontSize: tokens.typeSize(TypeRole.bodySmall),
                color: theme.colorScheme.outline,
              ),
            ),
        ],
      ),
    );
    final card = Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      // A focused poster tile has to be distinguishable without moving the row it sits in, which is why the
      // ring is drawn as a border on the card rather than a scale transform on the tile.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RadiusToken.medium.px),
        side: _focusSide(theme, context),
      ),
      child: InkWell(
        onTap: onTap,
        focusColor: Colors.transparent,
        hoverColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        child: width == null ? _column(label) : SizedBox(width: width, child: _column(label)),
      ),
    );
    return card;
  }

  Column _column(Widget label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(child: CoverImage(cover: cover)),
      label,
    ],
  );

  BorderSide _focusSide(ThemeData theme, BuildContext context) {
    final tokens = context.themeTokens;
    final color = tokens.color(ColorRole.focus);
    return tokens.focusRing(color ?? theme.colorScheme.tertiary) ?? BorderSide.none;
  }
}

/// The cover image with an icon placeholder on missing or failed loads.
final class CoverImage extends StatelessWidget {
  const CoverImage({required this.cover, this.icon = Icons.movie_outlined, super.key});

  final String? cover;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.designTokens;
    final placeholder = ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          icon,
          size: switch (tokens.input) {
            InputMode.remote => 48,
            InputMode.touch => 36,
            InputMode.pointer => 28,
          },
          color: theme.colorScheme.outline,
        ),
      ),
    );
    if (cover == null || cover!.isEmpty) {
      return placeholder;
    }
    return Image.network(
      cover!,
      fit: BoxFit.cover,
      width: double.infinity,
      // A broken url should not leave an empty box: the placeholder is what tells the viewer the tile is
      // there and the artwork is not.
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (_, child, progress) => progress == null ? child : placeholder,
    );
  }
}
