import 'package:pure_live/core/index.dart';

class AppPromptDialogs {
  static Future<bool> showAlertDialog(
    String content, {
    String title = '',
    String confirm = '',
    String cancel = '',
    bool selectable = false,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) async {
    final result = await Get.dialog<bool>(
      _SharedAlertDialog(
        title: title,
        content: content,
        selectable: selectable,
        cancel: cancel,
        confirm: confirm,
        additionalActions: actions,
      ),
      barrierDismissible: barrierDismissible,
    );
    return result ?? false;
  }

  static Future<String?> showEditTextDialog(
    String content, {
    String title = '',
    String? hintText,
    String confirm = '',
    String cancel = '',
  }) async {
    return Get.dialog<String>(
      _EditTextDialog(initialValue: content, title: title, hintText: hintText, confirm: confirm, cancel: cancel),
    );
  }

  static Future<T?> showOptionDialog<T>(List<T> contents, T value, {String title = ''}) async {
    return Get.dialog<T>(_OptionDialog<T>(contents: contents, selectedValue: value, title: title));
  }
}

class _SharedAlertDialog extends StatelessWidget {
  const _SharedAlertDialog({
    required this.title,
    required this.content,
    required this.selectable,
    required this.confirm,
    this.cancel,
    this.additionalActions,
  });

  final String title;
  final String content;
  final bool selectable;
  final String confirm;
  final String? cancel;
  final List<Widget>? additionalActions;

  @override
  Widget build(BuildContext context) {
    final actionWidgets = <Widget>[
      if (cancel != null)
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancel!.isEmpty ? i18n("cancel") : cancel!),
        ),
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: () => Navigator.of(context).pop(true),
        child: Text(confirm.isEmpty ? i18n("confirm") : confirm),
      ),
      ...?additionalActions,
    ];

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      title: title.isEmpty ? null : Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: selectable ? SelectableText(content) : Text(content),
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
      actions: actionWidgets,
    );
  }
}

class _OptionDialog<T> extends StatelessWidget {
  const _OptionDialog({required this.contents, required this.selectedValue, required this.title});

  final List<T> contents;
  final T selectedValue;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    void select(T? value) {
      if (value != null) {
        Navigator.of(context).pop(value);
      }
    }

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      title: title.isEmpty ? null : Text(title),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: RadioGroup<T>(
          groupValue: selectedValue,
          onChanged: select,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < contents.length; index++)
                SimpleDialogOption(
                  key: ValueKey<String>('shared-option-$index'),
                  padding: EdgeInsets.zero,
                  onPressed: () => select(contents[index]),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Radio<T>(value: contents[index], activeColor: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(contents[index].toString(), style: theme.textTheme.bodyLarge, softWrap: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditTextDialog extends StatefulWidget {
  const _EditTextDialog({
    required this.initialValue,
    required this.title,
    required this.hintText,
    required this.confirm,
    required this.cancel,
  });

  final String initialValue;
  final String title;
  final String? hintText;
  final String confirm;
  final String cancel;

  @override
  State<_EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<_EditTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height;
    final dialogHeight = availableHeight > 40 ? availableHeight - 40 : availableHeight;
    final largeText = media.textScaler.scale(1) >= 1.6;
    final stackActions = media.size.width < 420 || largeText;
    final cancelButton = TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => Navigator.of(context).pop(),
      child: Text(widget.cancel.isNotEmpty ? widget.cancel : i18n("cancel")),
    );
    final confirmButton = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => Navigator.of(context).pop(_controller.text),
      child: Text(widget.confirm.isNotEmpty ? widget.confirm : i18n("confirm")),
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 468, maxHeight: dialogHeight),
        child: SizedBox(
          width: 468,
          height: largeText ? dialogHeight : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                fit: largeText ? FlexFit.tight : FlexFit.loose,
                child: SingleChildScrollView(
                  key: const ValueKey<String>('shared-edit-text-scroll'),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _controller,
                        autofocus: true,
                        maxLines: 5,
                        minLines: 4,
                        style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', fontSize: 13, height: 1.5),
                        decoration: InputDecoration(
                          hintText: widget.hintText ?? widget.title,
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: stackActions
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [cancelButton, const SizedBox(height: 8), confirmButton],
                        )
                      : Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [cancelButton, confirmButton],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
