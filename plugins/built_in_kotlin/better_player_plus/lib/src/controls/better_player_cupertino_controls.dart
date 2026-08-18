import 'dart:async';
import 'package:better_player_plus/src/configuration/better_player_controls_configuration.dart';
import 'package:better_player_plus/src/controls/better_player_controls_state.dart';
import 'package:better_player_plus/src/controls/better_player_cupertino_progress_bar.dart';
import 'package:better_player_plus/src/controls/better_player_multiple_gesture_detector.dart';
import 'package:better_player_plus/src/controls/better_player_progress_colors.dart';
import 'package:better_player_plus/src/core/better_player_controller.dart';
import 'package:better_player_plus/src/core/better_player_utils.dart';
import 'package:better_player_plus/src/video_player/video_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BetterPlayerCupertinoControls extends StatefulWidget {
  const BetterPlayerCupertinoControls({
    required this.onControlsVisibilityChanged,
    required this.controlsConfiguration,
    super.key,
  });

  ///Callback used to send information if player bar is hidden or not
  final void Function(bool visbility) onControlsVisibilityChanged;

  ///Controls config
  final BetterPlayerControlsConfiguration controlsConfiguration;

  @override
  State<StatefulWidget> createState() => _BetterPlayerCupertinoControlsState();
}

class _BetterPlayerCupertinoControlsState extends BetterPlayerControlsState<BetterPlayerCupertinoControls> {
  final marginSize = 5.0;
  VideoPlayerValue? _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _expandCollapseTimer;
  Timer? _initTimer;
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
    _betterPlayerController = BetterPlayerController.of(context);

    if (_latestValue?.hasError ?? false) {
      return ColoredBox(color: Colors.black, child: _buildErrorWidget());
    }

    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;
    final backgroundColor = _controlsConfiguration.controlBarColor;
    final iconColor = _controlsConfiguration.iconsColor;
    final orientation = MediaQuery.of(context).orientation;
    final barHeight = orientation == Orientation.portrait
        ? _controlsConfiguration.controlBarHeight
        : _controlsConfiguration.controlBarHeight + 10;
    const buttonPadding = 10.0;
    final isFullScreen = _betterPlayerController?.isFullScreen ?? false;

