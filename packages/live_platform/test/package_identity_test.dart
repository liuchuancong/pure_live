import 'package:live_platform/live_platform.dart';
import 'package:test/test.dart';

/// The FFI probe follows the official Flutter/winapp example; the contract
/// under test here is only its failure shape — any platform, missing symbol
/// or API error degrades to null, never to an exception.
void main() {
  test('the probe answers without throwing', () {
    final familyName = PackageIdentity.windowsFamilyName();

    // On a Windows CI with an identity-less runner this is null; inside a
    // packaged or winapp-run build it is a family name. Both are correct.
    expect(familyName, anyOf(isNull, isA<String>()));
  });
}
