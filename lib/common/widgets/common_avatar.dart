import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/common/utils/network_image_url.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/common/services/settings_service.dart';

class CommonAvatar extends StatelessWidget {
  final String? avatarUrl;
  final bool dense;
  final double? size;
  final String? fallbackName;

  const CommonAvatar({super.key, this.avatarUrl, this.dense = false, this.size, this.fallbackName});

  bool _isNetwork(String value) {
    return RegExp(r'^(?:https?:)?//', caseSensitive: false).hasMatch(value.trim());
  }

  bool _isAsset(String value) {
    return value.trim().toLowerCase().startsWith('assets/');
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = size ?? (dense ? 34 : 40);
    final value = avatarUrl?.trim() ?? '';

    Widget fallback() {
      final text = fallbackName != null && fallbackName!.isNotEmpty
          ? fallbackName!.characters.first.toUpperCase()
          : '';

      return Container(
        alignment: Alignment.center,
        color: Theme.of(context).disabledColor.withValues(alpha: 80 / 255),
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(fontSize: avatarSize * 0.4, fontWeight: FontWeight.bold),
        ),
      );
    }

    Widget child;

    if (_isNetwork(value)) {
      final url = normalizeNetworkImageUrl(value);

      child = Obx(() {
        final epoch = SettingsService.to.cache.imageCacheEpoch.value;

        return CachedNetworkImage(
          imageUrl: url,
          cacheKey: epoch == 0 ? url : '$url#$epoch',
          httpHeaders: networkImageHeaders(url),
          cacheManager: CustomImageCacheManager.instance,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          memCacheWidth: (avatarSize * MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(48, 256)
              .toInt(),
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          useOldImageOnUrlChange: true,
          placeholder: (_, _) =>
              Container(color: Theme.of(context).disabledColor.withValues(alpha: 0.2)),
          errorWidget: (_, _, _) => fallback(),
        );
      });
    } else if (_isAsset(value)) {
      child = Image.asset(value, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback());
    } else {
      child = fallback();
    }

    return SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: ClipOval(child: child),
    );
  }
}
