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
    return ReleaseModel(
      version: json['version'] ?? '',
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      github: json['github'] ?? '',
      author: AuthorModel.fromJson(json['author'] ?? {}),
      changelog: json['changelog'] ?? '',
      files: (json['files'] as List<dynamic>? ?? []).map((e) => ReleaseFileModel.fromJson(e)).toList(),
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
    return AuthorModel(name: json['name'] ?? '', avatar: json['avatar'] ?? '', profile: json['profile'] ?? '');
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
      name: json['name'] ?? '',
      size: json['size'] ?? '',
      downloads: json['downloads'] ?? 0,
      url: json['url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'size': size, 'downloads': downloads, 'url': url};
  }
}
