/// Resolves the mpv video-track value for the requested presentation state.
///
/// Track selection follows the room's requested presentation state.
///
/// A detached Android Surface is not a reason to disable video decoding. The
/// SurfaceProducer callback may already have fired before the application asks
/// for video mode, so writing `vid=no` while [surfaceAttached] is false can
/// create a circular wait: no decoded video parameters, no new Surface resize
/// callback, and therefore no later `vid=auto`. Keeping video mode on `auto`
/// also matches media_kit's upstream startup state; `vo=null` is sufficient to
/// make a detached Surface safe.
String resolveVideoTrackForSurface({
  required bool videoOutputEnabled,
  required bool surfaceAttached,
}) {
  return videoOutputEnabled ? 'auto' : 'no';
}

/// Builds the ordered Android properties for one Surface attachment state.
///
/// `vid` is deliberately present for every output driver. Audio-only therefore
/// survives detach/attach, while video restore is immediate even if WID is not
/// currently available.
Map<String, String> resolveAndroidSurfaceProperties({
  required int width,
  required int height,
  required int? wid,
  required String configuredVo,
  required bool videoOutputEnabled,
}) {
  final widValue = wid?.toString() ?? '0';
  final surfaceAttached = widValue != '0';
  return <String, String>{
    'android-surface-size': '${width}x$height',
    'wid': widValue,
    'vo': surfaceAttached ? configuredVo : 'null',
    'vid': resolveVideoTrackForSurface(
      videoOutputEnabled: videoOutputEnabled,
      surfaceAttached: surfaceAttached,
    ),
  };
}
