import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/platform_logo.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The "当前站点" selector the discovery pages carry in their header (the
/// reference's `站点选择`): the current platform's logo and name with a
/// chevron, opening a searchable list of the sites — logo, name, a check on
/// the one showing now. It rises centred on the window, like every other
/// floating surface in the app.
final class SitePickerButton extends StatelessWidget {
  /// A picker over [sites], [current] selected, [onSelected] fired once.
  const new({required this.sites, required this.current, required this.onSelected, this.compact = false, super.key});

  /// The sites the page offers, in display order.
  final List<LiveSite> sites;

  /// The site showing now.
  final LiveSite current;

  /// Applies the picked site.
  final ValueChanged<LiveSite> onSelected;

  /// Whether to drop the "当前站点" prefix and show the logo and name alone —
  /// the narrow bar's shape.
  final bool compact;

  static String _name(BuildContext context, LiveSite site) =>
      site.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN');

  Future<void> _open(BuildContext context) async {
    final picked = await showPureDialog<LiveSite>(
      context: context,
      title: context.t.discovery.pickSite,
      child: _SitePickerBody(sites: sites, current: current),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final label = compact ? _name(context, current) : context.t.discovery.currentSite(site: _name(context, current));
    // A self-contained compact row, not a list row: the app bar's title slot
    // gives an unbounded width, and a list row's flexible title turns that
    // into an infinite-width layout. Everything here is sized by its content.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: const ValueKey('site-picker-button'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => unawaited(_open(context)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: theme.colors.fillSecondary, borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlatformLogo(siteId: current.manifest.id, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.text.body),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, size: 18, color: theme.colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The picker's body: the search field over the rows, and the rows
/// themselves — logo, name, a check on the one showing now.
final class _SitePickerBody extends StatefulWidget {
  const new({required this.sites, required this.current});

  final List<LiveSite> sites;
  final LiveSite current;

  @override
  State<_SitePickerBody> createState() => _SitePickerBodyState();
}

final class _SitePickerBodyState extends State<_SitePickerBody> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _name(BuildContext context, LiveSite site) =>
      site.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN');

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: PureTextField(
              key: const ValueKey('site-picker-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              placeholder: context.t.discovery.searchSite,
              prefix: const Icon(Icons.search_rounded, size: 18),
            ),
          ),
          Flexible(
            child: Builder(
              builder: (context) {
                final needle = _search.text.trim().toLowerCase();
                final visible = [
                  for (final site in widget.sites)
                    if (needle.isEmpty ||
                        site.manifest.id.contains(needle) ||
                        _name(context, site).toLowerCase().contains(needle))
                      site,
                ];
                if (visible.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.t.errors.notFound,
                      textAlign: TextAlign.center,
                      style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final site = visible[index];
                    final isCurrent = site.manifest.id == widget.current.manifest.id;
                    return PureListRow(
                      key: ValueKey('site-picker-${site.manifest.id}'),
                      leading: PlatformLogo(siteId: site.manifest.id),
                      title: _name(context, site),
                      trailing: isCurrent ? Icon(Icons.check_rounded, size: 20, color: theme.colors.primary) : null,
                      onTap: isCurrent ? null : () => Navigator.of(context).pop(site),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
