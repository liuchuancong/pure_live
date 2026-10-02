/// 多实例新窗口的初始设置导出接口。
///
/// Core 需要把当前设置写成临时文件交给新进程，但「设置快照包含哪些分区、哪些
/// 字段算敏感」属于 Features（features/backup 的 BackupController）。实现由 App
/// 装配层在启动时通过 [exporter] 绑定，Core 因此不反向 import Features。
typedef MultiInstanceSettingsExporter = Map<String, dynamic> Function({required bool includeSensitiveData});

abstract final class MultiInstanceSettingsSource {
  static MultiInstanceSettingsExporter? exporter;

  /// 未绑定实现时返回空快照：新窗口仍能启动，只是不带调用方的设置。
  static Map<String, dynamic> export({required bool includeSensitiveData}) {
    final current = exporter;
    if (current == null) return const <String, dynamic>{};
    return current(includeSensitiveData: includeSensitiveData);
  }
}
