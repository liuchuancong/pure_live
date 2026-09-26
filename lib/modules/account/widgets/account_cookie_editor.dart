import 'dart:async';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/cookie_value.dart';

export 'package:pure_live/common/services/settings/cookie_value.dart' show normalizeAccountCookie;

/// Decoration every account-cookie input uses.
///
/// Exported because a platform with extra inputs (Douyu's renewal key and device
/// id) must render them like the cookie box: two different field styles on one
/// screen read as two different kinds of input, and the viewer cannot tell which
/// one the paste belongs in.
InputDecoration accountCookieFieldDecoration(ThemeData theme, {String? labelText, String? hintText}) {
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: width),
  );

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    hintStyle: TextStyle(color: theme.hintColor.withValues(alpha: 0.5)),
    contentPadding: const EdgeInsets.all(14),
    filled: true,
    fillColor: theme.colorScheme.surfaceContainerLowest,
    border: border(theme.dividerColor.withValues(alpha: 0.1)),
    enabledBorder: border(theme.dividerColor.withValues(alpha: 0.05)),
    focusedBorder: border(theme.colorScheme.primary, 1.5),
  );
}

class AccountCookieEditorPage extends StatefulWidget {
  const AccountCookieEditorPage({
    required this.controller,
    required this.hintText,
    required this.tipText,
    required this.onSave,
    super.key,
    this.extraFields = const <Widget>[],
    this.tipBody,
  });

  final TextEditingController controller;
  final String hintText;
  final String tipText;
  final ValueChanged<String> onSave;

  /// Extra inputs a platform needs next to the cookie itself.
  ///
  /// Douyu's renewal key and device id come from a different request than the
  /// page cookie, so they cannot be part of the pasted string and need fields of
  /// their own.
  final List<Widget> extraFields;

  /// Rich replacement for [tipText] inside the same banner.
  ///
  /// A platform whose instructions include a link or a list needs more than one
  /// string, and the banner is where a viewer looks for them.
  final Widget? tipBody;

  @override
  State<AccountCookieEditorPage> createState() => _AccountCookieEditorPageState();
}

class _AccountCookieEditorPageState extends State<AccountCookieEditorPage> {
  late String _savedCookie;
  bool _dirty = false;
  bool _confirmingDiscard = false;

  @override
  void initState() {
    super.initState();
    _savedCookie = normalizeAccountCookie(widget.controller.text);
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant AccountCookieEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleTextChanged);
    _savedCookie = normalizeAccountCookie(widget.controller.text);
    _dirty = false;
    widget.controller.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    final dirty = normalizeAccountCookie(widget.controller.text) != _savedCookie;
    if (dirty == _dirty || !mounted) return;
    setState(() => _dirty = dirty);
  }

  void _save() {
    final value = normalizeAccountCookie(widget.controller.text);
    widget.onSave(value);
    widget.controller.value = widget.controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
    setState(() {
      _savedCookie = value;
      _dirty = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(i18n('cookie_saved_local')), behavior: SnackBarBehavior.floating));
  }

  Future<void> _confirmDiscard() async {
    if (_confirmingDiscard) return;
    _confirmingDiscard = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('account-cookie-discard-dialog'),
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(i18n('discard_cookie_changes')),
        content: Text(i18n('discard_cookie_changes_detail')),
        actions: [
          TextButton(
            key: const ValueKey('account-cookie-keep-editing'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(i18n('keep_editing')),
          ),
          TextButton(
            key: const ValueKey('account-cookie-discard'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(i18n('discard'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (!mounted || discard != true) {
      _confirmingDiscard = false;
      return;
    }
    setState(() => _dirty = false);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) await Navigator.of(context).maybePop();
    _confirmingDiscard = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope<Object?>(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmDiscard());
      },
      child: Scaffold(
        appBar: AppBar(title: Text(i18n('set_cookie'))),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth < 360 ? 12.0 : 16.0;
              return ListView(
                key: const ValueKey('account-cookie-scroll'),
                physics: const PureLiveScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 32),
                children: [
                  _buildTipBanner(theme),
                  const SizedBox(height: 20),
                  context.buildGroupTitle(i18n('cookie')),
                  context.buildModernCard([
                    Padding(
                      padding: EdgeInsets.all(constraints.maxWidth < 360 ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            key: const ValueKey('account-cookie-input'),
                            minLines: 3,
                            maxLines: 7,
                            controller: widget.controller,
                            style: AppTextStyles.t14,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            autocorrect: false,
                            enableSuggestions: false,
                            smartDashesType: SmartDashesType.disabled,
                            smartQuotesType: SmartQuotesType.disabled,
                            scrollPadding: const EdgeInsets.only(bottom: 120),
                            decoration: accountCookieFieldDecoration(theme, hintText: widget.hintText),
                          ),
                          for (final field in widget.extraFields) ...<Widget>[
                            const SizedBox(height: 12),
                            field,
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            key: const ValueKey('account-cookie-save'),
                            onPressed: _save,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.save_rounded, size: 18),
                            label: Text(
                              i18n('save'),
                              textAlign: TextAlign.center,
                              style: AppTextStyles.t14.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTipBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Remix.information_line, size: 18, color: theme.colorScheme.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child:
                widget.tipBody ??
                Text(
                  widget.tipText,
                  style: AppTextStyles.t13.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }
}
