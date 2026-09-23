class ReleaseModel {
  final String version;
  final String title;
  final String date;
  final String github;
  final AuthorModel author;
  final String changelog;
  final List<ReleaseFileModel> files;

  ReleaseModel({
    required this.version,
    required this.title,
    required this.date,
    required this.github,
    required this.author,
    required this.changelog,
    required this.files,
  });

  factory ReleaseModel.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'] ?? json['assets'];
    final filesData = rawFiles is List ? rawFiles : const <dynamic>[];

    final authorData = json['author'] is Map ? Map<String, dynamic>.from(json['author'] as Map) : <String, dynamic>{};

    return ReleaseModel(
      version: _string(json['version'] ?? json['tagName']),
      title: _string(json['title'] ?? json['name']),
      date: _string(json['date'] ?? json['publishedAt']),
      github: _string(json['github'] ?? json['url']),
      author: AuthorModel(
        name: _string(authorData['name'] ?? authorData['login']),
        avatar: _string(authorData['avatar'] ?? authorData['avatar_url']),
        profile: _string(authorData['profile'] ?? authorData['html_url']),
      ),
      changelog: _string(json['changelog'] ?? json['body']),
      files: filesData.whereType<Map>().map((e) => ReleaseFileModel.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'title': title,
      'date': date,
      'github': github,
      'author': author.toJson(),
      'changelog': changelog,
      'files': files.map((e) => e.toJson()).toList(),
    };
  }
}

class AuthorModel {
  final String name;
  final String avatar;
  final String profile;

  AuthorModel({required this.name, required this.avatar, required this.profile});

  factory AuthorModel.fromJson(Map<String, dynamic> json) {
    return AuthorModel(
      name: _string(json['name'] ?? json['login']),
      avatar: _string(json['avatar'] ?? json['avatar_url']),
      profile: _string(json['profile'] ?? json['html_url']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'avatar': avatar, 'profile': profile};
  }
}

class ReleaseFileModel {
  final String name;
  final String size;
  final int downloads;
  final String url;

  ReleaseFileModel({required this.name, required this.size, required this.downloads, required this.url});

  factory ReleaseFileModel.fromJson(Map<String, dynamic> json) {
    return ReleaseFileModel(
      name: _string(json['name']),
      size: _formatSize(json['size']),
      downloads: _int(json['downloads'] ?? json['downloadCount']),
      url: _string(json['url'] ?? json['browser_download_url']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'size': size, 'downloads': downloads, 'url': url};
  }
}

String _string(Object? value) {
  if (value == null) return '';
  return value.toString().trim();
}

int _int(Object? value) {
  return switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text.trim()) ?? 0,
    _ => 0,
  };
}

/// Normalizes size to a human-readable string.
///
/// GitHub API returns the size in bytes as a number.
/// The custom format already returns a formatted string like "120.42mb".
String _formatSize(Object? value) {
  if (value == null) return '0.0mb';
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '0.0mb' : trimmed;
  }
  if (value is num) {
    return '${(value / (1024 * 1024)).toStringAsFixed(2)}mb';
  }
  return value.toString();
}
