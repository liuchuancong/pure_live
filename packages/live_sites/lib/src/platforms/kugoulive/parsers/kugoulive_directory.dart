import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_json.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_room_parser.dart';

/// A page of a room list: the cards of `list` (`star` rows unwrapped), a
/// room once; more pages while `hasNextPage` is 1 or true. The answer's
/// `times` dates the live cards' `livetime`.
({List<LiveRoom> rooms, bool hasMore}) kugouliveDirectoryPage(String body, {required int page, int status = 200}) {
  const what = 'room list';
  final (:root, :data) = KugouliveJson.answer(body, what: what, status: status);
  final at = KugouliveJson.answeredAt(root);
  final seen = <String>{};
  final rooms = <LiveRoom>[];
  for (final entry in KugouliveJson.list(data['list'])) {
    final wrapper = KugouliveJson.map(entry) ?? const {};
    final raw = wrapper['uiType'] == 'star' ? KugouliveJson.map(wrapper['data']) ?? const {} : wrapper;
    if (KugouliveRoomParser.card(raw, answeredAt: at) case final room? when seen.add(room.roomId)) {
      rooms.add(room);
    }
  }
  final more = data['hasNextPage'];
  return (rooms: rooms, hasMore: more == true || KugouliveJson.integer(more) == 1);
}

/// The platform's answer time of [body], for the room lists' clocks.
DateTime? kugouliveAnsweredAt(String body, {required int status, required String what}) =>
    KugouliveJson.answeredAt(KugouliveJson.map(KugouliveJson.decode(body, what: what, status: status)) ?? const {});
