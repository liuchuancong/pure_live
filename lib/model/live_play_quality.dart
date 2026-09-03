import 'dart:convert';

class LivePlayQuality {
  /// 清晰度
  final String quality;

  /// 清晰度信息
  final dynamic data;

  /// Stable platform identifier used to confirm that a requested quality was
  /// actually applied. Keeping this separate from [data] avoids comparing
  /// mutable URL lists or adapter-specific maps when a stream is switched.
  final Object? id;

  final int sort;

  LivePlayQuality({required this.quality, this.data, this.id, this.sort = 0});

  /// Never derive identity from [data]: URL lists and request maps are mutable
  /// implementation details and their string form is not a platform contract.
  /// Older adapters without an explicit id fall back to the visible label.
  Object get selectionId => id ?? quality;

  @override
  String toString() {
    return json.encode({'quality': quality, 'id': id?.toString(), 'data': data?.toString()});
  }
}
