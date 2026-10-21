import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_interaction/live_interaction.dart' show MessageFilter;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/engine/danmaku.dart' show addShieldKeyword, addShieldUser;
import 'package:pure_live/features/room/room_providers.dart' show RoomIdentity, danmakuSessionProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_surface.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// A masked display name (a Bilibili guest's `观***`) stands for many
/// viewers, so it has no "屏蔽此用户" — the reference's B-1 rule, its own
/// codec's regex ported here because the app never imports a platform codec.
bool _isMaskedViewerName(String name) => RegExp(r'\*{2,}|＊{2,}').hasMatch(name.trim());

/// What the reference's copy row puts on the clipboard: "用户名: 内容".
String chatCopyText(LiveMessage message) {
  final name = message.effectiveSender.userName.trim();
  return name.isEmpty ? message.text : '$name: ${message.text}';
}

/// The flying danmaku's actions (3.x `handleDanmakuPointer`, the reference's
/// `RoomMessagePanel`): the message in a card, then copy, block the viewer
/// and block a keyword. Both the tap and the long press of a line on the
/// picture reach it, as the reference has them reach one panel.
///
/// A block writes the stored shield list — the same keys the shield page
/// edits — and hands the name/word to the running session's filter, so it
/// bites without a reconnect; [onBlockedUser] lets the barrage surface drop
/// that viewer's lines already in flight.
Future<void> showRoomMessageActions(
  BuildContext context,
  WidgetRef ref,
  LiveMessage message, {
  required RoomIdentity identity,
  void Function(String userName)? onBlockedUser,
}) async {
  // The same surface rule as every other floating panel: centred on a desktop
  // window, rising from the bottom edge on a handheld.
  await showSettingsSurface<void>(
    context,
    ref.settingsFormFactor,
    title: null,
    body: (surfaceContext) => _RoomMessageSheet(message: message, identity: identity, onBlockedUser: onBlockedUser),
  );
}

final class _RoomMessageSheet extends ConsumerStatefulWidget {
  const new({required this.message, required this.identity, this.onBlockedUser});

  final LiveMessage message;
  final RoomIdentity identity;
  final void Function(String userName)? onBlockedUser;

  @override
  ConsumerState<_RoomMessageSheet> createState() => _RoomMessageSheetState();
}

final class _RoomMessageSheetState extends ConsumerState<_RoomMessageSheet> {
  /// The keyword page is open (the reference's second page: no centred
  /// dialog over the picture, which is often fullscreen).
  bool _keyword = false;
  late final TextEditingController _keywordInput = TextEditingController(text: _initialKeyword(widget.message));

  static const _keywordMaxLength = 40;

  /// A gift's name is the word that blocks it (A08.11); a chat starts at its
  /// own text, cut down like the reference's 40-char field.
  static String _initialKeyword(LiveMessage message) {
    final gift = switch (message.giftOrNull) {
      final LiveGift value => value,
      _ => null,
    };
    final name = gift?.name.trim() ?? '';
    final source = name.isNotEmpty ? name : message.text;
    return source.length > _keywordMaxLength ? source.substring(0, _keywordMaxLength) : source;
  }

  @override
  void dispose() {
    _keywordInput.dispose();
    super.dispose();
  }

  /// The live session's filter, if the room has one — the block must bite on
  /// the messages arriving right now, not only after the next reconnect.
  MessageFilter? get _filter => ref.read(danmakuSessionProvider(widget.identity)).value?.filter;

  Future<void> _blockUser(String name) async {
    Navigator.of(context).pop();
    await addShieldUser(name);
    _filter?.addUser(name);
    widget.onBlockedUser?.call(name);
    if (mounted) {
      PureToast.show(context, context.t.room.userBlocked(name: name), type: PureToastType.success);
    }
  }

