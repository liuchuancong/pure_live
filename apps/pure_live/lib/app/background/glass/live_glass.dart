import 'dart:math' show min;
import 'dart:ui' show ImageFilter;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_device/live_device.dart' show PlatformDeviceIdentityService;
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:pure_live/app/background/settings/background_settings.dart';
import 'package:pure_live/app/background/tone/background_tone.dart';
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformKindProvider;

/// The glass material a floating layer wears, from the unified strategy:
/// features never write a sigma or a glass alpha themselves — they ask for a
/// [LiveGlassLevel] and paint what the policy resolves for it.
///
/// `solid` carries no material of its own: it is the answer every level
/// gives when the glass is off, and the floor a degraded device falls back
/// to. `subtle` is the navigation/toolbar layer, `standard` the menu family,
/// `strong` dialogs and sheets, and `isolated` the near-solid answer a layer
/// stacked over another dialog should wear — its job is isolation, not
/// transparency, so it frosts nothing.
enum LiveGlassLevel {
  solid(blurSigma: 0, lightAlpha: 1, darkAlpha: 1, minimumAlpha: 1),
  subtle(blurSigma: 8, lightAlpha: 0.88, darkAlpha: 0.85, minimumAlpha: 0.75),
  standard(blurSigma: 16, lightAlpha: 0.93, darkAlpha: 0.92, minimumAlpha: 0.86),
  strong(blurSigma: 22, lightAlpha: 0.97, darkAlpha: 0.97, minimumAlpha: 0.94),
  isolated(blurSigma: 0, lightAlpha: 0.99, darkAlpha: 0.99, minimumAlpha: 0.98);

  LiveGlassLevel({
    required this.blurSigma,
    required this.lightAlpha,
    required this.darkAlpha,
    required this.minimumAlpha,
  });

  /// The frost radius at full strength.
  final double blurSigma;

  /// The background's designed opacity on a light palette.
  final double lightAlpha;

  /// The background's designed opacity on a dark palette.
  final double darkAlpha;

  /// How transparent the layer may get however the viewer slides the
  /// strength or picks a transparency mode; the readability floor.
  final double minimumAlpha;
}

/// The frost radius behind a decorative cover wash — a room's own picture
/// standing in for a missing stream, a music hero or an EQ header bleeding
/// behind its gradient. One value, so those backdrops do not drift apart.
const double kLiveGlassCoverFrostSigma = 24;

/// The frost radius behind a full-bleed cover backdrop: the player page's
/// own stage and the preview's letterbox, where the picture is only a wash
/// under the whole window.
const double kLiveGlassHeroFrostSigma = 48;

/// Android devices at or under this much RAM never frost: a blur redrawn on
/// every scroll or playback frame costs them more than it is worth, so they
/// keep the tint alone. Four GiB, as the old liquid-glass bar measured it.
const int kLiveGlassFrostMinMemoryMegabytes = 4 * 1024;

/// What the glass resolves to for one app state: whether it paints at all,
/// how hard it frosts, and how transparent its layers aim.
final class LiveGlassPolicy {
  const LiveGlassPolicy({
    required this.enabled,
    required this.strength,
    required this.opacity,
    required this.frost,
  });

  /// Resolves the saved choices and the device's cost signal.
  factory LiveGlassPolicy.resolve({
    required BackgroundSettings settings,
    required bool android,
    required int? memoryMegabytes,
  }) {
    final mode = settings.glassMode;
    if (mode == BackgroundGlassMode.off) return disabled;
    var strength = (settings.glassStrength / 100).clamp(0.0, 1.0);
    if (mode == BackgroundGlassMode.reduced && strength > _reducedStrength) {
      strength = _reducedStrength;
    }
    return LiveGlassPolicy(
      enabled: true,
      strength: strength,
      opacity: settings.glassOpacity,
      // Unknown memory keeps a phone out of the blur range, as before.
      frost: !android || (memoryMegabytes != null && memoryMegabytes > kLiveGlassFrostMinMemoryMegabytes),
    );
  }

  /// The glass off: every level resolves to its solid answer.
  static const LiveGlassPolicy disabled = LiveGlassPolicy(
    enabled: false,
    strength: 0,
    opacity: BackgroundGlassOpacity.smart,
    frost: false,
  );

  /// The strength the `reduced` mode and the system's own "fewer effects"
  /// signals cap the glass at: translucent, lightly frosted, never busy.
  static const double _reducedStrength = 0.35;

  final bool enabled;

