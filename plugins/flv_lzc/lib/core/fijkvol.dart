//MIT License
//
//Copyright (c) [2019] [Befovy]
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

part of fijkplayer;

/// [vol] is the value of volume, and has been mapped into range [0.0, 1.0].
/// true value of [sui] indicates that Android/iOS system volume changed UI is shown for this volume change event.
/// [type] shows track\stream type for this volume change, this value is always [FijkVolume.STREAM_MUSIC] in this version
@immutable
class FijkVolumeEvent {
  final double vol;
  final bool sui;
  final int type;

  const FijkVolumeEvent({
    required this.vol,
    required this.sui,
    required this.type,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FijkVolumeEvent &&
          vol != 0.0 &&
          vol != 1.0 &&
          hashCode == other.hashCode);

  @override
  int get hashCode => Object.hash(vol, sui, type);
}

class _VolumeValueNotifier extends ValueNotifier<FijkVolumeEvent> {
  _VolumeValueNotifier(FijkVolumeEvent value) : super(value);
}

/// Fijk System Volume Manger
class FijkVolume {
  FijkVolume._();

  static const int STREAM_VOICE_CALL = 0;
  static const int STREAM_SYSTEM = 1;
  static const int STREAM_RING = 2;
  static const int STREAM_MUSIC = 3;
  static const int STREAM_ALARM = 4;

  /// show system volume changed UI if no playable player.
  /// hide system volume changed UI if some players are in playable state.
  static const int hideUIWhenPlayable = 0;

  /// show system volume changed UI if no start state player.
  /// hide system volume changed UI if some players are in start state.
  static const int hideUIWhenPlaying = 1;

  /// never show system volume changed UI.
  static const int neverShowUI = 2;

  /// always show system volume changed UI
  static const int alwaysShowUI = 3;

  static FijkVolume _instance = FijkVolume._();

  static _VolumeValueNotifier _notifier =
      _VolumeValueNotifier(FijkVolumeEvent(vol: 0, sui: false, type: 0));

  static const double _defaultStep = 1.0 / 16.0;

  /// Mute system volume.
  /// return system volume after mute
  static Future<double> mute() async {
    var vol = await FijkPlugin._channel.invokeMethod("volumeMute");
    if (vol != null) return Future.value(vol);
    return Future.value(0);
  }

  /// set system volume to [vol].
  /// the range of [vol] is [0.0, 1,0].
  /// return the system volume value after set.
  static Future<double> setVol(double vol) async {
    if (vol < 0.0 || vol > 1.0) {
      return Future.error(ArgumentError.value(
          vol, "step must be not null and in range [0.0, 1.0]"));
    } else {
      var afterSet = await FijkPlugin._channel
          .invokeMethod("volumeSet", <String, dynamic>{'vol': vol});
      if (afterSet != null) return Future.value(afterSet);
      return Future.value(0);
    }
  }

  /// get ths current system volume.
  /// the range of returned value is [0.0, 1.0].
  static Future<double> getVol() async {
    var vol = await FijkPlugin._channel.invokeMethod("systemVolume");
    if (vol != null) return Future.value(vol);
    return Future.value(0);
  }

  /// increase system volume by step, step must be in range [0.0, 1.0].
  /// return the system volume value after increase.
  /// the return volume value may be not equals to the current volume + step.
  static Future<double> up({double step = _defaultStep}) async {
    if (step < 0.0 || step > 1.0) {
      return Future.error(ArgumentError.value(
          step, "step must be not null and in range [0.0, 1.0]"));
    } else {
      var vol = await FijkPlugin._channel
          .invokeMethod("volumeUp", <String, dynamic>{'step': step});
      if (vol != null) return Future.value(vol);
      return Future.value(0);
    }
  }

