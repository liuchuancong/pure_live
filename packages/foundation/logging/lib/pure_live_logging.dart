// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_logging.dart
// Purpose: Public barrel of pure_live_logging; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-08
///
/// Layer: foundation. Allowed dependencies: pub.dev packages only; foundation packages do not depend on
/// each other, except that utils and logging are the leaves everyone may use.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// The app owns one LogRouter and hands Loggers out of it. Feature code never writes to stdout and never
/// installs a zone: it takes a Logger, so a test can assert on what was logged.
library;

export 'src/logger.dart';
export 'src/record.dart';
