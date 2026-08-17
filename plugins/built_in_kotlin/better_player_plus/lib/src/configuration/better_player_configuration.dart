import 'package:better_player_plus/better_player_plus.dart';
import 'package:better_player_plus/src/enum/aspect_enum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

///Configuration of Better Player. Allows to setup general behavior of player.
///Master configuration which contains children that configure specific part
///of player.
class BetterPlayerConfiguration {
  const BetterPlayerConfiguration({
    this.aspectRatio,
    this.aspectRatioIOS = AspectRatioTypeIOS.fill,
    this.autoPlay = false,
    this.startAt,
    this.looping = false,
    this.fullScreenByDefault = false,
    this.placeholder,
    this.showPlaceholderUntilPlay = false,
    this.placeholderOnTop = true,
    this.overlay,
    this.errorBuilder,
    this.allowedScreenSleep = true,
    this.fullScreenAspectRatio,
    this.deviceOrientationsOnFullScreen = const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
    this.systemOverlaysAfterFullScreen = SystemUiOverlay.values,
    this.deviceOrientationsAfterFullScreen = const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
    this.routePageBuilder,
    this.eventListener,
    this.subtitlesConfiguration = const BetterPlayerSubtitlesConfiguration(),
    this.controlsConfiguration = const BetterPlayerControlsConfiguration(),
    this.fit = BoxFit.fill,
    this.rotation = 0,
    this.playerVisibilityChangedBehavior,
    this.translations,
    this.autoDetectFullscreenDeviceOrientation = false,
    this.autoDetectFullscreenAspectRatio = false,
    this.handleLifecycle = true,
    this.autoDispose = true,
    this.expandToFill = true,
    this.useRootNavigator = false,
  });

  /// Play the video as soon as it's displayed
  final bool autoPlay;

  /// Start video at a certain position
  final Duration? startAt;

  /// Whether or not the video should loop
  final bool looping;

  /// When the video playback runs  into an error, you can build a custom
  /// error message.
  final Widget Function(BuildContext context, String? errorMessage)? errorBuilder;

  /// The Aspect Ratio of the Video. Important to get the correct size of the
  /// video!
  ///
  /// Will fallback to fitting within the space allowed.
  final double? aspectRatio;

  final AspectRatioTypeIOS? aspectRatioIOS;

  /// The placeholder is displayed underneath the Video before it is initialized
  /// or played.
  final Widget? placeholder;

  /// Should the placeholder be shown until play is pressed
  final bool showPlaceholderUntilPlay;

  /// Placeholder position of player stack. If false, then placeholder will be
  /// displayed on the bottom, so user need to hide it manually. Default is
  /// true.
  final bool placeholderOnTop;

  /// A widget which is placed between the video and the controls
  final Widget? overlay;

  /// Defines if the player will start in fullscreen when play is pressed
  final bool fullScreenByDefault;

  /// Defines if the player will sleep in fullscreen or not
  final bool allowedScreenSleep;

  /// Defines aspect ratio which will be used in fullscreen
  final double? fullScreenAspectRatio;

  /// Defines the set of allowed device orientations on entering fullscreen
  final List<DeviceOrientation> deviceOrientationsOnFullScreen;

  /// Defines the system overlays visible after exiting fullscreen
  final List<SystemUiOverlay> systemOverlaysAfterFullScreen;

  /// Defines the set of allowed device orientations after exiting fullscreen
  final List<DeviceOrientation> deviceOrientationsAfterFullScreen;

  /// Defines a custom RoutePageBuilder for the fullscreen
  final BetterPlayerRoutePageBuilder? routePageBuilder;

  /// Defines a event listener where video player events will be send
  final void Function(BetterPlayerEvent)? eventListener;

  ///Defines subtitles configuration
  final BetterPlayerSubtitlesConfiguration subtitlesConfiguration;

  ///Defines controls configuration
  final BetterPlayerControlsConfiguration controlsConfiguration;

  ///Defines fit of the video, allows to fix video stretching, see possible
  ///values here: https://api.flutter.dev/flutter/painting/BoxFit-class.html
  final BoxFit fit;

  ///Defines rotation of the video in degrees. Default value is 0. Can be 0, 90, 180, 270.
  ///Angle will rotate only video box, controls will be in the same place.
  final double rotation;

  ///Defines function which will react on player visibility changed
  final void Function(double visibilityFraction)? playerVisibilityChangedBehavior;

  ///Defines translations used in player. If null, then default english translations
  ///will be used.
  final List<BetterPlayerTranslations>? translations;

  ///Defines if player should auto detect full screen device orientation based
  ///on aspect ratio of the video. If aspect ratio of the video is < 1 then
  ///video will played in full screen in portrait mode. If aspect ratio is >= 1
  ///then video will be played horizontally. If this parameter is true, then
  ///[deviceOrientationsOnFullScreen] and [fullScreenAspectRatio] value will be
  /// ignored.
  final bool autoDetectFullscreenDeviceOrientation;

