class PolicyModel {
  String owner;

  PolicyModel({this.owner = ''});

  factory PolicyModel.fromJson(Map<String, dynamic> json) {
    return PolicyModel(owner: json['owner_uid'] ?? json['owner'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'owner_uid': owner, 'owner': owner};
  }
}
