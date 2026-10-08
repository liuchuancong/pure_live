class FontModel {
  final String id;
  final String name;
  final List<String> files;
  final String desc;
  final String official;
  final Map<String, dynamic> license;

  FontModel({
    required this.id,
    required this.name,
    required this.files,
    required this.desc,
    required this.official,
    required this.license,
  });

  factory FontModel.fromJson(Map<String, dynamic> json) {
    return FontModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      files: (json['files'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      desc: json['desc'] as String? ?? '',
      official: json['official'] as String? ?? '',
      license: json['license'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'files': files, 'desc': desc, 'official': official, 'license': license};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FontModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
