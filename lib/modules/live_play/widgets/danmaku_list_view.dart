import 'dart:async';
import 'dart:ui' as ui;
import 'package:get/get.dart';
import 'package:flutter/rendering.dart';
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
  bool _scrollHappen = false;
  StreamSubscription? _messagesSubscription;

  // 节流相关变量
  Timer? _throttleTimer;
  bool _needsScroll = false;
  static const _throttleDuration = Duration(milliseconds: 150);

  LivePlayController get controller => Get.find<LivePlayController>();

  @override
  void initState() {
    super.initState();
    // 监听消息变化，使用节流逻辑处理滚动
    _messagesSubscription = controller.messages.listen((p0) {
      _throttledScroll();
    });

    // 监听全屏切换，确保状态同步
    GlobalPlayerState.to.isWindowFullscreen.listen((value) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), _checkScrollPositionManually);
      }
    });
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _throttleTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void scrollToBottom() {
    _throttledScroll();
  }

  /// 核心节流滚动逻辑
  void _throttledScroll() {
    if (!mounted || _scrollHappen) return;

    _needsScroll = true;
    if (_throttleTimer?.isActive ?? false) return;

    _throttleTimer = Timer(_throttleDuration, () {
      if (_needsScroll && mounted && _scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        // 使用 jumpTo 替代 animateTo 性能更好
        _scrollController.jumpTo(maxScroll);
        _needsScroll = false;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_scrollHappen) {
      _throttledScroll();
    }
  }

  void _checkScrollPositionManually() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final isAtBottom = pos.maxScrollExtent - pos.pixels <= 100;
    if (isAtBottom && _scrollHappen) {
      setState(() => _scrollHappen = false);
    }
  }

  void _onNotification(ScrollNotification notification) {
    // This handles the user manual scroll action
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.forward) {
        // User is scrolling up
        if (_scrollController.position.maxScrollExtent - _scrollController.offset > 100) {
          if (!_scrollHappen) setState(() => _scrollHappen = true);
        }
      } else if (notification.direction == ScrollDirection.reverse) {
        // User is scrolling back down
        final pos = _scrollController.position;
        if (pos.maxScrollExtent - pos.pixels <= 50) {
          if (_scrollHappen) setState(() => _scrollHappen = false);
        }
      }
    } else if (notification is ScrollMetricsNotification) {
      _checkScrollPositionManually();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _onNotification(notification);
            return false;
          },
          child: Obx(
            () => ListView.separated(
              controller: _scrollController,
              itemCount: controller.messages.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              cacheExtent: 600,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                return DanmakuItem(
                  key: ValueKey(controller.messages[index].hashCode),
                  danmaku: controller.messages[index],
                );
              },
            ),
          ),
        ),
        if (_scrollHappen)
          Positioned(
            left: 12,
            bottom: 12,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_downward_rounded),
              label: const Text('回到底部'),
              onPressed: () {
                setState(() => _scrollHappen = false);
                _throttledScroll();
              },
            ),
          ),
      ],
    );
  }
}

/// 弹幕条目：使用 RepaintBoundary 隔离绘制，防止列表滚动时重复解析文本
class DanmakuItem extends StatelessWidget {
  final LiveMessage danmaku;

  const DanmakuItem({super.key, required this.danmaku});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: "${danmaku.userName}: ",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                ...parseEmojis(danmaku.message, 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 表情解析逻辑
List<InlineSpan> parseEmojis(String text, double fontSize) {
  final List<InlineSpan> spans = [];
  final regex = RegExp(r'\[(.*?)\]');
  int lastIndex = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > lastIndex) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(fontSize: fontSize),
        ),
      );
    }

    final emojiKey = match.group(0)!;
    final image = EmojiManager.getEmoji(emojiKey);

    if (image != null) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(
            width: fontSize * 1.3,
            height: fontSize * 1.3,
            child: CustomPaint(painter: EmojiPainter(image)),
          ),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: emojiKey,
          style: TextStyle(fontSize: fontSize),
        ),
      );
    }
    lastIndex = match.end;
  }

  if (lastIndex < text.length) {
    spans.add(
      TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(fontSize: fontSize),
      ),
    );
  }
  return spans;
}

/// 表情绘制
class EmojiPainter extends CustomPainter {
  final ui.Image image;
  EmojiPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(EmojiPainter old) => image != old.image;
}
