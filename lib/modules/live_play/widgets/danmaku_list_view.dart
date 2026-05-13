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

  bool _userScrolling = false;

  StreamSubscription? _messagesSub;
  Timer? _throttleTimer;
  bool _pendingScroll = false;

  static const _throttleDuration = Duration(milliseconds: 120);

  LivePlayController get controller => Get.find<LivePlayController>();

  @override
  void initState() {
    super.initState();
    _messagesSub = controller.messages.listen((_) => _scheduleScroll());
    ever(GlobalPlayerState.to.isWindowFullscreen, (_) {
      _forceScrollToBottom();
    });
    ever(GlobalPlayerState.to.isFullscreen, (_) {
      _forceScrollToBottom();
    });
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _throttleTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _forceScrollToBottom() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!_scrollController.hasClients) return;
        final max = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(max);
        debugPrint("📌 Danmaku scroll -> $max");
      });
    });
  }

  void _scheduleScroll() {
    if (!mounted || _userScrolling) return;

    _pendingScroll = true;

    _throttleTimer?.cancel();

    _throttleTimer = Timer(_throttleDuration, () {
      if (!_pendingScroll || !_scrollController.hasClients) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;

        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });

      _pendingScroll = false;
    });
  }

  void _onScrollNotification(ScrollNotification n) {
    if (n is UserScrollNotification) {
      final pos = _scrollController.position;

      if (n.direction == ScrollDirection.forward) {
        if (pos.maxScrollExtent - pos.pixels > 80) {
          if (!_userScrolling) {
            setState(() => _userScrolling = true);
          }
        }
      } else if (n.direction == ScrollDirection.reverse) {
        if (pos.maxScrollExtent - pos.pixels < 60) {
          if (_userScrolling) {
            setState(() => _userScrolling = false);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            _onScrollNotification(n);
            return false;
          },
          child: Obx(() {
            final list = controller.messages;

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              cacheExtent: 500,
              itemCount: list.length,
              itemBuilder: (_, i) {
                final msg = list[i];

                return DanmakuItem(key: ValueKey(msg.hashCode), danmaku: msg);
              },
            );
          }),
        ),

        if (_userScrolling)
          Positioned(
            left: 12,
            bottom: 12,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_downward_rounded),
              label: const Text('回到底部'),
              onPressed: () {
                setState(() => _userScrolling = false);
                _forceScrollToBottom();
              },
            ),
          ),
      ],
    );
  }
}

class DanmakuItem extends StatelessWidget {
  final LiveMessage danmaku;

  const DanmakuItem({super.key, required this.danmaku});

  @override
  Widget build(BuildContext context) {
    final baseColor = Color.fromARGB(255, danmaku.color.r, danmaku.color.g, danmaku.color.b);
    final vibrantColor = baseColor.asHexString == '#FFFFFFFF'
        ? Colors.black
        : HSLColor.fromColor(baseColor).withLightness(0.5).withSaturation(1).toColor();

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: "${danmaku.userName}: ",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
                          ),
                          TextSpan(
                            children: parseEmojis(danmaku.message, 14),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: vibrantColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<InlineSpan> parseEmojis(String text, double size) {
  final spans = <InlineSpan>[];
  final regex = RegExp(r'\[(.*?)\]');

  int last = 0;

  for (final m in regex.allMatches(text)) {
    if (m.start > last) {
      spans.add(
        TextSpan(
          text: text.substring(last, m.start),
          style: TextStyle(fontSize: size),
        ),
      );
    }

    final key = m.group(0)!;
    final img = EmojiManager.getEmoji(key);

    if (img != null) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(
            width: size * 1.25,
            height: size * 1.25,
            child: RepaintBoundary(child: CustomPaint(painter: EmojiPainter(img))),
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

    last = m.end;
  }

  if (last < text.length) {
    spans.add(
      TextSpan(
        text: text.substring(last),
        style: TextStyle(fontSize: size),
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
