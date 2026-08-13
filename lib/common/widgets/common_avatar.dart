import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CommonAvatar extends StatelessWidget {
  final String? avatarUrl;
  final bool dense;
  final double? radius;
  final String? fallbackName;
  const CommonAvatar({super.key, required this.avatarUrl, this.dense = false, this.radius, this.fallbackName});
  @override
  Widget build(BuildContext context) {
    final double r = radius ?? (dense ? 17.0 : 20.0);
    final double size = r * 2;
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    Widget fallback() {
      final String text = (fallbackName != null && fallbackName!.isNotEmpty)
          ? fallbackName!.characters.first.toUpperCase()
          : '';
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).disabledColor.withAlpha(80)),
        child: Text(
          text,
          style: TextStyle(fontSize: r * 0.8, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (!hasAvatar) return fallback();

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(48, 256).toInt(),
          maxWidthDiskCache: 256,
          fadeInDuration: const Duration(milliseconds: 100),
          fadeOutDuration: Duration.zero,
          placeholder: (_, _) => Container(color: Theme.of(context).disabledColor.withValues(alpha: 0.2)),
          errorWidget: (_, _, _) => fallback(),
        ),
      ),
    );
  }
}
