import 'dart:convert';
import 'dart:io';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:better_player_plus/src/core/better_player_utils.dart';
import 'package:better_player_plus/src/subtitles/better_player_subtitle.dart';

class BetterPlayerSubtitlesFactory {
  const BetterPlayerSubtitlesFactory._();

  static Future<List<BetterPlayerSubtitle>> parseSubtitles(BetterPlayerSubtitlesSource source) async {
    switch (source.type) {
      case BetterPlayerSubtitlesSourceType.file:
        return _parseSubtitlesFromFile(source);
      case BetterPlayerSubtitlesSourceType.network:
        return _parseSubtitlesFromNetwork(source);
      case BetterPlayerSubtitlesSourceType.memory:
        return _parseSubtitlesFromMemory(source);
      default:
        return [];
    }
  }

  static Future<List<BetterPlayerSubtitle>> _parseSubtitlesFromFile(BetterPlayerSubtitlesSource source) async {
    try {
      final List<BetterPlayerSubtitle> subtitles = [];
      for (final String? url in source.urls!) {
        final file = File(url!);
        if (file.existsSync()) {
          final String fileContent = await file.readAsString();
          final subtitlesCache = _parseString(fileContent);
          subtitles.addAll(subtitlesCache);
        } else {
          BetterPlayerUtils.log("$url doesn't exist!");
        }
      }
      return subtitles;
    } on Exception catch (exception) {
      BetterPlayerUtils.log('Failed to read subtitles from file: $exception');
    }
    return [];
  }

  static Future<List<BetterPlayerSubtitle>> _parseSubtitlesFromNetwork(BetterPlayerSubtitlesSource source) async {
    try {
      final client = HttpClient();
      final List<BetterPlayerSubtitle> subtitles = [];
      for (final String? url in source.urls!) {
        final request = await client.getUrl(Uri.parse(url!));
        source.headers?.keys.forEach((key) {
          final value = source.headers![key];
          if (value != null) {
            request.headers.add(key, value);
          }
        });
        final response = await request.close();
        final data = await response.transform(const Utf8Decoder()).join();
        final cacheList = _parseString(data);
        subtitles.addAll(cacheList);
      }
      client.close();

      BetterPlayerUtils.log('Parsed total subtitles: ${subtitles.length}');
      return subtitles;
    } on Exception catch (exception) {
      BetterPlayerUtils.log('Failed to read subtitles from network: $exception');
    }
    return [];
  }

  static List<BetterPlayerSubtitle> _parseSubtitlesFromMemory(BetterPlayerSubtitlesSource source) {
    try {
      return _parseString(source.content!);
    } on Exception catch (exception) {
      BetterPlayerUtils.log('Failed to read subtitles from memory: $exception');
    }
    return [];
  }

  static List<BetterPlayerSubtitle> _parseString(String value) {
    List<String> components = value.split('\r\n\r\n');
    if (components.length == 1) {
      components = value.split('\n\n');
    }

    // Skip parsing files with no cues
    if (components.length == 1) {
      return [];
    }

    final List<BetterPlayerSubtitle> subtitlesObj = [];

    final bool isWebVTT = components.contains('WEBVTT');
    for (final component in components) {
      if (component.isEmpty) {
        continue;
      }
      final subtitle = BetterPlayerSubtitle(component, isWebVTT);
      if (subtitle.start != null && subtitle.end != null && subtitle.texts != null) {
        subtitlesObj.add(subtitle);
      }
    }

    return subtitlesObj;
  }
}
