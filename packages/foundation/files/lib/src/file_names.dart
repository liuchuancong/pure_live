// Module: lib/src/file_names.dart
// Purpose: Name sanitizing, collision handling and the guard that keeps a caller inside its own directory.
// Author: liuchuancong
// Created: 2026-10-08
//
// Two real hazards drive this file. Names arriving from a site or an imported playlist are attacker-
// controlled text, so they must be made safe before they touch disk. And a plugin that is handed a base
// directory plus a relative key can escape it with ../ unless someone normalises and checks - which is
// what resolveWithin does here, once, instead of in every caller that remembers to.

/// Characters that are illegal or unsafe in a file name on at least one supported platform.
final RegExp _illegalNameChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

/// Names Windows refuses regardless of extension.
const Set<String> _reservedWindowsNames = <String>{
  'CON', 'PRN', 'AUX', 'NUL',
  'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
  'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
};

/// The longest name we keep, leaving room for a collision suffix.
const int maxFileNameLength = 120;

/// Makes [candidate] usable as a single file name.
///
/// Never returns an empty string: an empty name would silently collide with every other empty name.
String sanitizeFileName(
  String candidate, {
  String fallback = 'untitled',
  int maxLength = maxFileNameLength,
}) {
  var name = candidate.replaceAll(_illegalNameChars, '').trim();
  // A leading dot would hide the file, and trailing dots and spaces are trimmed by Windows silently.
  name = name.replaceAll(RegExp(r'^\.+'), '').replaceAll(RegExp(r'[ .]+$'), '');
  if (name.isEmpty) {
    return fallback;
  }
  final dot = name.lastIndexOf('.');
  final hasExtension = dot > 0 && dot < name.length - 1;
  final stem = hasExtension ? name.substring(0, dot) : name;
  final extension = hasExtension ? name.substring(dot) : '';
  if (_reservedWindowsNames.contains(stem.toUpperCase())) {
    name = '_$stem$extension';
  }
  if (name.length <= maxLength) {
    return name;
  }
  // Truncate the stem, not the whole name, so the extension survives and the file still opens.
  final keep = maxLength - extension.length;
  if (keep <= 1) {
    return name.substring(0, maxLength);
  }
  return '${name.substring(0, keep)}$extension';
}

/// Turns an already-safe name into the next free one: `video.mp4`, `video (1).mp4`, `video (2).mp4`.
String disambiguateName(String base, bool Function(String name) exists) {
  if (!exists(base)) {
    return base;
  }
  final dot = base.lastIndexOf('.');
  final hasExtension = dot > 0 && dot < base.length - 1;
  final stem = hasExtension ? base.substring(0, dot) : base;
  final extension = hasExtension ? base.substring(dot) : '';
  for (var index = 1; index <= 1000; index++) {
    final candidate = '$stem ($index)$extension';
    if (!exists(candidate)) {
      return candidate;
    }
  }
  // Beyond 1000 collisions something is wrong; a timestamp is still better than lying about success.
  return '$stem (${DateTime.now().millisecondsSinceEpoch})$extension';
}

/// Resolves [relative] inside [directory] and refuses an escape.
///
/// Throws [StateError] when [relative] is itself absolute, or when the result would land outside
/// [directory]. That is how a zip entry named `../../config.json`, a plugin key of `../other` or a
/// `C:\windows` absolute path handed to a cache namespace is stopped.
String resolveWithin(String directory, String relative) {
  // An absolute key would silently become a nested path below the directory, which hides the caller's
  // mistake instead of reporting it.
  if (_rootOf(relative.replaceAll(_backslash, '/')).isNotEmpty) {
    throw StateError('path "$relative" must be relative to "$directory"');
  }
  final normalizedDirectory = _normalize(directory);
  final separator = normalizedDirectory.endsWith('/') ? '' : '/';
  final joined = _normalize('$normalizedDirectory$separator$relative');
  if (joined != normalizedDirectory && !joined.startsWith('$normalizedDirectory$separator')) {
    throw StateError('path "$relative" escapes its directory "$directory"');
  }
  return joined;
}

/// Collapses `.` and `..` segments without touching the file system, so the check works for a path that
/// does not exist yet.
String _normalize(String path) {
  final slashed = path.replaceAll(_backslash, '/');
  final root = _rootOf(slashed);
  final body = slashed.substring(root.length);
  final out = <String>[];
  for (final segment in body.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (out.isNotEmpty && out.last != '..') {
        out.removeLast();
      } else if (root.isEmpty) {
        out.add('..');
      }
      // Above an absolute root there is nowhere to go: the escape is caught by resolveWithin instead.
      continue;
    }
    out.add(segment);
  }
  final joined = out.join('/');
  if (root.isEmpty) {
    return joined;
  }
  if (joined.isEmpty) {
    return root;
  }
  // A POSIX root already carries its separator; a drive letter does not.
  return root.endsWith('/') ? '$root$joined' : '$root/$joined';
}

/// The volume or filesystem root of [path]: `/`, or a drive letter such as `C:`.
String _rootOf(String path) {
  if (path.startsWith(_uncPrefix)) {
    return path;
  }
  if (path.startsWith('/')) {
    return '/';
  }
  if (path.length > 1 && path[1] == ':') {
    return path.substring(0, 2);
  }
  return '';
}

/// A Windows path separator, written as an escape so the source has no literal backslash to mangle.
const String _backslash = '\u005C';

/// The prefix of a UNC path, which is one opaque root rather than a list of segments.
const String _uncPrefix = '\u005C\u005C';
