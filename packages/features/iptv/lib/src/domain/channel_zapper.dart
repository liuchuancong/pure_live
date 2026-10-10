// Module: lib/src/domain/channel_zapper.dart
// Purpose: IPTV channel zapping: ordered channel list, current position,
// next/previous with wrap-around, and group filtering.
// Author: liuchuancong
// Created: 2026-10-10

/// One zappable channel: name, group and its stream urls.
final class ZapChannel {
  const ZapChannel({
    required this.name,
    required this.group,
    required this.urls,
    this.headers = const <String, String>{},
  });

  final String name;
  final String group;
  final List<Uri> urls;
  final Map<String, String> headers;

  Uri get primaryUrl => urls.first;
}

/// The zapper. Wrap-around is what a remote's channel-up/down means; the
/// group filter narrows the cycle to one category without changing position
/// in the full list.
final class ChannelZapper {
  ChannelZapper({required List<ZapChannel> channels}) : _channels = List.of(channels) {
    if (_channels.isNotEmpty) {
      _position = 0;
    }
  }

  final List<ZapChannel> _channels;
  int _position = -1;
  String? _groupFilter;

  List<ZapChannel> get channels => List.unmodifiable(_channels);
  ZapChannel? get current => (_position >= 0 && _position < _channels.length) ? _channels[_position] : null;
  int get position => _position;

  /// The visible channels: filtered by the group when one is set.
  List<ZapChannel> visible() => _groupFilter == null
      ? _channels
      : _channels.where((channel) => channel.group == _groupFilter).toList(growable: false);

  /// Narrows zapping to [group]; null clears the filter. The position moves
  /// to the first channel of the new scope so "next" is meaningful.
  void setGroupFilter(String? group) {
    _groupFilter = group;
    final scope = visible();
    if (scope.isEmpty) {
      _position = -1;
      return;
    }
    final currentChannel = current;
    final keep = currentChannel != null && scope.contains(currentChannel);
    _position = keep ? _channels.indexOf(currentChannel) : _channels.indexOf(scope.first);
  }

  ZapChannel? _step(int direction) {
    final scope = visible();
    if (scope.isEmpty) {
      return null;
    }
    final currentIndex = current == null ? -1 : scope.indexOf(current!);
    final nextIndex = (currentIndex + direction) % scope.length;
    _position = _channels.indexOf(scope[nextIndex < 0 ? scope.length + nextIndex : nextIndex]);
    return current;
  }

  ZapChannel? zapUp() => _step(-1);

  ZapChannel? zapDown() => _step(1);

  /// Jumps directly to a channel by name; returns whether it existed.
  bool jumpTo(String name) {
    final index = _channels.indexWhere((channel) => channel.name == name);
    if (index < 0) {
      return false;
    }
    _position = index;
    return true;
  }
}
