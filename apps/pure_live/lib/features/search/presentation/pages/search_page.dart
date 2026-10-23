import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/i18n/translations.g.dart';

/// The search branch: the query field and, once the sites are wired in, the
/// results.
final class SearchPage extends ConsumerStatefulWidget {
  /// The search page.
  const new({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

final class _SearchPageState extends ConsumerState<SearchPage> {
  @override
  Widget build(BuildContext context) {
    final typography = DsTheme.of(context).typography;
    return Align(
      alignment: Alignment.topLeft,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DsSearchField(placeholder: t.search.hint),
          const SizedBox(height: 16),
          Text(t.search.empty, style: typography.body.copyWith(color: DsTheme.colorsOf(context).textMuted)),
        ],
      ),
    );
  }
}
