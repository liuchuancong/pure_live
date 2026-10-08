// Module: test/models/source_and_diagnostics_test.dart
// Purpose: Verify source, extension, runtime, repository and diagnostics rules from platform-models sections 4 to 14.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

void main() {
  test('test_sourceConfig_defaults_matchTheSpec', () {
    const config = SourceConfig();

    expect(config.enabled, isTrue);
    expect(config.refreshInterval, const Duration(hours: 6));
    expect(config.headers, isEmpty);
  });

  test('test_sourceConfig_fromJson_appliesDefaultsToMissingKeys', () {
    final config = SourceConfig.fromJson(const <String, Object?>{});

    expect(config.enabled, isTrue);
    expect(config.refreshInterval, const Duration(hours: 6));
  });

  test('test_sourceDescriptor_jsonRoundTrip_keepsRuntimeAndExtension', () {
    const source = SourceDescriptor(
      id: 'src-1',
      extensionId: 'tvbox',
      runtimeId: 'pure_live_tvbox_runtime',
      uri: 'https://example.com/api.json',
      type: SourceType.url,
      name: 'Demo',
      config: SourceConfig(headers: <String, String>{'Referer': 'https://example.com/'}),
    );

    final decoded = SourceDescriptor.fromJson(source.toJson());
    expect(decoded.runtimeId, 'pure_live_tvbox_runtime');
    expect(decoded.extensionId, 'tvbox');
    expect(decoded.name, 'Demo');
    expect(decoded.config.headers['Referer'], 'https://example.com/');
  });

  test('test_sourceDescriptor_equal_ignoresConfigChanges', () {
    // Enabling or refreshing a source is not a change of identity.
    const base = SourceDescriptor(
      id: 's',
      extensionId: 'e',
      runtimeId: 'r',
      uri: 'u',
      type: SourceType.url,
    );
    const edited = SourceDescriptor(
      id: 's',
      extensionId: 'e',
      runtimeId: 'r',
      uri: 'u',
      type: SourceType.url,
      config: SourceConfig(enabled: false),
    );

    expect(base, equals(edited));
  });

  test('test_sourceStatus_json_keepsTimestampsInUtc', () {
    final status = SourceStatus(
      state: SourceState.ready,
      lastUpdatedAt: DateTime.utc(2026, 10, 8, 1),
    );
    final decoded = SourceStatus.fromJson(status.toJson());

    expect(decoded.lastUpdatedAt, DateTime.utc(2026, 10, 8, 1));
    expect(decoded.lastUpdatedAt!.isUtc, isTrue);
    // A null nextRefreshAt means "not scheduled", which is distinct from any state value.
    expect(decoded.nextRefreshAt, isNull);
    expect(decoded.state, SourceState.ready);
  });

  test('test_extensionDescriptor_jsonRoundTrip_keepsCapabilities', () {
    const descriptor = ExtensionDescriptor(
      id: 'tvbox-main',
      name: 'TVBox',
      version: '1.2.3',
      protocol: 'tvbox',
      protocolVersion: '3',
      platformApiVersion: '2',
      type: ExtensionType.external,
      capabilities: <ExtensionCapability>{ExtensionCapability.live, ExtensionCapability.vod},
      permissions: <Permission>{Permission.network, Permission.storage},
      metadata: ExtensionMetadata(author: 'someone', extra: <String, Object?>{'tvbox.jar': 'x'}),
    );

    final decoded = ExtensionDescriptor.fromJson(descriptor.toJson());
    expect(decoded.capabilities, descriptor.capabilities);
    expect(decoded.permissions, descriptor.permissions);
    expect(decoded.metadata.author, 'someone');
    expect(decoded.metadata.extra['tvbox.jar'], 'x');
    expect(decoded, descriptor);
  });

  test('test_extensionDescriptor_notEqual_whenProtocolVersionChanges', () {
    const base = ExtensionDescriptor(
      id: 'e',
      name: 'n',
      version: '1',
      protocol: 'tvbox',
      type: ExtensionType.external,
      protocolVersion: '3',
    );
    const newer = ExtensionDescriptor(
      id: 'e',
      name: 'n',
      version: '1',
      protocol: 'tvbox',
      type: ExtensionType.external,
      protocolVersion: '4',
    );

    expect(base, isNot(equals(newer)));
  });

  test('test_runtimeDescriptor_jsonRoundTrip_keepsProtocols', () {
    const runtime = RuntimeDescriptor(
      id: 'pure_live_tvbox_runtime',
      name: 'TVBox runtime',
      version: '1',
      protocols: <String>{'tvbox'},
      supportedTypes: <ExtensionType>{ExtensionType.external},
    );

    final decoded = RuntimeDescriptor.fromJson(runtime.toJson());
    expect(decoded.protocols, <String>{'tvbox'});
    expect(decoded.supportedTypes, <ExtensionType>{ExtensionType.external});
    expect(decoded, runtime);
  });

  test('test_runtimeStatus_fromJson_degradesUnknownHealthToUnavailable', () {
    final status = RuntimeStatus.fromJson(const <String, Object?>{'health': 'wobbly'});

    expect(status.health, RuntimeHealth.unavailable);
  });

  test('test_repositoryDescriptor_jsonRoundTrip_keepsParserAndCapabilities', () {
    const repository = RepositoryDescriptor(
      id: 'repo-1',
      sourceId: 'src-1',
      name: 'Demo repo',
      version: '1',
      parser: RepositoryParser.tvboxJson,
      capabilities: <RepositoryCapability>{RepositoryCapability.list, RepositoryCapability.resolve},
    );

    final decoded = RepositoryDescriptor.fromJson(repository.toJson());
    expect(decoded.parser, RepositoryParser.tvboxJson);
    expect(decoded.capabilities, repository.capabilities);
    expect(decoded, repository);
  });

  test('test_providerDescriptor_jsonRoundTrip_keepsType', () {
    const provider = ProviderDescriptor(
      id: 'p-1',
      repositoryId: 'repo-1',
      name: 'Live',
      type: ProviderType.live,
      version: '1',
    );

    expect(ProviderDescriptor.fromJson(provider.toJson()), provider);
  });

  test('test_platformErrorInfo_jsonRoundTrip_keepsCategoryAndMetadata', () {
    const error = PlatformErrorInfo(
      code: PlatformErrorCodes.sourceParseFailed,
      message: 'jar entry rejected',
      category: PlatformErrorCategory.source,
      retryable: true,
      metadata: <String, Object?>{'tvbox.entry': 'cctv1'},
    );

    final decoded = PlatformErrorInfo.fromJson(error.toJson());
    expect(decoded.code, 'source.parse_failed');
    expect(decoded.category, PlatformErrorCategory.source);
    expect(decoded.retryable, isTrue);
    expect(decoded.recoverable, isFalse);
    expect(decoded.metadata['tvbox.entry'], 'cctv1');
    expect(decoded, error);
  });

  test('test_platformErrorInfo_fromJson_keepsNullCategory_whenWriterOmittedIt', () {
    // Section 16: a null means "the protocol did not say", which is not the same as "unknown".
    final decoded = PlatformErrorInfo.fromJson(const <String, Object?>{
      'code': 'media.unavailable',
      'message': 'gone',
    });

    expect(decoded.category, isNull);
  });

  test('test_platformErrorInfo_fromJson_degradesUnrecognisedCategory', () {
    final decoded = PlatformErrorInfo.fromJson(const <String, Object?>{
      'code': 'x.y',
      'message': 'm',
      'category': 'quantum',
    });

    expect(decoded.category, PlatformErrorCategory.unknown);
  });

  test('test_platformErrorInfo_fromJson_reportsTheMissingField', () {
    expect(
      () => PlatformErrorInfo.fromJson(const <String, Object?>{'message': 'no code'}),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'message',
        contains('platform_error_info is missing required field "code"'),
      )),
    );
  });

  test('test_diagnosticEvent_jsonRoundTrip_keepsCorrelationIds', () {
    final event = DiagnosticEvent(
      id: 'evt-1',
      timestamp: DateTime.utc(2026, 10, 8, 9, 30),
      level: DiagnosticLevel.warning,
      name: 'source.refresh',
      traceId: 'trace-1',
      sourceId: 'src-1',
      content: const ContentRef(sourceId: 'src-1', contentId: 'c', kind: ContentKind.liveChannel),
      metadata: const <String, Object?>{'attempt': 2},
    );

    final decoded = DiagnosticEvent.fromJson(event.toJson());
    expect(decoded.traceId, 'trace-1');
    expect(decoded.level, DiagnosticLevel.warning);
    expect(decoded.content!.sourceId, 'src-1');
    expect(decoded.metadata['attempt'], 2);
    expect(decoded.timestamp, event.timestamp);
  });

  test('test_diagnosticTrace_elapsed_isNullWhileOpen', () {
    final trace = DiagnosticTrace(id: 't', operation: 'play', startedAt: DateTime.utc(2026, 10, 8));

    expect(trace.elapsed, isNull);
    expect(trace.completedAt, isNull);
  });

  test('test_diagnosticTrace_elapsed_countsClosedDuration', () {
    final start = DateTime.utc(2026, 10, 8);
    final trace = DiagnosticTrace(
      id: 't',
      operation: 'play',
      startedAt: start,
      completedAt: start.add(const Duration(seconds: 3)),
    );

    expect(trace.elapsed, const Duration(seconds: 3));
  });

  test('test_diagnosticSpan_jsonRoundTrip_keepsStatus', () {
    final span = DiagnosticSpan(
      id: 'span-1',
      traceId: 'trace-1',
      operation: 'resolver.resolve',
      startedAt: DateTime.utc(2026, 10, 8),
      status: DiagnosticSpanStatus.failed,
    );

    final decoded = DiagnosticSpan.fromJson(span.toJson());
    expect(decoded.status, DiagnosticSpanStatus.failed);
    expect(decoded.traceId, 'trace-1');
  });
}
