import 'dart:io';

import 'package:live_platform/live_platform.dart' show PlatformRuntimeInfo;
import 'package:live_platform_path_provider/src/contracts/storage_area.dart';
import 'package:path/path.dart' as p;

/// Ordered candidate directories per storage area.
///
/// The resolver tries candidates in order and keeps the first one that
/// passes a real write probe. Implementations decide fallback order from
/// the deployment snapshot — a portable build keeps its data on its own
/// medium, an installed build never writes next to the executable.
abstract interface class StoragePolicy {
  /// The candidate directories for [area], best first. May be empty; an
  /// empty list means "no acceptable location was planned" and the
  /// resolver reports it as such.
  List<Directory> candidatesFor(StorageArea area, PlatformRuntimeInfo runtime);
}

/// The standard layout, parameterized by the host application's namespace.
///
/// No product name is spelled here: the identity a shared directory is
/// namespaced with is `appNamespace` when the caller declared one, and
/// otherwise the `appNamespace` of the runtime snapshot handed to
/// `candidatesFor` — a shell declares who it is once, the layout reads it
/// off that declaration. Every candidate is assembled with `package:path`,
/// so a separator is never hand-assembled and always matches the host
/// platform.
///
/// Root directories come from the app shell (path_provider results):
/// `portableRoot` is the executable's own directory, under which portable
/// layouts put the per-area trees; `userRoot` the OS application-support
/// directory, `cacheRoot` the OS cache directory, `tempRoot` the system
/// temporary directory, `downloadsRoot` the user-visible OS download folder.
///
/// The layout, for a host whose namespace is `ns`:
///
/// * portable persistent areas — `exe/data/ns`, `exe/config`,
///   `exe/extensions`, `exe/imports`, `exe/exports`, `exe/downloads`. Only
///   the data tree takes `ns`, because `data/` beside the executable is
///   Flutter's own bundle directory; the rest of the bundle belongs to the
///   app already.
/// * installed persistent areas — `appsupport/data`, `appsupport/config`,
///   … un-namespaced on purpose: the application-support root path_provider
///   hands back is already per-application, so repeating the identity would
///   relocate a host's existing data tree for nothing. A host pointing at a
///   genuinely shared root namespaces it deeper itself before handing it over.
/// * clearable areas — portable `exe/cache` and `exe/temp`; installed
///   `cacheRoot/ns_cache`, `tempRoot/ns_cache` and `tempRoot/ns_temp`. The
///   OS cache and the system temp directory *are* shared between
///   applications, so exactly those trees derive their names from the one
///   source `cacheDirectoryName` / `tempDirectoryName`. The storage
///   manager's last-resort scratch directories reuse the same two names,
///   which is why a degraded area cannot land somewhere else depending on
///   which tier failed.
/// * writability probes — `.ns_probe_<pid>_<count>`, from
///   `probeBaseName`.
///
/// The one hard rule: a portable build never resolves a persistent area
/// into `userRoot`/`cacheRoot` — user data follows the executable, which is
/// the entire point of the distribution. The OS temporary directory stays
/// reachable for clearable scratch only, through the manager's fallback.
final class DefaultStoragePolicy implements StoragePolicy {
  /// A policy over the five roots and the namespace they are namespaced
  /// with. Null roots are simply never offered as candidates; a null
  /// [appNamespace] defers to the runtime snapshot's, so the usual wiring
  /// declares the identity once and leaves this field unset.
  const new({this.portableRoot, this.userRoot, this.cacheRoot, this.tempRoot, this.downloadsRoot, this.appNamespace});

  /// The executable's directory (portable layouts only); the per-area
  /// segments (`data/<namespace>`, `cache/`, …) are appended beneath it.
  final Directory? portableRoot;

  /// The OS per-user application-data directory. Never offered to a
  /// portable build.
  final Directory? userRoot;

  /// The OS cache directory (installed builds only, same rule as [userRoot]).
  final Directory? cacheRoot;

  /// The system temporary directory (installed builds only).
  final Directory? tempRoot;

  /// The user-visible OS download folder. For an installed or packaged
  /// build it is the first download target; a portable build keeps its
  /// downloads in its own tree and falls back to this folder when that
  /// tree cannot host them (a read-only medium).
  final Directory? downloadsRoot;

  /// The namespace this layout writes under, overriding the runtime
  /// snapshot's. Null means "whatever the snapshot declares" — the normal
  /// case, since the shell bootstraps that declaration once. A caller that
  /// sets it (a test, a host running two identities side by side) gets
  /// trees named after its own, never the product's.
  final String? appNamespace;

  /// The namespace in force for [runtime]: the declared [appNamespace] when
  /// this policy carries one, the snapshot's otherwise. The single place
  /// that resolution happens, so a caller that must name a tree asks here
  /// instead of re-deriving the rule.
  String namespaceFor(PlatformRuntimeInfo runtime) => appNamespace ?? runtime.appNamespace;

