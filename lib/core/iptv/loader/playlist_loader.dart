import 'dart:io';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:pure_live/plugins/race_http.dart';
import 'package:pure_live/core/iptv/models/channel.dart';
import 'package:pure_live/common/utils/githup_mirror.dart';
import 'package:pure_live/core/iptv/parsers/txt_parser.dart';
import 'package:pure_live/core/iptv/parsers/m3u_parser.dart';
import 'package:pure_live/common/global/app_path_manager.dart';

class PlaylistLoader {
  static final Dio _dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)),
  );

  /// 从本地文件读取 playlist
  static Future<List<Channel>> loadFromFile({required String path, required String providerId}) async {
    final file = File(path);

    if (!await file.exists()) {
      throw Exception('Playlist file not found');
    }

    final content = await file.readAsString();

    return parseContent(content, providerId: providerId);
  }

  /// 从网络读取 playlist
  static Future<List<Channel>> loadFromUrl({required String url, required String providerId}) async {
    final response = await _dio.get<String>(url);

    final content = response.data;

    if (content == null || content.isEmpty) {
      throw Exception('Playlist content is empty');
    }

    return parseContent(content, providerId: providerId);
  }

  /// 自动识别 txt/m3u
  static List<Channel> parseContent(String content, {required String providerId}) {
    final trimmed = content.trimLeft();

    // M3U
    if (trimmed.startsWith('#EXTM3U') || trimmed.contains('#EXTINF')) {
      return M3uParser().parse(content, providerId: providerId).channels;
    }

    // TXT
    return TxtParser().parse(content, providerId: providerId).channels;
  }

  /// 推荐源
  static Future<List<Channel>> loadRecommended({required String providerId}) async {
    try {
      final mirror = GitHubMirror(owner: 'YueChan', repo: 'Live', branch: 'main');
      final urls = mirror.mirrors('GNTV.m3u');
      final m3uText = await RaceHttp.fetchText(urls);
      if (m3uText == null || m3uText.isEmpty) {
        throw Exception('m3u download failed');
      }
      return parseContent(m3uText, providerId: providerId);
    } catch (e, s) {
      log('loadRecommended error', error: e, stackTrace: s);
      rethrow;
    }
  }

  /// 从 assets 读取
  static Future<String> loadTextAsset(String assetsPath) {
    return rootBundle.loadString(assetsPath);
  }

  /// 从 cache 读取
  static Future<List<Channel>> loadCachedPlaylist({required String providerId}) async {
    final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
    final file = File(p.join(dir.path, AppPathManager.iptvHotFile));
    if (!await file.exists()) {
      return [];
    }
    return loadFromFile(path: file.path, providerId: providerId);
  }

  static Future<List<Channel>> load({required String providerId, String? url, String? filePath}) async {
    if (providerId == 'hot') {
      return await loadRecommended(providerId: providerId);
    }
    if (filePath != null) {
      return await loadFromFile(path: filePath, providerId: providerId);
    }
    if (url != null) {
      return await loadFromUrl(url: url, providerId: providerId);
    }
    return [];
  }
}
