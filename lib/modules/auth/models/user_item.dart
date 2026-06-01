class UserItem {
  final String uid;
  final String email;
  bool canUpload; // 用户能否上传（由 /users/uid 下的 canUpload 决定）
  String role; // 角色身份：'admin' | 'manager' | 'user'

  UserItem({required this.uid, required this.email, required this.canUpload, required this.role});
}
