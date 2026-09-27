import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/core/flv_splice_relay.dart';

const _frame = 40; // video frame interval, ms
const _gop = 2000; // keyframe interval, ms

Uint8List _tag(int type, int ts, List<int> data) {
  final size = data.length;
  final out = BytesBuilder()
    ..add([type, (size >> 16) & 0xff, (size >> 8) & 0xff, size & 0xff])
    ..add([(ts >> 16) & 0xff, (ts >> 8) & 0xff, ts & 0xff, (ts >> 24) & 0xff, 0, 0, 0])
    ..add(data);
  final total = 11 + size;
  out.add([(total >> 24) & 0xff, (total >> 16) & 0xff, (total >> 8) & 0xff, total & 0xff]);
  return out.toBytes();
}

final Uint8List _header = Uint8List.fromList([0x46, 0x4c, 0x56, 1, 5, 0, 0, 0, 9, 0, 0, 0, 0]);
Uint8List _videoConfig(int variant) => _tag(9, 0, [0x17, 0, 0, 0, 0, 1, 0x64, 0, variant]);
Uint8List _audioConfig() => _tag(8, 0, [0xaf, 0, 0x12, 0x10]);
Uint8List _video(int ts) => _tag(9, ts, [ts % _gop == 0 ? 0x17 : 0x27, 1, 0, 0, 0, 1, 2, 3]);
Uint8List _audio(int ts) => _tag(8, ts, [0xaf, 1, 9, 9]);

/// A live connection: configs, then audio and video from the GOP starting at
/// [start] until [end] (exclusive), on a timeline shifted by [shift].
class _FakeLive implements FlvTagReader {
  _FakeLive({required int start, required this.end, this.shift = 0, this.configVariant = 1, this.onDeliver})
    : _next = start {
    _queue.addAll([_header, _videoConfig(configVariant), _audioConfig()]);
  }

  final int end;
  final int shift;
  final int configVariant;
  final void Function(int ts)? onDeliver;
  final List<Uint8List> _queue = [];
  int _next;
  bool cancelled = false;

  @override
  Future<Uint8List?> next() async {
    if (cancelled) return null;
    if (_queue.isEmpty) {
      if (_next >= end) return null;
      _queue.addAll([_video(_next + shift), _audio(_next + shift + 20)]);
      onDeliver?.call(_next);
      _next += _frame;
    }
    return _queue.removeAt(0);
  }

  @override
  Future<void> cancel() async => cancelled = true;
}

class _Output {
  final List<Uint8List> packets = [];
  List<Uint8List> get tags => packets.skip(1).toList();
  List<int> timestamps(int type) => [
    for (final t in tags)
      if (FlvTag.type(t) == type && !FlvTag.isVideoConfig(t) && !FlvTag.isAudioConfig(t)) FlvTag.timestamp(t),
  ];
}

