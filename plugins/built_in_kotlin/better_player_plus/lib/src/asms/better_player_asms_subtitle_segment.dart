///Class which represents one segment of subtitles. It consists of start time
///and end time which are relative from start of the video and real url of the
///video (with domain and all paths).
class BetterPlayerAsmsSubtitleSegment {
  BetterPlayerAsmsSubtitleSegment(this.startTime, this.endTime, this.realUrl);

  ///Start of the subtitles counting from the start of the video.
  final Duration startTime;

  ///End of the subtitles counting from the start of the video.
  final Duration endTime;

  ///Real url of the subtitles (with all domains and paths).
  final String realUrl;
}
