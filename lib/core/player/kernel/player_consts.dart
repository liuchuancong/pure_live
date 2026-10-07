import 'package:flutter/material.dart';
import 'package:pure_live/core/player/models/player_engine.dart';

import 'package:media_core_media_kit/media_core_media_kit.dart' as mk;

class PlayerConsts {
  static const String defaultKey = 'mpv';

  static const Map<String, PlayerEngine> engines = {
    'mpv': PlayerEngine.mediaKit,
    'ijk': PlayerEngine.fijk,
    'exo': PlayerEngine.exo,
  };

  static const Map<String, String> names = {'mpv': 'player_mpv', 'ijk': 'player_ijk', 'exo': 'player_exo'};

  static bool mobileOnlyEnginesAvailable(TargetPlatform platform) =>
      platform == TargetPlatform.android || platform == TargetPlatform.iOS;

  static const List<String> resolutions = ['原画', '蓝光8M', '蓝光4M', '超清', '流畅'];
  static const Map<String, String> resolutionLabelKeys = {
    '原画': 'prefer_resolution_option_original',
    '蓝光8M': 'prefer_resolution_option_blu_ray_8m',
    '蓝光4M': 'prefer_resolution_option_blu_ray_4m',
    '超清': 'prefer_resolution_option_super_hd',
    '流畅': 'prefer_resolution_option_smooth',
  };

  static String? resolutionLabelKey(String value) => resolutionLabelKeys[value];

  static Map<String, String> get videoOutputDrivers => mk.PlayerConsts.videoOutputDrivers;
  static Map<String, String> get audioOutputDrivers => mk.PlayerConsts.audioOutputDrivers;
  static Map<String, String> get hardwareDecoder => mk.PlayerConsts.hardwareDecoder;
}
