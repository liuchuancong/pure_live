// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_design.dart
// Purpose: Public barrel of pure_live_design; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-10
///
/// Layer: ui. Design tokens and persisted appearance configuration: numbers
/// and names, never concrete colors - the active style builds the scheme.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// This package is pure Dart on purpose: a surface that needs a BuildContext to read a spacing step cannot
/// be tested without one, and the whole point of the token set is that the numbers are agreed in advance.
/// What a style adapter receives is a resolved [DesignTokens], never a per-platform guess.
library;

export 'src/control_metrics.dart';
export 'src/design_tokens.dart';
export 'src/scale_tokens.dart';
export 'src/semantic_roles.dart';
