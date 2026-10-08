// Module: tool/check_workflow_yaml.dart
// Purpose: Parse every GitHub Actions workflow and composite action so a malformed file fails locally, not in CI.
// Author: liuchuancong
// Created: 2026-10-08
//
// Actions only reports a broken workflow after a push, which turns a five-second syntax mistake into a
// CI round trip. This check parses the same files with a real YAML parser before that happens.
//
// Usage:
//   dart run tool/check_workflow_yaml.dart
//
// Exit codes: 0 all files parse, 1 at least one file is invalid, 64 the workflows directory is missing.

import 'dart:io';

import 'package:yaml/yaml.dart';

void main(List<String> args) {
  final files = <File>[..._workflowFiles(''), ..._actionFiles('')];
  if (files.isEmpty) {
    stderr.writeln('No workflow or action files found under .github/.');
    exitCode = 64;
    return;
  }

  var failures = 0;
  for (final file in files) {
    final error = _validate(file);
    if (error == null) {
      stdout.writeln('ok ${file.path}');
      continue;
    }
    failures++;
    stdout.writeln('error ${file.path} - $error');
  }
  stdout.writeln('files=${files.length} errors=$failures');
  if (failures > 0) {
    exitCode = 1;
  }
}

List<File> _workflowFiles(String prefix) {
  final directory = Directory('$prefix.github/workflows');
  if (!directory.existsSync()) {
    return const <File>[];
  }
  return directory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.yml') || file.path.endsWith('.yaml'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

List<File> _actionFiles(String prefix) {
  final root = Directory('$prefix.github/actions');
  if (!root.existsSync()) {
    return const <File>[];
  }
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.uri.pathSegments.last == 'action.yml')
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

/// Returns null when the file parses and declares a usable top-level mapping, otherwise the reason.
String? _validate(File file) {
  try {
    final document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) {
      return 'the document is not a mapping';
    }
    if (file.path.contains('workflows') && !document.containsKey('on')) {
      // YAML reads a bare `on:` as the boolean true, which silently detaches the trigger block.
      return 'no trigger: a bare on: key is parsed as boolean true by YAML 1.1';
    }
    return null;
  } on YamlException catch (error) {
    return error.message;
  } on Object catch (error) {
    return 'cannot read the file: $error';
  }
}
