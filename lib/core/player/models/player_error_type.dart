import 'package:media_core/media_core.dart';

/// App-facing error category, used to pick the localized failure message.
///
/// The thrown object is media_core's [PlayerException]; this enum is derived
/// from its [PlayerErrorCode] so the UI keeps stable copy per category.
enum PlayerErrorType { network, native, codec, source, initialization, lifecycle, texture, unknown }

extension PlayerErrorCodeAppType on PlayerErrorCode {
  PlayerErrorType get appType {
    if (this == PlayerErrorCode.network ||
        this == PlayerErrorCode.networkUnavailable ||
        this == PlayerErrorCode.networkTimeout ||
        this == PlayerErrorCode.networkDnsFailed ||
        this == PlayerErrorCode.networkConnectionFailed ||
        this == PlayerErrorCode.networkConnectionRefused ||
        this == PlayerErrorCode.networkAborted ||
        this == PlayerErrorCode.httpError) {
      return PlayerErrorType.network;
    }
    if (this == PlayerErrorCode.decoderError ||
        this == PlayerErrorCode.decoderUnavailable ||
        this == PlayerErrorCode.codecUnsupported) {
      return PlayerErrorType.codec;
    }
    if (this == PlayerErrorCode.sourceMissing ||
        this == PlayerErrorCode.sourceInvalid ||
        this == PlayerErrorCode.sourceResolveFailed ||
        this == PlayerErrorCode.sourceInspectFailed ||
        this == PlayerErrorCode.sourceValidationFailed ||
        this == PlayerErrorCode.sourceProtocolUnsupported ||
        this == PlayerErrorCode.sourceMediaTypeUnsupported ||
        this == PlayerErrorCode.sourceFormatUnsupported) {
      return PlayerErrorType.source;
    }
    if (this == PlayerErrorCode.rendererTextureFailed ||
        this == PlayerErrorCode.rendererSurfaceFailed ||
        this == PlayerErrorCode.rendererInitializationFailed) {
      return PlayerErrorType.texture;
    }
    if (this == PlayerErrorCode.adapterInitializationFailed ||
        this == PlayerErrorCode.backendInitializationFailed ||
        this == PlayerErrorCode.audioInitializationFailed) {
      return PlayerErrorType.initialization;
    }
    if (this == PlayerErrorCode.lifecycleInactive ||
        this == PlayerErrorCode.lifecycleTransitionFailed ||
        this == PlayerErrorCode.playbackInvalidState ||
        this == PlayerErrorCode.invalidState) {
      return PlayerErrorType.lifecycle;
    }
    if (this == PlayerErrorCode.unknown) return PlayerErrorType.unknown;
    return PlayerErrorType.native;
  }
}
