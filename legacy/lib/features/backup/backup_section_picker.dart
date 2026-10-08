import 'package:pure_live/core/index.dart';

enum BackupSectionDirection { export, import }

String backupSectionLabel(String name) => i18n('backup_section_$name');

Future<List<String>?> pickBackupSections({
  required BackupSectionDirection direction,
  required List<String> available,
  Set<String>? initiallySelected,
}) {
  if (available.isEmpty) return Future<List<String>?>.value(const <String>[]);
  final opened = Get.to<List<String>>(
    () => BackupSectionPickerPage(direction: direction, available: available, initiallySelected: initiallySelected),
  );
  if (opened == null) return Future<List<String>?>.value(null);
  return opened;
}

class BackupSectionPickerPage extends StatefulWidget {
  const BackupSectionPickerPage({super.key, required this.direction, required this.available, this.initiallySelected});

  final BackupSectionDirection direction;
  final List<String> available;
  final Set<String>? initiallySelected;

  @override
  State<BackupSectionPickerPage> createState() => _BackupSectionPickerPageState();
}

class _BackupSectionPickerPageState extends State<BackupSectionPickerPage> {
  late final Set<String> _selected = {...(widget.initiallySelected ?? widget.available)};

  bool get _isExport => widget.direction == BackupSectionDirection.export;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allSelected = _selected.length == widget.available.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n(_isExport ? 'backup_section_pick_export' : 'backup_section_pick_import')),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              if (allSelected) {
                _selected.clear();
              } else {
                _selected
                  ..clear()
                  ..addAll(widget.available);
              }
            }),
            child: Text(i18n(allSelected ? 'backup_section_clear_all' : 'backup_section_select_all')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Text(
            i18n(_isExport ? 'backup_section_export_hint' : 'backup_section_import_hint'),
            style: AppTextStyles.t13.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final name in widget.available)
                  CheckboxListTile(
                    key: ValueKey('backup-section-$name'),
                    dense: false,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(backupSectionLabel(name)),
                    subtitle: Text(name, style: AppTextStyles.t12.copyWith(color: theme.hintColor)),
                    value: _selected.contains(name),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _selected.add(name);
                      } else {
                        _selected.remove(name);
                      }
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
      bottomNavigationBar: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('backup-section-confirm'),
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(Get.context!).pop(_selected.toList(growable: false)),
              child: Text(i18n('confirm')),
            ),
          ),
        ),
      ),
    );
  }
}