void main() {
  final base = DateTime.utc(2026, 9, 27, 12);

  test('a lease renewed while the old stream is alive splices without gap or repeat', () async {
    var liveTs = 0;
    DateTime now() => base.add(Duration(milliseconds: liveTs));
    final a = _FakeLive(start: 0, end: 30000, onDeliver: (ts) => liveTs = ts);
    late _FakeLive b;
    final out = _Output();
    final session = FlvSpliceSession(
      initial: FlvLeasedSource(Uri.parse('https://cdn/a.flv'), refreshAt: base.add(const Duration(seconds: 20))),
      open: (url) async => url.path == '/a.flv' ? a : b,
      renew: (current) async {
        if (current.url.path == '/b.flv') throw StateError('no more leases');
        // The CDN starts a new connection at its cached GOP, behind the old one.
        b = _FakeLive(start: (liveTs ~/ _gop - 1) * _gop, end: 60000);
        return FlvLeasedSource(Uri.parse('https://cdn/b.flv'));
      },
      emit: out.packets.add,
      now: now,
    );
    await session.run();

    expect(session.switches, 1);
    expect(a.cancelled, isTrue);
    final video = out.timestamps(9);
    expect(video.first, 0);
    expect(video.last, 60000 - _frame);
    for (var i = 1; i < video.length; i++) {
      expect(video[i] - video[i - 1], _frame, reason: 'video ${video[i - 1]} -> ${video[i]}');
    }
    final audio = out.timestamps(8);
    for (var i = 1; i < audio.length; i++) {
      expect(audio[i] - audio[i - 1], _frame, reason: 'audio ${audio[i - 1]} -> ${audio[i]}');
    }
    final switchTag = out.tags.firstWhere(
      (t) => FlvTag.type(t) == 9 && FlvTag.timestamp(t) > 20000 && FlvTag.isKeyframe(t),
    );
    expect(FlvTag.timestamp(switchTag) % _gop, 0);
    expect(out.tags.where(FlvTag.isVideoConfig), hasLength(1), reason: 'an identical configuration is not repeated');
  });

  test('an old stream cut early continues at the next keyframe of the new one', () async {
    final out = _Output();
    final session = FlvSpliceSession(
      initial: FlvLeasedSource(Uri.parse('https://cdn/a.flv')),
      open: (url) async => url.path == '/a.flv' ? _FakeLive(start: 0, end: 20000) : _FakeLive(start: 24000, end: 30000),
      renew: (current) async {
        if (current.url.path == '/b.flv') throw StateError('no more leases');
        return FlvLeasedSource(Uri.parse('https://cdn/b.flv'));
      },
      emit: out.packets.add,
    );
    await session.run();

    final video = out.timestamps(9);
    expect(session.switches, 1);
    expect(video, containsAllInOrder([20000 - _frame, 24000]));
    expect(video.indexOf(24000), video.indexOf(20000 - _frame) + 1);
    for (var i = 1; i < video.length; i++) {
      expect(video[i], greaterThan(video[i - 1]));
    }
  });

  test('a new connection on another timeline is shifted to continue the old one', () async {
    var liveTs = 0;
    final out = _Output();
    final session = FlvSpliceSession(
      initial: FlvLeasedSource(Uri.parse('https://cdn/a.flv'), refreshAt: base.add(const Duration(seconds: 10))),
      open: (url) async => url.path == '/a.flv'
          ? _FakeLive(start: 0, end: 30000, onDeliver: (ts) => liveTs = ts)
          : _FakeLive(start: 10000, end: 16000, shift: -1000000),
      renew: (current) async {
        if (current.url.path == '/b.flv') throw StateError('no more leases');
        return FlvLeasedSource(Uri.parse('https://cdn/b.flv'));
      },
      emit: out.packets.add,
      now: () => base.add(Duration(milliseconds: liveTs)),
    );
    await session.run();

    final video = out.timestamps(9);
    expect(session.switches, 1);
    for (var i = 1; i < video.length; i++) {
      expect(video[i] - video[i - 1], inInclusiveRange(1, _frame), reason: 'video ${video[i - 1]} -> ${video[i]}');
    }
  });

  test('a changed decoder configuration is sent before the switch keyframe', () async {
    var liveTs = 0;
    final out = _Output();
    final session = FlvSpliceSession(
      initial: FlvLeasedSource(Uri.parse('https://cdn/a.flv'), refreshAt: base.add(const Duration(seconds: 10))),
      open: (url) async => url.path == '/a.flv'
          ? _FakeLive(start: 0, end: 30000, onDeliver: (ts) => liveTs = ts)
          : _FakeLive(start: 8000, end: 16000, configVariant: 2),
      renew: (current) async {
        if (current.url.path == '/b.flv') throw StateError('no more leases');
        return FlvLeasedSource(Uri.parse('https://cdn/b.flv'));
      },
      emit: out.packets.add,
      now: () => base.add(Duration(milliseconds: liveTs)),
    );
    await session.run();

    final configs = out.tags.where(FlvTag.isVideoConfig).toList();
    expect(configs, hasLength(2));
    final index = out.tags.indexOf(configs.last);
    final following = out.tags.skip(index + 1).firstWhere((t) => FlvTag.type(t) == 9);
    expect(FlvTag.isKeyframe(following), isTrue);
    expect(FlvTag.timestamp(configs.last), FlvTag.timestamp(following));
  });

  test('a failed renewal keeps the working stream to its end', () async {
    var liveTs = 0;
    final out = _Output();
    final session = FlvSpliceSession(
      initial: FlvLeasedSource(Uri.parse('https://cdn/a.flv'), refreshAt: base.add(const Duration(seconds: 5))),
      open: (url) async => _FakeLive(start: 0, end: 12000, onDeliver: (ts) => liveTs = ts),
      renew: (current) async => throw StateError('resolver offline'),
      emit: out.packets.add,
      now: () => base.add(Duration(milliseconds: liveTs)),
    );
    await session.run();

    final video = out.timestamps(9);
    expect(session.switches, 0);
    expect(video.first, 0);
    expect(video.last, 12000 - _frame);
    expect(video, hasLength(12000 ~/ _frame));
  });

  test('only leased plain FLV inputs are relayed', () {
    final soon = DateTime.now().add(const Duration(minutes: 4));
    expect(FlvSpliceRelay.appliesTo('https://hdl.cdn/live/1.flv?expire=300', refreshAt: soon), isTrue);
    expect(FlvSpliceRelay.appliesTo('https://hdl.cdn/live/1.flv?expire=300', refreshAt: null), isFalse);
    expect(FlvSpliceRelay.appliesTo('https://hdl.cdn/live/1.flv?expire=0', refreshAt: soon), isFalse);
    expect(FlvSpliceRelay.appliesTo('https://al.flv.huya.com/src/1.flv?wsTime=66f&fm=x', refreshAt: soon), isFalse);
    expect(FlvSpliceRelay.appliesTo('https://hls.cdn/live/1.m3u8?expire=300', refreshAt: soon), isFalse);
  });
}
