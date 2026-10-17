import 'package:flutter/material.dart' show BlendMode, Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit_background/pure_uikit_background.dart';

void main() {
  group('BackgroundLayer and BackgroundLayerStack', () {
    test('a layer defaults to full opacity and srcOver blend', () {
      const layer = BackgroundLayer(config: SolidBackground(color: Colors.black));
      expect(layer.opacity, 1);
      expect(layer.blend, BlendMode.srcOver);
    });

    test('a layer rejects out-of-range opacity', () {
      expect(
        () => BackgroundLayer(config: const SolidBackground(color: Colors.black), opacity: 1.5),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a stack preserves layer order', () {
      const stack = BackgroundLayerStack(
        layers: [
          BackgroundLayer(config: SolidBackground(color: Colors.black)),
          BackgroundLayer(config: SolidBackground(color: Colors.white), opacity: 0.5),
        ],
      );
      expect(stack.layers, hasLength(2));
      expect((stack.layers.first.config as SolidBackground).color, Colors.black);
      expect(stack.layers.last.opacity, 0.5);
    });
  });
}
