import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_retriever_platform_interface/screen_retriever_platform_interface.dart';

class ScreenRetriever {
  ScreenRetriever._();

  /// The shared instance of [ScreenRetriever].
  static final ScreenRetriever instance = ScreenRetriever._();

  ScreenRetrieverPlatform get _platform => ScreenRetrieverPlatform.instance;

  /// Handle screen events from the platform side.
  void _handleScreenEvent(event) {
    final type = event['type'] as String?;
    if (type == null) return;
    for (var listener in _listeners) {
      listener.onScreenEvent(type);
    }
  }

  final ObserverList<ScreenListener> _listeners =
      ObserverList<ScreenListener>();

  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  void addListener(ScreenListener listener) {
    if (!hasListeners) {
      _platform.onScreenEventReceiver.listen(_handleScreenEvent);
    }
    _listeners.add(listener);
  }

  void removeListener(ScreenListener listener) {
    _listeners.remove(listener);
    if (!hasListeners) {
      _platform.onScreenEventReceiver.listen(null);
    }
  }

  Future<Offset> getCursorScreenPoint() {
    return _platform.getCursorScreenPoint();
  }

  Future<Display> getPrimaryDisplay() {
    return _platform.getPrimaryDisplay();
  }

  Future<List<Display>> getAllDisplays() async {
    return _platform.getAllDisplays();
  }
}

final ScreenRetriever screenRetriever = ScreenRetriever.instance;