  /// decrease system volume by step, step must be in range [0.0, 1.0].
  /// return the system volume value after decrease.
  /// the return volume value may be not equals to the current volume - step.
  static Future<double> down({double step = _defaultStep}) async {
    if (step < 0.0 || step > 1.0) {
      return Future.error(ArgumentError.value(
          step, "step must be not null and in range [0.0, 1.0]"));
    } else {
      var vol = await FijkPlugin._channel
          .invokeMethod("volumeDown", <String, dynamic>{'step': step});
      if (vol != null) return Future.value(vol);
      return Future.value(0);
    }
  }

  /// update the ui mode when system volume changing.
  /// mode can be one of
  /// {[hideUIWhenPlayable], [hideUIWhenPlaying], [neverShowUI], [alwaysShowUI]}
  static Future<void> setUIMode(int mode) {
    if (mode < hideUIWhenPlayable || hideUIWhenPlayable > alwaysShowUI)
      return Future.error(ArgumentError.notNull("mode"));
    else
      return FijkPlugin._channel
          .invokeMethod("volUiMode", <String, dynamic>{'mode': mode});
  }

  void _onVolCallback(double vol, bool ui) {
    _notifier.value = FijkVolumeEvent(vol: vol, sui: ui, type: STREAM_MUSIC);
  }

  /// the [listener] wiil be nitified after system volume changed.
  /// the value after change can be obtained through [FijkVolume.value]
  static void addListener(VoidCallback listener) {
    FijkPlugin._onLoad("vol");
    _notifier.addListener(listener);
  }

  /// remove the [listener] set using [addListener]
  static void removeListener(VoidCallback listener) {
    _notifier.removeListener(listener);
  }

  /// get the system volume event.
  /// a valid value is returned only if [addListener] is called and there's really volume changing
  static FijkVolumeEvent get value => _notifier.value;
}

/// Volume changed callback func.
///
/// See [FijkVolumeEvent]
/// [value] is the value of volume, and has been mapped into range [0.0, 1.0]
/// true value of [ui] indicates that Android/iOS system volume changed UI is shown for this volume change event
/// [streamType] shows track\stream type for this volume change, this value is always [FijkVolume.STREAM_MUSIC] in this version
typedef FijkVolumeCallback = void Function(FijkVolumeEvent value);

/// stateful widget that watching system volume, no ui widget
/// when system volume changed, [watcher] will be invoked.
class FijkVolumeWatcher extends StatefulWidget {
  /// volume changed callback
  final FijkVolumeCallback watcher;

  /// child widget, must be non-null
  final Widget child;

  /// whether show default volume changed toast, default value is false.
  ///
  /// The default toast ui insert an OverlayEntry to current context's overlay
  final bool showToast;

  FijkVolumeWatcher({
    required this.watcher,
    /*required*/ required this.child,
    bool showToast = false,
  }) : showToast = showToast;

  @override
  _FijkVolumeWatcherState createState() => _FijkVolumeWatcherState();
}

class _FijkVolumeWatcherState extends State<FijkVolumeWatcher> {
  static OverlayEntry? _entry;
  static Timer? _timer;
  late StreamController<double> _volController;

  @override
  void initState() {
    super.initState();
    _volController = StreamController.broadcast();
    FijkVolume.addListener(volChanged);
    FijkVolume.setUIMode(FijkVolume.hideUIWhenPlayable);
  }

  void volChanged() {
    FijkVolumeEvent value = FijkVolume.value;
    _volController.add(value.vol);
    widget.watcher(value);
    if (widget.showToast && !value.sui) {
      showVolToast(value.vol);
    }
  }

  /// reference https://www.kikt.top/posts/flutter/toast/oktoast/
  void showVolToast(double vol) {
    bool active = _timer?.isActive ?? false;
    _timer?.cancel();
    Widget widget = defaultFijkVolumeToast(vol, _volController.stream);
    if (active == false) {
      var entry = OverlayEntry(builder: (_) => widget);
      _entry = entry;
      var overlay = Overlay.of(context);
      overlay.insert(entry);
    }
    _timer = Timer(const Duration(milliseconds: 800), () {
      _entry?.remove();
    });
  }

  @override
  void dispose() {
    super.dispose();
    FijkVolume.removeListener(volChanged);
    _volController.close();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
