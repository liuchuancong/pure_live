import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show XtreamAccount;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_import_flow.dart';

/// The inputs an import page owns: its text controllers, what the clipboard
/// held when the page opened, and the actions that need the page's context
/// (a file picker, the phone bridge).
final class IptvImportInputs {
  /// The page's inputs.
  const new({
    required this.link,
    required this.text,
    required this.xtreamServer,
    required this.xtreamUser,
    required this.xtreamPassword,
    required this.onPreview,
    required this.onPickFile,
    required this.onXtreamPreview,
    required this.onXtreamCheck,
    this.clipboard,
    this.onUseClipboard,
    this.onPhone,
  });

  /// The address field.
  final TextEditingController link;

  /// The pasted-list field.
  final TextEditingController text;

  /// The Xtream panel address.
  final TextEditingController xtreamServer;

  /// The Xtream user name.
  final TextEditingController xtreamUser;

  /// The Xtream password.
  final TextEditingController xtreamPassword;

  /// Previews the link or the text, whichever origin is open.
  final VoidCallback onPreview;

  /// Picks a file and previews it.
  final VoidCallback onPickFile;

  /// Previews the Xtream account's live list.
  final VoidCallback onXtreamPreview;

  /// Asks the Xtream panel about the account.
  final VoidCallback onXtreamCheck;

  /// A link or a list the clipboard held, worth offering.
  final String? clipboard;

  /// Fills the clipboard's content in.
  final VoidCallback? onUseClipboard;

  /// Opens the phone form; null where there is no phone bridge.
  final VoidCallback? onPhone;
}

/// The origins [kind] offers, in the order the page lists them.
List<IptvImportOrigin> iptvImportOrigins(IptvImportKind kind, {required bool phone}) => switch (kind) {
  IptvImportKind.playlist => [
    if (phone) IptvImportOrigin.scan,
    IptvImportOrigin.link,
    IptvImportOrigin.file,
    IptvImportOrigin.text,
    IptvImportOrigin.xtream,
  ],
  IptvImportKind.guide => [IptvImportOrigin.link, IptvImportOrigin.file],
};

/// The source half of the import page: where the import reads from and the
/// fields that origin needs.
///
/// A wide page lists the origins as rows with a line about each, beside the
/// preview; a narrow one puts them on a strip over the fields, the house
/// rule for a choice between more than two places.
final class IptvImportSourcePane extends ConsumerWidget {
  /// The pane over [inputs]; [rail] lists the origins as rows.
  const IptvImportSourcePane({required this.inputs, required this.rail, required this.phone, super.key});

  /// The page's inputs.
  final IptvImportInputs inputs;

  /// Whether the origins are rows (a wide page) or a strip.
  final bool rail;

  /// Whether the phone origin is offered.
  final bool phone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final flow = ref.watch(iptvImportFlowProvider);
    final controller = ref.read(iptvImportFlowProvider.notifier);
    final origins = iptvImportOrigins(flow.kind, phone: phone);
    final busy = flow.step == IptvImportStep.reading || flow.step == IptvImportStep.writing;
    final clipboard = inputs.clipboard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        if (clipboard != null && flow.kind == IptvImportKind.playlist)
          DsAlert(
            title: Text(t.iptv.importClipboardFound),
            description: Text(_clip(clipboard), maxLines: 2, overflow: TextOverflow.ellipsis),
            icon: const DsIcon(DsIcons.clipboardPaste),
            action: DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: busy ? null : inputs.onUseClipboard,
              child: Text(t.iptv.importClipboardUse),
            ),
          ),
        if (rail)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s4,
            children: [
              for (final origin in origins)
                _OriginRow(
                  origin: origin,
                  kind: flow.kind,
                  selected: origin == flow.origin,
                  onPressed: busy ? null : () => controller.setOrigin(origin),
                ),
            ],
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DsTopNav<IptvImportOrigin>(
              value: flow.origin,
              onChanged: busy ? null : controller.setOrigin,
              semanticLabel: t.iptv.importStepSource,
              items: [
                for (final origin in origins)
                  DsTopNavItem(
                    value: origin,
                    icon: DsIcon(_originIcon(origin), size: 15),
                    label: Text(_originLabel(origin, t)),
                  ),
              ],
            ),
          ),
        if (rail) const DsDivider(),
        _OriginInputs(inputs: inputs, flow: flow, busy: busy),
      ],
    );
  }

  static String _clip(String text) => text.trim().split('\n').take(2).join(' ');
}

