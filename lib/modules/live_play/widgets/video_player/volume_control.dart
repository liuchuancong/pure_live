import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

class OverlayVolumeControl extends StatefulWidget {
  final VideoController controller;
  const OverlayVolumeControl({super.key, required this.controller});

  @override
  State<OverlayVolumeControl> createState() => _OverlayVolumeControlState();
}

class _OverlayVolumeControlState extends State<OverlayVolumeControl> {
  double _volume = 0.5;
  double _lastVolume = 0.5;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isMouseInIcon = false;
  bool _isMouseInBar = false;
  Timer? _hideTimer;
  StreamSubscription? _volumeListener;
  StreamSubscription? _platformVolWorker;
  int _controllerGeneration = 0;
  int _valueRevision = 0;
  StreamSubscription? _controllerVolumeSub;
  static const double _barHeight = 150.0;
  static const double _barWidth = 44.0;

  VideoController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _listenGlobalVolume();
    _bindController();
  }

  @override
  void didUpdateWidget(covariant OverlayVolumeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, controller)) return;
    _hideTimer?.cancel();
    _removeOverlay(owner: oldWidget.controller);
    _isMouseInIcon = false;
    _bindController();
  }

  @override
  void dispose() {
    _controllerGeneration++;
    _valueRevision++;
    _hideTimer?.cancel();
    _volumeListener?.cancel();
    _platformVolWorker?.cancel();
    _controllerVolumeSub?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _listenGlobalVolume() {
    final v = SettingsService.to.vol;
    _volumeListener = v.globalVolumeMute.stream.listen((_) => _updateVolumeFromGlobal());
    final platformDefault = PlatformUtils.isMobile ? v.defaultMobileVolume : v.defaultDesktopVolume;
    _platformVolWorker = platformDefault.stream.listen((_) => _updateVolumeFromGlobal());
  }

  bool _owns(VideoController owner, int generation) =>
      mounted && generation == _controllerGeneration && identical(controller, owner);

  void _bindController() {
    _controllerVolumeSub?.cancel();
    final owner = controller;
    final generation = ++_controllerGeneration;
    _valueRevision++;
    final initial = owner.currentVolume.value;
    _volume = initial.isFinite ? initial.clamp(0.0, 1.0) : 0.5;
    _lastVolume = _volume > 0 ? _volume : 0.5;
    _controllerVolumeSub = owner.currentVolume.stream.listen((value) {
      if (!_owns(owner, generation) || !value.isFinite) return;
      // Even an equal-valued event supersedes a pending initial query.
      _valueRevision++;
      _displayVolume(value);
    });
    unawaited(initVolume(owner, generation));
  }

  void _displayVolume(double value) {
    final resolved = value.clamp(0.0, 1.0).toDouble();
    setState(() {
      _volume = resolved;
      if (resolved > 0) _lastVolume = resolved;
    });
    _overlayEntry?.markNeedsBuild();
  }

  void _updateVolumeFromGlobal() {
    if (!mounted) return;
    final v = SettingsService.to.vol;
    final raw = PlatformUtils.isMobile ? v.defaultMobileVolume.v : v.defaultDesktopVolume.v;
    if (!raw.isFinite) return;
    final platformVolume = raw.clamp(0.0, 1.0).toDouble();
    _valueRevision++;
    setState(() {
      if (v.globalVolumeMute.v) {
        if (_volume > 0) _lastVolume = _volume;
        _volume = 0.0;
      } else {
        _volume = platformVolume;
        _lastVolume = _volume;
      }
    });

    unawaited(controller.setVolume(_volume));
    _overlayEntry?.markNeedsBuild();
  }

  Future<void> initVolume(VideoController owner, int generation) async {
    final revision = _valueRevision;
    try {
      final volume = await owner.volume();
      if (!_owns(owner, generation) || revision != _valueRevision || volume == null || !volume.isFinite) return;
      _displayVolume(volume);
    } catch (error) {
      // Keep the bound controller's current value if its optional query fails.
      debugPrint('Volume overlay initial read failed: $error');
    }
  }

  void _handleToggleMute() {
    _valueRevision++;
    setState(() {
      if (_volume > 0) {
        _lastVolume = _volume;
        _volume = 0;
      } else {
        _volume = _lastVolume > 0 ? _lastVolume : 0.5;
      }
    });
    unawaited(controller.setVolume(_volume));
    _overlayEntry?.markNeedsBuild();
  }

  void _showVolumeBar() {
    if (_overlayEntry != null || !mounted) return;
    final owner = controller;
    final generation = _controllerGeneration;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _barWidth,
        height: _barHeight + 45,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          followerAnchor: Alignment.bottomCenter,
          targetAnchor: Alignment.topCenter,
          offset: const Offset(0, 5),
          child: MouseRegion(
            onEnter: (_) {
              if (!_owns(owner, generation)) return;
              _isMouseInBar = true;
              owner.stopHideController();
            },
            onExit: (_) {
              if (!_owns(owner, generation)) return;
              _isMouseInBar = false;
              owner.enableController();
              _startHideTimer();
            },
            child: _buildVolumeBarUI(),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 150), () {
      if (!_isMouseInIcon && !_isMouseInBar) {
        _removeOverlay();
      }
    });
  }

  void _removeOverlay({VideoController? owner}) {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
    if (_isMouseInBar) {
      (owner ?? controller).enableController();
      _isMouseInBar = false;
    }
  }

  Widget _buildVolumeBarUI() {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(220),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white10),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double trackHeight = constraints.maxHeight - 65;
              final int percentage = (_volume * 100).round();
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Text(
                    "$percentage%",
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onVerticalDragUpdate: (details) => _handleVolumeDrag(details, trackHeight),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Container(
                            width: 4,
                            margin: const EdgeInsets.only(top: 10, bottom: 20),
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                          ),
                          Positioned(
                            bottom: 20,
                            child: Container(
                              width: 4,
                              height: _volume * trackHeight,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
                            ),
                          ),
                          Positioned(
                            bottom: 20 + (_volume * trackHeight) - 6,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleVolumeDrag(DragUpdateDetails details, double trackHeight) {
    if (trackHeight <= 0) return;
    final deltaRatio = -details.delta.dy / trackHeight;
    _applyVolume(_volume + deltaRatio);
  }

  void _applyVolume(double value) {
    final newVolume = value.clamp(0.0, 1.0).toDouble();
    if (newVolume != _volume) {
      _valueRevision++;
      setState(() {
        _volume = newVolume;
        if (_volume > 0) _lastVolume = _volume;
      });
      _overlayEntry?.markNeedsBuild();
      unawaited(controller.setVolume(_volume));
    }
  }

  @override
  Widget build(BuildContext context) {
    IconData icon = _volume == 0 ? Icons.volume_off : (_volume < 0.5 ? Icons.volume_down : Icons.volume_up);
    final percentage = (_volume * 100).round();

    return Semantics(
      label: i18n('room_volume'),
      value: '$percentage%',
      increasedValue: _volume < 1 ? '${((_volume + 0.05).clamp(0.0, 1.0) * 100).round()}%' : null,
      decreasedValue: _volume > 0 ? '${((_volume - 0.05).clamp(0.0, 1.0) * 100).round()}%' : null,
      onIncrease: _volume < 1 ? () => _applyVolume(_volume + 0.05) : null,
      onDecrease: _volume > 0 ? () => _applyVolume(_volume - 0.05) : null,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: MouseRegion(
          onEnter: (_) {
            _isMouseInIcon = true;
            _showVolumeBar();
          },
          onExit: (_) {
            _isMouseInIcon = false;
            _startHideTimer();
          },
          child: IconButton(
            onPressed: _handleToggleMute,
            visualDensity: VisualDensity.standard,
            constraints: const BoxConstraints(minWidth: kMinInteractiveDimension, minHeight: kMinInteractiveDimension),
            icon: Icon(icon, color: Colors.white, size: 24),
            tooltip: _volume == 0 ? i18n('cancel_mute') : i18n('mute'),
          ),
        ),
      ),
    );
  }
}
