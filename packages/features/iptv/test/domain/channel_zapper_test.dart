// Module: test/domain/channel_zapper_test.dart
// Purpose: Pins wrap-around, filter-without-jumping, typed-number selection and unplayable handling.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:pure_live_iptv_feature/pure_live_iptv_feature.dart';
import 'package:test/test.dart';

ZapChannel _channel(String name, String group, {String? url}) =>
    ZapChannel(name: name, group: group, urls: <Uri>[Uri.parse(url ?? 'http://cdn.example.com/$name.m3u8')]);

ZapChannel _broken(String name, String group) => ZapChannel(name: name, group: group, urls: const <Uri>[]);

void main() {
  final lineup = <ZapChannel>[
    _channel('cctv1', '央卫'),
    _channel('cctv2', '央卫'),
    _channel('hunan', '地方'),
    _broken('ghost', '地方'),
  ];

  test('test_channelZapper_startsAtTheFirstPlayableChannel', () {
    final zapper = ChannelZapper.lineup(lineup);

    expect(zapper.current?.name, 'cctv1');
    expect(zapper.visibleNumber, 1);
  });

  test('test_channelZapper_wrapsInBothDirections', () {
    var zapper = ChannelZapper.lineup(lineup, skipUnplayable: false);
    expect((zapper.zapUp() as ZapMoved).channel.name, 'ghost', reason: 'up from the first entry wraps to the last');

    zapper = ChannelZapper.lineup(lineup);
    // cctv1 -> cctv2 -> hunan (ghost is skipped) -> wraps to cctv1
    final second = zapper.zapDown();
    expect((second as ZapMoved).channel.name, 'cctv2');
    final third = zapper.selectChannel(second.channel).zapDown();
    expect((third as ZapMoved).channel.name, 'hunan');
    final wrapped = zapper.selectChannel(third.channel).zapDown();
    expect((wrapped as ZapMoved).channel.name, 'cctv1');
  });

  test('test_channelZapper_skipsUnplayableEntriesByDefault', () {
    final zapper = ChannelZapper.lineup(lineup);

    final moved = zapper.selectChannel(_channel('cctv2', '央卫')).zapDown();
    expect((moved as ZapMoved).channel.name, 'hunan');
    expect(zapper.unplayableCount, 1);
  });

  test('test_channelZapper_selectReachesAnUnplayableEntryDeliberately', () {
    final zapper = ChannelZapper.lineup(lineup);

    expect(zapper.select(4).current?.name, 'ghost', reason: 'a typed number is an explicit choice');
    expect(zapper.select(4).current?.isPlayable, isFalse);
  });

  test('test_channelZapper_changingGroupKeepsTheStationWhenItIsStillInScope', () {
    final zapper = ChannelZapper.lineup(lineup).select(1);

    final widened = zapper.withGroup(null);
    expect(widened.current?.name, zapper.current?.name, reason: 'clearing a filter is not a channel change');

    final narrowed = zapper.withGroup('地方');
    expect(narrowed.current?.name, isNot('cctv1'), reason: 'cctv1 left the scope, so something in 地方 is chosen');
    expect(narrowed.visible().map((channel) => channel.group), <String>['地方', '地方']);
  });

  test('test_channelZapper_selectIsOneBasedAgainstTheVisibleScope', () {
    final zapper = ChannelZapper.lineup(lineup).withGroup('央卫');

    expect(zapper.select(2).current?.name, 'cctv2');
    expect(() => zapper.select(0), throwsA(isA<LineupFailure>()));
    expect(() => zapper.select(3), throwsA(isA<LineupFailure>()));
  });

  test('test_channelZapper_anEmptyScopeSaysSoInsteadOfReturningNullSilently', () {
    final zapper = ChannelZapper.lineup(lineup).withGroup('不存在');

    expect(zapper.isEmpty, isTrue);
    expect(zapper.zapDown(), isA<ZapEmpty>());
    expect(() => zapper.select(1), throwsA(isA<LineupFailure>()));
  });

  test('test_channelZapper_allUnplayableGroupDoesNotSpinTheViewerAround', () {
    final zapper = ChannelZapper.lineup(<ZapChannel>[_broken('a', 'x'), _broken('b', 'x')], group: 'x');

    final step = zapper.zapDown();
    expect(step, isA<ZapEmpty>());
    expect((step as ZapEmpty).reason, contains('no playable stream'));
  });

  test('test_channelZapper_channelsAndVisibleAreUnmodifiable', () {
    final zapper = ChannelZapper.lineup(lineup);

    expect(() => zapper.channels.add(_channel('extra', '地方')), throwsUnsupportedError);
    expect(() => zapper.visible().clear(), throwsUnsupportedError);
  });

  test('test_channelZapper_groupsListsCountsInFirstAppearanceOrder', () {
    final zapper = ChannelZapper.lineup(lineup);

    expect(zapper.groups.keys, <String>['央卫', '地方']);
    expect(zapper.groups['地方'], 2);
  });

  test('test_channelZapper_selectChannelRefusesAForeignEntry', () {
    final zapper = ChannelZapper.lineup(lineup);

    expect(() => zapper.selectChannel(_channel('other list', 'nope')), throwsA(isA<LineupFailure>()));
  });

  test('test_zapChannel_emptyUrlListIsNotACrashAndIsNotPlayable', () {
    final channel = ZapChannel(name: 'header', group: '', urls: const <Uri>[]);

    expect(channel.primaryUrl, isNull);
    expect(channel.isPlayable, isFalse);
    expect(() => channel.primaryUrl, isNot(throwsA(anything)));
  });

  test('test_zapChannel_schemelessUrlIsNotPlayable', () {
    final channel = _channel('x', 'g', url: '/truncated/line.m3u8');

    expect(channel.isPlayable, isFalse);
  });

  test('test_zapChannel_headersAreNamedButNeverPrinted', () {
    final channel = ZapChannel(
      name: 'x',
      group: 'g',
      urls: <Uri>[Uri.parse('http://a/b')],
      headers: <String, String>{'Cookie': 'session=secret'},
    );

    expect(channel.headerNames, <String>['Cookie']);
    expect(channel.toString(), isNot(contains('session=secret')));
  });
}
