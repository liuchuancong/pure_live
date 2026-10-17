import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_helper_utils/flutter_helper_utils.dart' show tryToColor;
import 'package:live_sites/live_sites.dart' show LiveSuperChatMessage;
import 'package:pure_uikit/pure_uikit.dart';

/// One super chat (highlighted paid message), the reference's
/// `SuperChatCard`: a two-tone banner — the platform's own header and body
/// colours when it prescribes them — with the donor, the price and a live
/// countdown of the message's remaining display time.
final class SuperChatCard extends StatefulWidget {
  /// A card for [message].
  const new({required this.message, super.key});

  /// The super chat the card renders.
  final LiveSuperChatMessage message;

  @override
  State<SuperChatCard> createState() => _SuperChatCardState();
}

final class _SuperChatCardState extends State<SuperChatCard> {
  Timer? _timer;
  int _remainSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initTimer();
  }

  @override
  void didUpdateWidget(covariant SuperChatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.startTime != widget.message.startTime ||
        oldWidget.message.endTime != widget.message.endTime) {
      _initTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initTimer() {
    _timer?.cancel();
    _updateRemainSeconds();
    if (_remainSeconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemainSeconds());
    }
  }

  void _updateRemainSeconds() {
    final end = widget.message.endTime;
    final remain = end == null ? 0 : ((end.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(0, 7200));
    if (mounted) {
      setState(() => _remainSeconds = remain);
    }
    if (remain <= 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  String get _remainText =>
      '${(_remainSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final message = widget.message;
    final headerColor = _platformColor(message.display.backgroundColor, theme.colors.primary);
    final bodyColor = _platformColor(message.display.backgroundBottomColor, theme.colors.fillSecondary);
    final headerText = _contrastText(headerColor);
    final bodyText = _contrastText(bodyColor);
    final price = message.price.displayText.isNotEmpty
        ? message.price.displayText
        : (message.price.amount == null ? '' : '￥${message.price.amount}');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PureCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: headerColor,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    PureAvatar(name: message.userName, src: _avatarOf(message.faceUrl), size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: headerText, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          if (price.isNotEmpty)
                            Text(
                              price,
                              style: TextStyle(
                                color: headerText.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: headerText.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'SC',
                            style: TextStyle(
                              color: headerText.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (message.endTime != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule, size: 12, color: headerText.withValues(alpha: 0.7)),
                              const SizedBox(width: 3),
                              Text(
                                _remainText,
                                style: TextStyle(
                                  color: headerText,
                                  fontSize: 12,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (message.text.isNotEmpty)
              ColoredBox(
                color: bodyColor,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: SelectableText(message.text, style: theme.text.body.copyWith(color: bodyText, height: 1.45)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _avatarOf(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      return null;
    }
    return CachedNetworkImageProvider(url);
  }

  /// A platform-prescribed colour, or [fallback] when the platform
  /// prescribed none (the model leaves the field blank rather than inventing
  /// a colour). The helper parses `#RRGGBB` and anything CSS-adjacent a
  /// platform might emit, resolving to null instead of throwing.
  Color _platformColor(String source, Color fallback) =>
      tryToColor(source.trim())?.withValues(alpha: 1) ?? fallback;

  Color _contrastText(Color background) =>
      background.computeLuminance() > 0.55 ? const Color(0xFF18181A) : Colors.white;
}
