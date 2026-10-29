import 'package:path/path.dart' as p;

/// The name an entry lands under: its own title plus whatever extension its
/// address carries, so the file system opens it by double click.
String wallpaperFileName({required String title, required String fallback, required String address}) {
  final extension = p.extension(Uri.tryParse(address)?.path ?? '').replaceFirst('.', '').toLowerCase();
  final cleaned = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  final base = cleaned.isEmpty ? fallback : cleaned;
  if (extension.isEmpty || base.toLowerCase().endsWith('.$extension')) return base;
  return '$base.$extension';
}
