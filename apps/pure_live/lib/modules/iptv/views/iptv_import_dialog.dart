import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:pure_live/app/app.dart' show RouteNames;
import 'package:pure_live/modules/iptv/controllers/iptv_import_flow.dart';

/// Opens the import page as [launch] says.
///
/// Every import — a playlist or a guide, from an address, a file, pasted
/// text, a phone or an Xtream account — goes through the one page, so each
/// is previewed before anything is written.
Future<void> openIptvImport(BuildContext context, IptvImportLaunch launch) =>
    context.push<void>(RouteNames.iptvImport, extra: launch);

/// Opens the import page on a playlist; [origin] chooses where it reads
/// from.
Future<void> runIptvPlaylistImport(BuildContext context, {IptvImportOrigin? origin}) =>
    openIptvImport(context, IptvImportLaunch(origin: origin));

/// Opens the import page on a guide.
Future<void> runIptvGuideImport(BuildContext context) =>
    openIptvImport(context, const IptvImportLaunch(kind: IptvImportKind.guide));
