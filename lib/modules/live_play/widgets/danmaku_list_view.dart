import 'dart:async';
import 'dart:ui' as ui;
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/emoji_manager.dart';
import 'package:pure_live/modules/live_play/player_state.dart';
import 'package:pure_live/modules/live_play/live_play_controller.dart';

class DanmakuListView extends StatefulWidget {
  final LiveRoom room;

  const DanmakuListView({super.key, required this.room});

  @override
  State<DanmakuListView> createState() => DanmakuListViewState();
}

class DanmakuListViewState extends State<DanmakuListView> {
  final ScrollController _scrollController = ScrollController();

  static const Duration throttleDuration = Duration(milliseconds: 120);

  bool userScrolling = false;

  bool pendingScroll = false;

  Timer? throttleTimer;

  Worker? fullscreenWorker;
  Worker? windowFullscreenWorker;

  StreamSubscription? messagesSub;
  bool _autoScrollEnabled = true;
  LivePlayController get controller => Get.find<LivePlayController>();

  @override
  void initState() {
    super.initState();

    messagesSub = controller.messages.listen((_) {
      scheduleAutoScroll();
    });

    fullscreenWorker = ever(GlobalPlayerState.to.isFullscreen, (value) {
      if (value == false) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          forceScrollToBottom();
        });
      }
    });

    windowFullscreenWorker = ever(GlobalPlayerState.to.isWindowFullscreen, (value) {
      if (value == false) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          forceScrollToBottom();
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      forceScrollToBottom();
    });
  }

  @override
  void dispose() {
    messagesSub?.cancel();

    fullscreenWorker?.dispose();
    windowFullscreenWorker?.dispose();

    throttleTimer?.cancel();

    _scrollController.dispose();

    super.dispose();
  }

  Future<void> forceScrollToBottom() async {
    if (!mounted) return;

    for (int i = 0; i < 3; i++) {
      await SchedulerBinding.instance.endOfFrame;

      if (!mounted) return;

      if (!_scrollController.hasClients) {
        continue;
      }

      final position = _scrollController.position;

      if (!position.hasContentDimensions) {
        continue;
      }

      final maxScroll = position.maxScrollExtent;

      if (position.pixels != maxScroll) {
        _scrollController.jumpTo(maxScroll);
      }
    }
  }

  void scheduleAutoScroll() {
    if (!mounted) return;
    if (!_autoScrollEnabled) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    bool shouldAutoScroll = true;
    if (position.hasContentDimensions) {
      final distanceToBottom = position.maxScrollExtent - position.pixels;
      shouldAutoScroll = distanceToBottom <= 120;
    }
    if (!shouldAutoScroll) {
      return;
    }
    pendingScroll = true;
    throttleTimer?.cancel();
    throttleTimer = Timer(throttleDuration, () async {
      if (!mounted) return;
      if (!pendingScroll) return;
      await forceScrollToBottom();
      pendingScroll = false;
    });
  }

  void onScrollNotification(ScrollNotification notification) {
    if (notification is! UserScrollNotification) {
      return;
    }

    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;

    final distanceToBottom = position.maxScrollExtent - position.pixels;

    if (notification.direction == ScrollDirection.forward) {
      if (distanceToBottom > 80) {
        if (!userScrolling) {
          setState(() {
            userScrolling = true;
            _autoScrollEnabled = false;
          });
        }
      }
    }

    if (notification.direction == ScrollDirection.reverse) {
      if (distanceToBottom < 60) {
        if (userScrolling) {
          setState(() {
            userScrolling = false;
          });
        }
      }
    }
    if (notification.direction == ScrollDirection.reverse || notification.direction == ScrollDirection.idle) {
      final distanceToBottom = position.maxScrollExtent - position.pixels;
      if (distanceToBottom <= 20) {
        if (!_autoScrollEnabled) {
          setState(() {
            _autoScrollEnabled = true;
            userScrolling = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
      decoration: BoxDecoration(
        color: Get.theme.colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Get.theme.colorScheme.outline.withValues(alpha: 0.02), width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                onScrollNotification(notification);
                return false;
              },
              child: Obx(() {
                final list = controller.messages;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  cacheExtent: 800,
                  itemCount: list.length,
                  itemBuilder: (_, index) {
                    final msg = list[index];

                    return DanmakuItem(key: ValueKey("${msg.userName}-${msg.message}-$index"), danmaku: msg);
                  },
                );
              }),
            ),

            if (userScrolling)
              Positioned(
                right: 12,
                bottom: 12,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    backgroundColor: Get.theme.colorScheme.primary.withValues(alpha: 0.92),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                  label: Text(i18n("scroll_to_bottom"), style: const TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () async {
                    setState(() {
                      userScrolling = false;
                      _autoScrollEnabled = true;
                    });

                    await forceScrollToBottom();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DanmakuItem extends StatelessWidget {
  final LiveMessage danmaku;

  const DanmakuItem({super.key, required this.danmaku});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = Color.fromARGB(255, danmaku.color.r, danmaku.color.g, danmaku.color.b);

    final vibrantColor =
        baseColor.toARGB32() == Colors.white.toARGB32() || baseColor.toARGB32() == Colors.black.toARGB32()
        ? (isDark ? Colors.white : Colors.black)
        : HSLColor.fromColor(baseColor).withLightness(isDark ? 0.75 : 0.52).withSaturation(1).toColor();

    final cardBgColor = isDark ? theme.cardColor.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.72);

    final textColor = isDark ? Colors.white70 : Colors.black87;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cardBgColor, // 动态背景色
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: vibrantColor.withValues(alpha: 0.08), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: vibrantColor.withValues(alpha: isDark ? 0.05 : 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  decoration: BoxDecoration(
                    color: vibrantColor,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: vibrantColor.withValues(alpha: 0.2), blurRadius: 6)],
                  ),
                ),

                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: () async {
                      final String textToCopy = "${danmaku.userName}: ${danmaku.message}";
                      try {
                        await Clipboard.setData(ClipboardData(text: textToCopy));
                        ToastUtil.show(i18n('copied_to_clipboard'));
                      } catch (e) {
                        debugPrint('Failed to copy to clipboard: $e');
                      }
                    },
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: "${danmaku.userName}: ",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
                          ),
                          TextSpan(
                            children: parseEmojis(danmaku.message, 14, vibrantColor),
                            style: TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w500, color: textColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final Map<String, List<InlineSpan>> emojiCache = {};

List<InlineSpan> parseEmojis(String text, double size, Color color) {
  final cacheKey = "$text-$size-${color.toARGB32()}";

  final cached = emojiCache[cacheKey];

  if (cached != null) {
    return cached;
  }

  final spans = <InlineSpan>[];

  final regex = RegExp(r'\[(.*?)\]');

  int last = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > last) {
      spans.add(
        TextSpan(
          text: text.substring(last, match.start),
          style: TextStyle(fontSize: size),
        ),
      );
    }

    final key = match.group(0)!;

    final image = EmojiManager.getEmoji(key);

    if (image != null) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(
            width: size * 1.25,
            height: size * 1.25,
            child: RepaintBoundary(child: CustomPaint(painter: EmojiPainter(image))),
          ),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: key,
          style: TextStyle(fontSize: size),
        ),
      );
    }

    last = match.end;
  }

  if (last < text.length) {
    spans.add(
      TextSpan(
        text: text.substring(last),
        style: TextStyle(fontSize: size),
      ),
    );
  }

  emojiCache[cacheKey] = spans;

  return spans;
}

class EmojiPainter extends CustomPainter {
  final ui.Image image;

  EmojiPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant EmojiPainter oldDelegate) {
    return oldDelegate.image != image;
  }
}
