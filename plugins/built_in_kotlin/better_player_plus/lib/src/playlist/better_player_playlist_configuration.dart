///Additional configuration used in Better Player Playlist player.
class BetterPlayerPlaylistConfiguration {
  const BetterPlayerPlaylistConfiguration({
    this.nextVideoDelay = const Duration(milliseconds: 3000),
    this.loopVideos = true,
    this.initialStartIndex = 0,
  });

  ///How long user should wait for next video
  final Duration nextVideoDelay;

  ///Should videos be looped
  final bool loopVideos;

  ///Index of video that will start on playlist start. Id must be less than
  ///elements in data source list. Default is 0.
  final int initialStartIndex;
}
