import 'package:flutter/foundation.dart';
import 'package:pure_live/core/player/kernel/mpv_platform_profile.dart';
import 'package:pure_live/core/utils/i18n.dart';

enum MpvOptionKind {
  videoOutput,
  audioOutput,
  hardwareDecoder,
  videoSync,
  interpolation,
  scale,
  deinterlace,
  hwdecCodecs,
  audioExclusive,
}

typedef MpvOption = ({String key, String label});

const Map<MpvOptionKind, String> _kindSlug = {
  MpvOptionKind.videoOutput: 'video_output',
  MpvOptionKind.audioOutput: 'audio_output',
  MpvOptionKind.hardwareDecoder: 'hardware_decoder',
  MpvOptionKind.videoSync: 'video_sync',
  MpvOptionKind.interpolation: 'interpolation',
  MpvOptionKind.scale: 'scale',
  MpvOptionKind.deinterlace: 'deinterlace',
  MpvOptionKind.hwdecCodecs: 'hwdec_codecs',
  MpvOptionKind.audioExclusive: 'audio_exclusive',
};

/// The locale key holding this option's readable name.
///
/// Deriving it from the stored value instead of a table keeps one source of
/// truth: the settings list is built from what the platform profile accepts,
/// so a driver added there needs only the two locale rows, not a third
/// catalogue that can silently disagree with the value it displays.
String mpvOptionLabelKey(MpvOptionKind kind, String value) =>
    'mpv_option_${_kindSlug[kind]}_${value.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').toLowerCase()}';

/// Values the settings page may offer for [kind] on [platform], in display
/// order.
List<String> _allowedValues(MpvOptionKind kind, TargetPlatform platform) {
  final android = platform == TargetPlatform.android;
  final desktop = !android && platform != TargetPlatform.iOS;

  return switch (kind) {
    MpvOptionKind.videoOutput => mpvVideoOutputDriversForPlatform(platform).keys.toList(growable: false),
    MpvOptionKind.audioOutput => mpvAudioOutputDriversForPlatform(platform).keys.toList(growable: false),
    MpvOptionKind.hardwareDecoder => mpvHardwareDecodersForPlatform(platform).keys.toList(growable: false),
    MpvOptionKind.videoSync => const [
      'audio',
      'display-resample',
      'display-resample-vdrop',
      'display-resample-drop',
      'display-adrop',
      'display-vdrop',
      'display-desync',
      'desync',
    ],
    MpvOptionKind.interpolation => const ['no', 'yes'],
    MpvOptionKind.scale =>
      desktop
          ? const [
              'lanczos',
              'ewa_lanczossharp',
              'ewa_lanczos4sharpest',
              'ewa_lanczos',
              'spline36',
              'spline16',
              'catmull_rom',
              'mitchell',
              'hermite',
              'bicubic_fast',
              'bilinear',
              'nearest',
            ]
          : const ['lanczos', 'bilinear'],
    MpvOptionKind.deinterlace => const ['auto', 'no', 'yes'],
    MpvOptionKind.hwdecCodecs =>
      android
          ? const ['h264,hevc', 'h264,hevc,vp9', 'all']
          : const ['all', 'h264,hevc', 'h264,hevc,vp9', 'h264,hevc,vp9,av1'],
    MpvOptionKind.audioExclusive => platform == TargetPlatform.windows ? const ['no', 'yes'] : const [],
  };
}

/// The stored value as the player will use it on [platform].
String normalizedMpvOption(MpvOptionKind kind, String value, TargetPlatform platform) => switch (kind) {
  MpvOptionKind.videoOutput => normalizeMpvVideoOutputDriverForPlatform(value, platform),
  MpvOptionKind.audioOutput => normalizeMpvAudioOutputDriverForPlatform(value, platform),
  MpvOptionKind.hardwareDecoder => normalizeMpvHardwareDecoderForPlatform(value, platform),
  MpvOptionKind.videoSync => value,
  MpvOptionKind.interpolation => value,
  MpvOptionKind.scale => value,
  MpvOptionKind.deinterlace => value,
  MpvOptionKind.hwdecCodecs => value,
  MpvOptionKind.audioExclusive => value,
};

/// The readable name for one stored value; falls back to the raw value while
/// the locale bundle is still loading or when a driver has no locale rows.
String mpvOptionLabel(MpvOptionKind kind, String value) => i18nOr(mpvOptionLabelKey(kind, value), value);

/// Options the settings page may offer on [platform].
///
/// Ordering contract: `auto` first, the disable entry (`no`/`null`) second,
/// then everything else. The hardware-decoder list omits `no` entirely —
/// disabling hardware acceleration is the hardware-acceleration switch's
/// job, not a decoder choice, so the two never duplicate.
List<MpvOption> mpvOptionsForPlatform(MpvOptionKind kind, TargetPlatform platform) {
  final all = <MpvOption>[
    for (final key in _allowedValues(kind, platform)) (key: key, label: mpvOptionLabel(kind, key)),
  ];

  final head = <MpvOption>[];
  for (final key in ['auto', 'no', 'null']) {
    final matches = all.where((entry) => entry.key == key).toList();
    if (matches.isNotEmpty) {
      head.add(matches.first);
      all.remove(matches.first);
    }
  }

  if (kind == MpvOptionKind.hardwareDecoder) {
    all.removeWhere((entry) => entry.key == 'no');
  }

  return [...head, ...all];
}
