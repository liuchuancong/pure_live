import 'dart:async' show Timer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';

import 'package:pure_live/modules/live/room/chat/membership_cards.dart' show isMembershipCard;

/// What the room's super chat board shows: the platform's own list plus the
/// messages and membership cards that arrived while the room was open.
typedef RoomSuperChatState = ({List<LiveSuperChatMessage> messages, bool loading, String? error});

RoomSuperChatState _empty() => (messages: const <LiveSuperChatMessage>[], loading: false, error: null);

/// The open room's super chats, oldest first, each for as long as the
/// platform (or the membership card) says. The room controller feeds it;
/// the super chat page reads only this.
final class RoomSuperChatController extends Notifier<RoomSuperChatState> {
  Timer? _expiry;

  @override
  RoomSuperChatState build() {
    ref.onDispose(() => _expiry?.cancel());
    return _empty();
  }

  /// Empties the board (a new room opens or this one closes).
  void clear() {
    _expiry?.cancel();
    _expiry = null;
    state = _empty();
  }

  /// Marks the platform board as being read; the messages already on the
  /// board stay visible while it loads.
  void beginLoad() {
    state = (messages: state.messages, loading: true, error: null);
  }

  /// The board read failed; the cards that arrived live stay visible.
  void fail(String error) {
    state = (messages: state.messages, loading: false, error: error);
  }

  /// Adds the platform's board (or a retry's answer), dropping the ones
  /// that have already ended.
  void addAll(Iterable<LiveSuperChatMessage> incoming) => _merge(incoming, loading: false, clearError: true);

  /// Adds one live super chat or membership card.
  void add(LiveSuperChatMessage message) => _merge([message], loading: state.loading, clearError: false);

  /// Takes the membership cards away when "上舰和开会员进醒目留言" goes off;
  /// the platform's own super chats stay.
  void removeMembershipCards() {
    if (!state.messages.any(isMembershipCard)) return;
    state = (
      messages: List.unmodifiable(state.messages.where((message) => !isMembershipCard(message))),
      loading: state.loading,
      error: state.error,
    );
    _scheduleExpiry();
  }

  void _merge(Iterable<LiveSuperChatMessage> incoming, {required bool loading, required bool clearError}) {
    final now = DateTime.now();
    final next = <LiveSuperChatMessage>{
      ...state.messages,
      ...incoming,
    }.where((message) => message.endTime == null || message.endTime!.isAfter(now)).toList()..sort(_oldestFirst);
    state = (messages: List.unmodifiable(next), loading: loading, error: clearError ? null : state.error);
    _scheduleExpiry();
  }

  /// Wakes once for the earliest end among the messages on the board, not
  /// once per card.
  void _scheduleExpiry() {
    _expiry?.cancel();
    final ends = state.messages.map((message) => message.endTime).whereType<DateTime>();
    if (ends.isEmpty) {
      _expiry = null;
      return;
    }
    final next = ends.reduce((a, b) => a.isBefore(b) ? a : b);
    final delay = next.difference(DateTime.now());
    _expiry = Timer(delay.isNegative ? Duration.zero : delay + const Duration(milliseconds: 1), _expire);
  }

  void _expire() {
    _expiry = null;
    final now = DateTime.now();
    final next = state.messages
        .where((message) => message.endTime == null || message.endTime!.isAfter(now))
        .toList(growable: false);
    if (next.length == state.messages.length) {
      _scheduleExpiry();
      return;
    }
    state = (messages: next, loading: state.loading, error: state.error);
    _scheduleExpiry();
  }

  static int _oldestFirst(LiveSuperChatMessage a, LiveSuperChatMessage b) {
    final left = a.startTime;
    final right = b.startTime;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return left.compareTo(right);
  }
}

/// The open room's super chat board.
final roomSuperChatsProvider = NotifierProvider<RoomSuperChatController, RoomSuperChatState>(
  RoomSuperChatController.new,
);
