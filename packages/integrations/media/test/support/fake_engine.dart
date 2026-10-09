// Module: test/support/fake_engine.dart
// Purpose: The fake backend both media tests register, so one kernel harness serves them all.
// Author: liuchuancong
// Created: 2026-10-09
import 'package:media_core/media_core.dart' as core;
import 'package:media_core/testing/library.dart' as doubles;

/// Hands the kernel a fresh fake adapter and keeps the ones it built.
class FakeEngineFactory implements core.PlayerAdapterFactory {
  FakeEngineFactory(this.created);

  final List<doubles.FakePlayerAdapter> created;

  @override
  core.PlayerAdapter create(String id) {
    final adapter = doubles.FakePlayerAdapter(id: id);
    created.add(adapter);
    return adapter;
  }

  @override
  bool supports(String id) => true;
}

/// What the fake engine can do. Native composite support is what lets a multi-essence source through the
/// planner; drop it and the same source is refused before any adapter exists.
const core.PlayerAdapterCapabilities fakeEngineCapabilities = core.PlayerAdapterCapabilities(
  supportsLive: true,
  supportsSeek: true,
  supportsPause: true,
  supportsStop: true,
  supportsVolumeControl: true,
  supportedProtocols: <String>{'http', 'https'},
  supportedFormats: <String>{'hls', 'dash', 'mp4'},
  compositeSupport: core.CompositeSupport.native,
);

/// A kernel with exactly one fake backend registered, id `fake`.
core.PlayerKernel fakeEngineKernel({
  required List<doubles.FakePlayerAdapter> created,
  core.PlayerAdapterCapabilities capabilities = fakeEngineCapabilities,
  String backendId = 'fake',
}) {
  final kernel = core.PlayerKernel();
  kernel.registerBackend(
    core.PlayerAdapterRegistration(id: backendId, factory: FakeEngineFactory(created), capabilities: capabilities),
  );
  return kernel;
}
