import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pure_live/get/get.dart';

class DisplayModeInfo {
  const DisplayModeInfo({
    required this.enabled,
    required this.currentRefreshRate,
    required this.maxRefreshRate,
    required this.preferredRefreshRate,
    required this.supportedRefreshRates,
    this.requestedRefreshRate,
    this.displayId,
    this.width,
    this.height,
  });

  final bool enabled;
  final double currentRefreshRate;
  final double maxRefreshRate;
  final double preferredRefreshRate;
  final List<double> supportedRefreshRates;
  final double? requestedRefreshRate;
  final int? displayId;
  final int? width;
  final int? height;

  factory DisplayModeInfo.fromMap(Map<dynamic, dynamic> map) {
    double number(String key, [double fallback = 0]) {
      final value = map[key];
      return value is num ? value.toDouble() : fallback;
    }

    final rates = (map['supportedRefreshRates'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList(growable: false);

    return DisplayModeInfo(
      enabled: map['enabled'] == true,
      currentRefreshRate: number('currentRefreshRate'),
      maxRefreshRate: number('maxRefreshRate'),
      preferredRefreshRate: number('preferredRefreshRate'),
      supportedRefreshRates: rates,
      requestedRefreshRate: map['requestedRefreshRate'] is num
          ? number('requestedRefreshRate')
          : null,
      displayId: (map['displayId'] as num?)?.toInt(),
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DisplayModeInfo &&
        other.enabled == enabled &&
        other.currentRefreshRate == currentRefreshRate &&
        other.maxRefreshRate == maxRefreshRate &&
        other.preferredRefreshRate == preferredRefreshRate &&
        other.requestedRefreshRate == requestedRefreshRate &&
        other.displayId == displayId &&
        other.width == width &&
        other.height == height &&
        listEquals(other.supportedRefreshRates, supportedRefreshRates);
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    currentRefreshRate,
    maxRefreshRate,
    preferredRefreshRate,
    requestedRefreshRate,
    displayId,
    width,
    height,
    Object.hashAll(supportedRefreshRates),
  );
}

class DisplayModeService {
  DisplayModeService._();

  static const MethodChannel _channel = MethodChannel('pure_live/display_mode');
  static final Rx<DisplayModeInfo?> info = Rx<DisplayModeInfo?>(null);
  static bool _handlerInstalled = false;

  static void _ensureHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'displayModeChanged' || call.arguments is! Map) return;
      _publish(DisplayModeInfo.fromMap(Map<dynamic, dynamic>.from(call.arguments as Map)));
    });
  }

  static void _publish(DisplayModeInfo next) {
    if (info.value == next) return;
    info.value = next;
  }

  static Future<DisplayModeInfo?> setHighRefreshRate(bool enabled) async {
    _ensureHandler();
    try {
      final result = await _channel.invokeMapMethod<dynamic, dynamic>('setHighRefreshRate', {
        'enabled': enabled,
      });
      if (result == null) return null;
      final parsed = DisplayModeInfo.fromMap(result);
      _publish(parsed);
      return parsed;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<DisplayModeInfo?> refreshInfo() async {
    _ensureHandler();
    try {
      final result = await _channel.invokeMapMethod<dynamic, dynamic>('getDisplayModeInfo');
      if (result == null) return null;
      final parsed = DisplayModeInfo.fromMap(result);
      _publish(parsed);
      return parsed;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