/// The fields and the action of the open origin.
final class _OriginInputs extends ConsumerWidget {
  const _OriginInputs({required this.inputs, required this.flow, required this.busy});

  final IptvImportInputs inputs;
  final IptvImportFlowState flow;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final hint = theme.typography.small.copyWith(color: colors.textMuted);
    final guide = flow.kind == IptvImportKind.guide;
    final reading = flow.step == IptvImportStep.reading;
    Widget previewButton({VoidCallback? onPressed}) => Align(
      alignment: AlignmentDirectional.centerEnd,
      child: DsButton(
        loading: reading,
        onPressed: busy ? null : onPressed,
        leading: const DsIcon(DsIcons.listChecks, size: 16),
        child: Text(t.iptv.importPreviewAction),
      ),
    );
    return switch (flow.origin) {
      IptvImportOrigin.link => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          DsTextField(
            controller: inputs.link,
            enabled: !busy,
            autofocus: true,
            clearable: true,
            keyboardType: TextInputType.url,
            placeholder: guide ? t.iptv.epgSourceHint : t.iptv.playlistUrlHint,
            semanticLabel: guide ? t.iptv.epgSourceHint : t.iptv.playlistUrl,
            onSubmitted: (_) => inputs.onPreview(),
          ),
          Text(t.iptv.importLinkHint, style: hint),
          previewButton(onPressed: inputs.onPreview),
        ],
      ),
      IptvImportOrigin.text => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          DsTextField.multiline(
            controller: inputs.text,
            enabled: !busy,
            minLines: 8,
            maxLines: 16,
            placeholder: t.iptv.playlistTextHint,
            semanticLabel: t.iptv.playlistText,
          ),
          previewButton(onPressed: inputs.onPreview),
        ],
      ),
      IptvImportOrigin.file => DsFileUpload(
        onBrowse: busy ? null : inputs.onPickFile,
        icon: const DsIcon(DsIcons.fileUp),
        title: Text(t.iptv.importFileAction),
        description: Text(guide ? t.iptv.importGuideFileFormats : t.iptv.importFileFormats),
        semanticLabel: t.iptv.importFileAction,
      ),
      IptvImportOrigin.scan => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Text(t.iptv.importScanHint, style: theme.typography.body.copyWith(color: colors.textMuted)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DsButton(
              autofocus: true,
              onPressed: busy ? null : inputs.onPhone,
              leading: const DsIcon(DsIcons.smartphone, size: 16),
              child: Text(t.iptv.importScanAction),
            ),
          ),
        ],
      ),
      IptvImportOrigin.xtream => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          DsTextField(
            controller: inputs.xtreamServer,
            enabled: !busy,
            autofocus: true,
            keyboardType: TextInputType.url,
            placeholder: t.iptv.importXtreamServerHint,
            semanticLabel: t.iptv.importXtreamServer,
          ),
          DsTextField(
            controller: inputs.xtreamUser,
            enabled: !busy,
            placeholder: t.iptv.importXtreamUser,
            semanticLabel: t.iptv.importXtreamUser,
          ),
          DsTextField(
            controller: inputs.xtreamPassword,
            enabled: !busy,
            obscureText: true,
            placeholder: t.iptv.importXtreamPassword,
            semanticLabel: t.iptv.importXtreamPassword,
          ),
          Text(t.iptv.importXtreamNote, style: hint),
          _XtreamStatus(flow: flow),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: DsSpace.s8,
            children: [
              DsButton(
                variant: DsButtonVariant.secondary,
                loading: flow.checkingAccount,
                onPressed: busy || flow.checkingAccount ? null : inputs.onXtreamCheck,
                leading: const DsIcon(DsIcons.keyRound, size: 15),
                child: Text(t.iptv.importXtreamCheck),
              ),
              DsButton(
                loading: reading,
                onPressed: busy ? null : inputs.onXtreamPreview,
                leading: const DsIcon(DsIcons.listChecks, size: 16),
                child: Text(t.iptv.importPreviewAction),
              ),
            ],
          ),
        ],
      ),
    };
  }
}

/// The line under the Xtream form: what the panel said about the account.
final class _XtreamStatus extends StatelessWidget {
  const _XtreamStatus({required this.flow});

