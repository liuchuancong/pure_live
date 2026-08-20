import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:pure_live/common/index.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_message_actions.dart';

bool isDanmakuUserScrollStart(ScrollNotification notification, {bool acceptDirectionOnlyUserScroll = false}) {
  return (notification is ScrollStartNotification && notification.dragDetails != null) ||
      (notification is ScrollUpdateNotification && notification.dragDetails != null) ||
      (acceptDirectionOnlyUserScroll &&
          notification is UserScrollNotification &&
          notification.direction != ScrollDirection.idle);
}

class DanmakuListView extends StatefulWidget {
  final LiveRoom room;

  const DanmakuListView({super.key, required this.room});

  @override
  State<DanmakuListView> createState() => DanmakuListViewState();
}

class DanmakuListViewState extends State<DanmakuListView> {
  final ScrollController _scrollController = createPureLiveScrollController();
  final TextEditingController _composerController = TextEditingController();

  static const Duration throttleDuration = Duration(milliseconds: 80);

  bool userScrolling = false;
  bool _autoScrollEnabled = true;
  final ValueNotifier<int> _pendingMessageCount = ValueNotifier<int>(0);
  int _lastControllerLength = 0;
  LiveMessage? _lastControllerTail;
  List<LiveMessage> _visibleMessages = const [];

  Timer? throttleTimer;
  Worker? fullscreenWorker;
  Worker? windowFullscreenWorker;
  Worker? presentationWorker;
  StreamSubscription? messagesSub;

  LivePlayController get controller => Get.find<LivePlayController>();

