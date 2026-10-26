import 'package:live_shell/live_shell.dart';

/// One live window, as the process knows it.
///
/// The plugin owns the id; the registry only records what the app asked the
/// window to be. A closed window is removed by the lifecycle observer, so a
/// stale id never answers a lookup.
final class DesktopWindowRecord {
  /// A record for [viewId].
  const new({required this.viewId, required this.role, required this.openedAt, this.businessKey, this.route});

  /// The plugin's public view id.
  final int viewId;

  /// What the window is for.
  final WindowRole role;

  /// The stable business identity, for example `bilibili/12345`.
  final String? businessKey;

  /// The route it was opened at.
  final String? route;

  /// When it was opened, for diagnostics and the newest-first reuse policy.
  final DateTime openedAt;

  @override
  String toString() => 'DesktopWindowRecord(view=$viewId, role=${role.name}, key=$businessKey, route=$route)';
}

/// The process's live window table.
///
/// Not persistent: ids are runtime handles, never business identifiers. The
/// app composes one registry and every window service/observer shares it.
final class DesktopWindowRegistry {
  final Map<int, DesktopWindowRecord> _byId = {};

  /// Every live window, newest last.
  List<DesktopWindowRecord> get records => List<DesktopWindowRecord>.unmodifiable(_byId.values);

  /// The record for [viewId], or null when the window is gone.
  DesktopWindowRecord? byId(int viewId) => _byId[viewId];

  /// The newest window with [businessKey], or null.
  DesktopWindowRecord? byBusinessKey(String businessKey) {
    DesktopWindowRecord? found;
    for (final record in _byId.values) {
      if (record.businessKey == businessKey) found = record;
    }
    return found;
  }

  /// Records a window. Re-registering an id replaces the old record.
  void add(DesktopWindowRecord record) => _byId[record.viewId] = record;

  /// Forgets a window that closed.
  void remove(int viewId) => _byId.remove(viewId);

  /// Forgets every window, used by the quit path.
  void clear() => _byId.clear();
}
