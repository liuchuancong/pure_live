import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:pure_live/app/providers/network/network_providers.dart' show networkFactoryProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart' show iptvLibraryProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_epg_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_presets_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_sources_controller.dart';
import 'package:pure_live/modules/iptv/data/iptv_preset.dart';

/// What is being imported.
enum IptvImportKind {
  /// A channel list.
  playlist,

  /// A programme guide.
  guide,
}

/// Where the import reads from.
enum IptvImportOrigin {
  /// A web address.
  link,

  /// Pasted text.
  text,

  /// A file picked from the device.
  file,

  /// One of the recommended sources.
  preset,

  /// An address sent from a phone (TV only).
  scan,

  /// An Xtream Codes account.
  xtream,
}

/// The step the page is on.
enum IptvImportStep {
  /// Choosing and filling a source.
  source,

  /// Reading it (a download, a decode).
  reading,

  /// Looking at what would be written.
  preview,

  /// Writing it.
  writing,

  /// What was written.
  done,
}

/// The page's temporary state: nothing here outlives the page.
///
/// The inputs are the page's own text controllers; this holds what they
/// lead to — the preview the importer answered, the viewer's choices over
/// it (the name, the groups to hide, the guide to attach), and the result.
typedef IptvImportFlowState = ({
  IptvImportKind kind,
  IptvImportOrigin origin,
  IptvImportStep step,
  IptvPlaylistPreview? playlist,
  IptvGuidePreview? guide,
  IptvPreset? preset,
  String name,
  Set<String> hiddenGroups,
  bool attachGuide,
  bool replaceNamed,
  String? guideCandidate,
  IptvImportResult? result,
  IptvImportResult? guideResult,
  XtreamAccount? account,
  Object? accountError,
  bool checkingAccount,
});

/// How an import page opens: on which kind, on which source, and with what
/// already filled in (a preset the start screen chose, a link the
/// clipboard held).
final class IptvImportLaunch {
  /// A launch.
  const new({this.kind = IptvImportKind.playlist, this.origin, this.preset, this.link});

  /// What to import.
  final IptvImportKind kind;

  /// The source to open on; the page chooses when null.
  final IptvImportOrigin? origin;

  /// A preset to preview straight away.
  final IptvPreset? preset;

  /// An address to fill in.
  final String? link;
}

/// The flow behind one import page: preview first, write on the viewer's
/// word, and say exactly what happened.
///
/// It owns no data: every read goes through the source and guide
/// controllers (and through them the importer), so the page shows what the
/// library itself would do, and closing the page mid-way leaves nothing
/// half-written — a preview is never stored.
final class IptvImportFlow extends Notifier<IptvImportFlowState> {
  /// The flow's starting state.
  @override
  IptvImportFlowState build() => (
    kind: IptvImportKind.playlist,
    origin: IptvImportOrigin.link,
    step: IptvImportStep.source,
    playlist: null,
    guide: null,
    preset: null,
    name: '',
    hiddenGroups: const {},
    attachGuide: false,
    replaceNamed: false,
    guideCandidate: null,
    result: null,
    guideResult: null,
    account: null,
    accountError: null,
    checkingAccount: false,
  );

  /// Switches what is imported, back to the source step.
  void setKind(IptvImportKind kind) {
    if (kind == state.kind) return;
    final origin = switch ((kind, state.origin)) {
      (IptvImportKind.guide, IptvImportOrigin.text || IptvImportOrigin.xtream || IptvImportOrigin.scan) =>
        IptvImportOrigin.link,
      _ => state.origin,
    };
    state = _reset(kind: kind, origin: origin);
  }

  /// Chooses where the import reads from.
  void setOrigin(IptvImportOrigin origin) {
    if (origin == state.origin && state.step == IptvImportStep.source) return;
    state = _reset(kind: state.kind, origin: origin);
  }

  /// Back from a preview or a result to the source, keeping the inputs.
  void backToSource() => state = _reset(kind: state.kind, origin: state.origin, preset: state.preset);

  /// The name the import will carry.
  void setName(String name) => state = _with(name: name, replaceNamed: false);

  /// Whether the import takes over the other playlist that has its name.
  void setReplaceNamed({required bool value}) => state = _with(replaceNamed: value);

  /// The stored playlist — other than the one this address already is — that
  /// carries the name typed, or null.
  ///
  /// The page asks before it writes: replace that one, or keep both under
  /// another name. Never a silent overwrite, never two sources one name.
  IptvPlaylist? nameClash() {
    if (state.kind != IptvImportKind.playlist) return null;
    final library = ref.read(iptvLibraryProvider).value;
    final named = library?.playlistNamed(state.name.trim());
    if (named == null || named.id == state.playlist?.urlClash?.id) return null;
    return named;
  }

