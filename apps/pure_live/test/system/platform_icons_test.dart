import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// The platform icons live in `packages/live_sites` (the site registry owns
/// them); the app must find them under the package's asset prefix.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('live_sites bundles its platform icons into the app', () async {
    final data = await rootBundle.load('packages/live_sites/assets/platforms/bilibili.png');
    expect(data.lengthInBytes, greaterThan(0));
  });
}
