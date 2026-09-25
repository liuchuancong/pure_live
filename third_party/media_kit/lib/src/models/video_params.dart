/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.

/// {@template video_params}
///
/// VideoParams
/// -----------
///
/// Video parameters, as output by the decoder (with overrides like aspect etc. applied). This has a number of sub-properties.
///
/// {@endtemplate}
class VideoParams {
  /// The pixel format as string. This uses the same names as used in other places of mpv.
  final String? pixelformat;

  /// The underlying pixel format as string. This is relevant for some cases of hardware decoding and unavailable otherwise.
  final String? hwPixelformat;

  /// Video size as integers, with no aspect correction applied.
  final int? w;

  /// Video size as integers, with no aspect correction applied.
  final int? h;

  /// Video size as integers, scaled for correct aspect ratio.
  final int? dw;

  /// Video size as integers, scaled for correct aspect ratio.
  final int? dh;

  /// Display aspect ratio as float.
  final double? aspect;

  /// Pixel aspect ratio as float.
  final double? par;

  /// The colormatrix in use as string.
  final String? colormatrix;

  /// The colorlevels in use as string.
  final String? colorlevels;

  /// The colorspace in use as string.
  final String? primaries;

  /// The gamma function in use as string.
  final String? gamma;

  /// The video file's tagged signal peak as float.
  final double? sigPeak;

  /// The light type in use as string.
  final String? light;

  /// Chroma location as string.
  final String? chromaLocation;

  /// Intended display rotation in degrees (clockwise).
  final int? rotate;

  /// Source file stereo 3D mode.
  final String? stereoIn;

  /// Average bits-per-pixel as integer. Subsampled planar formats use a different resolution, which is the reason this value can sometimes be odd or confusing. Can be unavailable with some formats.
  final int? averageBpp;

  /// Alpha type. If the format has no alpha channel, this will be unavailable (but in future releases, it could change to no). If alpha is present, this is set to straight or premul.
  final String? alpha;

  /// {@macro video_params}
  const VideoParams({
    this.pixelformat,
    this.hwPixelformat,
    this.w,
    this.h,
    this.dw,
    this.dh,
    this.aspect,
    this.par,
    this.colormatrix,
    this.colorlevels,
    this.primaries,
    this.gamma,
    this.sigPeak,
    this.light,
    this.chromaLocation,
    this.rotate,
    this.stereoIn,
    this.averageBpp,
    this.alpha,
  });

  @override
  operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is VideoParams &&
        other.pixelformat == pixelformat &&
        other.hwPixelformat == hwPixelformat &&
        other.w == w &&
        other.h == h &&
        other.dw == dw &&
        other.dh == dh &&
        other.aspect == aspect &&
        other.par == par &&
        other.colormatrix == colormatrix &&
        other.colorlevels == colorlevels &&
        other.primaries == primaries &&
        other.gamma == gamma &&
        other.sigPeak == sigPeak &&
        other.light == light &&
        other.chromaLocation == chromaLocation &&
        other.rotate == rotate &&
        other.stereoIn == stereoIn &&
        other.averageBpp == averageBpp &&
        other.alpha == alpha;
  }

  @override
  int get hashCode =>
      pixelformat.hashCode ^
      hwPixelformat.hashCode ^
      w.hashCode ^
      h.hashCode ^
      dw.hashCode ^
      dh.hashCode ^
      aspect.hashCode ^
      par.hashCode ^
      colormatrix.hashCode ^
      colorlevels.hashCode ^
      primaries.hashCode ^
      gamma.hashCode ^
      sigPeak.hashCode ^
      light.hashCode ^
      chromaLocation.hashCode ^
      rotate.hashCode ^
      stereoIn.hashCode ^
      averageBpp.hashCode ^
      alpha.hashCode;

  @override
  String toString() => 'VideoParams('
      'pixelformat: $pixelformat, '
      'hwPixelformat: $hwPixelformat, '
      'w: $w, '
      'h: $h, '
      'dw: $dw, '
      'dh: $dh, '
      'aspect: $aspect, '
      'par: $par, '
      'colormatrix: $colormatrix, '
      'colorlevels: $colorlevels, '
      'primaries: $primaries, '
      'gamma: $gamma, '
      'sigPeak: $sigPeak, '
      'light: $light, '
      'chromaLocation: $chromaLocation, '
      'rotate: $rotate, '
      'stereoIn: $stereoIn, '
      'averageBpp: $averageBpp, '
      'alpha: $alpha'
      ')';
}
