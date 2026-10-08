// Module: tool/check_architecture.dart
// Purpose: Mechanically enforce the v2 package layout and dependency direction from docs/architecture.
// Author: liuchuancong
// Created: 2026-10-08
//
// This is the guard required by docs/roadmap/milestones.md milestone M1. It replaces the v1
// tool/validate_architecture.py, which still checks the retired lib/app -> core -> domains layout.
//
// Usage:
//   dart run tool/check_architecture.dart            # check the whole repository
//   dart run tool/check_architecture.dart --strict   # also fail on warnings
//   dart run tool/check_architecture.dart --root X   # check another tree (used by the tests)
//
// Exit codes: 0 clean, 1 violations found, 64 the repository cannot be read.

import 'dart:io';

import 'package:yaml/yaml.dart';

/// Layers in dependency order; the application shell is not a layer, it is the composition root.
const List<String> kLayers = <String>[
  'foundation',
  'integrations',
  'ecosystem',
  'services',
  'ui',
  'features',
  'providers',
];

/// Foundation packages everyone may depend on.
///
/// docs/architecture/dependency-rules.md section 3 says L0 packages do not depend on each other, and names
/// utils and logging as the exception: they are the leaves every other package may use.
const Set<String> kLeafPackages = <String>{'pure_live_utils', 'pure_live_logging'};

/// The shared model umbrella every layer above L0 may depend on.
///
/// docs/contracts/platform-models.md section 18 makes pure_live_platform the single home of the contract
/// and model types, so an ecosystem, services, ui, features or providers package has to reach it; that is
/// a downward edge to shared vocabulary, not a cycle between siblings.
const Set<String> kSharedModelPackages = <String>{'pure_live_platform'};

/// Layers a package of the given layer may depend on, from docs/architecture/dependency-rules.md section 3.
const Map<String, Set<String>> kAllowedLayers = <String, Set<String>>{
  'foundation': <String>{},
  'integrations': <String>{'foundation'},
  'ecosystem': <String>{'foundation'},
  'services': <String>{'foundation', 'ecosystem'},
  'ui': <String>{'foundation', 'ecosystem', 'ui'},
  'features': <String>{'foundation', 'ecosystem', 'services', 'ui', 'features'},
  'providers': <String>{'foundation', 'ecosystem'},
};

/// Documented same-layer and upward exceptions from dependency-rules.md section 4.
/// Key is the depending package, value the set of packages it may additionally depend on.
const Map<String, Set<String>> kApprovedExceptions = <String, Set<String>>{
  'pure_live_danmaku': <String>{'pure_live_media'},
  'pure_live_background': <String>{'pure_live_media'},
  'pure_live_sync': <String>{'pure_live_firebase'},
  'pure_live_backup': <String>{'pure_live_auth'},
  'pure_live_player_ui': <String>{'pure_live_media'},
  'pure_live_ui_kit': <String>{'pure_live_design'},
  // ADR 0017: an external ecosystem runtime must sit on the embedded CPython host.
  'pure_live_external_tvbox': <String>{'pure_live_python_runtime'},
};

/// A package discovered on disk, with the dependencies declared in its pubspec.
class PackageInfo {
  PackageInfo({
    required this.name,
    required this.relativePath,
    required this.layer,
    required this.domain,
    required this.dependencies,
  });

  final String name;
  final String relativePath;

  /// Layer directory, or `app` for the composition root.
  final String layer;

  /// Feature or provider grouping directory, empty when the package sits directly under its layer.
  final String domain;
  final Set<String> dependencies;

  bool get isApplication => layer == 'app';
}

/// One rule violation or warning found by a check.
class Finding {
  Finding(this.rule, this.subject, this.detail, {this.isWarning = false});

  final String rule;
  final String subject;
  final String detail;
  final bool isWarning;
}

void main(List<String> args) {
  final strict = args.contains('--strict');
  final root = Directory(rootArgument(args) ?? Directory.current.path);

  final List<String> members;
  try {
    members = readWorkspaceMembers(root);
  } on Object catch (error) {
    stderr.writeln('Cannot read the workspace root pubspec.yaml: $error');
    exitCode = 64;
    return;
  }

  final packages = <String, PackageInfo>{};
  final findings = <Finding>[];
  findings.addAll(checkRegistration(root, members, packages));
  for (final path in members) {
    final package = loadPackage(root, path);
    if (package == null) {
      findings.add(Finding('missing-package', path, 'listed in workspace: but no pubspec.yaml was found'));
      continue;
    }
    packages[package.name] = package;
  }

  for (final package in packages.values) {
    if (package.isApplication) {
      continue;
    }
    findings.addAll(checkLayout(root, package));
    findings.addAll(checkDependencies(package, packages));
    findings.addAll(checkImports(root, package));
  }

  final errors = findings.where((finding) => !finding.isWarning).toList();
  final warnings = findings.where((finding) => finding.isWarning).toList();
  for (final finding in findings) {
    final label = finding.isWarning ? 'warn' : 'error';
    stdout.writeln('$label ${finding.rule}: ${finding.subject} - ${finding.detail}');
  }
  stdout.writeln('packages=${packages.length} errors=${errors.length} warnings=${warnings.length}');
  if (errors.isNotEmpty || (strict && warnings.isNotEmpty)) {
    exitCode = 1;
  }
}