  ///Defines if player should auto detect full screen aspect ration of the video.
  ///If [deviceOrientationsOnFullScreen] is true this is done automaticaly also.
  final bool autoDetectFullscreenAspectRatio;

  ///Defines flag which enables/disables lifecycle handling (pause on app closed,
  ///play on app resumed). Default value is true.
  final bool handleLifecycle;

  ///Defines flag which enabled/disabled auto dispose of
  ///[BetterPlayerController] on [BetterPlayer] dispose. When it's true and
  ///[BetterPlayerController] instance has been attached to [BetterPlayer] widget
  ///and dispose has been called on [BetterPlayer] instance, then
  ///[BetterPlayerController] will be disposed.
  ///Default value is true.
  final bool autoDispose;

  ///Flag which causes to player expand to fill all remaining space. Set to false
  ///to use minimum constraints
  final bool expandToFill;

  ///Flag which causes to player use the root navigator to open new pages.
  ///Default value is false.
  final bool useRootNavigator;

  BetterPlayerConfiguration copyWith({
    double? aspectRatio,
    AspectRatioTypeIOS? aspectRatioIOS,
    bool? autoPlay,
    Duration? startAt,
    bool? looping,
    bool? fullScreenByDefault,
    Widget? placeholder,
    bool? showPlaceholderUntilPlay,
    bool? placeholderOnTop,
    Widget? overlay,
    bool? showControlsOnInitialize,
    Widget Function(BuildContext context, String? errorMessage)? errorBuilder,
    bool? allowedScreenSleep,
    double? fullScreenAspectRatio,
    List<DeviceOrientation>? deviceOrientationsOnFullScreen,
    List<SystemUiOverlay>? systemOverlaysAfterFullScreen,
    List<DeviceOrientation>? deviceOrientationsAfterFullScreen,
    BetterPlayerRoutePageBuilder? routePageBuilder,
    void Function(BetterPlayerEvent)? eventListener,
    BetterPlayerSubtitlesConfiguration? subtitlesConfiguration,
    BetterPlayerControlsConfiguration? controlsConfiguration,
    BoxFit? fit,
    double? rotation,
    void Function(double visibilityFraction)? playerVisibilityChangedBehavior,
    List<BetterPlayerTranslations>? translations,
    bool? autoDetectFullscreenDeviceOrientation,
    bool? handleLifecycle,
    bool? autoDispose,
    bool? expandToFill,
    bool? useRootNavigator,
  }) => BetterPlayerConfiguration(
    aspectRatio: aspectRatio ?? this.aspectRatio,
    autoPlay: autoPlay ?? this.autoPlay,
    startAt: startAt ?? this.startAt,
    looping: looping ?? this.looping,
    fullScreenByDefault: fullScreenByDefault ?? this.fullScreenByDefault,
    placeholder: placeholder ?? this.placeholder,
    showPlaceholderUntilPlay: showPlaceholderUntilPlay ?? this.showPlaceholderUntilPlay,
    placeholderOnTop: placeholderOnTop ?? this.placeholderOnTop,
    overlay: overlay ?? this.overlay,
    errorBuilder: errorBuilder ?? this.errorBuilder,
    allowedScreenSleep: allowedScreenSleep ?? this.allowedScreenSleep,
    fullScreenAspectRatio: fullScreenAspectRatio ?? this.fullScreenAspectRatio,
    deviceOrientationsOnFullScreen: deviceOrientationsOnFullScreen ?? this.deviceOrientationsOnFullScreen,
    systemOverlaysAfterFullScreen: systemOverlaysAfterFullScreen ?? this.systemOverlaysAfterFullScreen,
    deviceOrientationsAfterFullScreen: deviceOrientationsAfterFullScreen ?? this.deviceOrientationsAfterFullScreen,
    routePageBuilder: routePageBuilder ?? this.routePageBuilder,
    eventListener: eventListener ?? this.eventListener,
    subtitlesConfiguration: subtitlesConfiguration ?? this.subtitlesConfiguration,
    controlsConfiguration: controlsConfiguration ?? this.controlsConfiguration,
    fit: fit ?? this.fit,
    rotation: rotation ?? this.rotation,
    playerVisibilityChangedBehavior: playerVisibilityChangedBehavior ?? this.playerVisibilityChangedBehavior,
    translations: translations ?? this.translations,
    autoDetectFullscreenDeviceOrientation:
        autoDetectFullscreenDeviceOrientation ?? this.autoDetectFullscreenDeviceOrientation,
    handleLifecycle: handleLifecycle ?? this.handleLifecycle,
    autoDispose: autoDispose ?? this.autoDispose,
    expandToFill: expandToFill ?? this.expandToFill,
    useRootNavigator: useRootNavigator ?? this.useRootNavigator,
    aspectRatioIOS: aspectRatioIOS ?? this.aspectRatioIOS,
  );
}
