import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/plugins/share_command_handler.dart';

class ShareCommandHandler {
  static final ShareCommandHandler instance = ShareCommandHandler._internal();

  ShareCommandHandler._internal();

  String _lastProcessedText = "";

  Future<void> checkClipboard(Function(String roomInfo) onMatchFound) async {
    try {
      ClipboardData? clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData == null || clipboardData.text == null) return;
      String currentText = clipboardData.text!.trim();
      if (currentText.isEmpty) return;
      if (currentText == _lastProcessedText) return;
      _lastProcessedText = currentText;
      Future.delayed(Duration(seconds: 10)).then((val) {
        _lastProcessedText = '';
      });
      final isMyCommand = ShareCommandCodec.isMyCommand(currentText);
      if (!isMyCommand) return;
      onMatchFound(currentText);
    } catch (e) {
      log(e.toString(), name: 'ShareCommandHandler');
    }
  }

  Future<void> onShareRoomPressed(LiveRoom room) async {
    final Map<String, dynamic> shareMap = {
      'platform': room.platform,
      'roomId': room.roomId,
      'title': room.title,
      'link': room.link,
      'cover': room.cover,
      'avatar': room.avatar,
      'nick': room.nick,
    };
    final String secret = ShareCommandCodec.encodeShort(shareMap);
    _lastProcessedText = secret;
    Future.delayed(Duration(seconds: 10)).then((val) {
      _lastProcessedText = '';
    });
    if (PlatformUtils.isDesktop) {
      Clipboard.setData(ClipboardData(text: secret));
      ToastUtil.show(i18n('copied_to_clipboard'));
    } else {
      await SharePlus.instance.share(ShareParams(text: secret));
    }
  }
}