  /// 0..1 of the viewer's strength slider; scales the frost radius and how
  /// far each layer moves from solid toward its designed opacity.
  final double strength;

  final BackgroundGlassOpacity opacity;

  /// Whether blurring what sits behind is allowed at all (false on a
  /// low-memory Android phone or when the system asks for fewer effects).
  final bool frost;

  /// The system asking for fewer effects (reduce-motion, high contrast)
  /// outranks the slider: the glass thins to its reduced answer and stops
  /// frosting.
  LiveGlassPolicy demoted({required bool reduceVisualEffects}) {
    if (!enabled || !reduceVisualEffects) return this;
    return LiveGlassPolicy(
      enabled: true,
      strength: min(strength, _reducedStrength),
      opacity: opacity,
      frost: false,
    );
  }

  /// The material for [level] under this policy. The alpha never leaves the
  /// level's [LiveGlassLevel.minimumAlpha] and 1, and the frost scales with
  /// strength — so no setting can push a readable layer into unreadable.
  LiveGlassMaterial materialFor(LiveGlassLevel level, {required bool dark, double readabilityRaise = 0}) {
    if (!enabled) return const LiveGlassMaterial(blurSigma: 0, fillAlpha: 1);
    final base = dark ? level.darkAlpha : level.lightAlpha;
    final target = switch (opacity) {
      BackgroundGlassOpacity.smart => base,
      BackgroundGlassOpacity.high => base + (1 - base) * 0.6,
      BackgroundGlassOpacity.low => level.minimumAlpha,
    };
    final alpha = (1 - (1 - target) * strength + readabilityRaise).clamp(level.minimumAlpha, 1.0);
    // Quantised to whole sigmas so the filter cache stays a handful of
    // entries however the slider moves.
    final blur = frost ? (level.blurSigma * strength).roundToDouble() : 0.0;
    return LiveGlassMaterial(blurSigma: blur, fillAlpha: alpha);
  }
}

/// A resolved material: the fill's opacity and the frost to paint under it.
final class LiveGlassMaterial {
  const LiveGlassMaterial({required this.blurSigma, required this.fillAlpha});

  final double blurSigma;
  final double fillAlpha;

  /// Whether anything behind this layer gets blurred at all.
  bool get frosted => blurSigma > 0;

  /// The frost as a filter, shared per sigma through the cache; null for a
  /// flat layer so callers can skip the BackdropFilter outright.
  ImageFilter? get backdropFilter => frosted
      ? _filters.putIfAbsent(blurSigma, () => ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma))
      : null;

  static final Map<double, ImageFilter> _filters = {};
}

/// How much the readability plans raise a glass fill: with auto scrim
/// painting more wash than the slider asked for, the wallpaper measured busy,
/// and every glass layer moves up with it — a fraction of the extra wash,
/// capped, never enough to flatten the glass.
double liveGlassReadabilityRaise({
  required BackgroundSettings settings,
  required BackgroundTone? tone,
  required bool dark,
}) {
  if (tone == null || settings.scrimMode != BackgroundScrimMode.auto) return 0;
  final plan = dark ? tone.plans.dark : tone.plans.light;
  return ((plan.opacity - settings.scrimOpacity) * 0.2).clamp(0.0, 0.12);
}

/// The panel fill the theme's surface and field tokens wear while the glass
/// is on: the saved value never below [kBackgroundGlassFillFloor], plus the
/// readability raise.
double liveGlassPanelFill({
  required BackgroundSettings settings,
  required bool dark,
  BackgroundTone? tone,
}) =>
    (settings.glassFill + liveGlassReadabilityRaise(settings: settings, tone: tone, dark: dark))
        .clamp(kBackgroundGlassFillFloor, 1.0);

/// The policy for the whole app: saved choices against the device's cost.
final liveGlassPolicyProvider = Provider<LiveGlassPolicy>((ref) {
  return LiveGlassPolicy.resolve(
    settings: ref.watch(backgroundSettingsProvider),
    android: ref.watch(platformKindProvider) == PlatformKind.android,
    memoryMegabytes: ref.watch(deviceMemoryMegabytesProvider).value,
  );
});

/// The device's physical memory for the frost decision; null where the
/// platform reports none or the read fails.
final deviceMemoryMegabytesProvider = FutureProvider<int?>((ref) async {
  try {
    final identity = await const PlatformDeviceIdentityService().read();
    return identity.memoryMegabytes;
  } on Object {
    return null;
  }
});
