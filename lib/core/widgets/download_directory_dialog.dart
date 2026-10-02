import 'package:pure_live/common/index.dart';

/// User answer to the download-directory prompt shown before an app update
/// starts downloading.
enum DownloadDirectoryChoice {
  /// Open the system directory picker and remember the selected folder.
  pickCustom,

  /// Keep downloading into the platform default folder.
  useDefault,
}

/// Asks where app updates, downloaded files and fonts should be stored.
///
/// Returns `null` when the user dismisses the prompt; the caller must then
/// leave the download untouched.
Future<DownloadDirectoryChoice?> showDownloadDirectoryChoiceDialog({String? defaultDirectoryPath}) {
  final normalizedDefault = defaultDirectoryPath?.trim() ?? '';

  return Get.dialog<DownloadDirectoryChoice>(
    barrierDismissible: false,
    AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      title: Text(i18n('download_directory_prompt_title')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Builder(
          builder: (contentContext) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i18n('download_directory_prompt_message')),
              if (normalizedDefault.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  i18n('download_directory_default_path', args: {'path': normalizedDefault}),
                  style: Theme.of(contentContext).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(contentContext).hintColor),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          key: const ValueKey('download-directory-use-default'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(Get.context!, rootNavigator: true).pop(DownloadDirectoryChoice.useDefault),
          child: Text(i18n('download_directory_use_default'), textAlign: TextAlign.center),
        ),
        FilledButton(
          key: const ValueKey('download-directory-pick'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(Get.context!, rootNavigator: true).pop(DownloadDirectoryChoice.pickCustom),
          child: Text(i18n('download_directory_choose'), textAlign: TextAlign.center),
        ),
      ],
    ),
  );
}
