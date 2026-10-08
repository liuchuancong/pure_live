import 'package:remixicon/remixicon.dart';

import 'package:pure_live/core/index.dart';

class AudioOnlyPresentation extends StatelessWidget {
  const AudioOnlyPresentation({super.key, required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final maxWidth = constraints.maxWidth;
        final compact = maxHeight < 500;
        final avatarRadius = compact ? (maxHeight * 0.11).clamp(25.0, 38.0) : 50.0;

        return IgnorePointer(
          child: ColoredBox(
            key: const ValueKey('audio-only-presentation'),
            color: Colors.black,
            child: Center(
              child: SingleChildScrollView(
                physics: compact ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24, vertical: compact ? 4 : 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? maxWidth : 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Avatar(radius: avatarRadius, url: room.avatar, name: room.nick),
                      SizedBox(height: compact ? 10 : 24),
                      Text(
                        key: const ValueKey('audio-only-title'),
                        _title(room),
                        textAlign: TextAlign.center,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: (compact ? AppTextStyles.t14 : AppTextStyles.t16).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _Badge(compact: compact, text: _nick(room)),
                      SizedBox(height: compact ? 8 : 16),
                      _Badge(compact: compact, icon: Remix.headphone_line, text: i18n('audio_only_mode')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.radius, required this.url, required this.name});

  final double radius;
  final String? url;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeNetworkImageUrl(url);
    final size = radius * 2;
    final placeholder = Icon(Remix.user_3_line, color: Colors.white24, size: radius);

    return Container(
      key: const ValueKey('audio-only-avatar'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
      ),
      child: ClipOval(
        child: normalized.isEmpty
            ? ColoredBox(color: Colors.white12, child: Center(child: placeholder))
            : Image.network(
                normalized,
                width: size,
                height: size,
                fit: BoxFit.cover,
                headers: networkImageHeaders(normalized),
                errorBuilder: (context, error, stackTrace) =>
                    ColoredBox(color: Colors.white12, child: Center(child: placeholder)),
              ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.compact, required this.text, this.icon});

  final bool compact;
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 3 : 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: compact ? 12 : 16),
            SizedBox(width: compact ? 4 : 8),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.t12.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _title(LiveRoom room) {
  final value = room.title?.trim() ?? '';
  return value.isEmpty ? _nick(room) : value;
}

String _nick(LiveRoom room) {
  final value = room.nick?.trim() ?? '';
  if (value.isNotEmpty) return value;
  final fallback = room.title?.trim() ?? '';
  return fallback.isEmpty ? i18n('untitled_room') : fallback;
}
