import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show KeyEvent, KeyUpEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;

import 'package:pure_live/app/app.dart';

/// A text field with a remote in the room: the field reads as one run of
/// text until the viewer presses OK on it, and only then becomes a real
/// editing field.
///
/// The two shapes exist because a live TextField under the focus eats the
/// arrow keys for caret moves — the remote could no longer leave the field
/// — and because Flutter's text input channel does not summon the soft
/// keyboard on many Android TV boxes (flutter#154924). One look, two
/// backends: this widget shows the text display and the editing field, the
/// way the reference does. On a TV build running Android, editing can open
/// without a keyboard to type on until the native text field plugin lands
/// (pending a separate decision); on every other surface the edit step is
/// the ordinary IME path. A multi-line field leaves editing through Escape
/// only — Enter adds a line, and the page's own action submits.
///
/// Off a TV build this is [DsTextField] itself.
final class TvInputField extends ConsumerStatefulWidget {
  /// Builds the field around [controller].
  const TvInputField({
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.placeholder,
    this.minLines = 1,
    this.maxLines = 1,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// The text the field holds and edits; null lets the field own its text
  /// (a picker filter that only reports changes).
  final TextEditingController? controller;

  /// Reports every change while editing.
  final ValueChanged<String>? onChanged;

  /// Runs when a single-line editing field submits; editing then closes.
  final ValueChanged<String>? onSubmitted;

  /// The display's hint while the field is empty.
  final String? placeholder;

  /// The editing field's line measure.
  final int minLines;
  final int maxLines;

  /// What screen readers call the display.
  final String? semanticLabel;

  /// The display's focus stop, when the caller owns one (a page shell's
  /// opening claim names it).
  final FocusNode? focusNode;

  /// Takes the keyboard when the page opens, so a page whose whole job is
  /// one field needs no extra walk.
  final bool autofocus;

  @override
  ConsumerState<TvInputField> createState() => _TvInputFieldState();
}

final class _TvInputFieldState extends ConsumerState<TvInputField> {
  late final FocusNode _displayNode = FocusNode(debugLabel: 'tv input display');
  late final FocusNode _editNode = FocusNode(debugLabel: 'tv input edit');
  late final TextEditingController _own = widget.controller ?? TextEditingController();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    // The display is a Text, not a field: something else writing the
    // controller (a clipboard offer, a form reset) must still show up.
    _own.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted && !_editing) setState(() {});
  }

  @override
  void dispose() {
    _own.removeListener(_onControllerChanged);
    _displayNode.dispose();
    _editNode.dispose();
    super.dispose();
  }

  /// The select keys — the dpad key set's select side, plus the
  /// control-left/right quirk some remotes send in place of OK.
  static bool _isSelect(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.gameButtonA ||
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight;

  KeyEventResult _onDisplayKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !_isSelect(event.logicalKey)) return KeyEventResult.ignored;
    setState(() => _editing = true);
    return KeyEventResult.handled;
  }

  void _stopEditing() {
    if (!_editing) return;
    setState(() => _editing = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _displayNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tv = ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv;
    final multiline = widget.maxLines > 1;
    if (!tv) {
      if (!multiline) {
        return DsTextField(
          controller: _own,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          placeholder: widget.placeholder,
          semanticLabel: widget.semanticLabel,
          focusNode: widget.focusNode,
        );
      }
      return DsTextField.multiline(
        controller: _own,
        onChanged: widget.onChanged,
        placeholder: widget.placeholder,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        semanticLabel: widget.semanticLabel,
      );
    }
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    if (!_editing) {
      return Focus(
        focusNode: widget.focusNode ?? _displayNode,
        autofocus: widget.autofocus,
        onKeyEvent: _onDisplayKey,
        child: GestureDetector(
          onTap: () => setState(() => _editing = true),
          child: Container(
            constraints: BoxConstraints(minHeight: widget.minLines * 24 + DsSpace.s16),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s8),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border),
              borderRadius: theme.radii.controlCorners(null, 40),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              _own.text.isEmpty ? (widget.placeholder ?? '') : _own.text,
              maxLines: widget.maxLines,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.copyWith(color: _own.text.isEmpty ? colors.textSubtle : colors.text),
            ),
          ),
        ),
      );
    }
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyUpEvent &&
            (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.goBack)) {
          _stopEditing();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: multiline
          ? DsTextField.multiline(
              key: const ValueKey('tv-input-editing'),
              controller: _own,
              focusNode: _editNode,
              autofocus: true,
              onChanged: widget.onChanged,
              placeholder: widget.placeholder,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              semanticLabel: widget.semanticLabel,
            )
          : DsTextField(
              key: const ValueKey('tv-input-editing'),
              controller: _own,
              focusNode: _editNode,
              autofocus: true,
              onChanged: widget.onChanged,
              onSubmitted: (text) {
                widget.onSubmitted?.call(text);
                _stopEditing();
              },
              placeholder: widget.placeholder,
              semanticLabel: widget.semanticLabel,
            ),
    );
  }
}
