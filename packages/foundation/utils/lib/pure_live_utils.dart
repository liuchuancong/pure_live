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
/// repository. A helper that only one feature needs belongs in that feature instead. Every module below is
/// a name the repository's own measured duplication paid for - see doc/design-decisions.md for the rule and
/// doc/public-api.md for what each module answers.
library pure_live_utils;

export 'src/async/async.dart';
export 'src/collections/collections.dart';
export 'src/conversion/conversion.dart';
export 'src/equality/equality.dart';
export 'src/errors/errors.dart';
export 'src/identifiers/identifiers.dart';
export 'src/math/math.dart';
export 'src/numbers/numbers.dart';
export 'src/result/result.dart';
export 'src/result/result_extensions.dart';
export 'src/result/result_sequence.dart';
export 'src/result/result_transformers.dart';
export 'src/strings/strings.dart';
export 'src/time/time.dart';
export 'src/types/types.dart';
export 'src/validation/validation.dart';
