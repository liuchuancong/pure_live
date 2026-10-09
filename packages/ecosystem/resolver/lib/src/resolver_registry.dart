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
    final candidates = _registry.candidatesFor(request.ref);
    if (candidates.isEmpty) {
      throw ResolverException.unsupported(request.ref);
    }

    ResolverException? firstFailure;

    for (final resolver in candidates) {
      try {
        final result = await resolver.resolve(request);
        if (!result.isEmpty) {
          return result;
        }
        firstFailure ??= ResolverException.failed(
          request.ref.contentId,
          '${resolver.descriptor.id} returned no tickets',
        );
      } on ResolverException catch (error) {
        if (error.isCancellation) {
          rethrow;
        }
        firstFailure ??= error;
        if (!request.allowFallback) {
          throw error;
        }
      } catch (error) {
        // A resolver that threw a foreign type is still a failed candidate; the caller should not have to
        // know which exception a third-party runtime chose.
        firstFailure ??= ResolverException.failed(request.ref.contentId, error);
        if (!request.allowFallback) {
          rethrow;
        }
      }
      if (!request.allowFallback) {
        break;
      }
    }

    // Every candidate was tried and none produced a ticket. The first refusal explains it best: the later
    // ones are usually the same network or the same missing kind.
    throw firstFailure ?? ResolverException.failed(request.ref.contentId, 'every candidate returned nothing');
  }
}
