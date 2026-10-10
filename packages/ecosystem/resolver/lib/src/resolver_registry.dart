// Module: lib/src/resolver_registry.dart
// Purpose: Resolver discovery (who can serve this content, in what order) and the candidate chain.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/contracts/platform-contracts.md section 12 ("注册与候选选择经 ResolverRegistry") and
// docs/media/recovery.md's ladder: line fallback happens inside one source, resolver fallback is the next
// source down, and the chain is where the second one is decided.

import 'package:pure_live_platform/pure_live_platform.dart';

import 'resolver.dart';

/// The resolvers this build knows about.
final class ResolverRegistry {
  ResolverRegistry([Iterable<Resolver> resolvers = const <Resolver>[]]) : _resolvers = List<Resolver>.of(resolvers);

  final List<Resolver> _resolvers;

  List<Resolver> get all => List<Resolver>.unmodifiable(_resolvers);

  /// Adds a resolver, replacing any that already claims the same id.
  ///
  /// A replacement lands at the end of the list, so it keeps a tie only against resolvers registered before
  /// it was re-declared; a host that must win the tie gives the replacement a higher priority.
  void register(Resolver resolver) {
    _resolvers
      ..removeWhere((existing) => existing.descriptor.id == resolver.descriptor.id)
      ..add(resolver);
  }

  void unregister(ResolverId id) => _resolvers.removeWhere((resolver) => resolver.descriptor.id == id);

  Resolver? byId(ResolverId id) {
    for (final resolver in _resolvers) {
      if (resolver.descriptor.id == id) {
        return resolver;
      }
    }
    return null;
  }

  /// Everything that says it can serve [ref], highest priority first.
  ///
  /// A tie is broken by insertion order on purpose, so a host that registers its preferred source first
  /// keeps getting it first without having to assign numbers. That needs an explicit index: `List.sort` is
  /// not stable in Dart, so sorting on priority alone would shuffle equal-priority candidates.
  List<Resolver> candidatesFor(ContentRef ref) {
    final matched = <_Ranked>[];
    for (var index = 0; index < _resolvers.length; index++) {
      final resolver = _resolvers[index];
      if (resolver.canResolve(ref)) {
        matched.add(_Ranked(index: index, resolver: resolver));
      }
    }
    matched.sort((a, b) {
      final byPriority = b.resolver.descriptor.priority.compareTo(a.resolver.descriptor.priority);
      return byPriority != 0 ? byPriority : a.index.compareTo(b.index);
    });
    return matched.map((ranked) => ranked.resolver).toList(growable: false);
  }
}

final class _Ranked {
  const _Ranked({required this.index, required this.resolver});

  final int index;
  final Resolver resolver;
}

/// Walks the registered candidates until one produces tickets.
final class ResolverChain {
  ResolverChain({required ResolverRegistry registry}) : _registry = registry;

  final ResolverRegistry _registry;

  /// Resolves [request], falling back to the next candidate unless the request forbids it.
  ///
  /// `allowFallback == false` is a real instruction, not a preference: a caller that is refreshing the
  /// *same* source during playback does not want a silent jump to another one mid-stream, because the
  /// line it chose carried its subtitles and its quality promise.
  Future<ResolveResult> resolve(ResolveRequest request) async {
    final outcome = await resolveReported(request);
    if (outcome.result != null) {
      return outcome.result!;
    }
    throw outcome.error ?? ResolverException.unsupported(request.ref);
  }

