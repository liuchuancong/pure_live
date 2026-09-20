import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

class DanmakuMessageActions {
  DanmakuMessageActions._();

  static Future<void> show(BuildContext context, LiveMessage message, {required LivePlayController controller}) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
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
                  await Clipboard.setData(ClipboardData(text: '${message.userName}: ${message.message}'));
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
                    if (!controller.isClosed) {
                      controller.removeDanmakuWhere(
                        (item) => item.userName.trim().toLowerCase() == message.userName.trim().toLowerCase(),
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
                  // The originating row may have been evicted while this sheet
                  // was open. The sheet still owns a live navigator context.
                  showKeywordDialog(sheetContext, message.message, controller: controller);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> showKeywordDialog(
    BuildContext context,
    String message, {
    required LivePlayController controller,
  }) async {
    final keyword = await showDialog<String>(
      context: context,
      builder: (_) => _DanmakuKeywordDialog(initialText: message),
    );
    if (keyword == null || keyword.isEmpty) return;
    SettingsService.to.fav.addShieldList(keyword);
    if (!controller.isClosed) {
      controller.removeDanmakuWhere((item) => item.message.toLowerCase().contains(keyword.toLowerCase()));
    }
    ToastUtil.show(i18n('danmaku_keyword_blocked'));
  }
}

class _DanmakuKeywordDialog extends StatefulWidget {
  const _DanmakuKeywordDialog({required this.initialText});
  final String initialText;

  @override
  State<_DanmakuKeywordDialog> createState() => _DanmakuKeywordDialogState();
}

class _DanmakuKeywordDialogState extends State<_DanmakuKeywordDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    // A dialog result completes before its exit transition unmounts TextField.
    // Keep the draft alive for exactly the dialog subtree's lifetime.
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(i18n('block_danmaku_keyword')),
    content: TextField(
      controller: _textController,
      autofocus: true,
      maxLength: FavoriteRoomController.maxShieldKeywordLength,
      decoration: InputDecoration(hintText: i18n('please_enter_keyword')),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n('cancel'))),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_textController.text.trim()),
        child: Text(i18n('confirm')),
      ),
    ],
  );
}
