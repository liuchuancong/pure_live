import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class AtlasLoader {
  const AtlasLoader();

  Future<ui.Image> loadFromAsset(String assetPath, {int? targetWidth, int? targetHeight}) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();

    final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth, targetHeight: targetHeight);

    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
