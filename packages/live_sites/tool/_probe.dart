import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';

Future<void> main() async {
  final http = DioFactory().create();
  final site = defaultSiteFactories(http)[SiteIds.yy]!();
  for (final keyword in ['星', '小', '舞蹈']) {
    final page = await site.searchRooms(keyword);
    final first = page.items.isEmpty
        ? '-'
        : '${page.items.first.roomId} | ${page.items.first.title} | ${page.items.first.nick} | ${page.items.first.status.name} | ${page.items.first.watching}';
    print('"$keyword": ${page.items.length} rooms | $first');
  }
}
