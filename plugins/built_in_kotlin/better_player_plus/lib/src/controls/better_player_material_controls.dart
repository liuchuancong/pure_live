import 'dart:async';
import 'package:better_player_plus/src/configuration/better_player_controls_configuration.dart';
import 'package:better_player_plus/src/controls/better_player_clickable_widget.dart';
import 'package:better_player_plus/src/controls/better_player_controls_state.dart';
import 'package:better_player_plus/src/controls/better_player_material_progress_bar.dart';
import 'package:better_player_plus/src/controls/better_player_multiple_gesture_detector.dart';
import 'package:better_player_plus/src/controls/better_player_progress_colors.dart';
import 'package:better_player_plus/src/core/better_player_controller.dart';
import 'package:better_player_plus/src/core/better_player_utils.dart';
import 'package:better_player_plus/src/video_player/video_player.dart';

// Flutter imports:
import 'package:flutter/material.dart';

class BetterPlayerMaterialControls extends StatefulWidget {
  const BetterPlayerMaterialControls({
    super.key,
    required this.onControlsVisibilityChanged,
    required this.controlsConfiguration,
  });

  ///Callback used to send information if player bar is hidden or not
  final void Function(bool visbility) onControlsVisibilityChanged;

  ///Controls config
  final BetterPlayerControlsConfiguration controlsConfiguration;

  @override
  State<StatefulWidget> createState() => _BetterPlayerMaterialControlsState();
}

class _BetterPlayerMaterialControlsState extends BetterPlayerControlsState<BetterPlayerMaterialControls> {
  VideoPlayerValue? _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _initTimer;
  Timer? _showAfterExpandCollapseTimer;
  bool _displayTapped = false;
  bool _wasLoading = false;
  VideoPlayerController? _controller;
  BetterPlayerController? _betterPlayerController;
  StreamSubscription<dynamic>? _controlsVisibilityStreamSubscription;

  BetterPlayerControlsConfiguration get _controlsConfiguration => widget.controlsConfiguration;

  @override
  VideoPlayerValue? get latestValue => _latestValue;

  @override
  BetterPlayerController? get betterPlayerController => _betterPlayerController;

  @override
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration => _controlsConfiguration;

  @override
  Widget build(BuildContext context) => buildLTRDirectionality(_buildMainWidget());

