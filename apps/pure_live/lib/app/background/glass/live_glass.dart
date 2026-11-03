import 'dart:math' show min;
import 'dart:ui' show ImageFilter;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_device/live_device.dart' show PlatformDeviceIdentityService;
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:pure_live/app/background/settings/background_settings.dart';
import 'package:pure_live/app/background/tone/background_tone.dart';
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformKindProvider;

export 'package:pure_live/app/background/glass/glass_level.dart';

/// The frost radius behind every floating layer — dialogs, panels, menus,
/// popovers, notices, the text-selection bar and the navigation capsule. The
/// component library's own glass recipe uses one blur for its whole floating
/// family, and one radius here keeps the layers indistinguishable in polish.
const double kLiveGlassFloatingBlurSigma = 16;

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
  const LiveGlassPolicy({required this.enabled, required this.strength, required this.frost});

  /// Resolves the saved choices and the device's cost signal.
  factory LiveGlassPolicy.resolve({
    required BackgroundSettings settings,
    required bool android,
    required int? memoryMegabytes,
  }) {
    final mode = settings.glassMode;
    if (mode == BackgroundGlassMode.off) return disabled;
    return LiveGlassPolicy(
      enabled: true,
      // The reduced mode thins every layer and softens every frost; the
      // normal modes leave each layer at the opacity the viewer chose.
      strength: mode == BackgroundGlassMode.reduced ? _reducedStrength : 1,
      // Unknown memory keeps a phone out of the blur range, as before.
      frost: !android || (memoryMegabytes != null && memoryMegabytes > kLiveGlassFrostMinMemoryMegabytes),
    );
  }

  /// The glass off: every level resolves to its solid answer.
  static const LiveGlassPolicy disabled = LiveGlassPolicy(enabled: false, strength: 0, frost: false);

  /// The strength the `reduced` mode and the system's own "fewer effects"
  /// signals cap the glass at: translucent, lightly frosted, never busy.
  static const double _reducedStrength = 0.35;

  final bool enabled;

  /// 0..1 of the glass mode's thinning; scales the frost radius and how far
  /// each layer moves from its chosen opacity toward solid.
  final double strength;

  /// Whether blurring what sits behind is allowed at all (false on a
  /// low-memory Android phone or when the system asks for fewer effects).
  final bool frost;

  /// The system asking for fewer effects (reduce-motion, high contrast)
  /// outranks the mode: the glass thins to its reduced answer and stops
  /// frosting.
  LiveGlassPolicy demoted({required bool reduceVisualEffects}) {
    if (!enabled || !reduceVisualEffects) return this;
    return LiveGlassPolicy(enabled: true, strength: min(strength, _reducedStrength), frost: false);
  }

  /// The material the floating layers wear at [opacity] — the viewer's 0–1
  /// slider. The glass mode's thinning moves it toward solid, the wallpaper's
  /// readability raise lifts it, and the frost is the one floating radius
  /// scaled the same way.
  LiveGlassMaterial floatingMaterial({required double opacity, double readabilityRaise = 0}) {
    if (!enabled) return const LiveGlassMaterial(blurSigma: 0, fillAlpha: 1);
    final alpha = (1 - (1 - opacity) * strength + readabilityRaise).clamp(0.0, 1.0);
    // Quantised to whole sigmas so the filter cache stays a handful of
    // entries however the mode moves.
    final blur = frost ? (kLiveGlassFloatingBlurSigma * strength).roundToDouble() : 0.0;
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
  ImageFilter? get backdropFilter =>
      frosted ? _filters.putIfAbsent(blurSigma, () => ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma)) : null;

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

/// The fill the theme's surface and field tokens wear while the glass is on:
/// the viewer's surface opacity plus the wallpaper's readability raise.
double liveGlassSurfaceFill({required BackgroundSettings settings, required bool dark, BackgroundTone? tone}) =>
    (settings.glassSurfaceOpacity + liveGlassReadabilityRaise(settings: settings, tone: tone, dark: dark)).clamp(
      0.0,
      1.0,
    );

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
