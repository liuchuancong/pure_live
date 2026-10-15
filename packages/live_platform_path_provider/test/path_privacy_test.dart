import 'package:live_platform/live_platform.dart';
import 'package:live_platform_path_provider/live_platform_path_provider.dart';
import 'package:test/test.dart';

/// `PathPrivacy` is the download-flow's warning light: before a file is
/// planned into a directory the user cannot reach from a gallery or a file
/// manager, someone has to say so. The cases below pin the platform split.
void main() {
  test('android app-private and app-specific-external trees are private', () {
    const kind = PlatformKind.android;

    expect(PathPrivacy.isPrivate('/data/data/com.purelive/files', kind: kind), isTrue);
    expect(PathPrivacy.isPrivate('/data/user/0/com.purelive/cache', kind: kind), isTrue);
    expect(PathPrivacy.isPrivate(r'C:\ports', kind: kind), isFalse, reason: 'a windows-shaped path says nothing here');
    expect(PathPrivacy.isPrivate('/storage/emulated/0/Android/data/com.purelive/files/Download', kind: kind), isTrue);
    expect(PathPrivacy.isPrivate('/storage/emulated/0/Android/obb/com.purelive', kind: kind), isTrue);
  });

  test('android public storage is not private', () {
    const kind = PlatformKind.android;

    expect(PathPrivacy.isPrivate('/storage/emulated/0/Download', kind: kind), isFalse);
    expect(PathPrivacy.isPrivate('/storage/emulated/0/Movies/PureLive', kind: kind), isFalse);
  });

  test('the ios sandbox is always private', () {
    expect(PathPrivacy.isPrivate('/var/mobile/Containers/Bundle/app/Documents', kind: PlatformKind.ios), isTrue);
  });

  test('desktop paths are not private', () {
    for (final kind in [PlatformKind.windows, PlatformKind.macos, PlatformKind.linux]) {
      expect(PathPrivacy.isPrivate('C:/Users/x/Downloads', kind: kind), isFalse, reason: '$kind');
      expect(PathPrivacy.isPrivate('/home/x/pure_live', kind: kind), isFalse, reason: '$kind');
    }
  });

  test('an unknown platform answers conservatively', () {
    expect(PathPrivacy.isPrivate('/some/ordinary/path', kind: PlatformKind.unknown), isTrue);
  });
}
