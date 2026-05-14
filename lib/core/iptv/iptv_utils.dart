import 'dart:io';
import 'dart:convert';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/plugins/race_http.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pure_live/core/iptv/src/m3u_item.dart';
import 'package:pure_live/core/iptv/src/m3u_list.dart';
import 'package:pure_live/common/utils/githup_mirror.dart';
import 'package:pure_live/common/global/app_path_manager.dart';

class IptvUtils {
  static const String directoryPath = '/assets/iptv/';
  static const String category = 'category';
  static const String recomand = 'recomand';

  static Future<List<IptvCategory>> readCategory() async {
    try {
      var dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final categories = File(p.join(dir.path, AppPathManager.iptvCategoryFile));
      String jsonData = await categories.readAsString();
      List jsonArr = jsonData.isNotEmpty ? jsonDecode(jsonData) : [];
      List<IptvCategory> categoriesArr = jsonArr.map((e) => IptvCategory.fromJson(e)).toList();
      return categoriesArr;
    } catch (e) {
      return [];
    }
  }

  static Future loadNetworkM3u8() async {
    Dio dio = Dio(
      BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)),
    );
    try {
      var dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final m3ufile = File(p.join(dir.path, AppPathManager.iptvHotFile));
      await dio.download(
        'https://ghfast.top/https://raw.githubusercontent.com/YueChan/Live/main/IPTV.m3u',
        m3ufile.path,
      );
    } catch (e) {
      log(e.toString());
    }
  }

  static Future<String> loadJsonFromAssets(String assetsPath) async {
    return await rootBundle.loadString(assetsPath);
  }

  static Future<List<M3uItem>> readCategoryItems(String filePath) async {
    List<M3uItem> list = [];
    try {
      final m3uList = await M3uList.loadFromFile(filePath);
      for (M3uItem item in m3uList.items) {
        list.add(item);
      }
    } catch (e) {
      log(e.toString());
    }
    return list;
  }

  static Future<List<M3uItem>> readRecommandsItems() async {
    List<M3uItem> list = [];
    try {
      final mirror = GitHubMirror(owner: 'YueChan', repo: 'Live', branch: 'main');
      final urls = mirror.mirrors('GNTV.m3u');
      final m3uText = await RaceHttp.fetchText(urls);

      if (m3uText == null || m3uText.isEmpty) {
        throw Exception("m3u download failed");
      }
      final m3uList = M3uList.load(m3uText);
      list.addAll(m3uList.items);
    } catch (e) {
      await loadNetworkM3u8();
      var dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final m3ufile = File(p.join(dir.path, 'hot.m3u'));
      if (m3ufile.existsSync()) {
        final m3uList = await M3uList.loadFromFile(m3ufile.path);
        list.addAll(m3uList.items);
      }
    }
    return list;
  }

  static Future<bool> recover(File file) async {
    return true;
  }
}

class IptvCategory {
  String? id;
  String? name;
  String? path;

  IptvCategory({this.id, this.name, this.path});

  factory IptvCategory.fromJson(Map<String, dynamic> json) {
    return IptvCategory(name: json['name'], id: json['id'], path: json['path']);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{'name': name, 'id': id, 'path': path};
}

class IptvCategoryItem {
  final String id;
  final String name;
  final String liveUrl;

  IptvCategoryItem({required this.id, required this.name, required this.liveUrl});

  factory IptvCategoryItem.fromJson(Map<String, dynamic> json) {
    return IptvCategoryItem(name: json['name'], id: json['id'], liveUrl: json['liveUrl']);
  }
}