  @override
  void initState() {
    super.initState();
    _visibleMessages = List<LiveMessage>.from(controller.danmakuMessages);
    _lastControllerLength = _visibleMessages.length;
    _lastControllerTail = _visibleMessages.isEmpty ? null : _visibleMessages.last;

    messagesSub = controller.danmakuMessages.listen((_) => _onMessagesChanged());

    fullscreenWorker = ever(GlobalPlayerState.to.isFullscreen, (value) {
      if (value == false && _autoScrollEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) => forceScrollToBottom());
      }
    });

    windowFullscreenWorker = ever(GlobalPlayerState.to.isWindowFullscreen, (value) {
      if (value == false && _autoScrollEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) => forceScrollToBottom());
      }
    });

    // LivePlayContent replaces the complete portrait subtree with the PiP
    // surface, so this State is normally disposed before isInPip becomes true
    // and recreated only after it is false. Listen to the persistent room
    // controller's presentation revision instead of trying to infer a
    // transition from this short-lived widget. The initial post-frame restore
    // also wins over synthetic viewport notifications emitted while Android
    // lays the portrait list out again.
    presentationWorker = ever<int>(controller.danmakuPresentationRevision, (_) => _scheduleLiveTailRestore());
    _scheduleLiveTailRestore();
  }

  void _onMessagesChanged() {
    if (!mounted) return;
    final currentMessages = controller.danmakuMessages;
    final nextLength = currentMessages.length;
    final nextTail = currentMessages.isEmpty ? null : currentMessages.last;
    final tailChanged = !identical(nextTail, _lastControllerTail);
    final lengthDelta = nextLength - _lastControllerLength;
    final addedCount = lengthDelta > 0 ? lengthDelta : (tailChanged ? 1 : 0);
    _lastControllerLength = nextLength;
    _lastControllerTail = nextTail;

    if (!_autoScrollEnabled) {
      if (addedCount > 0) {
        _pendingMessageCount.value = (_pendingMessageCount.value + addedCount).clamp(0, 9999);
      }
      return;
    }

    if (nextTail?.isLocal == true && addedCount > 0) {
      throttleTimer?.cancel();
      throttleTimer = null;
      setState(() => _visibleMessages = List<LiveMessage>.of(currentMessages, growable: false));
      WidgetsBinding.instance.addPostFrameCallback((_) => forceScrollToBottom());
      return;
    }

    throttleTimer ??= Timer(throttleDuration, () {
      throttleTimer = null;
      if (!mounted || !_autoScrollEnabled) return;
      setState(() => _visibleMessages = List<LiveMessage>.of(controller.danmakuMessages, growable: false));
      WidgetsBinding.instance.addPostFrameCallback((_) => forceScrollToBottom());
    });
  }

  @override
  void dispose() {
    messagesSub?.cancel();
    fullscreenWorker?.dispose();
    windowFullscreenWorker?.dispose();
    presentationWorker?.dispose();
    throttleTimer?.cancel();
    _composerController.dispose();
    _pendingMessageCount.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> forceScrollToBottom() async {
    if (!mounted || !_autoScrollEnabled) return;
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    if ((position.pixels - position.minScrollExtent).abs() > 0.5) {
      _scrollController.jumpTo(position.minScrollExtent);
    }
  }

  void _pauseAutoScroll() {
    if (!_autoScrollEnabled) return;
    throttleTimer?.cancel();
    throttleTimer = null;
    setState(() {
      _autoScrollEnabled = false;
      userScrolling = true;
    });
    _pendingMessageCount.value = 0;
  }

  void _scheduleLiveTailRestore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_resumeAutoScroll());
    });
  }

  Future<void> _resumeAutoScroll() async {
    if (!mounted) return;
    throttleTimer?.cancel();
    throttleTimer = null;
    final messages = controller.danmakuMessages;
    setState(() {
      _visibleMessages = List<LiveMessage>.from(messages);
      _autoScrollEnabled = true;
      userScrolling = false;
    });
    _lastControllerLength = messages.length;
    _lastControllerTail = messages.isEmpty ? null : messages.last;
    _pendingMessageCount.value = 0;
    await forceScrollToBottom();
  }

  void onScrollNotification(ScrollNotification notification) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final distanceToBottom = position.pixels - position.minScrollExtent;

    // A UserScrollNotification is emitted before the first drag has produced a
    // useful pixel distance. Waiting for a 24 px offset let the 80 ms live
    // update jump the list back to the bottom, so Android users had to swipe
    // repeatedly. Claim a real drag (or mouse wheel) immediately.
    // On Android the viewport detach/attach performed by system PiP emits a
    // direction-only UserScrollNotification even when there was no finger
    // gesture. Treating it as a drag immediately paused live-follow again,
    // after the presentation restore above had already resumed it. Desktop mouse-wheel
    // input has no DragDetails, so it deliberately keeps the direction-only
    // path.
    if (isDanmakuUserScrollStart(notification, acceptDirectionOnlyUserScroll: PlatformUtils.isDesktop)) {
      _pauseAutoScroll();
    } else if ((notification is ScrollEndNotification ||
            (notification is UserScrollNotification && notification.direction == ScrollDirection.idle)) &&
        distanceToBottom <= 12 &&
        !_autoScrollEnabled) {
      _resumeAutoScroll();
    }
  }

  void _sendLocalMessage() {
    final text = _composerController.text.trim();
    final local = controller.localInteractionController;
    if (!local.enabled.v || text.isEmpty) return;
    controller.emitLocalMessage(
      local.createChat(text, platform: controller.site),
      showAsDanmaku: local.showAsDanmaku.v,
      delay: LivePlayController.localChatDeliveryDelay,
    );
    _composerController.clear();
    ToastUtil.show(i18n('local_message_queued'));
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
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      onScrollNotification(notification);
                      return false;
                    },
                    child: ListView.builder(
                      key: const ValueKey('danmaku-message-list'),
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      scrollCacheExtent: const ScrollCacheExtent.pixels(360),
                      itemCount: _visibleMessages.length,
                      itemBuilder: (_, index) {
                        final msg = _visibleMessages[_visibleMessages.length - 1 - index];
                        return DanmakuItem(key: ObjectKey(msg), danmaku: msg);
                      },
                    ),
                  ),
                  if (userScrolling)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FilledButton.icon(
                        key: const ValueKey('danmaku-resume-live'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          backgroundColor: Get.theme.colorScheme.primary.withValues(alpha: 0.92),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                        label: ValueListenableBuilder<int>(
                          valueListenable: _pendingMessageCount,
                          builder: (context, count, _) => Text(
                            count > 0
                                ? i18n('danmaku_new_messages', args: {'count': '$count'})
                                : i18n('scroll_to_bottom'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        onPressed: _resumeAutoScroll,
                      ),
                    ),
                ],
              ),
            ),
            Obx(() {
              if (!controller.localInteractionController.enabled.v) return const SizedBox.shrink();
              return Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _composerController,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendLocalMessage(),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: i18n('local_message_hint'),
                              prefixIcon: const Icon(Icons.auto_awesome_rounded, size: 19),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filled(
                          tooltip: i18n('local_send_message'),
                          onPressed: _sendLocalMessage,
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class DanmakuItem extends StatelessWidget {
  final LiveMessage danmaku;

  const DanmakuItem({super.key, required this.danmaku});

  Future<void> _copyMessage() async {
    await Clipboard.setData(ClipboardData(text: "${danmaku.userName}: ${danmaku.message}"));
    ToastUtil.show(i18n('copied_to_clipboard'));
  }

  Future<void> _showActions(BuildContext context) => DanmakuMessageActions.show(context, danmaku);

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
                  decoration: BoxDecoration(color: vibrantColor, shape: BoxShape.circle),
                ),

                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onSecondaryTap: () => _showActions(context),
                    onLongPress: () => _showActions(context),
                    onDoubleTap: _copyMessage,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: "${danmaku.userName}: ",
                            style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.w700, color: textColor),
                          ),
                          TextSpan(
                            children: parseEmojis(danmaku.message, AppTextStyles.t14.fontSize!, textColor),
                            style: AppTextStyles.t14.copyWith(
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                              color: textColor,
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
        ),
      ),
    );
  }
}

