import 'layout_span.dart';

class LayoutResult {
  LayoutResult({
    required this.width,
    required this.height,
    required this.spans,
    required this.cacheKey,
  });

  final double width;

  final double height;

  final List<LayoutSpan> spans;

  final String cacheKey;
}
