import 'dart:ui';
import '../../layout/layout_result.dart';
import 'package:flame_barrage/src/render/base_renderer.dart';

class MixedRenderer implements BaseRenderer {
  const MixedRenderer();

  @override
  Picture buildPicture(LayoutResult result) {
    final recorder = PictureRecorder();
    // Keep a modest cull allowance for cached outlines and shadows. This does
    // not allocate a layer and prevents glow/italic glyphs being cut at the
    // paragraph bounds.
    final canvas = Canvas(recorder, Rect.fromLTRB(-8, -8, result.width + 8, result.height + 8));

    final spans = result.spans;
    final len = spans.length;
    for (int i = 0; i < len; i++) {
      spans[i].paint(canvas);
    }

    return recorder.endRecording();
  }
}