/// `--root <path>` lets the test harness point the guard at a fixture tree.
String? rootArgument(List<String> args) {
  final index = args.indexOf('--root');
  if (index < 0) {
    return null;
  }
  if (index + 1 >= args.length) {
    throw const FormatException('--root requires a path');
  }
  return args[index + 1];
}

/// Reads the `workspace:` list from the repository root pubspec.
List<String> readWorkspaceMembers(Directory root) {
  final text = File('${root.path}/pubspec.yaml').readAsStringSync();
  final document = loadYaml(text);
  final members = (document as YamlMap)['workspace'];
  if (members is! YamlList) {
    throw const FormatException('the root pubspec has no workspace: list');
  }
  return members.map((item) => item.toString()).toList();
}

/// Loads one member package, or null when the directory holds no readable pubspec.
PackageInfo? loadPackage(Directory root, String relativePath) {
  final file = File('${root.path}/$relativePath/pubspec.yaml');
  if (!file.existsSync()) {
    return null;
  }
  final document = loadYaml(file.readAsStringSync()) as YamlMap;
  final name = document['name'].toString();
  final dependencies = <String>{};
  final declared = document['dependencies'];
  if (declared is YamlMap) {
    dependencies.addAll(declared.keys.map((key) => key.toString()));
  }
  return PackageInfo(
    name: name,
    relativePath: relativePath,
    layer: layerOf(relativePath),
    domain: domainOf(relativePath),
    dependencies: dependencies,
  );
}

/// `packages/<layer>/...` for packages, `apps/pure_live` for the composition root.
String layerOf(String relativePath) {
  final segments = relativePath.split('/');
  if (segments.first == 'apps') {
    return 'app';
  }
  return segments.length > 1 ? segments[1] : 'unknown';
}

/// The grouping directory inside a layer, e.g. `live` for packages/features/live/repository.
String domainOf(String relativePath) {
  final segments = relativePath.split('/');
  return segments.length > 3 ? segments[2] : '';
}

/// Reports members on disk that the root does not list, and listed members that are gone.
List<Finding> checkRegistration(Directory root, List<String> members, Map<String, PackageInfo> packages) {
  final findings = <Finding>[];
  final listed = members.toSet();
  for (final layer in kLayers) {
    final directory = Directory('${root.path}/packages/$layer');
    if (!directory.existsSync()) {
      continue;
    }
    for (final entry in directory.listSync(recursive: true)) {
      if (entry is! File || entry.uri.pathSegments.last != 'pubspec.yaml') {
        continue;
      }
      final relative = entry.path.substring(root.path.length + 1).replaceAll(r'\', '/').split('/pubspec.yaml').first;
      if (!listed.contains(relative)) {
        findings.add(Finding('unregistered-package', relative, 'exists on disk but is missing from workspace:'));
      }
    }
  }
  return findings;
}

/// Files and directories every package must own, from package-architecture.md section 2.
List<Finding> checkLayout(Directory root, PackageInfo package) {
  final findings = <Finding>[];
  final expected = <String>[
    'pubspec.yaml',
    'README.md',
    'CHANGELOG.md',
    'analysis_options.yaml',
    'lib/${package.name}.dart',
  ];
  for (final relative in expected) {
    if (!FileSystemEntity.isFileSync('${root.path}/${package.relativePath}/$relative')) {
      findings.add(Finding('missing-file', package.relativePath, '$relative is required for every package'));
    }
  }
  if (!FileSystemEntity.isDirectorySync('${root.path}/${package.relativePath}/test')) {
    findings.add(Finding('missing-file', package.relativePath, 'test/ is required for every package'));
  }
  for (final directory in internalLayout(package)) {
    if (!FileSystemEntity.isDirectorySync('${root.path}/${package.relativePath}/$directory')) {
      findings.add(
        Finding('layout-drift', package.relativePath, '$directory/ is required for the ${package.layer} layer'),
      );
    }
  }
  final include = File('${root.path}/${package.relativePath}/analysis_options.yaml').readAsStringSync();
  final expectedInclude = '${'../' * package.relativePath.split('/').length}analysis_options.package.yaml';
  if (!include.contains('include: $expectedInclude')) {
    findings.add(
      Finding('analyzer-drift', package.relativePath, 'analysis_options.yaml must include $expectedInclude'),
    );
  }
  for (final marker in _staleSkeletonMarkers(root, package)) {
    findings.add(
      Finding('stale-scaffold-marker', marker, 'a .gitkeep only belongs in a directory that is otherwise empty'),
    );
  }
  return findings;
}

/// Skeleton markers left behind in directories that now hold real files.
List<String> _staleSkeletonMarkers(Directory root, PackageInfo package) {
  final found = <String>[];
  for (final area in <String>['lib', 'test']) {
    final directory = Directory('${root.path}/${package.relativePath}/$area');
    if (!directory.existsSync()) {
      continue;
    }
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.gitkeep')) {
        continue;
      }
      final parent = Directory(entity.path.substring(0, entity.path.length - '.gitkeep'.length));
      if (parent.existsSync() && parent.listSync().length > 1) {
        found.add(entity.path.substring(root.path.length + 1).replaceAll('\\', '/'));
      }
    }
  }
  return found;
}

