import 'package:live_iptv/src/guide/epg_guide/epg_guide.dart';
import 'package:live_iptv/src/guide/guide_parser/guide_parser.dart';
import 'package:live_iptv/src/guide/xmltv_parser/xmltv_parser.dart';
import 'package:live_iptv/src/import/iptv_importer.dart';

/// Reads a programme guide into an [EpgGuide].
///
/// [parseXmltv] is for text already in hand — a file the user picked, a
/// string the application downloaded itself. [fetchGuide] reads a remote
/// address over the importer's [IptvBytesFetcher] seam, wired at the
/// composition root with `iptvBytesFetcherFor`, so a gzipped guide and a
/// plain one are the same call and the download goes out with the client
/// the rest of the app uses.
final class EpgParser {
  /// A parser over [fetchBytes].
  new({required this.fetchBytes});

  /// How remote guides are downloaded.
  final IptvBytesFetcher fetchBytes;

  /// Parses [xml] as XMLTV: each `programme` becomes one entry with its
  /// channel id, start and stop, title and description.
  ///
  /// A programme missing an id, a title, or a usable start or stop is
  /// dropped rather than failing the file; a malformed document throws a
  /// [FormatException], because a broken download must not be mistaken for
  /// an empty guide.
  static EpgGuide parseXmltv(String xml) => EpgGuide.fromParsed(XmltvParser.parse(xml));

  /// Downloads [url] and parses it as a guide.
  ///
  /// The bytes are inflated when they carry the gzip magic and decoded as
  /// UTF-8 otherwise ([decodeGuideBytes]), and the format is detected from
  /// the text ([parseGuide]) — an XMLTV guide and the JSON shape some APIs
  /// serve are the same call. Malformed content throws a [FormatException];
  /// network failures propagate to the caller.
  Future<EpgGuide> fetchGuide(Uri url, {Map<String, String> headers = const {}}) async {
    final bytes = await fetchBytes(url, headers: headers);
    return EpgGuide.fromParsed(parseGuide(decodeGuideBytes(bytes)));
  }
}