  ///Builds main widget of the controls.
  Widget _buildMainWidget() {
    _wasLoading = isLoading(_latestValue);
    if (_latestValue?.hasError ?? false) {
      return ColoredBox(color: Colors.black, child: _buildErrorWidget());
    }
    return GestureDetector(
      onTap: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onTap?.call();
        }
        controlsNotVisible ? cancelAndRestartTimer() : changePlayerControlsNotVisible(true);
      },
      onDoubleTap: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onDoubleTap?.call();
        }
        cancelAndRestartTimer();
      },
      onLongPress: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onLongPress?.call();
        }
      },
      child: AbsorbPointer(
        absorbing: controlsNotVisible,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_wasLoading) Center(child: _buildLoadingWidget()) else _buildHitArea(),
            Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
            _buildNextVideoWidget(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    _controller?.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
    _controlsVisibilityStreamSubscription?.cancel();
  }

  @override
  void didChangeDependencies() {
    final oldController = _betterPlayerController;
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;
    _latestValue = _controller!.value;

    if (oldController != _betterPlayerController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  Widget _buildErrorWidget() {
    final errorBuilder = _betterPlayerController!.betterPlayerConfiguration.errorBuilder;
    if (errorBuilder != null) {
      return errorBuilder(context, _betterPlayerController!.videoPlayerController!.value.errorDescription);
    } else {
      final textStyle = TextStyle(color: _controlsConfiguration.textColor);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning, color: _controlsConfiguration.iconsColor, size: 42),
            Text(_betterPlayerController!.translations.generalDefaultError, style: textStyle),
            if (_controlsConfiguration.enableRetry)
              TextButton(
                onPressed: () {
                  _betterPlayerController!.retryDataSource();
                },
                child: Text(
                  _betterPlayerController!.translations.generalRetry,
                  style: textStyle.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      );
    }
  }

  Widget _buildTopBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    return Container(
      child: (_controlsConfiguration.enableOverflowMenu)
          ? AnimatedOpacity(
              opacity: controlsNotVisible ? 0.0 : 1.0,
              duration: _controlsConfiguration.controlsHideTime,
              onEnd: _onPlayerHide,
              child: SizedBox(
                height: _controlsConfiguration.controlBarHeight,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_controlsConfiguration.enablePip)
                      _buildPipButtonWrapperWidget(controlsNotVisible, _onPlayerHide)
                    else
                      const SizedBox(),
                    _buildMoreButton(),
                  ],
                ),
              ),
            )
          : const SizedBox(),
    );
  }

  Widget _buildPipButton() => BetterPlayerMaterialClickableWidget(
    onTap: () {
      betterPlayerController!.enablePictureInPicture(betterPlayerController!.betterPlayerGlobalKey!);
    },
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(betterPlayerControlsConfiguration.pipMenuIcon, color: betterPlayerControlsConfiguration.iconsColor),
    ),
  );

  Widget _buildPipButtonWrapperWidget(bool hideStuff, void Function() onPlayerHide) => FutureBuilder<bool>(
    future: betterPlayerController!.isPictureInPictureSupported(),
    builder: (context, snapshot) {
      final bool isPipSupported = snapshot.data ?? false;
      if (isPipSupported && _betterPlayerController!.betterPlayerGlobalKey != null) {
        return AnimatedOpacity(
          opacity: hideStuff ? 0.0 : 1.0,
          duration: betterPlayerControlsConfiguration.controlsHideTime,
          onEnd: onPlayerHide,
          child: SizedBox(
            height: betterPlayerControlsConfiguration.controlBarHeight,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildPipButton()]),
          ),
        );
      } else {
        return const SizedBox();
      }
    },
  );

  Widget _buildMoreButton() => BetterPlayerMaterialClickableWidget(
    onTap: onShowMoreClicked,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(_controlsConfiguration.overflowMenuIcon, color: _controlsConfiguration.iconsColor),
    ),
  );

  Widget _buildBottomBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return AnimatedOpacity(
      opacity: controlsNotVisible ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      onEnd: _onPlayerHide,
      child: SizedBox(
        height: _controlsConfiguration.controlBarHeight + 20.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              flex: 75,
              child: Row(
                children: [
                  if (_controlsConfiguration.enablePlayPause) _buildPlayPause(_controller!) else const SizedBox(),
                  if (_betterPlayerController!.isLiveStream())
                    _buildLiveWidget()
                  else
                    _controlsConfiguration.enableProgressText ? Expanded(child: _buildPosition()) : const SizedBox(),
                  const Spacer(),
                  if (_controlsConfiguration.enableMute) _buildMuteButton(_controller) else const SizedBox(),
                  if (_controlsConfiguration.enableFullscreen) _buildExpandButton() else const SizedBox(),
                ],
              ),
            ),
            if (_betterPlayerController!.isLiveStream())
              const SizedBox()
            else
              _controlsConfiguration.enableProgressBar ? _buildProgressBar() : const SizedBox(),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveWidget() => Text(
    _betterPlayerController!.translations.controlsLive,
    style: TextStyle(color: _controlsConfiguration.liveTextColor, fontWeight: FontWeight.bold),
  );

  Widget _buildExpandButton() => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: BetterPlayerMaterialClickableWidget(
      onTap: _onExpandCollapse,
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: Container(
          height: _controlsConfiguration.controlBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: Icon(
              _betterPlayerController!.isFullScreen
                  ? _controlsConfiguration.fullscreenDisableIcon
                  : _controlsConfiguration.fullscreenEnableIcon,
              color: _controlsConfiguration.iconsColor,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildHitArea() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return Center(
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: _buildMiddleRow(),
      ),
    );
  }

  Widget _buildMiddleRow() => Container(
    color: _controlsConfiguration.controlBarColor,
    width: double.infinity,
    height: double.infinity,
    child: _betterPlayerController?.isLiveStream() ?? false
        ? const SizedBox()
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (_controlsConfiguration.enableSkips) Expanded(child: _buildSkipButton()) else const SizedBox(),
              Expanded(child: _buildReplayButton(_controller!)),
              if (_controlsConfiguration.enableSkips) Expanded(child: _buildForwardButton()) else const SizedBox(),
            ],
          ),
  );

  Widget _buildHitAreaClickableButton({Widget? icon, required void Function() onClicked}) => Container(
    constraints: const BoxConstraints(maxHeight: 80, maxWidth: 80),
    child: BetterPlayerMaterialClickableWidget(
      onTap: onClicked,
      child: Align(
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(48)),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(children: [icon!]),
          ),
        ),
      ),
    ),
  );

  Widget _buildSkipButton() => _buildHitAreaClickableButton(
    icon: Icon(_controlsConfiguration.skipBackIcon, size: 24, color: _controlsConfiguration.iconsColor),
    onClicked: skipBack,
  );

  Widget _buildForwardButton() => _buildHitAreaClickableButton(
    icon: Icon(_controlsConfiguration.skipForwardIcon, size: 24, color: _controlsConfiguration.iconsColor),
    onClicked: skipForward,
  );

  Widget _buildReplayButton(VideoPlayerController controller) {
    final bool isFinished = isVideoFinished(_latestValue);
    return _buildHitAreaClickableButton(
      icon: isFinished
          ? Icon(Icons.replay, size: 42, color: _controlsConfiguration.iconsColor)
          : Icon(
              controller.value.isPlaying ? _controlsConfiguration.pauseIcon : _controlsConfiguration.playIcon,
              size: 42,
              color: _controlsConfiguration.iconsColor,
            ),
      onClicked: () {
        if (isFinished) {
          if (_latestValue != null && _latestValue!.isPlaying) {
            if (_displayTapped) {
              changePlayerControlsNotVisible(true);
            } else {
              cancelAndRestartTimer();
            }
          } else {
            _onPlayPause();
            changePlayerControlsNotVisible(true);
          }
        } else {
          _onPlayPause();
        }
      },
    );
  }

  Widget _buildNextVideoWidget() => StreamBuilder<int?>(
    stream: _betterPlayerController!.nextVideoTimeStream,
    builder: (context, snapshot) {
      final time = snapshot.data;
      if (time != null && time > 0) {
        return BetterPlayerMaterialClickableWidget(
          onTap: () {
            _betterPlayerController!.playNextVideo();
          },
          child: Align(
            alignment: Alignment.bottomRight,
            child: Container(
              margin: EdgeInsets.only(bottom: _controlsConfiguration.controlBarHeight + 20, right: 24),
              decoration: BoxDecoration(
                color: _controlsConfiguration.controlBarColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${_betterPlayerController!.translations.controlsNextVideoIn} $time...',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        );
      } else {
        return const SizedBox();
      }
    },
  );

  Widget _buildMuteButton(VideoPlayerController? controller) => BetterPlayerMaterialClickableWidget(
    onTap: () {
      cancelAndRestartTimer();
      if (_latestValue!.volume == 0) {
        _betterPlayerController!.setVolume(_latestVolume ?? 0.5);
      } else {
        _latestVolume = controller!.value.volume;
        _betterPlayerController!.setVolume(0);
      }
    },
    child: AnimatedOpacity(
      opacity: controlsNotVisible ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      child: ClipRect(
        child: Container(
          height: _controlsConfiguration.controlBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            (_latestValue != null && _latestValue!.volume > 0)
                ? _controlsConfiguration.muteIcon
                : _controlsConfiguration.unMuteIcon,
            color: _controlsConfiguration.iconsColor,
          ),
        ),
      ),
    ),
  );

  Widget _buildPlayPause(VideoPlayerController controller) => BetterPlayerMaterialClickableWidget(
    key: const Key('better_player_material_controls_play_pause_button'),
    onTap: _onPlayPause,
    child: Container(
      height: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Icon(
        controller.value.isPlaying ? _controlsConfiguration.pauseIcon : _controlsConfiguration.playIcon,
        color: _controlsConfiguration.iconsColor,
      ),
    ),
  );

  Widget _buildPosition() {
    final position = _latestValue != null ? _latestValue!.position : Duration.zero;
    final duration = _latestValue != null && _latestValue!.duration != null ? _latestValue!.duration! : Duration.zero;

    return Padding(
      padding: _controlsConfiguration.enablePlayPause
          ? const EdgeInsets.only(right: 24)
          : const EdgeInsets.symmetric(horizontal: 22),
      child: RichText(
        text: TextSpan(
          text: BetterPlayerUtils.formatDuration(position),
          style: TextStyle(fontSize: 10, color: _controlsConfiguration.textColor, decoration: TextDecoration.none),
          children: <TextSpan>[
            TextSpan(
              text: ' / ${BetterPlayerUtils.formatDuration(duration)}',
              style: TextStyle(fontSize: 10, color: _controlsConfiguration.textColor, decoration: TextDecoration.none),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    changePlayerControlsNotVisible(false);
    _displayTapped = true;
  }

  Future<void> _initialize() async {
    _controller!.addListener(_updateState);

    _updateState();

    if ((_controller!.value.isPlaying) || _betterPlayerController!.betterPlayerConfiguration.autoPlay) {
      _startHideTimer();
    }

    if (_controlsConfiguration.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        changePlayerControlsNotVisible(false);
      });
    }

    _controlsVisibilityStreamSubscription = _betterPlayerController!.controlsVisibilityStream.listen((state) {
      if (controlsNotVisible == !state) {
        return;
      }
      changePlayerControlsNotVisible(!state);
      if (!controlsNotVisible) {
        cancelAndRestartTimer();
      }
    });
  }

  void _onExpandCollapse() {
    changePlayerControlsNotVisible(true);
    _betterPlayerController!.toggleFullScreen();
    _showAfterExpandCollapseTimer = Timer(_controlsConfiguration.controlsHideTime, () {
      setState(cancelAndRestartTimer);
    });
  }

  void _onPlayPause() {
    bool isFinished = false;

    if (_latestValue?.position != null && _latestValue?.duration != null) {
      isFinished = _latestValue!.position >= _latestValue!.duration!;
    }

    if (_controller!.value.isPlaying) {
      changePlayerControlsNotVisible(false);
      _hideTimer?.cancel();
      _betterPlayerController!.pause();
    } else {
      cancelAndRestartTimer();

      if (!_controller!.value.initialized) {
      } else {
        if (isFinished) {
          _betterPlayerController!.seekTo(Duration.zero);
        }
        _betterPlayerController!.play();
        _betterPlayerController!.cancelNextVideoTimer();
      }
    }
  }

  void _startHideTimer() {
    if (_betterPlayerController!.controlsAlwaysVisible) {
      return;
    }
    _hideTimer = Timer(const Duration(milliseconds: 3000), () {
      changePlayerControlsNotVisible(true);
    });
  }

  void _updateState() {
    if (mounted) {
      if (!controlsNotVisible || isVideoFinished(_controller!.value) || _wasLoading || isLoading(_controller!.value)) {
        setState(() {
          _latestValue = _controller!.value;
          if (isVideoFinished(_latestValue) && _betterPlayerController?.isLiveStream() == false) {
            changePlayerControlsNotVisible(false);
          }
        });
      }
    }
  }

  Widget _buildProgressBar() => Expanded(
    flex: 40,
    child: Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: BetterPlayerMaterialVideoProgressBar(
        _controller,
        _betterPlayerController,
        onDragStart: () {
          _hideTimer?.cancel();
        },
        onDragEnd: _startHideTimer,
        onTapDown: cancelAndRestartTimer,
        colors: BetterPlayerProgressColors(
          playedColor: _controlsConfiguration.progressBarPlayedColor,
          handleColor: _controlsConfiguration.progressBarHandleColor,
          bufferedColor: _controlsConfiguration.progressBarBufferedColor,
          backgroundColor: _controlsConfiguration.progressBarBackgroundColor,
        ),
      ),
    ),
  );

  void _onPlayerHide() {
    _betterPlayerController!.toggleControlsVisibility(!controlsNotVisible);
    _betterPlayerController!.setControlsVisibility(!controlsNotVisible);
    widget.onControlsVisibilityChanged(!controlsNotVisible);
  }

  Widget? _buildLoadingWidget() {
    if (_controlsConfiguration.loadingWidget != null) {
      return ColoredBox(color: _controlsConfiguration.controlBarColor, child: _controlsConfiguration.loadingWidget);
    }

    return CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_controlsConfiguration.loadingColor));
  }
}