  final IptvImportFlowState flow;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final account = flow.account;
    if (flow.accountError != null) {
      final rejected = '${flow.accountError}'.contains('rejected');
      return DsBadge(
        status: rejected ? DsStatus.danger : DsStatus.warning,
        label: Text(rejected ? t.iptv.importXtreamAccountBad : t.iptv.importXtreamCheckFailed),
      );
    }
    if (account == null) return const SizedBox.shrink();
    final date = _date(account);
    if (!account.isActive()) {
      return DsBadge(
        status: DsStatus.warning,
        label: Text(t.iptv.importXtreamAccountExpired(date: date)),
      );
    }
    return DsBadge(
      status: DsStatus.success,
      label: Text(
        t.iptv.importXtreamAccountOk(
          date: date,
          active: '${account.activeConnections ?? 0}',
          max: '${account.maxConnections ?? '∞'}',
        ),
      ),
    );
  }

  static String _date(XtreamAccount account) {
    final end = account.expiresAt?.toLocal();
    if (end == null) return '—';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${end.year}-${two(end.month)}-${two(end.day)}';
  }
}

/// A pressable bordered surface: the house tile the origin rows and the
/// guide rows share, so all answer focus, hover and press alike — and a TV
/// remote can land on each.
final class _Tile extends StatefulWidget {
  const _Tile({required this.child, required this.onPressed, this.selected = false});

  final Widget child;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  State<_Tile> createState() => _TileState();
}

final class _TileState extends State<_Tile> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final enabled = widget.onPressed != null;
    final edge = _focus
        ? colors.accent
        : widget.selected
        ? colors.accentEdge
        : colors.border;
    return FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowHoverHighlight: (value) => setState(() => _hover = value),
      onShowFocusHighlight: (value) => setState(() => _focus = value),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed?.call())},
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: theme.motion.toneDuration,
          padding: const EdgeInsets.all(DsSpace.s12),
          decoration: BoxDecoration(
            color: widget.selected
                ? colors.accentTint
                : _hover && enabled
                ? colors.controlHover
                : colors.surface,
            border: Border.all(color: edge, width: _focus ? 2 : 1),
            borderRadius: BorderRadius.circular(theme.radii.card - 4),
          ),
          child: Opacity(opacity: enabled ? 1 : .55, child: widget.child),
        ),
      ),
    );
  }
}

/// One origin as a row: its glyph, its name and a line about it.
final class _OriginRow extends StatelessWidget {
  const _OriginRow({required this.origin, required this.kind, required this.selected, required this.onPressed});

  final IptvImportOrigin origin;
  final IptvImportKind kind;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return _Tile(
      onPressed: onPressed,
      selected: selected,
      child: Row(
        spacing: DsSpace.s12,
        children: [
          DsIcon(_originIcon(origin), size: theme.sizes.iconMd, color: selected ? colors.accentText : colors.textMuted),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  _originLabel(origin, t),
                  style: theme.typography.bodyStrong.copyWith(color: selected ? colors.accentText : colors.text),
                ),
                Text(
                  _originDescription(origin, kind, t),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          if (selected) DsIcon(DsIcons.check, size: theme.sizes.iconSm, color: colors.accentText),
        ],
      ),
    );
  }
}

DsIconData _originIcon(IptvImportOrigin origin) => switch (origin) {
  IptvImportOrigin.link => DsIcons.link,
  IptvImportOrigin.text => DsIcons.clipboard,
  IptvImportOrigin.file => DsIcons.folderOpen,
  IptvImportOrigin.scan => DsIcons.smartphone,
  IptvImportOrigin.xtream => DsIcons.server,
};

String _originLabel(IptvImportOrigin origin, Translations t) => switch (origin) {
  IptvImportOrigin.link => t.iptv.importOriginLink,
  IptvImportOrigin.text => t.iptv.importOriginText,
  IptvImportOrigin.file => t.iptv.importOriginFile,
  IptvImportOrigin.scan => t.iptv.importOriginScan,
  IptvImportOrigin.xtream => t.iptv.importOriginXtream,
};

String _originDescription(IptvImportOrigin origin, IptvImportKind kind, Translations t) => switch ((origin, kind)) {
  (IptvImportOrigin.link, IptvImportKind.guide) => t.iptv.importGuideOriginLinkDesc,
  (IptvImportOrigin.file, IptvImportKind.guide) => t.iptv.importGuideOriginFileDesc,
  (IptvImportOrigin.link, _) => t.iptv.importOriginLinkDesc,
  (IptvImportOrigin.text, _) => t.iptv.importOriginTextDesc,
  (IptvImportOrigin.file, _) => t.iptv.importOriginFileDesc,
  (IptvImportOrigin.scan, _) => t.iptv.importOriginScanDesc,
  (IptvImportOrigin.xtream, _) => t.iptv.importOriginXtreamDesc,
};