  Future<void> _blockKeyword(String keyword) async {
    final raw = keyword.trim();
    if (raw.isEmpty) {
      return;
    }
    final trimmed = raw.length > _keywordMaxLength ? raw.substring(0, _keywordMaxLength) : raw;
    Navigator.of(context).pop();
    await addShieldKeyword(trimmed);
    _filter?.addKeyword(trimmed);
    if (mounted) {
      PureToast.show(context, context.t.room.keywordBlocked, type: PureToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final message = widget.message;
    final sender = message.effectiveSender;
    final name = sender.userName.trim();
    final level = (sender.userLevel ?? '').trim();
    // A local danmaku never passes the filters, so blocking its sender or
    // words would only take these lines off the list (A08.13) — copy stays.
    final canBlockUser = name.isNotEmpty && !message.isLocal && !_isMaskedViewerName(name);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (_keyword)
                  PureIconButton(
                    key: const ValueKey('message-panel-back'),
                    icon: Icons.arrow_back,
                    tooltip: t.common.back,
                    onPressed: () => setState(() => _keyword = false),
                  ),
                Expanded(
                  child: Text(_keyword ? t.room.blockKeywordTitle : t.room.messageActions, style: theme.text.title),
                ),
                PureIconButton(
                  key: const ValueKey('message-panel-close'),
                  icon: Icons.close,
                  tooltip: t.common.close,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (_keyword) ...[
              const SizedBox(height: 8),
              Focus(
                autofocus: true,
                child: PureTextField(
                  controller: _keywordInput,
                  placeholder: t.shield.keywordHint,
                  onSubmitted: (submitted) => unawaited(_blockKeyword(submitted)),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: PureButton(
                  key: const ValueKey('message-panel-block-keyword'),
                  label: t.room.block,
                  onPressed: () => unawaited(_blockKeyword(_keywordInput.text)),
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              DecoratedBox(
                key: const ValueKey('live-play-message-card'),
                decoration: BoxDecoration(
                  color: theme.colors.bgElevated,
                  border: Border.all(color: theme.colors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (name.isNotEmpty)
                        Text(
                          name,
                          style: theme.text.body.copyWith(fontWeight: FontWeight.w700, color: _nameColor(sender)),
                        ),
                      Text(message.text.isEmpty ? ' ' : message.text, style: theme.text.body),
                      if (level.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Semantics(
                            label: t.room.userLevel(level: level),
                            excludeSemantics: true,
                            child: Text(
                              'Lv.$level',
                              key: const ValueKey('live-play-message-level'),
                              style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PureListRow(
                key: const ValueKey('live-play-copy-message'),
                leading: const Icon(Icons.copy, size: 20),
                title: t.room.copyMessage,
                divided: canBlockUser || !message.isLocal,
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(Clipboard.setData(ClipboardData(text: chatCopyText(message))));
                  PureToast.show(context, t.room.copiedToClipboard, type: PureToastType.success);
                },
              ),
              if (canBlockUser)
                PureListRow(
                  key: const ValueKey('live-play-block-user'),
                  leading: const Icon(Icons.block, size: 20),
                  title: t.room.blockViewer,
                  subtitle: t.room.blockViewerDesc(name: name),
                  divided: !message.isLocal,
                  onTap: () => unawaited(_blockUser(name)),
                ),
              if (!message.isLocal)
                PureListRow(
                  key: const ValueKey('live-play-block-keyword'),
                  leading: const Icon(Icons.search_off, size: 20),
                  title: t.room.blockWord,
                  subtitle: t.room.blockWordDesc,
                  onTap: () => setState(() => _keyword = true),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// The sender's own colour when the platform gave one, lifted off near-black
  /// the way the flying lines are (a name over video must stay readable).
  Color _nameColor(MessageSender sender) {
    final color = sender.nameColor;
    if (color == null) {
      return PureTheme.of(context).colors.text;
    }
    final base = Color.fromARGB(255, color.r, color.g, color.b);
    final hsl = HSLColor.fromColor(base);
    return hsl.lightness < 0.35 ? hsl.withLightness(0.62).toColor() : base;
  }
}
