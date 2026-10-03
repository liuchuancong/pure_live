import 'package:media_core_ingest/media_core_ingest.dart';

IngestFfmpegStarter? _starter;

/// Installs the host's FFmpeg runtime for the ingest pipelines.
///
/// `media_core_ingest` deliberately ships no FFmpeg: the app already has one for
/// recording and conversion, and only the app knows how to start and stop it.
/// The registry keeps that wiring out of the ingest decision itself, so the
/// planner stays a pure function and this file stays the single seam.
void configureIngestFfmpegStarter(IngestFfmpegStarter? starter) => _starter = starter;

/// Whether an FFmpeg-backed ingest can run at all.
bool get ingestFfmpegAvailable => _starter != null;

/// Starts one FFmpeg ingest, or throws when no runtime is installed.
Future<IngestFfmpegProcess> startIngestFfmpeg(List<String> arguments) {
  final IngestFfmpegStarter? starter = _starter;
  if (starter == null) {
    throw StateError('No ingest FFmpeg runtime is installed');
  }
  return starter(arguments);
}
