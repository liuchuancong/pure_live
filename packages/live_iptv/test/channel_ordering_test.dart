import 'dart:convert';

import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/order/iptv_channel_ordering.dart';
import 'package:test/test.dart';

/// A channel for the ordering tests: [name] is the display name, [group]
/// the playlist group, and the rest are the user's own state.
IptvChannel channel(
  String name, {
  String? group,
  int position = 0,
  int? number,
  bool pinned = false,
  bool hidden = false,
  int? providerNumber,
}) => IptvChannel.of(
  id: name,
  entry: IptvEntry.of(name: name, url: 'http://a/$name.m3u8', group: group, channelNumber: providerNumber),
  position: position,
  number: number,
  pinned: pinned,
  hidden: hidden,
);

void main() {
  group('rankIptvGroups', () {
    test('orders the arranged groups by their order', () {
      final ranks = rankIptvGroups(
        channels: [
          channel('a', group: '卫视'),
          channel('b', group: '央视'),
        ],
        groups: [
          IptvGroup.of(name: '卫视'),
          IptvGroup.of(name: '央视', order: 1),
        ],
      );

      expect(ranks['卫视'], 0);
      expect(ranks['央视'], 1);
    });

    test('a pinned group sorts ahead of the order it was given', () {
      final ranks = rankIptvGroups(
        channels: [
          channel('a', group: '卫视'),
          channel('b', group: '央视'),
        ],
        groups: [
          IptvGroup.of(name: '卫视', order: 5),
          IptvGroup.of(name: '央视', pinned: true),
        ],
      );

      expect(ranks['央视'], 0);
      expect(ranks['卫视'], 1);
    });

    test('a group the user never touched lands after the arranged ones, in channel order', () {
      final ranks = rankIptvGroups(
        channels: [
          channel('a', group: '电影', position: 30),
          channel('b', group: '央视', position: 1),
          channel('c', group: '卫视', position: 2),
          channel('d', group: '体育', position: 40),
        ],
        groups: [
          IptvGroup.of(name: '卫视'),
          IptvGroup.of(name: '央视', order: 1),
        ],
      );

      expect(ranks.keys.take(2).toList(), ['卫视', '央视']);
      // 电影 and 体育 are unarranged: they follow in the order their first
      // channel appears in the list, not alphabetically.
      expect(ranks.keys.skip(2).toList(), ['电影', '体育']);
    });

    test('channels with no group have a key of their own', () {
      final ranks = rankIptvGroups(channels: [channel('a')], groups: const []);

      expect(ranks.keys.single, iptvUngroupedKey);
      expect(iptvGroupKeyOf(channel('x')), iptvUngroupedKey);
    });

    test('two groups with equal orders still decide, by name', () {
      final ranks = rankIptvGroups(
        channels: [
          channel('a', group: 'Beta'),
          channel('b', group: 'Alpha'),
        ],
        groups: [
          IptvGroup.of(name: 'Beta'),
          IptvGroup.of(name: 'Alpha'),
        ],
      );

      expect(ranks.keys.toList(), ['Alpha', 'Beta']);
    });
  });

  group('compareIptvChannels', () {
    test('a number beats the list position', () {
      final ranks = rankIptvGroups(channels: const [], groups: const []);

      expect(
        compareIptvChannels(channel('low', number: 3), channel('high', number: 1), groupRanks: ranks),
        greaterThan(0),
      );
    });

    test('an unnumbered channel sorts after every numbered one', () {
      final ranks = rankIptvGroups(channels: const [], groups: const []);

      expect(compareIptvChannels(channel('none'), channel('numbered', number: 900), groupRanks: ranks), greaterThan(0));
    });

    test('a pinned channel beats a number', () {
      final ranks = rankIptvGroups(channels: const [], groups: const []);

      expect(
        compareIptvChannels(channel('pinned', pinned: true), channel('numbered', number: 1), groupRanks: ranks),
        lessThan(0),
      );
    });

    test('the group order decides between two unnumbered channels', () {
      final ranks = {'央视': 0, '卫视': 1};

      expect(
        compareIptvChannels(
          channel('h', group: '卫视'),
          channel('c', group: '央视', position: 9),
          groupRanks: ranks,
        ),
        greaterThan(0),
      );
    });

    test('inside one group the list position decides', () {
      final ranks = {'央视': 0};

      expect(
        compareIptvChannels(
          channel('first', group: '央视', position: 1),
          channel('second', group: '央视', position: 2),
          groupRanks: ranks,
        ),
        lessThan(0),
      );
    });

    test('the order is total: two identical channels still differ by id', () {
      final ranks = {'央视': 0};

      expect(
        compareIptvChannels(
          channel('a', group: '央视'),
          channel('b', group: '央视'),
          groupRanks: ranks,
        ),
        isNot(0),
      );
    });
  });

  group('sortIptvChannels', () {
    test('puts pinned, then numbered, then grouped channels in place', () {
      final ranks = {'央视': 0, '卫视': 1};
      final sorted = sortIptvChannels([
        channel('weibo', group: '卫视'),
        channel('cctv2', group: '央视', position: 1),
        channel('cctv1', group: '央视', number: 1),
        channel('star', group: '卫视', position: 5, pinned: true),
      ], groupRanks: ranks);

      expect(sorted.map((entry) => entry.entry.name), ['star', 'cctv1', 'cctv2', 'weibo']);
    });
  });

  group('assignChannelNumbers', () {
    test('sequential numbers the list from the start value', () {
      final ordered = [channel('a'), channel('b'), channel('c')];

      final assigned = assignChannelNumbers(ordered: ordered);

      expect(assigned.values.toList(), [1, 2, 3]);
    });

    test('per group gives each group its own block', () {
      final ranks = {'央视': 0, '卫视': 1};
      final ordered = [channel('cctv1', group: '央视'), channel('cctv2', group: '央视'), channel('hun', group: '卫视')];

      final assigned = assignChannelNumbers(ordered: ordered, mode: IptvNumberingMode.perGroup, groupRanks: ranks);

      expect(assigned['cctv1'], 1);
      expect(assigned['cctv2'], 2);
      expect(assigned['hun'], 101);
    });

    test('from playlist uses the provider number and fills the gaps', () {
      final ordered = [channel('a', providerNumber: 7), channel('b'), channel('c', providerNumber: 8)];

      final assigned = assignChannelNumbers(ordered: ordered, mode: IptvNumberingMode.fromPlaylist);

      expect(assigned['a'], 7);
      // b carries no provider number, so it continues where a left off and
      // takes 8; c asked for that same 8 and climbs to the next free one.
      expect(assigned['b'], 8);
      expect(assigned['c'], 9);
      expect(assigned.values.toSet().length, 3);
    });

    test('keep existing leaves the numbers the user typed alone and reserves them', () {
      final ordered = [channel('a', number: 1), channel('b'), channel('c')];

      final assigned = assignChannelNumbers(ordered: ordered);

      expect(assigned['a'], 1);
      expect(assigned['b'], 2);
      expect(assigned['c'], 3);
      expect(assigned.values.toSet().length, 3);
    });

    test('without keep existing everything is handed out fresh', () {
      final ordered = [channel('a', number: 500), channel('b')];

      final assigned = assignChannelNumbers(ordered: ordered, keepExisting: false);

      expect(assigned['a'], 1);
      expect(assigned['b'], 2);
    });

    test('a channel keeping its number still holds its place in the group', () {
      final ordered = [
        channel('cctv1', group: '央视', number: 300),
        channel('cctv2', group: '央视'),
        channel('cctv3', group: '央视'),
      ];

      final assigned = assignChannelNumbers(
        ordered: ordered,
        mode: IptvNumberingMode.perGroup,
        groupRanks: const {'央视': 0},
      );

      expect(assigned['cctv1'], 300);
      // The block's second and third places, not its first and second:
      // cctv1 stands in the first one whatever number it carries.
      expect(assigned['cctv2'], 2);
      expect(assigned['cctv3'], 3);
    });

    test('two channels that want one number do not both get it', () {
      final ordered = [channel('first', providerNumber: 9), channel('second', providerNumber: 9)];

      final assigned = assignChannelNumbers(ordered: ordered, mode: IptvNumberingMode.fromPlaylist);

      expect(assigned['first'], 9);
      expect(assigned['second'], 10);
    });
  });

  group('iptvNextFreeNumber', () {
    test('climbs one at a time over a run of taken numbers', () {
      expect(iptvNextFreeNumber([5, 6, 7], 5), 8);
    });

    test('returns the wanted number when it is free', () {
      expect(iptvNextFreeNumber([1, 2], 5), 5);
    });

    test('never answers below one, whatever it is asked for', () {
      expect(iptvNextFreeNumber(const [1], 0), 2);
      expect(iptvNextFreeNumber(const [], -7), 1);
    });
  });

  group('the user state survives storage', () {
    test('a channel written before numbers existed reads back unnumbered', () {
      final restored = IptvChannel.fromJson({
        'id': 'old',
        'entry': {'name': 'Old', 'url': 'http://a/1'},
        'position': 3,
      });

      expect(restored.number, isNull);
      expect(restored.pinned, isFalse);
      expect(restored.hidden, isFalse);
    });

    test('number and pinned travel through JSON', () {
      final saved = channel('cctv1', group: '央视', number: 1, pinned: true);
      // Through the encoder, not through [toJson] alone: json_serializable
      // writes a nested model as the object itself and leaves `jsonEncode`
      // to call its `toJson`, so a store that kept `toJson`'s map verbatim
      // would be holding a model instance where a reader expects a map.
      final restored = IptvChannel.fromJson(jsonDecode(jsonEncode(saved)) as Map<String, Object?>);

      expect(restored, saved);
      expect(restored.number, 1);
      expect(restored.pinned, isTrue);
    });

    test('a group record travels through JSON', () {
      final saved = IptvGroup.of(name: '央视', order: 4, pinned: true, hidden: true);
      final restored = IptvGroup.fromJson(saved.toJson());

      expect(restored, saved);
    });
  });

  group('IptvLineHealth JSON', () {
    final checked = DateTime.utc(2026, 10, 12, 3, 30);

    test('a good verdict travels', () {
      final health = IptvLineHealth.probe(
        url: 'http://a/1',
        checkedAt: checked,
        latency: const Duration(milliseconds: 120),
      );

      expect(IptvLineHealth.fromJson(health.toJson()), health);
    });

    test('a bad verdict keeps its failure count', () {
      final first = IptvLineHealth.failed(url: 'http://a/1', checkedAt: checked, message: 'timeout');
      final second = IptvLineHealth.failed(url: 'http://a/1', checkedAt: checked, message: 'timeout', previous: first);

      expect(second.failures, 2);
      expect(IptvLineHealth.fromJson(second.toJson())?.failures, 2);
    });

    test('a record naming no address is dropped rather than guessed at', () {
      expect(IptvLineHealth.fromJson({'ok': false, 'checkedAt': checked.toIso8601String()}), isNull);
      expect(IptvLineHealth.fromJson({'url': 'http://a/1', 'ok': false, 'checkedAt': 'not a time'}), isNull);
    });

    test('a successful verdict says so and carries no failures', () {
      final back = IptvLineHealth.probe(url: 'http://a/1', checkedAt: checked, latency: Duration.zero);

      expect(back.ok, isTrue);
      expect(back.failures, 0);
    });
  });
}
