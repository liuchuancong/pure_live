import 'package:better_player_plus/src/hls/hls_parser/util.dart';

class MimeTypes {
  const MimeTypes._();

  static const String baseTypeVideo = 'video';
  static const String baseTypeAudio = 'audio';
  static const String baseTypeText = 'text';
  static const String baseTypeApplication = 'application';
  static const String videoMp4 = '$baseTypeVideo/mp4';
  static const String videoWebm = '$baseTypeVideo/webm';
  static const String videoH263 = '$baseTypeVideo/3gpp';
  static const String videoH264 = '$baseTypeVideo/avc';
  static const String videoH265 = '$baseTypeVideo/hevc';
  static const String videoVp8 = '$baseTypeVideo/x-vnd.on2.vp8';
  static const String videoVp9 = '$baseTypeVideo/x-vnd.on2.vp9';
  static const String videoAv1 = '$baseTypeVideo/av01';
  static const String videoMp4v = '$baseTypeVideo/mp4v-es';
  static const String videoMpeg = '$baseTypeVideo/mpeg';
  static const String videoMpeg2 = '$baseTypeVideo/mpeg2';
  static const String videoVc1 = '$baseTypeVideo/wvc1';
  static const String videoDivx = '$baseTypeVideo/divx';
  static const String videoDolbyVision = '$baseTypeVideo/dolby-vision';
  static const String videoUnknown = '$baseTypeVideo/x-unknown';
  static const String audioMp4 = '$baseTypeAudio/mp4';
  static const String audioAac = '$baseTypeAudio/mp4a-latm';
  static const String audioWebm = '$baseTypeAudio/webm';
  static const String audioMpeg = '$baseTypeAudio/mpeg';
  static const String audioMpegL1 = '$baseTypeAudio/mpeg-L1';
  static const String audioMpegL2 = '$baseTypeAudio/mpeg-L2';
  static const String audioRaw = '$baseTypeAudio/raw';
  static const String audioAlaw = '$baseTypeAudio/g711-alaw';
  static const String audioMlaw = '$baseTypeAudio/g711-mlaw';
  static const String audioAc3 = '$baseTypeAudio/ac3';
  static const String audioEAc3 = '$baseTypeAudio/eac3';
  static const String audioEAc3Joc = '$baseTypeAudio/eac3-joc';
  static const String audioAc4 = '$baseTypeAudio/ac4';
  static const String audioTruehd = '$baseTypeAudio/true-hd';
  static const String audioDts = '$baseTypeAudio/vnd.dts';
  static const String audioDtsHd = '$baseTypeAudio/vnd.dts.hd';
  static const String audioDtsExpress = '$baseTypeAudio/vnd.dts.hd;profile=lbr';
  static const String audioVorbis = '$baseTypeAudio/vorbis';
  static const String audioOpus = '$baseTypeAudio/opus';
  static const String audioAmrNb = '$baseTypeAudio/3gpp';
  static const String audioAmrWb = '$baseTypeAudio/amr-wb';
  static const String audioFlac = '$baseTypeAudio/flac';
  static const String audioAlac = '$baseTypeAudio/alac';
  static const String audioMsgsm = '$baseTypeAudio/gsm';
  static const String audioUnknown = '$baseTypeAudio/x-unknown';
  static const String textVtt = '$baseTypeText/vtt';
  static const String textSsa = '$baseTypeText/x-ssa';
  static const String applicationMp4 = '$baseTypeApplication/mp4';
  static const String applicationWebm = '$baseTypeApplication/webm';
  static const String applicationMpd = '$baseTypeApplication/dash+xml';
  static const String applicationM3u8 = '$baseTypeApplication/x-mpegURL';
  static const String applicationSs = '$baseTypeApplication/vnd.ms-sstr+xml';
  static const String applicationId3 = '$baseTypeApplication/id3';
  static const String applicationCea608 = '$baseTypeApplication/cea-608';
  static const String applicationCea708 = '$baseTypeApplication/cea-708';
  static const String applicationSubrip = '$baseTypeApplication/x-subrip';
  static const String applicationTtml = '$baseTypeApplication/ttml+xml';
  static const String applicationTx3g = '$baseTypeApplication/x-quicktime-tx3g';
  static const String applicationMp4vtt = '$baseTypeApplication/x-mp4-vtt';
  static const String applicationMp4cea608 = '$baseTypeApplication/x-mp4-cea-608';
  static const String applicationRawcc = '$baseTypeApplication/x-rawcc';
  static const String applicationVobsub = '$baseTypeApplication/vobsub';
  static const String applicationPgs = '$baseTypeApplication/pgs';
  static const String applicationScte35 = '$baseTypeApplication/x-scte35';
  static const String applicationCameraMotion = '$baseTypeApplication/x-camera-motion';
  static const String applicationEmsg = '$baseTypeApplication/x-emsg';
  static const String applicationDvbsubs = '$baseTypeApplication/dvbsubs';
  static const String applicationExif = '$baseTypeApplication/x-exif';
  static const String applicationIcy = '$baseTypeApplication/x-icy';

