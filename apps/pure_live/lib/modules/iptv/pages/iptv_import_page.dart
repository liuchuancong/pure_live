import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show XtreamSource;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_import_flow.dart';
import 'package:pure_live/modules/iptv/data/iptv_preset.dart';
import 'package:pure_live/modules/iptv/views/iptv_import_preview_pane.dart';
import 'package:pure_live/modules/iptv/views/iptv_import_source_pane.dart';
import 'package:pure_live/shared/shared.dart';

/// The source pane's width beside the preview on a wide window.
const double _sourceWidth = 420;

/// The import page: a source, its preview, then the write — the one flow
/// every playlist and guide comes in through.
///
/// A wide window shows the source and the preview side by side; a tablet
/// stacks them in one column over a pinned action bar; a phone takes them
/// one step at a time. A TV opens on the phone origin, because typing an
/// address with a remote is the thing nobody should have to do.
///
/// Nothing is written before the viewer presses import: the preview is the
/// importer's own read of the source, so what it counts is what lands.
final class IptvImportPage extends ConsumerStatefulWidget {
  /// The page, opened as [launch] says.
  const IptvImportPage({this.launch = const IptvImportLaunch(), super.key});

  /// How the page opens.
  final IptvImportLaunch launch;

  @override
  ConsumerState<IptvImportPage> createState() => _IptvImportPageState();
}

final class _IptvImportPageState extends ConsumerState<IptvImportPage> {
  final _link = TextEditingController();
  final _text = TextEditingController();
  final _xtreamServer = TextEditingController();
  final _xtreamUser = TextEditingController();
  final _xtreamPassword = TextEditingController();
  final GlobalKey _previewKey = GlobalKey();

  /// What the clipboard held when the page opened, if it reads as a source.
  String? _clipboard;

  /// The last read, for the retry verb.
  Future<void> Function()? _lastRead;

  /// The last picked file, so a guide that arrived as a playlist can be read
  /// again under the guide tab without picking it twice.
  ({List<int> bytes, String name, String path})? _lastFile;

  bool get _tv => ref.read(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  @override
  void dispose() {
    _link.dispose();
    _text.dispose();
    _xtreamServer.dispose();
    _xtreamUser.dispose();
    _xtreamPassword.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!mounted) return;
    final launch = widget.launch;
    final flow = ref.read(iptvImportFlowProvider.notifier);
    final preset = launch.preset;
    final origin =
        launch.origin ??
        (preset != null
            ? IptvImportOrigin.preset
            : _tv && launch.kind == IptvImportKind.playlist
            ? IptvImportOrigin.scan
            : IptvImportOrigin.link);
    flow
      ..setKind(launch.kind)
      ..setOrigin(origin);
    final link = launch.link;
    if (link != null) _link.text = link;
    if (preset != null) {
      unawaited(_read(() => flow.previewLink(preset.url, preset: preset)));
      return;
    }
    if (!_tv) await _readClipboard();
  }