  /// The same walk, keeping every attempt.
  ///
  /// The failure sheet needs more than the first error: "试了 4 个源都不行" is only actionable when it says
  /// which four and what each did (timed out, refused the kind, returned nothing). Returns a reported
  /// failure instead of throwing so the caller can show the attempts and the error together.
  Future<ChainReport> resolveReported(ResolveRequest request) async {
    final watch = Stopwatch()..start();
    final candidates = _registry.candidatesFor(request.ref);
    if (candidates.isEmpty) {
      return ChainReport(
        request: request,
        attempts: const <ChainAttempt>[],
        error: ResolverException.unsupported(request.ref),
      );
    }

    final attempts = <ChainAttempt>[];
    ResolverException? firstFailure;
    ResolveResult? winner;
    var index = 0;

    for (final resolver in candidates) {
      final started = DateTime.now().microsecondsSinceEpoch;
      index++;
      try {
        final result = await resolver.resolve(request);
        final took = Duration(microseconds: DateTime.now().microsecondsSinceEpoch - started);
        if (!result.isEmpty) {
          attempts.add(
            ChainAttempt(
              resolverId: resolver.descriptor.id,
              position: index,
              outcome: ChainAttemptOutcome.succeeded,
              elapsed: took,
            ),
          );
          winner = result;
          break;
        }
        firstFailure ??= ResolverException.failed(
          request.ref.contentId,
          '${resolver.descriptor.id} returned no tickets',
        );
        attempts.add(
          ChainAttempt(
            resolverId: resolver.descriptor.id,
            position: index,
            outcome: ChainAttemptOutcome.empty,
            elapsed: took,
            detail: 'answered with no tickets',
          ),
        );
      } on ResolverException catch (error) {
        final took = Duration(microseconds: DateTime.now().microsecondsSinceEpoch - started);
        if (error.isCancellation) {
          attempts.add(
            ChainAttempt(
              resolverId: resolver.descriptor.id,
              position: index,
              outcome: ChainAttemptOutcome.cancelled,
              elapsed: took,
            ),
          );
          return ChainReport(request: request, attempts: attempts, error: error);
        }
        firstFailure ??= error;
        attempts.add(
          ChainAttempt(
            resolverId: resolver.descriptor.id,
            position: index,
            outcome: ChainAttemptOutcome.failed,
            elapsed: took,
            code: error.code,
            detail: error.error.message,
          ),
        );
        if (!request.allowFallback) {
          break;
        }
      } catch (error) {
        final took = Duration(microseconds: DateTime.now().microsecondsSinceEpoch - started);
        // A resolver that threw a foreign type is still a failed candidate; the caller should not have to
        // know which exception a third-party runtime chose.
        firstFailure ??= ResolverException.failed(request.ref.contentId, error);
        attempts.add(
          ChainAttempt(
            resolverId: resolver.descriptor.id,
            position: index,
            outcome: ChainAttemptOutcome.failed,
            elapsed: took,
            detail: '$error',
          ),
        );
        if (!request.allowFallback) {
          // A caller that forbade fallback asked for *this* source's answer, so its own exception is the
          // answer: wrapping it here would hide a bridge bug behind a resolver code.
          rethrow;
        }
      }
      if (!request.allowFallback) {
        break;
      }
    }

    watch.stop();
    return ChainReport(
      request: request,
      attempts: List<ChainAttempt>.unmodifiable(attempts),
      result: winner,
      error: winner == null
          ? firstFailure ?? ResolverException.failed(request.ref.contentId, 'every candidate returned nothing')
          : null,
      elapsed: Duration(microseconds: watch.elapsedMicroseconds),
    );
  }
}

/// What one candidate did during a chain walk.
enum ChainAttemptOutcome { succeeded, failed, empty, cancelled }

/// One candidate's turn.
final class ChainAttempt {
  const ChainAttempt({
    required this.resolverId,
    required this.position,
    required this.outcome,
    required this.elapsed,
    this.code,
    this.detail,
  });

  final ResolverId resolverId;

  /// 1-based place in the candidate order, so a report can say "the third source timed out".
  final int position;
  final ChainAttemptOutcome outcome;
  final Duration elapsed;
  final String? code;
  final String? detail;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'resolver': resolverId,
      'position': position,
      'outcome': outcome.name,
      'elapsedMs': elapsed.inMilliseconds,
      if (code != null) 'code': code,
      if (detail != null) 'detail': detail,
    };
  }

  @override
  String toString() =>
      '$position.$resolverId ${outcome.name}(${elapsed.inMilliseconds}ms${code == null ? '' : ' $code'})';
}

/// The whole walk: what was tried, what won, and what to report when nothing did.
final class ChainReport {
  const ChainReport({
    required this.request,
    required this.attempts,
    this.result,
    this.error,
    this.elapsed = Duration.zero,
  });

  final ResolveRequest request;
  final List<ChainAttempt> attempts;
  final ResolveResult? result;
  final ResolverException? error;
  final Duration elapsed;

  bool get succeeded => result != null;

  /// How many candidates existed before the walk stopped early (a win, a cancellation, or no-fallback).
  int get triedCount => attempts.length;

  List<ChainAttempt> get failures =>
      attempts.where((attempt) => attempt.outcome != ChainAttemptOutcome.succeeded).toList(growable: false);

  @override
  String toString() =>
      'ChainReport(${succeeded ? 'ok' : 'failed'} after ${attempts.length} attempt(s) in '
      '${elapsed.inMilliseconds}ms${error == null ? '' : ', ${error!.code}'})';
}
