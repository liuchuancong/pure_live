import 'dart:ui';
import 'package:flame_barrage/src/layout/layout_result.dart';

abstract class BaseRenderer {
  Picture buildPicture(LayoutResult result);
}
