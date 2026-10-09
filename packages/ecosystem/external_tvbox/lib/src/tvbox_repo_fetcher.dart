// Module: lib/src/tvbox_repo_fetcher.dart
// Purpose: Turns a multi-repo into parsed single repos, one fetch per url,
// failures kept per url.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/sources/vod/tvbox.md - "解析失败逐源隔离,不影响仓内其他源". A
// multi-repo names other repos; this fetcher resolves them one at a time with
// a bounded count so one giant storeHouse cannot hold the import hostage.

import 'package:pure_live_network/pure_live_network.dart';

import 'tvbox_repository.dart';

/// One successfully parsed repo, with the url it came from.
final class FetchedTvBoxRepo {
  const FetchedTvBoxRepo({required this.url, required this.config});

  final Uri url;
  final TvBoxConfig config;
}

/// One repo that could not be fetched or parsed.
final class FailedTvBoxRepo {
  const FailedTvBoxRepo({required this.url, required this.error});

  final Uri url;
  final String error;
}

/// The whole multi-repo run.
final class TvBoxMultiRepoResult {
  const TvBoxMultiRepoResult({required this.repos, required this.failures});

  final List<FetchedTvBoxRepo> repos;
  final List<FailedTvBoxRepo> failures;

  bool get isAllFailed => repos.isEmpty;
}

/// Fetches and parses the repos a multi-repo names.
final class TvBoxRepoFetcher {
  TvBoxRepoFetcher({NetworkClient? client, this.maxRepos = 32, this.perRepoTimeout = const Duration(seconds: 15)})
    : _client = client ?? NetworkClient();

  final NetworkClient _client;
  final int maxRepos;
  final Duration perRepoTimeout;

  /// Fetches every url in [repo]. Relative urls are resolved against
  /// [baseUrl] - the multi-repo's own location - because TVBox configs write
  /// sibling paths. A url that nests another multi-repo is not followed: one
  /// level of indirection is the documented shape, and unbounded recursion is
  /// how a hostile config becomes a fetch loop.
  Future<TvBoxMultiRepoResult> fetch(TvBoxMultiRepo repo, {Uri? baseUrl}) async {
    final repos = <FetchedTvBoxRepo>[];
    final failures = <FailedTvBoxRepo>[];
    var seen = 0;
    for (final url in repo.repoUrls) {
      if (seen >= maxRepos) {
        failures.add(FailedTvBoxRepo(url: url, error: 'skipped: the multi-repo cap is $maxRepos'));
        continue;
      }
      seen++;
      final resolved = baseUrl == null ? url : baseUrl.resolveUri(url);
      try {
        final response = await _client
            .get(resolved.toString(), headers: const <String, String>{'accept': '*/*'})
            .timeout(perRepoTimeout);
        final status = response.statusCode ?? 0;
        if (status < 200 || status >= 300) {
          failures.add(FailedTvBoxRepo(url: url, error: 'status $status'));
          continue;
        }
        final config = const TvBoxConfigParser().parse(response.data ?? '');
        repos.add(FetchedTvBoxRepo(url: url, config: config));
      } catch (error) {
        failures.add(FailedTvBoxRepo(url: url, error: '$error'));
      }
    }
    return TvBoxMultiRepoResult(repos: repos, failures: failures);
  }

  void dispose() => _client.close();
}