  @override
  List<Directory> candidatesFor(StorageArea area, PlatformRuntimeInfo runtime) {
    final portable = runtime.isPortable;
    final namespace = namespaceFor(runtime);
    if (area == StorageArea.downloads) {
      // A portable build keeps its downloads in the bundle — the medium is
      // the point — and degrades to the user-visible OS folder only when the
      // bundle's tree cannot host them. An installed or packaged build never
      // writes next to its executable (Program Files, the MSIX WindowsApps
      // root), so there the OS download folder stays first and the user's
      // application-data tree is the last resort.
      final bundleTree = portable
          ? (portableRoot == null ? null : Directory(p.join(portableRoot!.path, 'downloads')))
          : null;
      final osTree = portable || userRoot == null ? null : Directory(p.join(userRoot!.path, 'downloads'));
      return portable ? [?bundleTree, ?downloadsRoot] : [?downloadsRoot, ?osTree];
    }
    final persistent = switch (area) {
      StorageArea.data ||
      StorageArea.config ||
      StorageArea.extensions ||
      StorageArea.imports ||
      StorageArea.exports ||
      StorageArea.downloads => true,
      StorageArea.cache || StorageArea.temporary => false,
    };
    if (persistent) {
      final root = portable ? portableRoot : userRoot;
      return [
        if (root != null)
          switch (area) {
            // Flutter's own Windows bundle occupies `data/` next to the
            // executable (`data/flutter_assets`, `data/icudtl.dat`), so the
            // portable data area namespaces itself beneath that directory
            // instead of writing into the runtime's files.
            StorageArea.data => portable ? portableDataRoot(root, namespace: namespace) : installedDataRoot(root),
            _ => Directory(p.join(root.path, _segment(area))),
          },
      ];
    }
    return switch (area) {
      StorageArea.cache => [
        if (portable && portableRoot != null) Directory(p.join(portableRoot!.path, 'cache')),
        if (!portable && cacheRoot != null) Directory(p.join(cacheRoot!.path, cacheDirectoryName(namespace))),
        if (!portable && tempRoot != null) Directory(p.join(tempRoot!.path, cacheDirectoryName(namespace))),
      ],
      StorageArea.temporary => [
        if (portable && portableRoot != null) Directory(p.join(portableRoot!.path, 'temp')),
        if (!portable && tempRoot != null) Directory(p.join(tempRoot!.path, tempDirectoryName(namespace))),
      ],
      _ => const [],
    };
  }

  /// The data tree a portable layout rooted beside [executableRoot]
  /// resolves to — one of the two places the `data/<namespace>` namespacing
  /// is spelled, so a diagnostic that must name the tree asks here instead
  /// of hand-assembling the segment and drifting from the policy.
  /// [namespace] defaults to this repository's own app; a host passes the
  /// identity it declared to the platform bootstrap.
  static Directory portableDataRoot(Directory executableRoot, {required String namespace}) =>
      Directory(p.join(executableRoot.path, 'data', namespace));

  /// The data tree an installed or packaged layout resolves to under its
  /// application-support root — the exact candidate [candidatesFor]
  /// answers for [StorageArea.data] on a non-portable build. Takes no
  /// namespace: the OS root is per-application already, which is the whole
  /// difference between this tree and the portable one.
  static Directory installedDataRoot(Directory userRoot) =>
      Directory(p.join(userRoot.path, _segment(StorageArea.data)));

  /// The name of the cache tree a host with [namespace] uses inside a root
  /// it shares with other applications (the OS cache directory, the system
  /// temporary directory, the manager's fallback). The one source of that
  /// name; the policy's candidates and the manager's degraded area both
  /// come from here.
  static String cacheDirectoryName(String namespace) => '${namespace}_cache';

  /// The temporary-tree counterpart of [cacheDirectoryName], spelled once
  /// for the same reason.
  static String tempDirectoryName(String namespace) => '${namespace}_temp';

  /// The base name of the writability probe file inside a tree owned by
  /// [namespace] (the caller adds the dot prefix and the process-unique
  /// suffix). Derived for the same reason as the directory names: a probe
  /// left in a shared directory must say who left it.
  static String probeBaseName(String namespace) => '${namespace}_probe';

  static String _segment(StorageArea area) => switch (area) {
    StorageArea.data => 'data',
    StorageArea.config => 'config',
    StorageArea.extensions => 'extensions',
    StorageArea.imports => 'imports',
    StorageArea.exports => 'exports',
    StorageArea.downloads => 'downloads',
    StorageArea.cache => 'cache',
    StorageArea.temporary => 'temp',
  };
}
