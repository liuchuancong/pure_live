import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_interaction/live_interaction.dart';
import 'package:live_sites/live_sites.dart' show LiveGift, LiveMessage, LiveMessageType;
import 'package:live_uikit/live_uikit.dart';
import 'package:pure_live/app/engine/danmaku.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';

/// The room's danmaku pane: the interaction session's messages, newest at
/// the bottom, auto-scrolling while the viewer stays at the bottom and
/// pausing the auto-scroll the moment they scroll up.
///
/// Only chat renders this wave; gifts and audience updates feed the
/// tracker later.
final class DanmakuPane extends ConsumerStatefulWidget {
  /// A pane for the room [siteId]/[roomId].
  const new({required this.siteId, required this.roomId, super.key});

  /// The platform the room belongs to.
  final String siteId;

  /// The platform-specific room id.
  final String roomId;

  @override
  ConsumerState<DanmakuPane> createState() => _DanmakuPaneState();
}

final class _DanmakuPaneState extends ConsumerState<DanmakuPane> {
  InteractionSession? _session;
  StreamSubscription<LiveMessage>? _messagesSub;
  final AudienceTracker _tracker = AudienceTracker();
  final ScrollController _scroll = ScrollController();
  final List<LiveMessage> _messages = [];
  bool _pinned = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    unawaited(_open());
  }

  @override
  void dispose() {
    unawaited(_messagesSub?.cancel());
    unawaited(_session?.dispose());
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final atBottom = _scroll.position.extentAfter < 40;
    if (_pinned != atBottom && mounted) {
      setState(() => _pinned = atBottom);
    }
  }

  Future<void> _open() async {
    try {
      final site = ref.read(sitesProvider).registry.getById(widget.siteId);
      if (site == null) {
        return;
      }
      final session = await openDanmakuSession(site: site, roomId: widget.roomId, shieldRules: await loadShieldRules());
      if (!mounted) {
        unawaited(session.dispose());
        return;
      }
      setState(() => _session = session);
      _messagesSub = session.messages.listen((message) {
        if (message.type == LiveMessageType.audienceUpdate) {
          _tracker.consume(message);
        }
        if (!mounted || (message.type != LiveMessageType.chat && message.type != LiveMessageType.gift)) {
          return;
        }
        setState(() {
          _messages.add(message);
          if (_messages.length > 200) {
            _messages.removeRange(0, _messages.length - 200);
          }
        });
        _scrollToBottom();
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  void _scrollToBottom() {
    if (!_pinned || !_scroll.hasClients) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.t.room.danmakuFailed,
              style: const TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            LiveButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: _open),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(10),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final sender = message.sender?.userName ?? '';
              final gift = message.type == LiveMessageType.gift && message.payload is LiveGift
                  ? message.payload! as LiveGift
                  : null;
              final giftNote = gift == null ? '' : (gift.count > 1 ? ' ×${gift.count}' : '');
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (sender.isNotEmpty)
                        TextSpan(
                          text: '$sender: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: gift != null ? const Color(0xFFFFC107) : Colors.white,
                          ),
                        ),
                      TextSpan(
                        text: '${message.text}$giftNote',
                        style: TextStyle(color: gift != null ? const Color(0xFFFFC107) : Colors.white),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.3),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
