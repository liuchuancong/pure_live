import 'package:live_sites/src/models/enums/live_gift_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_combo/live_gift_combo.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/platforms/douyu/api/douyu_endpoints.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_failure.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_json.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What the douyu danmaku needs to know about one gift: its `dgb` packets
/// carry only the id, a name and a count — the price, the picture and
/// whether it is free come from the catalogues.
final class DouyuGiftInfo {
  /// Creates a DouyuGiftInfo.
  const DouyuGiftInfo({required this.id, required this.name, this.price, this.free = false, this.iconUrl});

  /// The gift id `dgb` sends as `gfid`.
  final String id;

  /// The gift's name.
  final String name;

  /// The price of one in fen (douyu's 鱼翅: 100 fen each); null when free
  /// or unknown.
  final int? price;

  /// Paid in 鱼丸 (douyu's free currency), or a prop from the backpack.
  final bool free;

  /// The gift's picture.
  final String? iconUrl;

  @override
  String toString() => 'DouyuGiftInfo($id $name${price == null ? '' : ', $price fen'}${free ? ', free' : ''})';
}

/// The gifts a douyu room's danmaku may name, by gift id: what `betard`
/// lists, the room's gift list and the platform's prop table, merged with
/// [DouyuGiftCatalog.merge].
final class DouyuGiftCatalog {
  /// Indexes [gifts] by id.
  DouyuGiftCatalog(Map<String, DouyuGiftInfo> gifts) : _gifts = Map.unmodifiable(gifts);

  const DouyuGiftCatalog._empty() : _gifts = const {};

  /// No gifts.
  static const DouyuGiftCatalog empty = DouyuGiftCatalog._empty();

  final Map<String, DouyuGiftInfo> _gifts;

  /// The gift of [id], or null.
  DouyuGiftInfo? operator [](String id) => _gifts[id];

  /// How many gifts.
  int get length => _gifts.length;

  /// Whether it has no gifts.
  bool get isEmpty => _gifts.isEmpty;

  /// These gifts with the other catalogue's over them (an id in both is
  /// the other's).
  DouyuGiftCatalog merge(DouyuGiftCatalog other) {
    if (other.isEmpty) return this;
    if (isEmpty) return other;
    return DouyuGiftCatalog({..._gifts, ...other._gifts});
  }
}

/// Pure parsing of the three douyu gift sources (reference `DouyuApi`
/// D07.3). Anything a source cannot read is left out; the room-table
/// reader never throws, the two fetched lists throw a [DouyuFailure] for
/// shape changes and the capability turns failures into an empty catalogue.
abstract final class DouyuGiftParser {
  /// The gifts of a `betard` answer: `room_gift.gift`, by id, each with
  /// `name`, `price` and `unit` (2 is 鱼翅, priced in fen; 1 is 鱼丸, free),
  /// the picture `pc_icon` (a path under [DouyuEndpoints.giftPictureBase])
  /// — only a room's paid gifts, and not every one. Never throws.
  static DouyuGiftCatalog roomGiftsOf(Object? decoded) {
    final table = jsonObject(jsonObject(jsonObject(decoded)?['room_gift'])?['gift']);
    if (table == null) return DouyuGiftCatalog.empty;
    final gifts = <String, DouyuGiftInfo>{};
    for (final value in table.values) {
      final item = jsonObject(value);
      final id = _giftId(item?['id']);
      final name = jsonString(item?['name']);
      if (item == null || id == null || name == null) continue;
      final free = jsonInt(item['unit']) == 1;
      final price = jsonCount(item['price']);
      gifts[id] = DouyuGiftInfo(
        id: id,
        name: name,
        price: free || price == null ? null : price,
        free: free,
        iconUrl: _giftPicture(item['pc_icon']),
      );
    }
    return DouyuGiftCatalog(gifts);
  }

