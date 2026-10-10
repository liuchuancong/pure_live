// Module: lib/src/device_profile.dart
// Purpose: Form factor, per-device capability overrides and the one-line device description a report shows.
// Author: liuchuancong
// Created: 2026-10-11
//
// "It is Android" is not enough to lay out a screen or to decide whether a controller matters, and the real
// world needs a way to switch a capability *off* for one device family without editing the table - broken PiP
// on a specific TV build is the ordinary reason. Both go through here so the table stays a published truth and
// the exceptions stay auditable.

import 'platform_info.dart';

/// The physical shape of the device, orthogonal to its operating system.
enum DeviceForm { phone, foldable, tablet, desktop, television, automotive, unknown }

/// Which form factor a device is, from the signals a host can actually read.
///
/// Width in logical pixels is the only classifier that works across targets; it is a heuristic with a stated
/// boundary rather than a device database, so the caller can pass [isTelevision] / [isAutomotive] when it
/// knows better (the platform channel does tell a TV app that it is on a TV).
DeviceForm resolveDeviceForm({
  required double shortestLogicalWidth,
  bool isTelevision = false,
  bool isAutomotive = false,
}) {
  if (isTelevision) {
    return DeviceForm.television;
  }
  if (isAutomotive) {
    return DeviceForm.automotive;
  }
  if (shortestLogicalWidth.isNaN || shortestLogicalWidth <= 0) {
    return DeviceForm.unknown;
  }
  // A television is 960+ logical pixels wide at a glance, which is why isTelevision is asked for explicitly
  // rather than derived: the bounds below are *layout* bounds, and a browser window at 700 px is a small
  // tablet layout, not a phone.
  if (shortestLogicalWidth < 600) {
    return DeviceForm.phone;
  }
  if (shortestLogicalWidth < 840) {
    return DeviceForm.foldable;
  }
  if (shortestLogicalWidth < 1080) {
    return DeviceForm.tablet;
  }
  return DeviceForm.desktop;
}

/// The layout class a form factor implies, kept as data so a UI package can align with it.
extension DeviceFormLayout on DeviceForm {
  bool get isCompact => this == DeviceForm.phone || this == DeviceForm.unknown;

  bool get isTouchFirst => this == DeviceForm.phone || this == DeviceForm.foldable || this == DeviceForm.tablet;

  bool get isPointerFirst => this == DeviceForm.desktop || this == DeviceForm.television;

  /// Focus navigation is mandatory on a television and on a car, optional on a desktop, and irrelevant on a
  /// phone - the difference between "the app is usable" and "the app is usable with a remote".
  bool get requiresFocusNavigation => this == DeviceForm.television || this == DeviceForm.automotive;
}

/// A rule that switches one capability off for one family of devices.
///
/// Only removal is offered. Granting a capability the table denies is a claim about a device nobody verified,
/// and the table is the reviewed source - an override that can add would let a stale test fixture light up
/// background playback on the web.
final class CapabilityOverride {
  const CapabilityOverride({required this.disable, this.modelPattern, this.kinds});

  /// Capability names to switch off when this rule matches.
  final Set<PlatformCapability> disable;

  /// A case-insensitive substring of the device model or manufacturer, for example `braun` or `Shield`.
  final String? modelPattern;

  /// Or the rule applies only to these platform kinds. Both bounds must match when both are given.
  final Set<PlatformKind>? kinds;

  /// Whether this rule speaks to [kind] running on [model].
  bool matches(PlatformKind kind, String model) {
    final allowedKinds = kinds;
    if (allowedKinds != null && !allowedKinds.contains(kind)) {
      return false;
    }
    final pattern = modelPattern;
    if (pattern == null) {
      return true;
    }
    return model.toLowerCase().contains(pattern.toLowerCase());
  }

  @override
  String toString() => 'CapabilityOverride(disable=${disable.map((c) => c.name).toList()}, model=$modelPattern)';
}

/// The table plus the exceptions, applied as one pass.
final class DeviceProfile {
  DeviceProfile({
    required this.kind,
    required this.capabilities,
    this.model = '',
    this.form,
    this.overrides = const <CapabilityOverride>[],
    Set<PlatformCapability>? disabled,
  }) : _disabled = disabled == null ? const <PlatformCapability>{} : Set<PlatformCapability>.unmodifiable(disabled);

