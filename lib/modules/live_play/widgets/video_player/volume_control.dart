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
  StreamSubscription? _mobileVolWorker;
  StreamSubscription? _desktopVolWorker;
  static const double _barHeight = 150.0;
  static const double _barWidth = 44.0;

  VideoController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    initVolume();
    _listenGlobalVolume();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _volumeListener?.cancel();
    _mobileVolWorker?.cancel();
    _desktopVolWorker?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _listenGlobalVolume() {
    final v = SettingsService.to.vol;
    _volumeListener = v.globalVolumeMute.stream.listen((_) => _updateVolumeFromGlobal());
    _mobileVolWorker = v.defaultMobileVolume.stream.listen((_) => _updateVolumeFromGlobal());
    _desktopVolWorker = v.defaultDesktopVolume.stream.listen((_) => _updateVolumeFromGlobal());
  }

  void _updateVolumeFromGlobal() {
    final v = SettingsService.to.vol;
    setState(() {
      double platformVolume = PlatformUtils.isMobile ? v.defaultMobileVolume.v : v.defaultDesktopVolume.v;

      if (v.globalVolumeMute.v) {
        _lastVolume = _volume;
        _volume = 0.0;
      } else {
        _volume = platformVolume;
        _lastVolume = _volume;
      }
    });

    controller.setVolume(_volume);
    _overlayEntry?.markNeedsBuild();
  }

  Future<void> initVolume() async {
    final volume = await controller.volume();
    if (!context.mounted) return;
    setState(() {
      _volume = volume ?? 0.5;
      if (_volume > 0) _lastVolume = _volume;
    });
  }

  void _handleToggleMute() {
    setState(() {
      if (_volume > 0) {
        _lastVolume = _volume;
        _volume = 0;
      } else {
        _volume = _lastVolume > 0 ? _lastVolume : 0.5;
      }
    });
    controller.setVolume(_volume);
    _overlayEntry?.markNeedsBuild();
  }

  void _showVolumeBar() {
    if (_overlayEntry != null || !mounted) return;

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
              _isMouseInBar = true;
              controller.stopHideController();
            },
            onExit: (_) {
              _isMouseInBar = false;
              controller.enableController();
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

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
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
    final newVolume = (_volume + deltaRatio).clamp(0.0, 1.0);
    if (newVolume != _volume) {
      setState(() {
        _volume = newVolume;
        if (_volume > 0) _lastVolume = _volume;
      });
      _overlayEntry?.markNeedsBuild();
      controller.setVolume(_volume);
    }
  }

  @override
  Widget build(BuildContext context) {
    IconData icon = _volume == 0 ? Icons.volume_off : (_volume < 0.5 ? Icons.volume_down : Icons.volume_up);

    return CompositedTransformTarget(
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
          icon: Icon(icon, color: Colors.white, size: 24),
          tooltip: _volume == 0 ? i18n('cancel_mute') : i18n('mute'),
        ),
      ),
    );
  }
}
