import 'package:cloud_firestore/cloud_firestore.dart';

/// Cloud mutations requested by the management UI. Presentation and route
/// lifetime are owned by the caller, not by the Firestore operation.
class UserManagementActions {
  const UserManagementActions();

  Future<void> deleteUser(String uid, {required bool deletePermission}) async {
    if (deletePermission) {
      await FirebaseFirestore.instance.collection('permissions').doc(uid).delete();
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
  }

  Future<void> promote(String uid, String email) => FirebaseFirestore.instance.collection('permissions').doc(uid).set({
    'canUpload': true,
    'role': 'manager',
    'email': email,
  });

  Future<void> demote(String uid) => FirebaseFirestore.instance.collection('permissions').doc(uid).delete();

  Future<void> setUpload(String uid, bool allowed) =>
      FirebaseFirestore.instance.collection('users').doc(uid).set({'canUpload': allowed}, SetOptions(merge: true));
}