    _wasLoading = isLoading(_latestValue);
    final controlsColumn = Column(
      children: <Widget>[
        _buildTopBar(backgroundColor, iconColor, barHeight, buttonPadding),
        if (_wasLoading) Expanded(child: Center(child: _buildLoadingWidget())) else _buildHitArea(),
        _buildNextVideoWidget(),
        _buildBottomBar(backgroundColor, iconColor, barHeight),
      ],
    );
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
        _onPlayPause();
      },
      onLongPress: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onLongPress?.call();
        }
      },
      child: AbsorbPointer(
        absorbing: controlsNotVisible,
        child: isFullScreen ? SafeArea(child: controlsColumn) : controlsColumn,
      ),
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    _controller!.removeListener(_updateState);
    _hideTimer?.cancel();
    _expandCollapseTimer?.cancel();
    _initTimer?.cancel();
    _controlsVisibilityStreamSubscription?.cancel();
  }

  @override
  void didChangeDependencies() {
    final oldController = _betterPlayerController;
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;

    if (oldController != _betterPlayerController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  Widget _buildBottomBar(Color backgroundColor, Color iconColor, double barHeight) {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return AnimatedOpacity(
      opacity: controlsNotVisible ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      onEnd: _onPlayerHide,
      child: Container(
        alignment: Alignment.bottomCenter,
        margin: EdgeInsets.all(marginSize),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: barHeight,
            decoration: BoxDecoration(color: backgroundColor),
            child: _betterPlayerController!.isLiveStream()
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const SizedBox(width: 8),
                      if (_controlsConfiguration.enablePlayPause)
                        _buildPlayPause(_controller!, iconColor, barHeight)
                      else
                        const SizedBox(),
                      const SizedBox(width: 8),
                      _buildLiveWidget(),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      if (_controlsConfiguration.enableSkips)
                        _buildSkipBack(iconColor, barHeight)
                      else
                        const SizedBox(),
                      if (_controlsConfiguration.enablePlayPause)
                        _buildPlayPause(_controller!, iconColor, barHeight)
                      else
                        const SizedBox(),
                      if (_controlsConfiguration.enableSkips)
                        _buildSkipForward(iconColor, barHeight)
                      else
                        const SizedBox(),
                      if (_controlsConfiguration.enableProgressText) _buildPosition() else const SizedBox(),
                      if (_controlsConfiguration.enableProgressBar) _buildProgressBar() else const SizedBox(),
                      if (_controlsConfiguration.enableProgressText) _buildRemaining() else const SizedBox(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveWidget() => Expanded(
    child: Text(
      _betterPlayerController!.translations.controlsLive,
      style: TextStyle(color: _controlsConfiguration.liveTextColor, fontWeight: FontWeight.bold),
    ),
  );

  GestureDetector _buildExpandButton(
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double iconSize,
    double buttonPadding,
  ) => GestureDetector(
    onTap: _onExpandCollapse,
    child: AnimatedOpacity(
      opacity: controlsNotVisible ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: barHeight,
          padding: EdgeInsets.symmetric(horizontal: buttonPadding),
          decoration: BoxDecoration(color: backgroundColor),
          child: Center(
            child: Icon(
              _betterPlayerController!.isFullScreen
                  ? _controlsConfiguration.fullscreenDisableIcon
                  : _controlsConfiguration.fullscreenEnableIcon,
              color: iconColor,
              size: iconSize,
            ),
          ),
        ),
      ),
    ),
  );

  Expanded _buildHitArea() => Expanded(
    child: GestureDetector(
      onTap: _latestValue != null && _latestValue!.isPlaying
          ? () {
              if (controlsNotVisible) {
                cancelAndRestartTimer();
              } else {
                _hideTimer?.cancel();
                changePlayerControlsNotVisible(true);
              }
            }
          : () {
              _hideTimer?.cancel();
              changePlayerControlsNotVisible(false);
            },
      child: Container(color: Colors.transparent),
    ),
  );

  GestureDetector _buildMoreButton(
    VideoPlayerController? controller,
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double iconSize,
    double buttonPadding,
  ) => GestureDetector(
    onTap: onShowMoreClicked,
    child: AnimatedOpacity(
      opacity: controlsNotVisible ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(color: backgroundColor),
          child: Container(
            height: barHeight,
            padding: EdgeInsets.symmetric(horizontal: buttonPadding),
            child: Icon(_controlsConfiguration.overflowMenuIcon, color: iconColor, size: iconSize),
          ),
        ),
      ),
    ),
  );

  GestureDetector _buildMuteButton(
    VideoPlayerController? controller,
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double iconSize,
    double buttonPadding,
  ) => GestureDetector(
    onTap: () {
      cancelAndRestartTimer();

      if (_latestValue!.volume == 0) {
        controller!.setVolume(_latestVolume ?? 0.5);
      } else {
        _latestVolume = controller!.value.volume;
        controller.setVolume(0);
      }
    },
    child: AnimatedOpacity(
      opacity: controlsNotVisible ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(color: backgroundColor),
          child: Container(
            height: barHeight,
            padding: EdgeInsets.symmetric(horizontal: buttonPadding),
            child: Icon(
              (_latestValue != null && _latestValue!.volume > 0)
                  ? _controlsConfiguration.muteIcon
                  : _controlsConfiguration.unMuteIcon,
              color: iconColor,
              size: iconSize,
            ),
          ),
        ),
      ),
    ),
  );

  GestureDetector _buildPlayPause(VideoPlayerController controller, Color iconColor, double barHeight) =>
      GestureDetector(
        onTap: _onPlayPause,
        child: Container(
          height: barHeight,
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            controller.value.isPlaying ? _controlsConfiguration.pauseIcon : _controlsConfiguration.playIcon,
            color: iconColor,
            size: barHeight * 0.6,
          ),
        ),
      );

  Widget _buildPosition() {
    final position = _latestValue != null ? _latestValue!.position : Duration.zero;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Text(
        BetterPlayerUtils.formatDuration(position),
        style: TextStyle(color: _controlsConfiguration.textColor, fontSize: 12),
      ),
    );
  }

  Widget _buildRemaining() {
    final position = _latestValue != null && _latestValue!.duration != null
        ? _latestValue!.duration! - _latestValue!.position
        : Duration.zero;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Text(
        '-${BetterPlayerUtils.formatDuration(position)}',
        style: TextStyle(color: _controlsConfiguration.textColor, fontSize: 12),
      ),
    );
  }

  GestureDetector _buildSkipBack(Color iconColor, double barHeight) => GestureDetector(
    onTap: skipBack,
    child: Container(
      height: barHeight,
      color: Colors.transparent,
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(_controlsConfiguration.skipBackIcon, color: iconColor, size: barHeight * 0.4),
    ),
  );

  GestureDetector _buildSkipForward(Color iconColor, double barHeight) => GestureDetector(
    onTap: skipForward,
    child: Container(
      height: barHeight,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      margin: const EdgeInsets.only(right: 8),
      child: Icon(_controlsConfiguration.skipForwardIcon, color: iconColor, size: barHeight * 0.4),
    ),
  );

  Widget _buildTopBar(Color backgroundColor, Color iconColor, double topBarHeight, double buttonPadding) {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    final barHeight = topBarHeight * 0.8;
    final iconSize = topBarHeight * 0.4;
    return Container(
      height: barHeight,
      margin: EdgeInsets.only(top: marginSize, right: marginSize, left: marginSize),
      child: Row(
        children: <Widget>[
          if (_controlsConfiguration.enableFullscreen)
            _buildExpandButton(backgroundColor, iconColor, barHeight, iconSize, buttonPadding)
          else
            const SizedBox(),
          const SizedBox(width: 4),
          if (_controlsConfiguration.enablePip)
            _buildPipButton(backgroundColor, iconColor, barHeight, iconSize, buttonPadding)
          else
            const SizedBox(),
          const Spacer(),
          if (_controlsConfiguration.enableMute)
            _buildMuteButton(_controller, backgroundColor, iconColor, barHeight, iconSize, buttonPadding)
          else
            const SizedBox(),
          const SizedBox(width: 4),
          if (_controlsConfiguration.enableOverflowMenu)
            _buildMoreButton(_controller, backgroundColor, iconColor, barHeight, iconSize, buttonPadding)
          else
            const SizedBox(),
        ],
      ),
    );
  }

  Widget _buildNextVideoWidget() => StreamBuilder<int?>(
    stream: _betterPlayerController!.nextVideoTimeStream,
    builder: (context, snapshot) {
      final time = snapshot.data;
      if (time != null && time > 0) {
        return InkWell(
          onTap: () {
            _betterPlayerController!.playNextVideo();
          },
          child: Align(
            alignment: Alignment.bottomRight,
            child: Container(
              margin: const EdgeInsets.only(bottom: 4, right: 8),
              decoration: BoxDecoration(
                color: _controlsConfiguration.controlBarColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${_betterPlayerController!.translations.controlsNextVideoIn} $time ...',
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

  @override
  void cancelAndRestartTimer() {
    _hideTimer?.cancel();
    changePlayerControlsNotVisible(false);
    _startHideTimer();
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
    _expandCollapseTimer = Timer(_controlsConfiguration.controlsHideTime, () {
      setState(cancelAndRestartTimer);
    });
  }

  Widget _buildProgressBar() => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 12),
      child: BetterPlayerCupertinoVideoProgressBar(
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
        if (_betterPlayerController!.betterPlayerDataSource?.liveStream ?? false) {
          _betterPlayerController!.play();
          _betterPlayerController!.cancelNextVideoTimer();
        }
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
    _hideTimer = Timer(const Duration(seconds: 3), () {
      changePlayerControlsNotVisible(true);
    });
  }

  void _updateState() {
    if (mounted) {
      if (!controlsNotVisible || isVideoFinished(_controller!.value) || _wasLoading || isLoading(_controller!.value)) {
        setState(() {
          _latestValue = _controller!.value;
          if (isVideoFinished(_latestValue)) {
            changePlayerControlsNotVisible(false);
          }
        });
      }
    }
  }

  void _onPlayerHide() {
    _betterPlayerController!.toggleControlsVisibility(!controlsNotVisible);
    _betterPlayerController!.setControlsVisibility(!controlsNotVisible);
    widget.onControlsVisibilityChanged(!controlsNotVisible);
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
            Icon(CupertinoIcons.exclamationmark_triangle, color: _controlsConfiguration.iconsColor, size: 42),
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

  Widget? _buildLoadingWidget() {
    if (_controlsConfiguration.loadingWidget != null) {
      return _controlsConfiguration.loadingWidget;
    }

    return CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_controlsConfiguration.loadingColor));
  }

  Widget _buildPipButton(
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double iconSize,
    double buttonPadding,
  ) => FutureBuilder<bool>(
    future: _betterPlayerController!.isPictureInPictureSupported(),
    builder: (context, snapshot) {
      final isPipSupported = snapshot.data ?? false;
      if (isPipSupported && _betterPlayerController!.betterPlayerGlobalKey != null) {
        return GestureDetector(
          onTap: () {
            betterPlayerController!.enablePictureInPicture(betterPlayerController!.betterPlayerGlobalKey!);
          },
          child: AnimatedOpacity(
            opacity: controlsNotVisible ? 0.0 : 1.0,
            duration: _controlsConfiguration.controlsHideTime,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: barHeight,
                padding: EdgeInsets.only(left: buttonPadding, right: buttonPadding),
                decoration: BoxDecoration(color: backgroundColor.withValues(alpha: 0.5)),
                child: Center(
                  child: Icon(_controlsConfiguration.pipMenuIcon, color: iconColor, size: iconSize),
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
}
