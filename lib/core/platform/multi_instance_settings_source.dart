typedef MultiInstanceSettingsExporter = Map<String, dynamic> Function({required bool includeSensitiveData});

abstract final class MultiInstanceSettingsSource {
  static MultiInstanceSettingsExporter? exporter;

  static Map<String, dynamic> export({required bool includeSensitiveData}) {
    final current = exporter;
    if (current == null) return const <String, dynamic>{};
    return current(includeSensitiveData: includeSensitiveData);
  }
}
