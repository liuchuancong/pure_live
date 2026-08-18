import 'package:better_player_plus/src/asms/better_player_asms_audio_track.dart';
import 'package:better_player_plus/src/asms/better_player_asms_data_holder.dart';
import 'package:better_player_plus/src/asms/better_player_asms_subtitle.dart';
import 'package:better_player_plus/src/asms/better_player_asms_subtitle_segment.dart';
import 'package:better_player_plus/src/asms/better_player_asms_track.dart';
import 'package:better_player_plus/src/asms/better_player_asms_utils.dart';
import 'package:better_player_plus/src/core/better_player_utils.dart';
import 'package:better_player_plus/src/hls/hls_parser/hls_master_playlist.dart';
import 'package:better_player_plus/src/hls/hls_parser/hls_media_playlist.dart';
import 'package:better_player_plus/src/hls/hls_parser/hls_playlist_parser.dart';
import 'package:better_player_plus/src/hls/hls_parser/rendition.dart';
import 'package:better_player_plus/src/hls/hls_parser/segment.dart';
import 'package:better_player_plus/src/hls/hls_parser/util.dart';

///HLS helper class
sealed class BetterPlayerHlsUtils {
  BetterPlayerHlsUtils._();

  static Future<BetterPlayerAsmsDataHolder> parse(String data, String masterPlaylistUrl) async {
    List<BetterPlayerAsmsTrack> tracks = [];
    List<BetterPlayerAsmsSubtitle> subtitles = [];
    List<BetterPlayerAsmsAudioTrack> audios = [];
    try {
      final List<List<dynamic>> list = await Future.wait([
        parseTracks(data, masterPlaylistUrl),
        parseSubtitles(data, masterPlaylistUrl),
        parseLanguages(data, masterPlaylistUrl),
      ]);
      tracks = list[0] as List<BetterPlayerAsmsTrack>;
      subtitles = list[1] as List<BetterPlayerAsmsSubtitle>;
      audios = list[2] as List<BetterPlayerAsmsAudioTrack>;
    } on Exception catch (exception) {
      BetterPlayerUtils.log('Exception on hls parse: $exception');
    }
    return BetterPlayerAsmsDataHolder(tracks: tracks, audios: audios, subtitles: subtitles);
  }

  static Future<List<BetterPlayerAsmsTrack>> parseTracks(String data, String masterPlaylistUrl) async {
    final List<BetterPlayerAsmsTrack> tracks = [];
    try {
      final parsedPlaylist = await HlsPlaylistParser.create().parseString(Uri.parse(masterPlaylistUrl), data);
      if (parsedPlaylist is HlsMasterPlaylist) {
        for (final variant in parsedPlaylist.variants) {
          tracks.add(
            BetterPlayerAsmsTrack(
              variant.format.id ?? '',
              variant.format.width,
              variant.format.height,
              variant.format.bitrate,
              variant.format.frameRate?.toInt() ?? 0,
              variant.format.codecs ?? '',
              variant.format.containerMimeType ?? '',
            ),
          );
        }
      }

      if (tracks.isNotEmpty) {
        tracks.insert(0, BetterPlayerAsmsTrack.defaultTrack());
      }
    } on Exception catch (exception) {
      BetterPlayerUtils.log('Exception on parseSubtitles: $exception');
    }
    return tracks;
  }

  ///Parse subtitles from provided m3u8 url
  static Future<List<BetterPlayerAsmsSubtitle>> parseSubtitles(String data, String masterPlaylistUrl) async {
    final List<BetterPlayerAsmsSubtitle> subtitles = [];
    try {
      final parsedPlaylist = await HlsPlaylistParser.create().parseString(Uri.parse(masterPlaylistUrl), data);

      if (parsedPlaylist is HlsMasterPlaylist) {
        for (final Rendition element in parsedPlaylist.subtitles) {
          final hlsSubtitle = await _parseSubtitlesPlaylist(element);
          if (hlsSubtitle != null) {
            subtitles.add(hlsSubtitle);
          }
        }
      }
    } on Exception catch (exception) {
      BetterPlayerUtils.log('Exception on parseSubtitles: $exception');
    }

    return subtitles;
  }

