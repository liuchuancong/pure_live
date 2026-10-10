// Module: lib/pure_live_utils.dart
// Purpose: Public barrel of pure_live_utils; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-08
///
/// Layer: foundation. Allowed dependencies: pub.dev packages only; foundation packages do not depend on
/// each other (utils and logging are leaf packages).
/// See docs/architecture/dependency-rules.md and the package README.
///
/// This package is the leaf every other package may use, so anything added here is inherited by the whole
/// repository. A helper that only one feature needs belongs in that feature instead. The five modules are
/// the whole surface on purpose - see doc/design-decisions.md for why there is no "misc" module.
library;

export 'src/async_tools/async_tools.dart';
export 'src/collections/collections.dart';
export 'src/result/result.dart';
export 'src/strings/strings.dart';
export 'src/time/time.dart';
