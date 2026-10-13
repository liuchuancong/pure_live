import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:live_shell/live_shell.dart';

/// `LASTINPUTINFO`, whose first field must hold the struct's own size.
final class _LastInputInfo extends Struct {
  @Uint32()
  external int cbSize;

  @Uint32()
  external int dwLastInputInfo;
}

typedef _GetLastInputInfoNative = Bool Function(Pointer<_LastInputInfo>);
typedef _GetLastInputInfoDart = bool Function(Pointer<_LastInputInfo>);
typedef _GetTickCount64Native = Uint64 Function();
typedef _GetTickCount64Dart = int Function();

class _User32 {
  static final DynamicLibrary _library = DynamicLibrary.open('user32.dll');
  static final _GetLastInputInfoDart getLastInputInfo = _library
      .lookupFunction<_GetLastInputInfoNative, _GetLastInputInfoDart>('GetLastInputInfo');
  // kernel32, not user32; loaded separately because the two live in different
  // libraries even though the call pair belongs to one feature.
  static final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');
  static final _GetTickCount64Dart getTickCount64 = _kernel32
      .lookupFunction<_GetTickCount64Native, _GetTickCount64Dart>('GetTickCount64');
}

/// Whether this platform can answer "how long since anyone touched the machine".
bool get supportsSystemIdleTime => Platform.isWindows;

/// A reader for the current platform, or null where there is none.
///
/// Null rather than a zero-returning stub: the shell reads this to decide
/// whether to give memory back, and an implementation that always answers "0"
/// would disable the feature silently while looking like it worked, whereas a
/// missing reader is something the settings screen can honestly grey out.
SystemIdleReader? get systemIdleReader => supportsSystemIdleTime ? windowsSystemIdleTime : null;

/// How long the machine has gone without keyboard or mouse input, on Windows.
///
/// `GetLastInputInfo` has been there since XP, so every Windows 10 build
/// qualifies; the tick source is `GetTickCount64` deliberately — the 32-bit
/// `GetTickCount` rolls over after 49.7 days of uptime, and a machine that has
/// been running longer than that reports an idle span that is off by exactly
/// that much, which on a box left recording for a month means a reclaim that
/// fires at the wrong moment or never at all.
///
/// Three readings this cannot give, worth knowing before the feature is trusted:
///
/// * **It is per interactive session, not per viewer.** When the screen is
///   locked or a UAC prompt is up, input goes to a different desktop and this
///   count stops advancing in a way that looks like activity — or freezes; the
///   two are indistinguishable from here. Idle therefore means "nobody touched
///   *this session's* mouse", never "nobody is watching".
/// * Remote desktop input counts as input, which is usually what you want and
///   occasionally not: an unattended RDP session left open looks permanently
///   active.
/// * The value is a whole-tick difference and is capped by a 32-bit field, so it
///   saturates at about 49 days of continuous idleness. Nothing acts on spans
///   that long; the number is simply not meaningful there.
Future<Duration> windowsSystemIdleTime() async {
  final info = calloc<_LastInputInfo>();
  try {
    // Without cbSize the call fails with ERROR_INVALID_PARAMETER, and the
    // failure is silent: the struct is left zeroed, which would then read back
    // as "idle since boot" — the worst possible direction for a function to
    // fail in, because it looks like a long idle and triggers the reclaim.
    info.ref.cbSize = sizeOf<_LastInputInfo>();
    if (!_User32.getLastInputInfo(info)) {
      throw const SystemIdleUnavailable('GetLastInputInfo failed');
    }
    final lastInput = info.ref.dwLastInputInfo;
    final now = _User32.getTickCount64();
    // The input tick is 32 bits and the uptime counter is 64, both on the same
    // clock, so the subtraction has to happen inside the narrow domain:
    // subtracting the whole 64-bit value would report a machine idle for ten
    // minutes as idle for fifty days whenever the box has been up that long.
    // A negative result means the last input landed before the counter's most
    // recent roll, which is one period earlier — not zero, and not a lie about
    // how recently anyone touched the mouse.
    var delta = (now & 0xFFFFFFFF) - lastInput;
    if (delta < 0) {
      delta += 1 << 32;
    }
    return Duration(milliseconds: delta);
  } finally {
    calloc.free(info);
  }
}

/// The read failed on a platform that claims to support it.
final class SystemIdleUnavailable implements Exception {
  /// With the reason from the operating system.
  const new(this.reason);

  /// What went wrong.
  final String reason;

  @override
  String toString() => 'SystemIdleUnavailable($reason)';
}
