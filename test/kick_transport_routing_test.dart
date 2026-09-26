import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/kick/kick_api.dart';

void main() {
  test('only kick.com API requests use the native (Android/Windows) TLS channel', () {
    // The room detail also fetches the IVS master playlist through the same
    // request function; the native channel only accepts kick.com, so routing
    // that playlist to it made every Kick room hang on Android.
    expect(KickApi.usesPlatformTls(Uri.parse('https://kick.com/api/v2/channels/westcol'), native: true), isTrue);
    expect(
      KickApi.usesPlatformTls(
        Uri.parse('https://fa723fc1b171.usw24.playlist.live-video.net/api/video/v1/x.m3u8'),
        native: true,
      ),
      isFalse,
    );
    expect(KickApi.usesPlatformTls(Uri.parse('https://kick.com/api/v2/channels/westcol'), native: false), isFalse);
    expect(KickApi.usesPlatformTls(Uri.parse('http://kick.com/api/v2/channels/westcol'), native: true), isFalse);
  });
}