  /// Offers what the clipboard holds when it reads as a link or a list.
  Future<void> _readClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (!mounted || text.isEmpty) return;
      if (_isLink(text) || _isList(text)) setState(() => _clipboard = text);
    } on Object {
      // A clipboard the platform will not read offers nothing.
    }
  }

  static bool _isLink(String text) =>
      !text.contains(RegExp(r'\s')) && (text.startsWith('http://') || text.startsWith('https://'));

  static bool _isList(String text) => text.contains('#EXTM3U') || text.contains('#EXTINF') || text.contains('#genre#');

  void _useClipboard() {
    final clip = _clipboard;
    if (clip == null) return;
    final flow = ref.read(iptvImportFlowProvider.notifier);
    setState(() => _clipboard = null);
    if (_isLink(clip)) {
      flow.setOrigin(IptvImportOrigin.link);
      _link.text = clip;
    } else {
      flow.setOrigin(IptvImportOrigin.text);
      _text.text = clip;
    }
    _preview();
  }

  /// Runs [read], remembering it for the retry verb, and brings the preview
  /// into view on a page that stacks it under the source.
  Future<void> _read(Future<void> Function() read) async {
    _lastRead = read;
    await read();
    if (!mounted) return;
    final target = _previewKey.currentContext;
    if (target != null && target.mounted) {
      Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 240));
    }
  }

  void _preview() {
    final flow = ref.read(iptvImportFlowProvider.notifier);
    final origin = ref.read(iptvImportFlowProvider).origin;
    final t = context.t;
    switch (origin) {
      case IptvImportOrigin.text:
        if (_text.text.trim().isEmpty) {
          _toast(t.iptv.importTextRequired);
          return;
        }
        final text = _text.text;
        unawaited(_read(() => flow.previewText(text, fallbackName: t.iptv.importDefaultName)));
      case IptvImportOrigin.link || IptvImportOrigin.preset || IptvImportOrigin.scan:
        final raw = _link.text.trim();
        if (raw.isEmpty) {
          _toast(t.iptv.importAddressRequired);
          return;
        }
        final uri = Uri.tryParse(raw);
        if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
          _toast(t.iptv.importAddressInvalid);
          return;
        }
        unawaited(_read(() => flow.previewLink(raw)));
      case IptvImportOrigin.file:
        _pickFile();
      case IptvImportOrigin.xtream:
        _previewXtream();
    }
  }

  void _pickFile() => unawaited(_pickFileAsync());

  Future<void> _pickFileAsync() async {
    final t = context.t;
    final guide = ref.read(iptvImportFlowProvider).kind == IptvImportKind.guide;
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: guide ? t.iptv.importGuide : t.iptv.pickPlaylistFile,
        type: FileType.custom,
        allowedExtensions: guide ? const ['xml', 'gz', 'json'] : const ['m3u', 'm3u8', 'txt'],
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final picked = (bytes: bytes, name: file.name, path: file.path ?? file.name);
      _lastFile = picked;
      final flow = ref.read(iptvImportFlowProvider.notifier);
      await _read(() => flow.previewFile(picked.bytes, fileName: picked.name, path: picked.path));
    } on Object {
      if (mounted) _toast(t.iptv.importFailed);
    }
  }

  XtreamSource? _xtreamSource() {
    final server = _xtreamServer.text.trim();
    final user = _xtreamUser.text.trim();
    final password = _xtreamPassword.text.trim();
    if (server.isEmpty || user.isEmpty || password.isEmpty) {
      _toast(context.t.iptv.importAddressRequired);
      return null;
    }
    return XtreamSource(url: server, username: user, password: password);
  }

  void _previewXtream() {
    final source = _xtreamSource();
    if (source == null) return;
    final Uri address;
    try {
      address = source.playlistUrl();
    } on FormatException {
      _toast(context.t.iptv.importAddressInvalid);
      return;
    }
    final flow = ref.read(iptvImportFlowProvider.notifier);
    unawaited(_read(() => flow.previewLink(address.toString())));
  }

  void _checkXtream() {
    final source = _xtreamSource();
    if (source == null) return;
    unawaited(ref.read(iptvImportFlowProvider.notifier).checkXtream(source));
  }

  void _presetPreview(IptvPreset? preset, String address) {
    final flow = ref.read(iptvImportFlowProvider.notifier);
    unawaited(_read(() => flow.previewLink(address, preset: preset)));
  }

  /// The phone form: a name and an address typed on a phone, read straight
  /// into a preview.
  Future<void> _phone() async {
    final t = context.t;
    final values = await showTvPhoneInput(
      context,
      PhoneInputRequest(
        title: t.iptv.importPageTitle,
        note: t.iptv.importScanHint,
        fields: [
          PhoneInputField(key: 'url', label: t.iptv.playlistUrl, hint: t.iptv.playlistUrlHint),
          PhoneInputField(key: 'name', label: t.iptv.playlistName, hint: t.iptv.playlistNameHint),
        ],
      ),
    );
    if (values == null || !mounted) return;
    final url = values['url']?.trim() ?? '';
    if (url.isEmpty) return;
    final flow = ref.read(iptvImportFlowProvider.notifier);
    _link.text = url;
    final name = values['name']?.trim() ?? '';
    if (name.isNotEmpty) flow.setName(name);
    showDsToast(context: context, title: t.iptv.importScanReceived);
    await _read(() => flow.previewLink(url));
  }

  void _retry() {
    final read = _lastRead;
    if (read != null) unawaited(_read(read));
  }

  /// A playlist read that turned out to be a guide, read again as one.
  void _switchToGuide() {
    final flow = ref.read(iptvImportFlowProvider.notifier);
    final origin = ref.read(iptvImportFlowProvider).origin;
    flow.setKind(IptvImportKind.guide);
    final file = _lastFile;
    if (origin == IptvImportOrigin.file && file != null) {
      flow.setOrigin(IptvImportOrigin.file);
      unawaited(_read(() => flow.previewFile(file.bytes, fileName: file.name, path: file.path)));
      return;
    }
    flow.setOrigin(IptvImportOrigin.link);
    final raw = _link.text.trim();
    if (raw.isNotEmpty) unawaited(_read(() => flow.previewLink(raw)));
  }

  void _finish({required bool showChannels}) {
    if (showChannels) ref.read(selectedNavItemProvider.notifier).selected = NavigationItem.channels;
    Navigator.of(context).maybePop();
  }

  void _toast(String message) => showDsToast(context: context, title: message, status: DsStatus.danger);

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final flow = ref.watch(iptvImportFlowProvider);
    final inputs = IptvImportInputs(
      link: _link,
      text: _text,
      xtreamServer: _xtreamServer,
      xtreamUser: _xtreamUser,
      xtreamPassword: _xtreamPassword,
      onPreview: _preview,
      onPickFile: _pickFile,
      onPresetPreview: _presetPreview,
      onXtreamPreview: _previewXtream,
      onXtreamCheck: _checkXtream,
      clipboard: _clipboard,
      onUseClipboard: _useClipboard,
      onPhone: _tv ? () => unawaited(_phone()) : null,
    );
    final body = IptvImportPreviewBody(key: _previewKey, onRetry: _retry, onSwitchToGuide: _switchToGuide);
    final footer = IptvImportPreviewFooter(onRetry: _retry, onFinish: _finish);
    return ColoredBox(
      color: colors.canvas,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final wide = width >= LiveWindow.expanded;
            final compact = width < LiveWindow.compact;
            final inset = LiveWindow.pageInset(width);
            final source = IptvImportSourcePane(inputs: inputs, rail: wide, phone: _tv);
            final Widget content;
            if (wide) {
              content = Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: _sourceWidth,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(inset, DsSpace.s16, DsSpace.s20, DsSpace.s24),
                      child: source,
                    ),
                  ),
                  Container(width: 1, color: colors.border),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(DsSpace.s24, DsSpace.s16, inset, DsSpace.s24),
                            child: Align(
                              alignment: AlignmentDirectional.topStart,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: LiveWindow.content),
                                child: body,
                              ),
                            ),
                          ),
                        ),
                        footer,
                      ],
                    ),
                  ),
                ],
              );
            } else if (compact && flow.step == IptvImportStep.source) {
              content = SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s24),
                child: source,
              );
            } else if (compact) {
              content = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s24),
                      child: body,
                    ),
                  ),
                  footer,
                ],
              );
            } else {
              // A tablet: the source over the preview in one column, the
              // preview's verbs pinned under both.
              content = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: DsSpace.s20,
                        children: [source, const DsDivider(), body],
                      ),
                    ),
                  ),
                  footer,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(flow: flow, compact: compact, inset: inset),
                Container(height: 1, color: colors.border),
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The page's bar: back, the title, the step the flow is on, and what is
/// being imported.
final class _Header extends ConsumerWidget {
  const _Header({required this.flow, required this.compact, required this.inset});

