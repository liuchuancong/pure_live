import 'package:flutter/widgets.dart' show BuildContext, Widget;
import 'package:pure_uikit/src/icons/rendering/icon_render_context.dart';

/// Builds one custom icon draw (SVG, raster brand art, animated marks).
typedef PureIconBuilder = Widget Function(BuildContext context, PureIconRenderContext renderContext);