  static const String hls = 'hls';

  static final List<CustomMimeType> _customMimeTypes = [];

  static String? _getMimeTypeFromMp4ObjectType(int objectType) {
    switch (objectType) {
      case 0x20:
        return MimeTypes.videoMp4v;
      case 0x21:
        return MimeTypes.videoH264;
      case 0x23:
        return MimeTypes.videoH265;
      case 0x60:
      case 0x61:
      case 0x62:
      case 0x63:
      case 0x64:
      case 0x65:
        return MimeTypes.videoMpeg2;
      case 0x6A:
        return MimeTypes.videoMpeg;
      case 0x69:
      case 0x6B:
        return MimeTypes.audioMpeg;
      case 0xA3:
        return MimeTypes.videoVc1;
      case 0xB1:
        return MimeTypes.videoVp9;
      case 0x40:
      case 0x66:
      case 0x67:
      case 0x68:
        return MimeTypes.audioAac;
      case 0xA5:
        return MimeTypes.audioAc3;
      case 0xA6:
        return MimeTypes.audioEAc3;
      case 0xA9:
      case 0xAC:
        return MimeTypes.audioDts;
      case 0xAA:
      case 0xAB:
        return MimeTypes.audioDtsHd;
      case 0xAD:
        return MimeTypes.audioOpus;
      case 0xAE:
        return MimeTypes.audioAc4;
      default:
        return null;
    }
  }

