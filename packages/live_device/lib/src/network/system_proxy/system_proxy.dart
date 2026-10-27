/// What the operating system's own proxy configuration left the app with.
///
/// The distinction matters because the two consumers of a system proxy here —
/// the app's HTTP transport and mpv's `http-proxy` — both take a single
/// `http://host:port` string. A platform that names its proxy some other way
/// (a PAC script that picks an upstream per URL, or a SOCKS-only setting) is
/// therefore not "no proxy": it is a configuration the app cannot express and
/// must say so about rather than silently going direct.
enum SystemProxyStatus {
  /// An HTTP proxy the app can use, with [SystemProxyEndpoint.host] and
  /// [SystemProxyEndpoint.port] filled in.
  resolved,

  /// The platform was read successfully and names no proxy.
  notConfigured,

  /// A proxy is configured, but not as a fixed HTTP endpoint: a PAC script or
  /// a SOCKS-only setting.
  notExpressible,

  /// This platform keeps its proxy behind an API the package does not reach
  /// (a mobile system setting, or a web build with no host at all).
  unsupported,

  /// The probe itself failed: a blocked command, an unreadable key.
  failed,

  /// The first read has not landed yet; a caller shows nothing rather than a
  /// wrong "no proxy".
  probing,
}

/// A point-in-time reading of the operating system's proxy configuration.
///
/// [detail] carries what the platform actually said — a PAC URL, a SOCKS
/// setting, a command's error — for diagnostics and for the settings surface's
/// status line. It is never parsed.
final class SystemProxyEndpoint {
  /// Creates a reading.
  const new({required this.status, this.host = '', this.port = 0, this.detail = ''});

  /// No proxy is configured; the common answer on a plain desktop.
  static const notConfigured = SystemProxyEndpoint(status: SystemProxyStatus.notConfigured);

  /// What the platform's configuration amounts to.
  final SystemProxyStatus status;

  /// The proxy host, when [status] is [SystemProxyStatus.resolved].
  final String host;

  /// The proxy port, when [status] is [SystemProxyStatus.resolved].
  final int port;

  /// Diagnostic text: what the platform reported, or why the read failed.
  final String detail;

  /// Whether [host]:[port] can be handed to a proxy option.
  bool get isUsable => status == SystemProxyStatus.resolved && host.isNotEmpty && port > 0;

  /// The endpoint as `host:port`, or an empty string when there is none.
  String get authority => isUsable ? '$host:$port' : '';

  @override
  String toString() => 'SystemProxyEndpoint(${status.name}, $authority${detail.isEmpty ? '' : ', $detail'})';
}

/// System-proxy lookup support reported for the current runtime platform.
final class SystemProxyCapabilities {
  /// Creates an immutable capability description.
  const new({required this.canReadSystemProxy, required this.platformName});

  /// Whether this platform's proxy configuration can be read at all.
  final bool canReadSystemProxy;

  /// Runtime platform label for diagnostics, not intended for feature branching.
  final String platformName;
}

/// Reads the proxy the operating system itself is configured to use.
///
/// The app's own proxy setting and mpv's `http-proxy` both need an explicit
/// endpoint, and neither platform asks the system for one: ffmpeg only follows
/// `http_proxy`-style environment variables, and Dart's `HttpClient` only what
/// `findProxyFromEnvironment` sees. This service closes that gap by asking the
/// platform directly — the per-user Internet Settings on Windows, `scutil` on
/// macOS, the environment elsewhere.
abstract interface class SystemProxyService {
  /// The proxy the system names for this user, or why it names none.
  ///
  /// Never throws: a failed probe arrives as [SystemProxyStatus.failed], so a
  /// slow or blocked helper process degrades the reading rather than the
  /// caller's request path.
  Future<SystemProxyEndpoint> read();

  /// Support declared for the current runtime platform.
  Future<SystemProxyCapabilities> getCapabilities();
}