/// A bounded LRU avoids retaining every unique chat line seen during an
/// overnight stream.  The old unbounded map was one of the main causes of the
/// steadily rising desktop heap.
const int emojiTokenCacheCapacity = 512;
final LinkedHashMap<String, List<EmojiToken>> emojiCache = LinkedHashMap<String, List<EmojiToken>>();

class EmojiToken {
  final bool isEmoji;
  final String value;

  const EmojiToken({required this.isEmoji, required this.value});
}

List<EmojiToken> _parseEmojiTokens(String text) {
  final cached = emojiCache[text];
  if (cached != null) {
    // LinkedHashMap does not reorder entries on lookup; reinsert to make this
    // a true least-recently-used cache.
    emojiCache.remove(text);
    emojiCache[text] = cached;
    return cached;
  }

  final regex = EmojiAtlas.instance.regex;

  if (regex == null) {
    final tokens = [EmojiToken(isEmoji: false, value: text)];
    _storeEmojiTokens(text, tokens);
    return tokens;
  }

  final tokens = <EmojiToken>[];

  int last = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > last) {
      tokens.add(EmojiToken(isEmoji: false, value: text.substring(last, match.start)));
    }

    tokens.add(EmojiToken(isEmoji: true, value: match.group(0)!));

    last = match.end;
  }

  if (last < text.length) {
    tokens.add(EmojiToken(isEmoji: false, value: text.substring(last)));
  }

  _storeEmojiTokens(text, tokens);

  return tokens;
}

void _storeEmojiTokens(String text, List<EmojiToken> tokens) {
  while (emojiCache.length >= emojiTokenCacheCapacity) {
    emojiCache.remove(emojiCache.keys.first);
  }
  emojiCache[text] = tokens;
}

List<InlineSpan> parseEmojis(String text, double size, Color color) {
  final tokens = _parseEmojiTokens(text);

  final spans = <InlineSpan>[];

  final style = TextStyle(fontSize: size, color: color);

  final emojiSize = size * 1.25;

  for (final token in tokens) {
    if (!token.isEmoji) {
      spans.add(TextSpan(text: token.value, style: style));
      continue;
    }

    final info = EmojiAtlas.instance.find(token.value);
    final image = info != null ? EmojiAtlas.instance.image(info.id) : null;

    if (image == null) {
      spans.add(TextSpan(text: token.value, style: style));
      continue;
    }

    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: RawImage(image: image, width: emojiSize, height: emojiSize),
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
