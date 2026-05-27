class LiveTag {
  final String id;
  String name;
  String description;
  int order;
  bool isPinned;

  LiveTag({required this.id, required this.name, this.description = '', this.order = 0, this.isPinned = false});

  factory LiveTag.fromJson(Map<String, dynamic> json) {
    return LiveTag(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      order: json['order'] ?? 0,
      isPinned: json['isPinned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'order': order,
    'isPinned': isPinned,
  };
}
