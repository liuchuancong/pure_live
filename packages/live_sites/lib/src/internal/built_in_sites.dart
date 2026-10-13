import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site.dart';
import 'package:live_sites/src/platforms/douyu/api/douyu_http.dart';
import 'package:live_sites/src/platforms/douyu/douyu_site.dart';
import 'package:live_sites/src/platforms/huya/api/huya_http.dart';
import 'package:live_sites/src/platforms/huya/huya_site.dart';

/// The single internal construction entry point for built-in sites.
///
/// Only platforms implemented against this contract belong here; an
/// unimplemented platform is not registered. The application composition
/// root calls this and hands the result to `LiveSiteRegistry`.
List<LiveSite> createBuiltInLiveSites({LiveHttp? http}) {
  final transport = http ?? DioFactory().create();
  return <LiveSite>[DouyuSite(http: DouyuHttp(transport)), HuyaSite(http: HuyaHttp(transport))];
}