/// The per-layer internal directory template from package-architecture.md section 2.
List<String> internalLayout(PackageInfo package) => switch (package.layer) {
  'features' => const <String>['lib/src/data', 'lib/src/domain', 'lib/src/presentation'],
  'providers' => const <String>['lib/src/models', 'fixtures'],
  _ => const <String>['lib/src'],
};

/// Enforces the dependency direction between layers, plus the approved exception table.
List<Finding> checkDependencies(PackageInfo package, Map<String, PackageInfo> byName) {
  final findings = <Finding>[];
  final allowed = kAllowedLayers[package.layer] ?? const <String>{};
  for (final dependency in package.dependencies) {
    if (dependency == 'pure_live') {
      findings.add(
        Finding(
          'depend-on-app',
          package.name,
          'only the composition root may be depended on, never the app itself (I9)',
        ),
      );
      continue;
    }
    if (!dependency.startsWith('pure_live_')) {
      continue;
    }
    final target = byName[dependency];
    if (target == null) {
      findings.add(
        Finding('unknown-dependency', package.name, 'depends on $dependency which is not a workspace member'),
      );
      continue;
    }
    if (allowed.contains(target.layer)) {
      continue;
    }
    if (kLeafPackages.contains(target.name)) {
      continue;
    }
    if (kSharedModelPackages.contains(target.name) && package.layer != 'foundation') {
      continue;
    }
    if (isApprovedException(package, target)) {
      continue;
    }
    findings.add(
      Finding('layer-direction', package.name, '${package.layer} may not depend on ${target.layer} ($dependency)'),
    );
  }
  return findings;
}

bool isApprovedException(PackageInfo package, PackageInfo target) {
  if (kApprovedExceptions[package.name]?.contains(target.name) ?? false) {
    return true;
  }
  if (package.layer != 'features' || target.layer != 'features') {
    return false;
  }
  // A feature UI package may use its own domain repository; other same-layer edges stay forbidden.
  return package.domain == target.domain &&
      package.relativePath.endsWith('/ui') &&
      target.relativePath.endsWith('/repository');
}

/// Source-level rules that a pubspec cannot express, from dependency-rules.md sections 5 and 6.
List<Finding> checkImports(Directory root, PackageInfo package) {
  final findings = <Finding>[];
  final lib = Directory('${root.path}/${package.relativePath}/lib');
  if (!lib.existsSync()) {
    return findings;
  }
  for (final entry in lib.listSync(recursive: true)) {
    if (entry is! File || !entry.path.endsWith('.dart')) {
      continue;
    }
    final relative = entry.path.substring(root.path.length + 1).replaceAll(r'\', '/');
    for (final line in entry.readAsLinesSync()) {
      final import = Uri.tryParse(_importTarget(line) ?? '');
      if (import == null || import.scheme != 'package') {
        continue;
      }
      final target = import.path.split('/').first;
      findings.addAll(checkImportedPackage(package, relative, target));
    }
  }
  return findings;
}

String? _importTarget(String line) {
  final match = RegExp("^import\\s+'([^']+)'").firstMatch(line.trim());
  return match?.group(1);
}

List<Finding> checkImportedPackage(PackageInfo package, String file, String target) {
  if (target == 'pure_live') {
    return <Finding>[Finding('import-app', file, 'imports the application shell (I9)')];
  }
  if (target == 'fluttersdk_wind' && package.name != 'pure_live_ui_kit') {
    return <Finding>[Finding('import-wind', file, 'only ui_kit may import fluttersdk_wind')];
  }
  if (package.layer == 'providers' && (target == 'media_core' || target.startsWith('media_core_'))) {
    return <Finding>[Finding('provider-touches-player', file, 'providers must not reach the player (I1 and I5)')];
  }
  return const <Finding>[];
}
