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
    final authorData = json['author'];
    final filesData = json['files'] ?? json['assets'];

    return ReleaseModel(
      version: _normalizeVersion(json['version'] ?? json['tagName']),
      title: _string(json['title'] ?? json['name']),
      date: _formatDate(json['date'] ?? json['publishedAt'] ?? json['published_at']),
      github: _string(json['github'] ?? json['url'] ?? json['htmlUrl'] ?? json['html_url']),
      author: authorData is Map
          ? AuthorModel.fromJson(Map<String, dynamic>.from(authorData))
          : AuthorModel.defaultAuthor(),
      changelog: _string(json['changelog'] ?? json['body']),
      files: filesData is List
          ? filesData.whereType<Map>().map((e) => ReleaseFileModel.fromJson(Map<String, dynamic>.from(e))).toList()
          : <ReleaseFileModel>[],
    );
  }
  static String _normalizeVersion(dynamic value) {
    final version = value?.toString().trim() ?? '';

    if (version.isEmpty) {
      return '';
    }

    return version.startsWith('v') ? version.substring(1) : version;
  }

  static String _string(dynamic value) {
    return value?.toString() ?? '';
  }

  static String _formatDate(dynamic value) {
    if (value == null) return '';

    final text = value.toString().trim();

    if (text.isEmpty) return '';

    final dateTime = DateTime.tryParse(text);

    if (dateTime == null) {
      return text;
    }

    final local = dateTime.toLocal();

    String two(int value) => value.toString().padLeft(2, '0');

    final date = '${local.year}-${two(local.month)}-${two(local.day)}';

    if (!text.contains('T') && !text.contains(' ') && !text.contains(':')) {
      return date;
    }

    return '$date '
        '${two(local.hour)}:'
        '${two(local.minute)}:'
        '${two(local.second)}';
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
      name: json['name'] ?? json['login'] ?? '',
      avatar: json['avatar'] ?? json['avatarUrl'] ?? json['avatar_url'] ?? '',
      profile: json['profile'] ?? json['htmlUrl'] ?? json['html_url'] ?? '',
    );
  }

  factory AuthorModel.defaultAuthor() {
    return AuthorModel(
      name: 'liuchuancong',
      avatar: 'https://avatars.githubusercontent.com/u/36957912?v=4',
      profile: 'https://github.com/liuchuancong',
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
      name: json['name']?.toString() ?? '',
      size: _formatSize(json['size']),
      downloads: _toInt(json['downloads'] ?? json['downloadCount'] ?? json['download_count']),
      url:
          json['url']?.toString() ??
          json['browserDownloadUrl']?.toString() ??
          json['browser_download_url']?.toString() ??
          '',
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _formatSize(dynamic value) {
    if (value == null) return '';

    if (value is String) {
      return value;
    }

    if (value is! num) {
      return value.toString();
    }

    final bytes = value.toDouble();

    if (bytes < 1024) {
      return '${bytes.toInt()} B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'size': size, 'downloads': downloads, 'url': url};
  }
}