  /// A free name beside [taken]: `name (2)`, `name (3)`, …
  String freeNameFor(String taken) {
    final library = ref.read(iptvLibraryProvider).value;
    for (var n = 2; ; n++) {
      final candidate = '$taken ($n)';
      if (library?.playlistNamed(candidate) == null) return candidate;
    }
  }

  /// Shows or hides [group] once the import is in.
  void toggleGroup(String group, {required bool shown}) {
    final hidden = {...state.hiddenGroups};
    if (shown) {
      hidden.remove(group);
    } else {
      hidden.add(group);
    }
    state = _with(hiddenGroups: hidden);
  }

  /// Shows every group, or hides every group.
  void setAllGroups({required bool shown}) {
    final groups = state.playlist?.result.groupCounts.keys ?? const <String>[];
    state = _with(hiddenGroups: shown ? const {} : groups.toSet());
  }

  /// Whether the guide the playlist names is added with it.
  void setAttachGuide({required bool value}) => state = _with(attachGuide: value);

  /// Previews the playlist at [address].
  Future<void> previewLink(String address, {IptvPreset? preset}) async {
    final uri = Uri.tryParse(address.trim());
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      return;
    }
    state = _with(step: IptvImportStep.reading, preset: preset);
    if (state.kind == IptvImportKind.guide) {
      final preview = await ref.read(iptvEpgProvider.notifier).previewUrl(uri);
      _showGuide(preview, fallbackName: uri.host);
      return;
    }
    final preview = await ref.read(iptvSourcesProvider.notifier).previewUrl(uri);
    _showPlaylist(
      preview,
      fallbackName: preset?.nameIn(currentLanguageTag()) ?? preview.urlClash?.name ?? preview.suggestedName ?? uri.host,
    );
  }

  /// Previews pasted [text].
  Future<void> previewText(String text, {required String fallbackName}) async {
    if (text.trim().isEmpty) return;
    state = _with(step: IptvImportStep.reading);
    final preview = await ref.read(iptvSourcesProvider.notifier).previewText(text);
    _showPlaylist(preview, fallbackName: preview.suggestedName ?? fallbackName);
  }

  /// Previews a picked file's [bytes], named after the file.
  Future<void> previewFile(List<int> bytes, {required String fileName, required String path}) async {
    state = _with(step: IptvImportStep.reading);
    final base = _baseName(fileName);
    if (state.kind == IptvImportKind.guide) {
      final preview = await ref.read(iptvEpgProvider.notifier).previewBytes(bytes, source: path);
      _showGuide(preview, fallbackName: base);
      return;
    }
    final preview = await ref.read(iptvSourcesProvider.notifier).previewBytes(bytes);
    _showPlaylist(preview, fallbackName: preview.suggestedName ?? base);
  }

  /// Asks an Xtream panel about [source]'s account, for the line under the
  /// form; an import does not wait for it.
  Future<void> checkXtream(XtreamSource source) async {
    state = _with(checkingAccount: true, clearAccount: true);
    try {
      final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
      final account = await XtreamCatalogService(http: http).fetchAccount(source);
      if (ref.mounted) state = _with(account: account, checkingAccount: false);
    } on Object catch (error) {
      if (ref.mounted) state = _with(accountError: error, checkingAccount: false, clearAccount: true);
    }
  }

  /// Writes what the preview showed.
  Future<void> commit() async {
    final playlist = state.playlist;
    final guide = state.guide;
    final name = state.name.trim();
    if (name.isEmpty) return;
    state = _with(step: IptvImportStep.writing);
    if (state.kind == IptvImportKind.guide && guide != null) {
      final result = await ref
          .read(iptvEpgProvider.notifier)
          .commitPreview(guide, name: name, replace: _guideNameIsOurs(name));
      if (!ref.mounted) return;
      state = _with(step: result.isImported ? IptvImportStep.done : IptvImportStep.preview, result: result);
      return;
    }
    if (playlist == null) return;
    final clash = nameClash();
    if (clash != null && !state.replaceNamed) {
      state = _with(step: IptvImportStep.preview);
      return;
    }
    final result = await ref
        .read(iptvSourcesProvider.notifier)
        .commitPreview(
          playlist,
          name: name,
          replaceId: playlist.urlClash?.id ?? clash?.id,
          hiddenGroups: state.hiddenGroups,
        );
    if (!ref.mounted) return;
    state = _with(step: result.isImported ? IptvImportStep.done : IptvImportStep.preview, result: result);
    if (!result.isImported || result.id == null) return;
    final presets = ref.read(iptvPresetsProvider.notifier);
    final preset = state.preset;
    if (preset != null) presets.noteAdded(preset.id, result.id!);
    if (state.attachGuide || preset != null) {
      unawaited(_attach(result.id!, preset));
    }
  }

  Future<void> _attach(String playlistId, IptvPreset? preset) async {
    final library = ref.read(iptvLibraryProvider).value;
    final before = library?.guideSources.length ?? 0;
    await ref.read(iptvPresetsProvider.notifier).attachGuide(playlistId, preset: preset, force: state.attachGuide);
    if (!ref.mounted) return;
    final after = ref.read(iptvLibraryProvider).value?.guideSources ?? const <EpgSource>[];
    if (after.length > before) {
      state = _with(guideResult: IptvImportResult(IptvImportStatus.imported, id: after.last.id));
    }
  }

  /// Whether the guide called [name] is the one the preview would update —
  /// a sync in all but name, not a clash to ask about.
  bool _guideNameIsOurs(String name) {
    final library = ref.read(iptvLibraryProvider).value;
    final source = state.guide?.source;
    if (library == null || source == null) return false;
    return library.guideSources.any(
      (stored) => stored.name.trim().toLowerCase() == name.toLowerCase() && stored.source.trim() == source.trim(),
    );
  }

  void _showPlaylist(IptvPlaylistPreview preview, {required String fallbackName}) {
    if (!ref.mounted) return;
    final library = ref.read(iptvLibraryProvider).value;
    final hasGuide = library?.guideSources.isNotEmpty ?? false;
    state = _with(
      step: IptvImportStep.preview,
      playlist: preview,
      name: state.name.trim().isEmpty ? fallbackName : state.name,
      hiddenGroups: const {},
      attachGuide: preview.result.header.declaresGuide && !hasGuide,
      guideCandidate: preview.result.header.guideUrls.firstOrNull,
    );
  }

  void _showGuide(IptvGuidePreview preview, {required String fallbackName}) {
    if (!ref.mounted) return;
    state = _with(
      step: IptvImportStep.preview,
      guide: preview,
      name: state.name.trim().isEmpty ? fallbackName : state.name,
    );
  }

  static String _baseName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = (dot > 0 ? fileName.substring(0, dot) : fileName).trim();
    return base.isEmpty ? fileName : base;
  }

  IptvImportFlowState _reset({required IptvImportKind kind, required IptvImportOrigin origin, IptvPreset? preset}) => (
    kind: kind,
    origin: origin,
    step: IptvImportStep.source,
    playlist: null,
    guide: null,
    preset: preset,
    name: state.name,
    hiddenGroups: const {},
    attachGuide: false,
    replaceNamed: false,
    guideCandidate: null,
    result: null,
    guideResult: null,
    account: state.account,
    accountError: state.accountError,
    checkingAccount: false,
  );

  IptvImportFlowState _with({
    IptvImportStep? step,
    IptvPlaylistPreview? playlist,
    IptvGuidePreview? guide,
    IptvPreset? preset,
    String? name,
    Set<String>? hiddenGroups,
    bool? attachGuide,
    bool? replaceNamed,
    String? guideCandidate,
    IptvImportResult? result,
    IptvImportResult? guideResult,
    XtreamAccount? account,
    Object? accountError,
    bool? checkingAccount,
    bool clearAccount = false,
  }) => (
    kind: state.kind,
    origin: state.origin,
    step: step ?? state.step,
    playlist: playlist ?? state.playlist,
    guide: guide ?? state.guide,
    preset: preset ?? state.preset,
    name: name ?? state.name,
    hiddenGroups: hiddenGroups ?? state.hiddenGroups,
    attachGuide: attachGuide ?? state.attachGuide,
    replaceNamed: replaceNamed ?? state.replaceNamed,
    guideCandidate: guideCandidate ?? state.guideCandidate,
    result: result ?? state.result,
    guideResult: guideResult ?? state.guideResult,
    account: clearAccount ? account : (account ?? state.account),
    accountError: clearAccount ? accountError : (accountError ?? state.accountError),
    checkingAccount: checkingAccount ?? state.checkingAccount,
  );
}

/// One import page's flow; it goes with the page.
final NotifierProvider<IptvImportFlow, IptvImportFlowState> iptvImportFlowProvider =
    NotifierProvider.autoDispose<IptvImportFlow, IptvImportFlowState>(IptvImportFlow.new);
