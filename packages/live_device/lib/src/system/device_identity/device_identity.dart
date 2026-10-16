/// Device and operating-system identity values for diagnostics.
///
/// Every platform information class of the underlying plugin stays inside
/// `live_device`; callers receive this single snapshot. Each field is nullable
/// because platforms report different subsets of the same idea — the field
/// notes say which platforms leave a value null and why.
///
/// This model deliberately carries no persistent identifier. The plugin also
/// exposes `androidId`, `identifierForVendor`, the Linux `machineId`, the
/// Windows `deviceId`, `digitalProductId` and `registeredOwner`, and none of
/// them are reachable here: this is a media app's diagnostics surface, not a
/// tracking-id surface, so a crash log or support dump built from a
/// `DeviceIdentity` can never recognise a device across installs or sessions.
final class DeviceIdentity {
  /// Creates an immutable identity snapshot.
  const new({
    required this.platformName,
    this.model,
    this.manufacturer,
    this.marketingName,
    this.hostname,
    this.systemName,
    this.systemVersion,
    this.majorVersion,
    this.minorVersion,
    this.logicalProcessorCount,
    this.memoryMegabytes,
    this.isPhysicalDevice,
  });

  /// Hardware model or product name, as the platform labels the machine.
  ///
  /// Android reports `Build.MODEL` (for example `Pixel 8`), iOS the commercial
  /// model name (`iPhone 16 Pro`) rather than the coarse `model` identifier,
  /// macOS the hardware identifier (`MacBookPro18,3`) and Windows the OS product
  /// name (`Windows 10 Pro`, which Windows 11 still reports for compatibility).
  /// Null on Linux, whose information class describes the installed system and
  /// not the hardware, and null in the browser.
  final String? model;

  /// Device manufacturer, reported by Android only.
  ///
  /// No other platform's information class exposes a manufacturer string; the
  /// browser's `vendor` field names the browser rather than the hardware.
  final String? manufacturer;

  /// User-visible device name, where the platform has one.
  ///
  /// Android and iOS return the name the owner set for the device (iOS 16 and
  /// newer report a generic name unless the app holds the device-name
  /// entitlement) and macOS its marketing model name (`MacBook Pro 16-inch,
  /// 2021`). Null on Windows, Linux and in the browser, where no comparable
  /// device name exists.
  final String? marketingName;

  /// Computer or network name reported by the desktop platforms.
  ///
  /// Filled on macOS and Windows. Null on Linux, whose only machine identity is
  /// `machineId` — a persistent identifier this model does not read — and null
  /// on Android, iOS and in the browser.
  final String? hostname;

  /// Operating-system label as the platform reports it.
  ///
  /// `Android`, `iOS` or `iPadOS`, `Windows` and `macOS` are constants; Linux
  /// reports its distribution name (for example `Ubuntu`) because that is the
  /// only system label `os-release` provides, falling back to `Linux`. On the
  /// web this is the detected browser label, such as `chrome` or `safari`.
  final String? systemName;

  /// Version string as the platform reports it.
  ///
  /// Android supplies its release string (`15`), iOS `systemVersion` (`18.1`)
  /// and Linux the `version` value of `os-release` (`24.04.1 LTS`). Windows and
  /// macOS publish their version only as separate numbers, so those are joined
  /// here (`10.0.26100`, `15.1`) to stay consistent with [majorVersion] and
  /// [minorVersion]; the Darwin `osRelease` and Windows `releaseId` numbering
  /// spaces are not surfaced. Null on the web, which only exposes a user-agent
  /// string.
  final String? systemVersion;

  /// First numeric version component, where the platform exposes it separately.
  ///
  /// Only Windows and macOS split their OS version into numbers. Android, iOS
  /// and Linux report a single string and the browser reports nothing, so this
  /// and [minorVersion] stay null there.
  final int? majorVersion;

  /// Second numeric version component; see [majorVersion] for availability.
  final int? minorVersion;

  /// Number of logical processors — hardware threads — the OS exposes.
  ///
  /// The name says *logical* on purpose: every source below counts scheduling
  /// threads, not physical cores, so a hyper-threaded or efficiency-core machine
  /// reads a higher number than its package's core count and the true set of
  /// cores is never recoverable from it. Windows fills it from
  /// `GetSystemInfo().dwNumberOfProcessors`, which is logical processors
  /// including hyperthreads; macOS fills it from `Sysctl.activeCPUs`, i.e.
  /// `hw.availcpu` (available logical CPUs) and not `hw.physicalcpu`; the web
  /// uses `navigator.hardwareConcurrency`, itself capped and rounded by the
  /// browser. Android, iOS and the Linux `os-release` source report no such
  /// number, so mobile and Linux reads yield null.
  final int? logicalProcessorCount;

  /// Physical memory in whole megabytes, normalized across platforms.
  ///
  /// macOS reports bytes and the browser reports approximate gibibytes, so both
  /// are converted here; Android, iOS and Windows already report megabytes and
  /// are passed through. See `device_identity_memory.dart` for the units of each
  /// source value. A platform that did not report memory (`-1` or `0`) yields
  /// null, and the browser value is null in browsers that hide `deviceMemory`.
  final int? memoryMegabytes;

  /// Whether the app runs on physical hardware rather than an emulator.
  ///
  /// Android and iOS only. Desktop platforms and the browser report nothing, so
  /// they yield null; on iOS the value also reflects whether the app runs in a
  /// simulator.
  final bool? isPhysicalDevice;

  /// Runtime label for diagnostics, independent of any project platform enum.
  ///
  /// One of `android`, `ios`, `linux`, `macos`, `windows`, `fuchsia` or `web`.
  /// It exists so a support log can name the runtime; branch on
  /// `DeviceIdentityCapabilities` flags instead, because reported fields differ
  /// even between versions of the same platform.
  final String platformName;
}