  /// Builds the profile from the table, then applies [overrides].
  factory DeviceProfile.resolve({
    required PlatformKind kind,
    String model = '',
    bool? webIsTouchPrimary,
    DeviceForm? form,
    List<CapabilityOverride> overrides = const <CapabilityOverride>[],
  }) {
    var current = capabilitiesFor(kind, webIsTouchPrimary: webIsTouchPrimary);
    final disabled = <PlatformCapability>{};
    for (final rule in overrides) {
      if (!rule.matches(kind, model)) {
        continue;
      }
      for (final capability in rule.disable) {
        final before = current;
        current = current.without(capability);
        if (current != before) {
          disabled.add(capability);
        }
      }
    }
    return DeviceProfile(
      kind: kind,
      capabilities: current,
      model: model,
      form: form,
      overrides: List<CapabilityOverride>.unmodifiable(overrides),
      disabled: disabled,
    );
  }

  final PlatformKind kind;
  final PlatformCapabilities capabilities;
  final String model;
  final DeviceForm? form;
  final List<CapabilityOverride> overrides;
  final Set<PlatformCapability> _disabled;

  /// Which capabilities a rule actually switched off. An override that stops matching - because the model
  /// string changed, usually - leaves this set empty, which is how a stale exception becomes visible instead
  /// of quietly doing nothing.
  Set<PlatformCapability> get disabledByOverrides => _disabled;

  bool get hasEffectiveOverrides => _disabled.isNotEmpty;

  bool supports(PlatformCapability capability) => capabilities.supports(capability);

  @override
  bool operator ==(Object other) =>
      other is DeviceProfile &&
      other.kind == kind &&
      other.capabilities == capabilities &&
      other.model == model &&
      other.form == form;

  @override
  int get hashCode => Object.hash(kind, capabilities, model, form);

  @override
  String toString() =>
      'DeviceProfile(${kind.name}${model.isEmpty ? '' : ' $model'}, ${form?.name ?? 'form?'}, '
      '$capabilities${hasEffectiveOverrides ? ', overridden ${_disabled.map((c) => c.name).join(' ')}' : ''})';
}

/// One line about the device, for the diagnostics header and the "About" screen.
final class DeviceDescription {
  const DeviceDescription({
    required this.kind,
    required this.form,
    required this.capabilities,
    this.model = '',
    this.systemVersion = '',
    this.locales = const <String>[],
    this.isPortableBuild = false,
  });

  final PlatformKind kind;
  final DeviceForm form;
  final PlatformCapabilities capabilities;

  /// Raw device model, as the platform reports it. Truncated by [summary] because it arrives unbounded.
  final String model;

  /// Android release / iOS version / Windows build, as the host supplies it.
  final String systemVersion;

  /// The user's language preferences, most preferred first, already normalised to tags.
  final List<String> locales;

  /// A Windows build running from a folder rather than an MSIX package.
  final bool isPortableBuild;

  static const int modelBudget = 64;

  String get primaryLocale => locales.isEmpty ? '' : locales.first;

  /// A single line safe to put in a report: fixed vocabulary, bounded free-text.
  String summary() {
    final cleanModel = model.replaceAll('\n', ' ').trim();
    final clipped = cleanModel.length <= modelBudget ? cleanModel : '${cleanModel.substring(0, modelBudget)}…';
    final parts = <String>[
      kind.name,
      form.name,
      if (clipped.isNotEmpty) clipped,
      if (systemVersion.isNotEmpty) 'os=$systemVersion',
      if (locales.isNotEmpty) 'lang=${locales.take(3).join(',')}',
      if (isPortableBuild) 'portable',
      'caps=${capabilities.enabled.isEmpty ? 'none' : capabilities.enabled.map((c) => c.name).join('+')}',
    ];
    return parts.join(' / ');
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'kind': kind.name,
      'form': form.name,
      if (model.isNotEmpty) 'model': model.length <= modelBudget ? model : model.substring(0, modelBudget),
      if (systemVersion.isNotEmpty) 'systemVersion': systemVersion,
      if (locales.isNotEmpty) 'locales': locales,
      'isPortableBuild': isPortableBuild,
      'capabilities': capabilities.enabled.map((cap) => cap.name).toList(growable: false),
    };
  }

  @override
  String toString() => summary();
}
