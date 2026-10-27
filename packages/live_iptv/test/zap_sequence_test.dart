import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/order/iptv_zap_sequence.dart';
import 'package:test/test.dart';

IptvChannel channel(String name, {int? number}) => IptvChannel.of(
  id: name,
  entry: IptvEntry.of(name: name, url: 'http://a/$name.m3u8'),
  number: number,
);

void main() {
  final abc = [channel('a'), channel('b'), channel('c')];

  group('IptvZapSequence', () {
    test('steps forward through the list', () {
      final sequence = IptvZapSequence(channels: abc);

      expect(sequence.next(fromId: 'a').channel?.id, 'b');
      expect(sequence.next(fromId: 'b').channel?.id, 'c');
    });

    test('steps past the end and comes back round the top', () {
      final sequence = IptvZapSequence(channels: abc);

      final step = sequence.next(fromId: 'c');

      expect(step.channel?.id, 'a');
      expect(step.edge, IptvZapEdge.wrapped);
      expect(step.wrapped, isTrue);
      expect(step.needsLoad, isTrue);
    });

    test('steps back past the top and lands at the end', () {
      final sequence = IptvZapSequence(channels: abc);

      final step = sequence.previous(fromId: 'a');

      expect(step.channel?.id, 'c');
      expect(step.edge, IptvZapEdge.wrapped);
    });

    test('a middle step does not report a wrap', () {
      final sequence = IptvZapSequence(channels: abc);

      expect(sequence.previous(fromId: 'c').edge, IptvZapEdge.moved);
    });

    test('reversal swaps the two keys without reordering the list', () {
      final forward = IptvZapSequence(channels: abc);
      final reversed = IptvZapSequence(channels: abc, reversed: true);

      expect(reversed.channels.map((entry) => entry.id), forward.channels.map((entry) => entry.id));
      expect(reversed.next(fromId: 'a').channel?.id, 'c');
      expect(reversed.previous(fromId: 'a').channel?.id, 'b');
    });

    test('with no channel playing, forward starts at the top and back at the end', () {
      final sequence = IptvZapSequence(channels: abc);

      expect(sequence.next().channel?.id, 'a');
      expect(sequence.previous().channel?.id, 'c');
    });

    test('a channel that has left the library is not an error', () {
      final sequence = IptvZapSequence(channels: abc);

      expect(sequence.next(fromId: 'gone').channel?.id, 'a');
      expect(sequence.previous(fromId: 'gone').channel?.id, 'c');
    });

    test('stepping in a one-channel list does not ask for a reload', () {
      final sequence = IptvZapSequence(channels: [channel('only')]);

      final step = sequence.next(fromId: 'only');

      expect(step.channel?.id, 'only');
      expect(step.edge, IptvZapEdge.same);
      expect(step.needsLoad, isFalse);
    });

    test('an empty list answers empty rather than throwing', () {
      final sequence = IptvZapSequence(channels: const []);

      expect(sequence.isEmpty, isTrue);
      expect(sequence.next().channel, isNull);
      expect(sequence.next().edge, IptvZapEdge.empty);
      expect(sequence.previous().edge, IptvZapEdge.empty);
      expect(sequence.first, isNull);
      expect(sequence.last, isNull);
    });

    test('a delta of zero stays put', () {
      final sequence = IptvZapSequence(channels: abc);

      expect(sequence.step(0, fromId: 'b').channel?.id, 'b');
      expect(sequence.step(0, fromId: 'b').edge, IptvZapEdge.same);
    });

    test('a long stride wraps the same way a single step does', () {
      final sequence = IptvZapSequence(channels: abc);

      expect(sequence.step(4, fromId: 'a').channel?.id, 'b');
      expect(sequence.step(-1, fromId: 'a').channel?.id, 'c');
    });

    test('a typed number is looked up, not stepped to', () {
      final sequence = IptvZapSequence(channels: [channel('a', number: 1), channel('b', number: 203)]);

      expect(sequence.byNumber(203)?.id, 'b');
      expect(sequence.byNumber(7), isNull);
    });

    test('index and position agree with the list', () {
      final sequence = IptvZapSequence(channels: abc);

      expect(sequence.indexOf('b'), 1);
      expect(sequence.indexOf('nope'), isNull);
      expect(sequence.at(0)?.id, 'a');
      expect(sequence.at(3), isNull);
      expect(sequence.at(-1), isNull);
    });
  });
}
