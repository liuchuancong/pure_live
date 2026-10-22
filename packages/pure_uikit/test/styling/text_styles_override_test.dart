import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The per-role pixel sizes the fine-tuning page writes: a role given a size
/// uses it under the global scale, and a role left alone keeps the design
/// language's own.
void main() {
  final token = ThemeAlgorithms.resolve(const SeedToken(), const []);
  final base = TextStyles.from(token, scale: 1);

  test('an override replaces exactly its role', () {
    final tuned = TextStyles.from(
      token,
      scale: 1,
      bodySmallSize: 20,
      bodySize: 21,
      subtitleSize: 22,
      titleSize: 23,
      headlineSize: 24,
    );
    expect(tuned.bodySmall.fontSize, 20);
    expect(tuned.caption.fontSize, 20);
    expect(tuned.body.fontSize, 21);
    expect(tuned.label.fontSize, 21);
    expect(tuned.subtitle.fontSize, 22);
    expect(tuned.title.fontSize, 23);
    expect(tuned.headline.fontSize, 24);
    expect(tuned.display.fontSize, base.display.fontSize);
  });

  test('the global scale still applies to an override', () {
    expect(TextStyles.from(token, scale: 2, bodySize: 10).body.fontSize, 20);
  });

  test('an omitted size keeps the token size', () {
    final tuned = TextStyles.from(token, scale: 1);
    expect(tuned.body.fontSize, base.body.fontSize);
  });
}
