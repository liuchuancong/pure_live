import 'package:remixicon/remixicon.dart';

import 'package:pure_live/core/index.dart';

class DummyVideoCover extends StatelessWidget {
  const DummyVideoCover({super.key, required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final candidates = [room.cover, room.avatar];
    var image = '';
    for (final candidate in candidates) {
      final normalized = normalizeNetworkImageUrl(candidate);
      if (normalized.isNotEmpty) {
        image = normalized;
        break;
      }
    }

    return IgnorePointer(
      child: ColoredBox(
        key: const ValueKey('dummy-video-cover'),
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image.isNotEmpty)
              Image.network(
                image,
                fit: BoxFit.cover,
                headers: networkImageHeaders(image),
                errorBuilder: (context, error, stackTrace) => const SizedBox.expand(),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Remix.headphone_line, size: 14, color: Colors.white.withValues(alpha: 0.85)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          i18n('dummy_video_cover_notice'),
                          key: const ValueKey('dummy-video-notice'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.t12.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