  final IptvImportFlowState flow;
  final bool compact;
  final double inset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final controller = ref.read(iptvImportFlowProvider.notifier);
    final busy = flow.step == IptvImportStep.reading || flow.step == IptvImportStep.writing;
    final kind = DsSegmentedControl<IptvImportKind>(
      value: flow.kind,
      onChanged: busy ? null : controller.setKind,
      semanticLabel: t.iptv.importPageTitle,
      segments: [
        DsSegment(
          value: IptvImportKind.playlist,
          icon: const DsIcon(DsIcons.list),
          label: Text(t.iptv.importKindPlaylist),
        ),
        DsSegment(
          value: IptvImportKind.guide,
          icon: const DsIcon(DsIcons.calendarClock),
          label: Text(t.iptv.importKindGuide),
        ),
      ],
    );
    // A phone on its preview step goes back to the source, not off the page:
    // the source is the step before, and its inputs are still there.
    final back = compact && flow.step != IptvImportStep.source && !busy
        ? controller.backToSource
        : () => Navigator.of(context).maybePop();
    return Padding(
      padding: EdgeInsets.fromLTRB(inset - DsSpace.s8, DsSpace.s8, inset, DsSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Row(
            spacing: DsSpace.s8,
            children: [
              DsButton.icon(
                variant: DsButtonVariant.ghost,
                onPressed: back,
                icon: const DsIcon(DsIcons.chevronLeft),
                semanticLabel: t.common.back,
              ),
              Expanded(
                child: Text(
                  t.iptv.importPageTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.title.copyWith(color: colors.text),
                ),
              ),
              if (!compact) _StepStrip(step: flow.step),
              if (!compact) kind,
            ],
          ),
          if (compact) Row(children: [Expanded(child: kind)]),
        ],
      ),
    );
  }
}

/// The three steps as a strip of numbered marks, the current one filled.
final class _StepStrip extends StatelessWidget {
  const _StepStrip({required this.step});

  final IptvImportStep step;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final current = switch (step) {
      IptvImportStep.source || IptvImportStep.reading => 0,
      IptvImportStep.preview || IptvImportStep.writing => 1,
      IptvImportStep.done => 2,
    };
    final labels = [t.iptv.importStepSource, t.iptv.importStepPreview, t.iptv.importStepDone];
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: DsSpace.s8),
      child: Row(
        spacing: DsSpace.s6,
        children: [
          for (final (index, label) in labels.indexed) ...[
            if (index > 0) Container(width: 16, height: 1, color: colors.border),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index <= current ? colors.accent : colors.control,
              ),
              child: Center(
                child: index < current
                    ? DsIcon(DsIcons.check, size: 12, color: colors.onAccent)
                    : Text(
                        '${index + 1}',
                        style: theme.typography.caption.copyWith(
                          color: index <= current ? colors.onAccent : colors.textMuted,
                        ),
                      ),
              ),
            ),
            Text(
              label,
              style: theme.typography.caption.copyWith(color: index == current ? colors.text : colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