  ///Parse HLS subtitles playlist. If subtitles are segmented (more than 1
  ///segment is present in playlist), then setup subtitles as segmented.
  ///Segmented subtitles are loading with JIT policy, when video is playing
  ///to prevent massive load od video start. Segmented subtitles will have
  ///filled segments list which contains start, end and url of subtitles based
  ///on time in playlist.
  static Future<BetterPlayerAsmsSubtitle?> _parseSubtitlesPlaylist(Rendition rendition) async {
    try {
      final HlsPlaylistParser hlsPlaylistParser = HlsPlaylistParser.create();
      final subtitleData = await BetterPlayerAsmsUtils.getDataFromUrl(rendition.url.toString());
      if (subtitleData == null) {
        return null;
      }

      final parsedSubtitle = await hlsPlaylistParser.parseString(rendition.url, subtitleData);
      final hlsMediaPlaylist = parsedSubtitle as HlsMediaPlaylist;
      final hlsSubtitlesUrls = <String>[];

      final List<BetterPlayerAsmsSubtitleSegment> asmsSegments = [];
      final bool isSegmented = hlsMediaPlaylist.segments.length > 1;
      int microSecondsFromStart = 0;
      for (final Segment segment in hlsMediaPlaylist.segments) {
        final split = rendition.url.toString().split('/');
        var realUrl = '';
        for (var index = 0; index < split.length - 1; index++) {
          // Loop count is always small (URL path segments); StringBuffer overhead not justified
          // ignore: use_string_buffers
          realUrl += '${split[index]}/';
        }
        if (segment.url?.startsWith('http') ?? false) {
          realUrl = segment.url!;
        } else {
          realUrl += segment.url!;
        }
        hlsSubtitlesUrls.add(realUrl);

        if (isSegmented) {
          final int nextMicroSecondsFromStart = microSecondsFromStart + segment.durationUs!;
          microSecondsFromStart = nextMicroSecondsFromStart;
          asmsSegments.add(
            BetterPlayerAsmsSubtitleSegment(
              Duration(microseconds: microSecondsFromStart),
              Duration(microseconds: nextMicroSecondsFromStart),
              realUrl,
            ),
          );
        }
      }

      int targetDuration = 0;
      if (parsedSubtitle.targetDurationUs != null) {
        targetDuration = parsedSubtitle.targetDurationUs! ~/ 1000;
      }

      bool isDefault = false;

      if (rendition.format.selectionFlags != null) {
        isDefault = Util.checkBitPositionIsSet(rendition.format.selectionFlags!, Util.selectionFlagDefault);
      }

      return BetterPlayerAsmsSubtitle(
        name: rendition.format.label,
        language: rendition.format.language,
        url: rendition.url.toString(),
        realUrls: hlsSubtitlesUrls,
        isSegmented: isSegmented,
        segmentsTime: targetDuration,
        segments: asmsSegments,
        mimeType: rendition.format.containerMimeType,
        isDefault: isDefault,
      );
    } on Exception catch (exception) {
      BetterPlayerUtils.log('Failed to process subtitles playlist: $exception');
      return null;
    }
  }

  static Future<List<BetterPlayerAsmsAudioTrack>> parseLanguages(String data, String masterPlaylistUrl) async {
    final List<BetterPlayerAsmsAudioTrack> audios = [];
    final parsedPlaylist = await HlsPlaylistParser.create().parseString(Uri.parse(masterPlaylistUrl), data);
    if (parsedPlaylist is HlsMasterPlaylist) {
      for (int index = 0; index < parsedPlaylist.audios.length; index++) {
        final Rendition audio = parsedPlaylist.audios[index];
        audios.add(
          BetterPlayerAsmsAudioTrack(
            id: index,
            label: audio.name,
            language: audio.format.language,
            url: audio.url.toString(),
            mimeType: audio.format.containerMimeType,
            isDefault: Util.checkBitPositionIsSet(audio.format.selectionFlags!, Util.selectionFlagDefault),
          ),
        );
      }
    }

    return audios;
  }
}
