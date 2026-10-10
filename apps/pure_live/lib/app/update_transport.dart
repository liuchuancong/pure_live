// Module: lib/app/update_transport.dart
// Purpose: Bind pure_live_release's feed seam to the HTTP client the runtime owns.
// Author: liuchuancong
// Created: 2026-10-10
//
// release is an L0 package and its README forbids it depending on another foundation package, so the
// dependency direction is satisfied here: the composition root names the transport, the package stays pure
// decision logic over values the application supplies.

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_release/pure_live_release.dart';

/// Reads the release feed through [client].
///
/// The client is borrowed: the same one serves the extension gateway, so an update check that closed it would
/// take that connection pool down with it. The runtime owns its lifecycle.
final class NetworkUpdateFeedTransport implements UpdateFeedTransport {
  NetworkUpdateFeedTransport(this.client);

  final NetworkClient client;

  @override
  Future<UpdateFeedResponse> fetch(String url) async {
    final response = await client.get(url, headers: const <String, String>{'accept': 'application/json'});
    return UpdateFeedResponse(statusCode: response.statusCode ?? 0, body: response.data ?? '');
  }
}
