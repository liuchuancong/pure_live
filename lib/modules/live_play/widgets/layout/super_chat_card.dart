import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:flutter_color/flutter_color.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:pure_live/common/utils/toast_util.dart';
import 'package:pure_live/common/models/live_message.dart';

class SuperChatCard extends StatefulWidget {
  final LiveSuperChatMessage message;

  const SuperChatCard(this.message, {super.key});

  @override
  State<SuperChatCard> createState() => _SuperChatCardState();
}

class _SuperChatCardState extends State<SuperChatCard> {
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
      _timer?.cancel();
      _timer = null;

      _initTimer();
    }
  }

  void _initTimer() {
    _updateRemainSeconds();

    if (_remainSeconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemainSeconds());
    }
  }

  void _updateRemainSeconds() {
    final duration = widget.message.endTime.difference(DateTime.now());

    final remain = duration.inMilliseconds <= 0
        ? 0
        : (duration.inMilliseconds / 1000).ceil().clamp(0, 7200);

    if (!mounted) {
      return;
    }

    setState(() {
      _remainSeconds = remain;
    });

    if (remain <= 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  String get _remainText {
    final minutes = _remainSeconds ~/ 60;
    final seconds = _remainSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Color _contrastText(Color background) {
    return background.computeLuminance() > 0.55 ? const Color(0xFF18181A) : Colors.white;
  }

  Color _secondaryText(Color background) {
    return background.computeLuminance() > 0.55
        ? const Color(0x8A18181A)
        : Colors.white.withValues(alpha: 0.70);
  }

  Color _overlay(Color background, double opacity) {
    return _contrastText(background).withValues(alpha: opacity);
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;

    final headerColor = HexColor(message.backgroundColor);
    final messageColor = HexColor(message.backgroundBottomColor);

    final headerText = _contrastText(headerColor);
    final headerSubText = _secondaryText(headerColor);
    final messageText = _contrastText(messageColor);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(
            message: message,
            backgroundColor: headerColor,
            primaryText: headerText,
            secondaryText: headerSubText,
          ),
          _buildMessageBody(
            message: message,
            backgroundColor: messageColor,
            textColor: messageText,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required LiveSuperChatMessage message,
    required Color backgroundColor,
    required Color primaryText,
    required Color secondaryText,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(color: backgroundColor),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(message.face, primaryText),
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
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Remix.money_cny_circle_fill, size: 16, color: Color(0xFFFFC107)),
                    const SizedBox(width: 1),
                    Text(
                      '￥${message.price}',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildInfoArea(
            backgroundColor: backgroundColor,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String url, Color borderColor) {
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(1.8),
      decoration: BoxDecoration(color: borderColor.withValues(alpha: 0.9), shape: BoxShape.circle),
      child: ClipOval(
        child: Image.network(
          url,
          width: 40.4,
          height: 40.4,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) {
            return Container(
              color: Colors.black.withValues(alpha: 0.10),
              alignment: Alignment.center,
              child: Icon(Remix.user_2_fill, size: 20, color: borderColor),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoArea({
    required Color backgroundColor,
    required Color primaryText,
    required Color secondaryText,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: _overlay(backgroundColor, 0.10),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Remix.vip_diamond_fill, size: 11, color: Color(0xFFFFC107)),
              const SizedBox(width: 3),
              Text(
                'SC',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Remix.time_line, size: 13, color: secondaryText),
            const SizedBox(width: 3),
            Text(
              _remainText,
              style: TextStyle(
                color: primaryText,
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> clipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ToastUtil.show(i18n('copied_to_clipboard'));
  }

  Widget _buildMessageBody({
    required LiveSuperChatMessage message,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 13),
      decoration: BoxDecoration(color: backgroundColor),
      child: GestureDetector(
        onDoubleTap: () => clipboard(message.message),
        child: SelectableText(
          message.message,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
