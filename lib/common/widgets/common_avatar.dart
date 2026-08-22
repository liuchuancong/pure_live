import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/common/utils/network_image_url.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/common/services/settings_service.dart';

class CommonAvatar extends StatefulWidget {
  final String? avatarUrl;
  final bool dense;
  final double? radius;
  final String? fallbackName;

  const CommonAvatar({super.key, required this.avatarUrl, this.dense = false, this.radius, this.fallbackName});

  @override
  State<CommonAvatar> createState() => _CommonAvatarState();
}

class _CommonAvatarState extends State<CommonAvatar> {
  String? _processedAvatarUrl;
  int? _processedEpoch;

  @override
  void initState() {
    super.initState();

    _scheduleCacheCheck();
  }

  @override
  void didUpdateWidget(covariant CommonAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUrl = normalizeNetworkImageUrl(oldWidget.avatarUrl);
    final newUrl = normalizeNetworkImageUrl(widget.avatarUrl);
    if (oldUrl != newUrl && oldUrl.isNotEmpty) {
      unawaited(CustomImageCacheManager.remove(oldUrl));
      _processedAvatarUrl = null;
      _processedEpoch = null;
    }

    _scheduleCacheCheck();
  }

  void _scheduleCacheCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _checkImageCache();
    });
  }

  Future<void> _checkImageCache() async {
    final avatarUrl = normalizeNetworkImageUrl(widget.avatarUrl);

    if (avatarUrl.isEmpty) {
      return;
    }

    final epoch = SettingsService.to.cache.imageCacheEpoch.value;
    if (_processedAvatarUrl == avatarUrl && _processedEpoch == epoch) {
      return;
    }
    _processedAvatarUrl = avatarUrl;
    _processedEpoch = epoch;

    await CustomImageCacheManager.remove(avatarUrl);
  }

  @override
  Widget build(BuildContext context) {
    final double r = widget.radius ?? (widget.dense ? 17.0 : 20.0);

    final double size = r * 2;

    final normalizedAvatarUrl = normalizeNetworkImageUrl(widget.avatarUrl);

    final hasAvatar = normalizedAvatarUrl.isNotEmpty;

    Widget fallback() {
      final String text = (widget.fallbackName != null && widget.fallbackName!.isNotEmpty)
          ? widget.fallbackName!.characters.first.toUpperCase()
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

    if (!hasAvatar) {
      return fallback();
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: normalizedAvatarUrl,
          httpHeaders: networkImageHeaders(normalizedAvatarUrl),
          cacheManager: CustomImageCacheManager.instance,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          useOldImageOnUrlChange: true,
          placeholder: (_, _) {
            return Container(color: Theme.of(context).disabledColor.withValues(alpha: 0.2));
          },
          errorWidget: (_, _, _) {
            return fallback();
          },
        ),
      ),
    );
  }
}