  static String? getMediaMimeType(String codecValue) {
    String codec = codecValue;

    codec = codec.trim().toLowerCase();
    if (codec.startsWith('avc1') || codec.startsWith('avc3')) {
      return MimeTypes.videoH264;
    }

    if (codec.startsWith('hev1') || codec.startsWith('hvc1')) {
      return MimeTypes.videoH265;
    }

    if (codec.startsWith('dvav') || codec.startsWith('dva1') || codec.startsWith('dvhe') || codec.startsWith('dvh1')) {
      return MimeTypes.videoDolbyVision;
    }

    if (codec.startsWith('av01')) {
      return MimeTypes.videoAv1;
    }

    if (codec.startsWith('vp9') || codec.startsWith('vp09')) {
      return MimeTypes.videoVp9;
    }
    if (codec.startsWith('vp8') || codec.startsWith('vp08')) {
      return MimeTypes.videoVp8;
    }
    if (codec.startsWith('mp4a')) {
      String? mimeType;
      if (codec.startsWith('mp4a.')) {
        final String objectTypeString = codec.substring(5);
        if (objectTypeString.length >= 2) {
          try {
            final String objectTypeHexString = objectTypeString.substring(0, 2).toUpperCase();
            final int objectTypeInt = int.parse(objectTypeHexString, radix: 16);
            mimeType = _getMimeTypeFromMp4ObjectType(objectTypeInt);
          } on FormatException {
            //do nothing
            //print(ignored);
          }
        }
      }
      return mimeType ??= MimeTypes.audioAac;
    }
    if (codec.startsWith('ac-3') || codec.startsWith('dac3')) {
      return MimeTypes.audioAc3;
    }

    if (codec.startsWith('ec-3') || codec.startsWith('dec3')) {
      return MimeTypes.audioEAc3;
    }

    if (codec.startsWith('ec+3')) {
      return MimeTypes.audioEAc3Joc;
    }

    if (codec.startsWith('ac-4') || codec.startsWith('dac4')) {
      return MimeTypes.audioAc4;
    }

    if (codec.startsWith('dtsc') || codec.startsWith('dtse')) {
      return MimeTypes.audioDts;
    }

    if (codec.startsWith('dtsh') || codec.startsWith('dtsl')) {
      return MimeTypes.audioDtsHd;
    }
    if (codec.startsWith('opus')) {
      return MimeTypes.audioOpus;
    }
    if (codec.startsWith('vorbis')) {
      return MimeTypes.audioVorbis;
    }
    if (codec.startsWith('flac')) {
      return MimeTypes.audioFlac;
    }
    return getCustomMimeTypeForCodec(codec);
  }

  static String? getCustomMimeTypeForCodec(String codec) {
    for (final customMimeType in _customMimeTypes) {
      if (codec.startsWith(customMimeType.codecPrefix)) {
        return customMimeType.mimeType;
      }
    }

    return null;
  }

  static int getTrackType(String? mimeType) {
    if (mimeType?.isNotEmpty == false) {
      return Util.trackTypeUnknown;
    }

    if (isAudio(mimeType)) {
      return Util.trackTypeAudio;
    }
    if (isVideo(mimeType)) {
      return Util.trackTypeVideo;
    }
    if (isText(mimeType) ||
        applicationCea608 == mimeType ||
        applicationCea708 == mimeType ||
        applicationMp4cea608 == mimeType ||
        applicationSubrip == mimeType ||
        applicationTtml == mimeType ||
        applicationTx3g == mimeType ||
        applicationMp4vtt == mimeType ||
        applicationRawcc == mimeType ||
        applicationVobsub == mimeType ||
        applicationPgs == mimeType ||
        applicationDvbsubs == mimeType) {
      return Util.trackTypeText;
    } else if ((applicationId3 == mimeType) || (applicationEmsg == mimeType) || (applicationScte35 == mimeType)) {
      return Util.trackTypeMetadata;
    } else if (applicationCameraMotion == mimeType) {
      return Util.trackTypeCameraMotion;
    } else {
      return getTrackTypeForCustomMimeType(mimeType);
    }
  }

  static int getTrackTypeForCustomMimeType(String? mimeType) {
    for (final it in _customMimeTypes) {
      if (it.mimeType == mimeType) {
        return it.trackType;
      }
    }

    return Util.trackTypeUnknown;
  }

  static String? getTopLevelType(String? mimeType) {
    if (mimeType == null) {
      return null;
    }
    final int indexOfSlash = mimeType.indexOf('/');
    if (indexOfSlash == -1) {
      return null;
    }
    return mimeType.substring(0, indexOfSlash);
  }

  static bool isAudio(String? mimeType) => baseTypeAudio == getTopLevelType(mimeType);

  static bool isVideo(String? mimeType) => baseTypeVideo == getTopLevelType(mimeType);

  static bool isText(String? mimeType) => baseTypeText == getTopLevelType(mimeType);

  static int getTrackTypeOfCodec(String codec) => getTrackType(getMediaMimeType(codec));
}

class CustomMimeType {
  CustomMimeType({required this.mimeType, required this.codecPrefix, required this.trackType});

  final String mimeType;
  final String codecPrefix;
  final int trackType;
}
