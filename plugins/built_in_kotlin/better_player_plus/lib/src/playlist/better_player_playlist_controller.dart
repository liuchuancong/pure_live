import 'dart:async';
import 'package:better_player_plus/better_player_plus.dart';

///Controller used to manage playlist player.
class BetterPlayerPlaylistController {
  BetterPlayerPlaylistController(
    this._betterPlayerDataSourceList, {
    this.betterPlayerConfiguration = const BetterPlayerConfiguration(),
    this.betterPlayerPlaylistConfiguration = const BetterPlayerPlaylistConfiguration(),
  }) : assert(_betterPlayerDataSourceList.isNotEmpty, "Better Player data source list can't be empty") {
    _setup();
  }

  ///List of data sources set for playlist.
  final List<BetterPlayerDataSource> _betterPlayerDataSourceList;

  //General configuration of Better Player
  final BetterPlayerConfiguration betterPlayerConfiguration;

  ///Playlist configuration of Better Player
  final BetterPlayerPlaylistConfiguration betterPlayerPlaylistConfiguration;

  ///BetterPlayerController instance
  BetterPlayerController? _betterPlayerController;

  ///Currently playing data source index
  int _currentDataSourceIndex = 0;

  ///Next video change listener subscription
  StreamSubscription<int?>? _nextVideoTimeStreamSubscription;

  ///Flag that determines whenever player is changing video
  bool _changingToNextVideo = false;

  ///Initialize controller and listeners.
  void _setup() {
    _betterPlayerController ??= BetterPlayerController(
      betterPlayerConfiguration,
      betterPlayerPlaylistConfiguration: betterPlayerPlaylistConfiguration,
    );

    var initialStartIndex = betterPlayerPlaylistConfiguration.initialStartIndex;
    if (initialStartIndex >= _betterPlayerDataSourceList.length) {
      initialStartIndex = 0;
    }

    _currentDataSourceIndex = initialStartIndex;
    setupDataSource(_currentDataSourceIndex);
    _betterPlayerController!.addEventsListener(_handleEvent);
    _nextVideoTimeStreamSubscription = _betterPlayerController!.nextVideoTimeStream.listen((time) {
      if (time != null && time == 0) {
        _onVideoChange();
      }
    });
  }

  /// Setup new data source list. Pauses currently played video and init new data
  /// source list. Previous data source list will be removed.
  void setupDataSourceList(List<BetterPlayerDataSource> dataSourceList) {
    _betterPlayerController?.pause();
    _betterPlayerDataSourceList
      ..clear()
      ..addAll(dataSourceList);
    _setup();
  }

  ///Handle video change signal from BetterPlayerController. Setup new data
  ///source based on configuration.
  void _onVideoChange() {
    if (_changingToNextVideo) {
      return;
    }
    final int nextDataSourceId = _getNextDataSourceIndex();
    if (nextDataSourceId == -1) {
      return;
    }
    if (_betterPlayerController!.isFullScreen) {
      _betterPlayerController!.exitFullScreen();
    }
    _changingToNextVideo = true;
    setupDataSource(nextDataSourceId);

    _changingToNextVideo = false;
  }

  ///Handle BetterPlayerEvent from BetterPlayerController. Used to control
  ///startup of next video timer.
  void _handleEvent(BetterPlayerEvent betterPlayerEvent) {
    if (betterPlayerEvent.betterPlayerEventType == BetterPlayerEventType.finished) {
      if (_getNextDataSourceIndex() != -1) {
        _betterPlayerController!.startNextVideoTimer();
      }
    }
  }

  ///Setup data source with index based on [_betterPlayerDataSourceList] provided
  ///in constructor. Index must
  void setupDataSource(int index) {
    assert(
      index >= 0 && index < _betterPlayerDataSourceList.length,
      'Index must be greater than 0 and less than size of data source '
      'list - 1',
    );
    if (index <= _dataSourceLength) {
      _currentDataSourceIndex = index;
      _betterPlayerController!.setupDataSource(_betterPlayerDataSourceList[index]);
    }
  }

  ///Get index of next data source. If current index is less than
  ///[_betterPlayerDataSourceList] size then next element will be picked, otherwise
  ///if loops is enabled then first element of [_betterPlayerDataSourceList] will
  ///be picked, otherwise -1 will be returned, indicating that player should
  ///stop changing videos.
  int _getNextDataSourceIndex() {
    final currentIndex = _currentDataSourceIndex;
    if (currentIndex + 1 < _dataSourceLength) {
      return currentIndex + 1;
    } else {
      if (betterPlayerPlaylistConfiguration.loopVideos) {
        return 0;
      } else {
        return -1;
      }
    }
  }

  ///Get index of currently played source, based on [_betterPlayerDataSourceList]
  int get currentDataSourceIndex => _currentDataSourceIndex;

  ///Get size of [_betterPlayerDataSourceList]
  int get _dataSourceLength => _betterPlayerDataSourceList.length;

  ///Get BetterPlayerController instance
  BetterPlayerController? get betterPlayerController => _betterPlayerController;

  ///Cleanup BetterPlayerPlaylistController
  void dispose() {
    _nextVideoTimeStreamSubscription?.cancel();
  }
}
