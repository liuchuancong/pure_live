class ReleaseAssetUrls {
  const ReleaseAssetUrls({required this.assets});

  final List<Map<String, dynamic>> assets;

  /// Finds the best matching asset URL.
  ///
  /// [requiredKeywords] must all be present in the file name.
  /// [preferredKeywords] are used only for scoring, not for filtering.
  /// [extensions] restricts the allowed file extensions.
  String? _find({
    required List<String> requiredKeywords,
    List<String> preferredKeywords = const <String>[],
    List<String> extensions = const <String>[],
  }) {
    final candidates = <_AssetCandidate>[];

    for (final asset in assets) {
      final name = asset['name']?.toString().trim() ?? '';
      final url = asset['browser_download_url']?.toString().trim() ?? '';

      if (name.isEmpty || url.isEmpty) {
        continue;
      }

      // Only allow HTTPS download URLs.
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
        continue;
      }

      final lowerName = name.toLowerCase();
      final lowerUrl = url.toLowerCase();

      // The extension must match one of the allowed extensions.
      // Some release metadata stores the extension only in the download URL,
      // so check both the asset name and URL.
      if (extensions.isNotEmpty &&
          !extensions.any(
            (extension) => lowerName.endsWith(extension.toLowerCase()) || lowerUrl.endsWith(extension.toLowerCase()),
          )) {
        continue;
      }

      // Every required keyword must be present in the file name.
      if (!requiredKeywords.every((keyword) => lowerName.contains(keyword.toLowerCase()))) {
        continue;
      }

      var score = 0;

      // Add one point for each preferred keyword found.
      for (final keyword in preferredKeywords) {
        if (lowerName.contains(keyword.toLowerCase())) {
          score++;
        }
      }

      // Prefer release builds, but do not add this to preferredKeywords
      // to avoid double counting.
      if (lowerName.contains('release')) {
        score++;
      }

      candidates.add(_AssetCandidate(name: name, url: url, score: score));
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      // Higher score wins.
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }

      // Shorter names are usually the canonical asset names.
      final lengthCompare = a.name.length.compareTo(b.name.length);
      if (lengthCompare != 0) {
        return lengthCompare;
      }

      // Stable fallback for deterministic selection.
      return a.name.compareTo(b.name);
    });

    return candidates.first.url;
  }

  /// Android arm64-v8a APK.
  String? get androidArm64 => _find(
    requiredKeywords: const <String>['android', 'arm64-v8a'],
    preferredKeywords: const <String>['release'],
    extensions: const <String>['.apk'],
  );

  /// Android armeabi-v7a APK.
  String? get androidArmeabiV7a => _find(
    requiredKeywords: const <String>['android', 'armeabi-v7a'],
    preferredKeywords: const <String>['release'],
    extensions: const <String>['.apk'],
  );

  /// Android x86_64 APK.
  String? get androidX8664 => _find(
    requiredKeywords: const <String>['android', 'x86_64'],
    preferredKeywords: const <String>['release'],
    extensions: const <String>['.apk'],
  );

  /// Windows x64 setup executable.
  String? get windowsSetup => _find(
    requiredKeywords: const <String>['windows', 'setup'],
    preferredKeywords: const <String>['x64'],
    extensions: const <String>['.exe'],
  );

  /// Windows x64 MSIX package.
  String? get windowsMsix => _find(
    requiredKeywords: const <String>['windows', 'x64'],
    preferredKeywords: const <String>[],
    extensions: const <String>['.msix'],
  );

  /// Windows x64 portable ZIP.
  String? get windowsPortable => _find(
    requiredKeywords: const <String>['windows', 'portable'],
    preferredKeywords: const <String>['x64'],
    extensions: const <String>['.zip'],
  );

  /// macOS universal ZIP.
  String? get macosUniversalZip => _find(
    requiredKeywords: const <String>['macos', 'universal'],
    preferredKeywords: const <String>[],
    extensions: const <String>['.zip'],
  );

  /// macOS universal DMG.
  String? get macosUniversalDmg => _find(
    requiredKeywords: const <String>['macos', 'universal'],
    preferredKeywords: const <String>[],
    extensions: const <String>['.dmg'],
  );

  /// Prefers DMG first, then ZIP.
  /// Change the order if you want ZIP to be preferred.
  String? get macosUrl => macosUniversalDmg ?? macosUniversalZip;

  /// Linux x64 tar.gz.
  String? get linuxX64 => _find(
    requiredKeywords: const <String>['linux', 'x64'],
    preferredKeywords: const <String>[],
    extensions: const <String>['.tar.gz'],
  );

  /// iOS arm64 TrollStore IPA.
  String? get iosArm64TrollStore => _find(
    requiredKeywords: const <String>['ios', 'trollstore'],
    preferredKeywords: const <String>['arm64'],
    extensions: const <String>['.ipa'],
  );

  /// iOS arm64 unsigned app ZIP.
  String? get iosArm64UnsignedApp => _find(
    requiredKeywords: const <String>['ios', 'unsigned'],
    preferredKeywords: const <String>['arm64'],
    extensions: const <String>['.zip'],
  );

  /// Returns all resolved asset URLs.
  /// Each getter is called only once.
  Map<String, String> get all {
    final result = <String, String>{};

    void add(String key, String? value) {
      if (value != null) {
        result[key] = value;
      }
    }

    add('android-arm64-v8a', androidArm64);
    add('android-armeabi-v7a', androidArmeabiV7a);
    add('android-x86_64', androidX8664);
    add('windows-x64-setup.exe', windowsSetup);
    add('windows-x64.msix', windowsMsix);
    add('windows-x64-portable.zip', windowsPortable);
    add('macos-universal.dmg', macosUniversalDmg);
    add('macos-universal.zip', macosUniversalZip);
    add('linux-x64.tar.gz', linuxX64);
    add('ios-arm64-trollstore.ipa', iosArm64TrollStore);
    add('ios-arm64-unsigned-app.zip', iosArm64UnsignedApp);

    return result;
  }
}

class _AssetCandidate {
  const _AssetCandidate({required this.name, required this.url, required this.score});

  final String name;
  final String url;
  final int score;
}
