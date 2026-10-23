import 'package:envied/envied.dart';

part 'env.g.dart';

/// The machine-local build configuration, read from `.env` at generation
/// time and compiled into the binary.
///
/// `.env` is not committed — [.env.example](../../../../.env.example) is
/// the template every field is named in. Values are baked in by
/// `build_runner`, so changing one means regenerating
/// (`dart run build_runner build`), not restarting: a running binary
/// carries the values it was generated with.
///
/// Every field here is optional. A developer working from a bare clone has
/// no `.env` at all, and that is a supported build: the app takes the
/// platform's own answer for anything unset rather than failing to
/// compile.
@Envied(path: '.env', allowOptionalFields: true)
abstract class Env {
  /// Where a diagnostic run keeps its data — the directory storage, the
  /// debug database and logs are rooted in, instead of the OS
  /// application-support directory.
  ///
  /// Set it for a local run that must not touch the installed app's files;
  /// the tree it names is `.run-data/` in a normal working checkout, which
  /// git ignores.
  @EnviedField(varName: 'PURE_LIVE_DATA_DIR')
  static const String? dataDir = _Env.dataDir;

  /// The proxy every site request is routed through, as `http://host:port`.
  ///
  /// Unset means the network layer decides on its own — the process
  /// `HTTP_PROXY`/`HTTPS_PROXY` environment is still honoured by
  /// `live_net`'s system route, so this is only for a build that must
  /// override it.
  @EnviedField(varName: 'PURE_LIVE_PROXY')
  static const Uri? proxy = _Env.proxy;

  /// Whether this build targets the ten-foot form factor.
  ///
  /// A TV is a different composition, not a wider window: the shell drops
  /// the sidebar, focus is the only pointer, and the layout scale rises. It
  /// is declared, never inferred from `Platform.isAndroid` — a phone
  /// misread as a TV yields an interface nobody can operate without a
  /// remote.
  @EnviedField(varName: 'PURE_LIVE_TV', defaultValue: false)
  static const bool isTv = _Env.isTv;

  /// Forces this build to resolve as a portable deployment: every storage
  /// area roots beside the executable instead of the OS directories.
  ///
  /// Unset keeps the trust chain honest — a `flutter run` debug exe stays
  /// an "unknown" deployment. Set `PURE_LIVE_PORTABLE=true` only for a
  /// build you actually ship as a zip.
  @EnviedField(varName: 'PURE_LIVE_PORTABLE', defaultValue: false)
  static const bool isPortable = _Env.isPortable;
}
