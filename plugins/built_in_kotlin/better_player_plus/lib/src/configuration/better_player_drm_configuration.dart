import 'package:better_player_plus/src/configuration/better_player_drm_type.dart';

///Configuration of DRM used to protect data source
class BetterPlayerDrmConfiguration {
  BetterPlayerDrmConfiguration({
    this.drmType,
    this.token,
    this.licenseUrl,
    this.certificateUrl,
    this.headers,
    this.clearKey,
  });

  ///Type of DRM
  final BetterPlayerDrmType? drmType;

  ///Parameter used only for token encrypted DRMs
  final String? token;

  ///Url of license server
  final String? licenseUrl;

  ///Url of fairplay certificate
  final String? certificateUrl;

  ///ClearKey json object, used only for ClearKey protection. Only support for Android.
  final String? clearKey;

  ///Additional headers send with auth request, used only for WIDEVINE DRM
  final Map<String, String>? headers;
}