  /// The room's gift list: `data.giftList`, each with `id`, `name`,
  /// `priceInfo` (`price` in fen when `priceType` is `YUCHI`; a `YUWAN`
  /// gift is free) and the picture `picUrlPrefix` + `basicInfo.giftPic`.
  static DouyuGiftCatalog giftList(String body, {int status = 200}) {
    final root = DouyuRoomParser.checked(body, status: status, what: 'gift list');
    final list = jsonObject(root['data'])?['giftList'];
    if (list is! List) {
      throw const DouyuFailure(DouyuFailureKind.apiChanged, 'gift list: no data.giftList');
    }
    final gifts = <String, DouyuGiftInfo>{};
    for (final value in list) {
      final item = jsonObject(value);
      final id = _giftId(item?['id']);
      final name = jsonString(item?['name']);
      if (item == null || id == null || name == null) continue;
      final priceInfo = jsonObject(item['priceInfo']);
      final type = jsonString(priceInfo?['priceType'])?.toUpperCase();
      final price = jsonCount(priceInfo?['price']);
      final free = type == 'YUWAN';
      gifts[id] = DouyuGiftInfo(
        id: id,
        name: name,
        price: type == 'YUCHI' && price != null ? price : null,
        free: free,
        iconUrl: _giftPicture(
          item['picUrlPrefix'] != null
              ? '${item['picUrlPrefix']}${jsonString(jsonObject(item['basicInfo'])?['giftPic']) ?? ''}'
              : null,
        ),
      );
    }
    return DouyuGiftCatalog(gifts);
  }

  /// The platform's prop (backpack gift) table: JSONP
  /// `DYConfigCallback({"error":0,"data":{<id>:{…}}})`, by the gift id
  /// `dgb` sends. Every prop is free: it is sent from the backpack.
  static DouyuGiftCatalog propGifts(String body, {int status = 200}) {
    DouyuRoomParser.statusChecks(status, 'prop table', body);
    final start = body.indexOf('(');
    final end = body.lastIndexOf(')');
    final json = start >= 0 && end > start ? body.substring(start + 1, end) : body;
    final root = DouyuRoomParser.checked(json, status: status, what: 'prop table');
    final table = jsonObject(root['data']);
    if (table == null) {
      throw const DouyuFailure(DouyuFailureKind.apiChanged, 'prop table: no data');
    }
    final gifts = <String, DouyuGiftInfo>{};
    for (final entry in table.entries) {
      final item = jsonObject(entry.value);
      final id = _giftId(entry.key);
      final name = jsonString(item?['name']);
      if (item == null || id == null || name == null) continue;
      gifts[id] = DouyuGiftInfo(
        id: id,
        name: name,
        free: true,
        iconUrl: [
          for (final field in const ['bimg', 'pc_full_icon', 'himg']) ?_giftPicture(item[field]),
        ].firstOrNull,
      );
    }
    return DouyuGiftCatalog(gifts);
  }

  /// A positive gift id as text, or null.
  static String? _giftId(Object? value) {
    final id = jsonInt(value);
    return id != null && id > 0 ? '$id' : null;
  }

  /// A relative picture path (`1609/….png`, with a size suffix such as
  /// `/rs144`).
  static final RegExp _giftPath = RegExp(r'^/?[\w./-]+\.(png|gif|jpe?g|webp)(/\w+)?$');

  /// A gift picture: an https address as it is, a path under
  /// [DouyuEndpoints.giftPictureBase]; null for anything else and for the
  /// test host.
  static String? _giftPicture(Object? value) {
    final text = jsonString(value);
    if (text == null || text.isEmpty) return null;
    final absolute = text.startsWith('//') ? 'https:$text' : text;
    final url = jsonUrl(absolute) != null
        ? jsonUrl(absolute)!.replace(scheme: 'https')
        : _giftPath.hasMatch(text)
        ? jsonUrl('${DouyuEndpoints.giftPictureBase}/${text.startsWith('/') ? text.substring(1) : text}')
        : null;
    if (url == null || url.host == 'gfs-test-op.douyucdn.cn') return null;
    return url.toString();
  }

  /// Builds the shared-model [LiveGift] a `dgb` packet reports, priced and
  /// pictured from `info` when the catalogues know the gift.
  static LiveGift toLiveGift({
    required String id,
    required String name,
    required int count,
    required int combo,
    required String receiverName,
    required String comboKey,
    required bool free,
    required int? priceFen,
    required String? iconUrl,
  }) {
    return LiveGift(
      giftId: id,
      name: name,
      iconUrl: iconUrl,
      kind: free ? LiveGiftKind.normal : LiveGiftKind.normal,
      count: count,
      value: LiveGiftValue(
        unit: free ? LiveGiftUnit.free : (priceFen == null ? LiveGiftUnit.other : LiveGiftUnit.rmb),
        unitPrice: priceFen == null ? null : priceFen / 100,
        totalValue: priceFen == null ? null : priceFen * count / 100,
      ),
      combo: LiveGiftCombo(comboKey: comboKey, comboTotal: combo > 0 ? combo : null),
      recipientName: receiverName,
    );
  }
}
