import 'dart:ui';
import '../../layout/layout_result.dart';
import 'package:flame_barrage/src/render/base_renderer.dart';

class MixedRenderer implements BaseRenderer {
  const MixedRenderer();

  @override
  Picture buildPicture(LayoutResult result) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, result.width, result.height));

    final spans = result.spans;
    final len = spans.length;
    for (int i = 0; i < len; i++) {
      spans[i].paint(canvas);
    }

    return recorder.endRecording();
  }
}
