import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/images/app_image_cache.dart' show cachedImage;

/// The black cover the room shows instead of the picture in ASMR/audio-only
/// mode: the streamer's avatar, the room title, the streamer's name and the
/// headphone badge (the reference's `AudioOnlyPresentation`).
final class AudioOnlyCover extends StatelessWidget {
  /// Creates the cover for [room].
  const AudioOnlyCover({required this.room, super.key});

  /// The room whose identity the cover shows.
  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final title = room.content.title.trim();
    final name = room.anchor?.name.trim() ?? '';
    final avatar = room.anchor?.avatarUrl?.trim() ?? '';
    return ColoredBox(
      key: const ValueKey('audio-only-presentation'),
      color: const Color(0xFF000000),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 500;
          final radius = compact ? (constraints.maxHeight * 0.11).clamp(25.0, 38.0) : 50.0;
          final size = radius * 2;
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: compact ? DsSpace.s16 : DsSpace.s24, vertical: DsSpace.s8),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? constraints.maxWidth : 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipOval(
                      child: SizedBox.square(
                        dimension: size,
                        child: avatar.isEmpty
                            ? const ColoredBox(
                                color: Color(0x1FFFFFFF),
                                child: Center(child: DsIcon(DsIcons.user, size: 32, color: Color(0x66FFFFFF))),
                              )
                            : Image(
                                image: cachedImage(avatar, width: size.toInt(), height: size.toInt()),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    SizedBox(height: compact ? DsSpace.s12 : DsSpace.s24),
                    Text(
                      title.isEmpty ? name : title,
                      textAlign: TextAlign.center,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: (compact ? theme.typography.bodyStrong : theme.typography.title).copyWith(
                        color: const Color(0xFFFFFFFF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (name.isNotEmpty) ...[const SizedBox(height: DsSpace.s8), _Badge(text: name)],
                    SizedBox(height: compact ? DsSpace.s8 : DsSpace.s16),
                    _Badge(icon: DsIcons.headphones, text: t.room.audioOnlyMode),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A translucent pill on the black cover.
final class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.icon});

  final String text;
  final DsIconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s4),
      decoration: DsBoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [
          if (icon case final icon?) DsIcon(icon, size: theme.sizes.iconXs, color: const Color(0xD9FFFFFF)),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(color: const Color(0xE6FFFFFF), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
