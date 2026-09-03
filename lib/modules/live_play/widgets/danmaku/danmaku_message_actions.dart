import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

class DanmakuMessageActions {
  DanmakuMessageActions._();

  static Future<void> show(BuildContext context, LiveMessage message) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              title: Text('${message.userName}: ${message.message}'),
              subtitle: message.userLevel.isEmpty ? null : Text('Lv.${message.userLevel}'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_rounded),
              title: Text(i18n('copy')),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await Clipboard.setData(
                  ClipboardData(text: '${message.userName}: ${message.message}'),
                );
                ToastUtil.show(i18n('copied_to_clipboard'));
              },
            ),
            if (!message.isLocal && message.userName.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.person_off_rounded),
                title: Text(i18n('block_danmaku_user')),
                subtitle: Text(message.userName, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  SettingsService.to.fav.addBlockedDanmakuUser(message.userName);
                  if (Get.isRegistered<LivePlayController>()) {
                    Get.find<LivePlayController>().removeDanmakuWhere(
                      (item) =>
                          item.userName.trim().toLowerCase() ==
                          message.userName.trim().toLowerCase(),
                    );
                  }
                  Navigator.of(sheetContext).pop();
                  ToastUtil.show(i18n('danmaku_user_blocked'));
                },
              ),
            ListTile(
              leading: const Icon(Icons.filter_alt_rounded),
              title: Text(i18n('block_danmaku_keyword')),
              subtitle: Text(message.message, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showKeywordDialog(context, message.message);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> showKeywordDialog(BuildContext context, String message) async {
    final textController = TextEditingController(text: message);
    final keyword = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n('block_danmaku_keyword')),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(hintText: i18n('please_enter_keyword')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(i18n('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(textController.text.trim()),
            child: Text(i18n('confirm')),
          ),
        ],
      ),
    );
    textController.dispose();
    if (keyword == null || keyword.isEmpty) return;
    SettingsService.to.fav.addShieldList(keyword);
    if (Get.isRegistered<LivePlayController>()) {
      Get.find<LivePlayController>().removeDanmakuWhere(
        (item) => item.message.toLowerCase().contains(keyword.toLowerCase()),
      );
    }
    ToastUtil.show(i18n('danmaku_keyword_blocked'));
  }
}
