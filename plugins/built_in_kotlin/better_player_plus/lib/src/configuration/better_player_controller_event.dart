///Internal events of BetterPlayerController, used in widgets to update state.
enum BetterPlayerControllerEvent {
  ///Fullscreen mode has started.
  openFullscreen,

  ///Fullscreen mode has ended.
  hideFullscreen,

  ///Subtitles changed.
  changeSubtitles,

  ///New data source has been set.
  setupDataSource,

  ///Video has started.
  play,

  ///Video set fit.
  setFit,

  ///Video track has changed.
  changedTrack,
}
