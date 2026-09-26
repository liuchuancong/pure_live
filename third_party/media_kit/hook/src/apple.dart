import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import 'process.dart';

Object _plistValue(XmlElement element) => switch (element.name.local) {
  'array' => element.childElements.map(_plistValue).toList(),
  'dict' => _dictionary(element),
  'true' => true,
  'false' => false,
  'integer' => int.parse(element.innerText),
  _ => element.innerText,
};

Map<String, Object> _dictionary(XmlElement element) {
  final children = element.childElements.toList();
  final result = <String, Object>{};
  for (var index = 0; index < children.length; index += 2) {
    result[children[index].innerText] = _plistValue(children[index + 1]);
  }
  return result;
}

Map<String, Object> selectAppleSlice(
  String plist,
  String os,
  String architecture, {
  required bool simulator,
}) {
  final document = XmlDocument.parse(plist);
  final data =
      _plistValue(document.rootElement.childElements.single)
          as Map<String, Object>;
  final slices = (data['AvailableLibraries'] as List)
      .cast<Map<String, Object>>();
  final matches = slices.where(
    (slice) =>
        slice['SupportedPlatform'] == os &&
        (slice['SupportedArchitectures'] as List).contains(architecture) &&
        (slice['SupportedPlatformVariant'] == 'simulator') == simulator &&
        (slice['SupportedPlatformVariant'] == null ||
            slice['SupportedPlatformVariant'] == 'simulator'),
  );
  if (matches.length != 1) {
    throw StateError(
      'Expected one XCFramework slice for $os/$architecture simulator=$simulator',
    );
  }
  return matches.single;
}

Future<List<File>> prepareAppleLibraries(
  Directory extracted,
  Directory destination,
  String os,
  String architecture, {
  required bool simulator,
}) async {
  await destination.create(recursive: true);
  final files = <File>[];
  await for (final entity in extracted.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File ||
        p.basename(entity.path) != 'Info.plist' ||
        !entity.parent.path.endsWith('.xcframework')) {
      continue;
    }
    final slice = selectAppleSlice(
      await entity.readAsString(),
      os,
      architecture,
      simulator: simulator,
    );
    final library = slice['LibraryPath'] as String;
    if (!library.endsWith('.framework')) {
      throw UnsupportedError(
        'Code assets require dynamic frameworks, got $library',
      );
    }
    final name = p.basenameWithoutExtension(library);
    final source = p.join(
      entity.parent.path,
      slice['LibraryIdentifier'] as String,
      library,
      name,
    );
    final output = File(p.join(destination.path, name));
    final architectures = (await runNativeTool('xcrun', [
      'lipo',
      '-archs',
      source,
    ])).trim().split(RegExp(r'\s+'));
    if (architectures.length == 1 && architectures.single == architecture) {
      await File(source).copy(output.path);
    } else {
      await runNativeTool('xcrun', [
        'lipo',
        source,
        '-thin',
        architecture,
        '-output',
        output.path,
      ]);
    }
    files.add(output);
  }
  if (files.where((file) => p.basename(file.path) == 'Mpv').length != 1) {
    throw StateError('The native bundle does not contain one Mpv framework');
  }
  // Dart loads flat libraries; Flutter repackages them using these install IDs.
  final installNames = <String, String>{};
  for (final file in files) {
    final lines = const LineSplitter().convert(
      await runNativeTool('xcrun', ['otool', '-D', file.path]),
    );
    for (final id in lines.skip(1).map((line) => line.trim())) {
      if (id.isNotEmpty) {
        installNames[id] = '@loader_path/${p.basename(file.path)}';
      }
    }
  }
  for (final file in files) {
    final dependencies = await runNativeTool('xcrun', [
      'otool',
      '-L',
      file.path,
    ]);
    await runNativeTool('xcrun', [
      'install_name_tool',
      '-id',
      '@loader_path/${p.basename(file.path)}',
      for (final entry in installNames.entries)
        if (dependencies.contains('${entry.key} (')) ...[
          '-change',
          entry.key,
          entry.value,
        ],
      file.path,
    ]);
    // Modified arm64 Mach-O files need a signature before Dart can load them.
    await runNativeTool('codesign', ['--force', '--sign', '-', file.path]);
  }
  return files..sort((a, b) => a.path.compareTo(b.path));
}
