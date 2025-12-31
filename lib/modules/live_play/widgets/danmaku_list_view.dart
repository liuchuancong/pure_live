import 'dart:async';
import 'dart:ui' as ui;
import 'package:get/get.dart';
import 'package:flutter/rendering.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/emoji_manager.dart';
import 'package:pure_live/modules/live_play/live_play_controller.dart';

// 假设 LivePlayController, LiveRoom, LiveMessage, parseEmojis 等已定义

class DanmakuListView extends StatefulWidget {
  final LiveRoom room;

  const DanmakuListView({super.key, required this.room});

  @override
  State<DanmakuListView> createState() => DanmakuListViewState();
}

class DanmakuListViewState extends State<DanmakuListView> with AutomaticKeepAliveClientMixin<DanmakuListView> {
  final ScrollController _scrollController = ScrollController();
  bool _scrollHappen = false;
  late StreamSubscription<List<LiveMessage>> _messagesSubscription;

  LivePlayController get controller => Get.find<LivePlayController>();

  @override
  void initState() {
    super.initState();
    _messagesSubscription = controller.messages.listen((p0) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    });
  }

  @override
  void dispose() {
    _messagesSubscription.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() async {
    if (_scrollHappen) return;
    if (!mounted) return;

    try {
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.linearToEaseOut,
        );
        if (!mounted) return;
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        debugPrint("滚动动画被取消或 Widget 已卸载: $e");
      }
    }
  }

  bool _userScrollAction(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.forward) {
      setState(() => _scrollHappen = true);
    } else if (notification.direction == ScrollDirection.reverse) {
      final pos = _scrollController.position;
      if (pos.maxScrollExtent - pos.pixels <= 100) {
        setState(() => _scrollHappen = false);
      }
    }
    return true;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        NotificationListener<UserScrollNotification>(
          onNotification: _userScrollAction,
          child: ListView.builder(
            controller: _scrollController,
            itemCount: controller.messages.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final danmaku = controller.messages[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "${danmaku.userName}: ",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
                        ),
                        ...parseEmojis(danmaku.message, 14),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_scrollHappen)
          Positioned(
            left: 12,
            bottom: 12,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_downward_rounded),
              label: const Text('回到底部'),
              // 在 onPressed 回调中添加 mounted 检查
              onPressed: () {
                if (mounted) {
                  // <--- 关键修复点
                  setState(() => _scrollHappen = false);
                  _scrollToBottom();
                }
              },
            ),
          ),
      ],
    );
  }
}

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

    // 处理表情
    final emojiKey = match.group(0)!;
    final image = EmojiManager.getEmoji(emojiKey);

    if (image != null) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(
            width: fontSize * 1.2,
            height: fontSize * 1.2,
            child: CustomPaint(painter: EmojiPainter(image)),
          ),
        ),
      );
    } else {
      // 表情不存在时显示原始文本
      spans.add(
        TextSpan(
          text: emojiKey,
          style: TextStyle(fontSize: fontSize),
        ),
      );
    }

    lastIndex = match.end;
  }

  // 添加剩余文本
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

class EmojiPainter extends CustomPainter {
  final ui.Image image;

  EmojiPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(EmojiPainter old) => image != old.image;
}
