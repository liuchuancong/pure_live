import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/modules/auth/models/user_item.dart';
import 'package:pure_live/modules/auth/utils/firebase_manager.dart';

class UserServerRemoteController extends ServerRemotePageController<UserItem> {
  final rxSearchKeyword = "".obs;
  String searchKeyword = "";
  late bool isSuperAdmin;
  DocumentSnapshot? lastDocument;

  final adminCount = 0.obs;
  final managerCount = 0.obs;
  final userCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    isSuperAdmin = FirebaseManager.getInstance().isAdmin();
    _fetchGlobalStats();
    debounce(rxSearchKeyword, (String keyword) {
      searchKeyword = keyword;
      lastDocument = null;
      refreshData();
    }, time: const Duration(milliseconds: 500));
  }

  Future<void> _fetchGlobalStats() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final permissionsSnapshot = await FirebaseFirestore.instance.collection('permissions').get();
      final permissionRoleMap = {for (var doc in permissionsSnapshot.docs) doc.id: doc.data()['role'] ?? 'user'};

      int admins = 0;
      int managers = 0;
      int users = 0;

      for (var doc in usersSnapshot.docs) {
        String role = permissionRoleMap[doc.id] ?? 'user';
        int weight = FirebaseManager.roleWeights[role] ?? 2;
        if (weight == 0) admins++;
        if (weight == 1) managers++;
        if (weight == 2) users++;
      }

      adminCount.value = admins;
      managerCount.value = managers;
      userCount.value = users;
    } catch (e) {
      Log.d("获取全局统计失败: $e");
    }
  }

  Future<List<DocumentSnapshot>> _fetchRawChunkFromCloud(int limitCount) async {
    Query baseQuery = FirebaseFirestore.instance.collection('users');

    if (searchKeyword.isNotEmpty) {
      String start = searchKeyword.toLowerCase();
      String end = start.substring(0, start.length - 1) + String.fromCharCode(start.codeUnitAt(start.length - 1) + 1);
      baseQuery = baseQuery.where('email', isGreaterThanOrEqualTo: start).where('email', isLessThan: end);
    }

    baseQuery = baseQuery.orderBy('email').limit(limitCount);
    if (lastDocument != null) {
      baseQuery = baseQuery.startAfterDocument(lastDocument!);
    }

    final userSnapshot = await baseQuery.get();
    return userSnapshot.docs;
  }

  @override
  Future<List<UserItem>> fetchNetworkData(int page, int pageSize) async {
    final currentUserUid = Get.find<AuthController>().user!.uid;

    if (page == 1) {
      lastDocument = null;
    }

    List<UserItem> finalCleanList = [];
    List<DocumentSnapshot> allFetchedDocs = [];
    bool isCloudDrained = false;

    while (finalCleanList.length < pageSize && !isCloudDrained) {
      final int neededCount = pageSize - finalCleanList.length;
      final rawDocs = await _fetchRawChunkFromCloud(neededCount);

      if (rawDocs.isEmpty) {
        isCloudDrained = true;
        break;
      }

      lastDocument = rawDocs.last;
      allFetchedDocs.addAll(rawDocs);

      List<String> uidsInPage = rawDocs.map((doc) => doc.id).toList();
      Map<String, String> permissionRoleMap = {};

      final permissionsSnapshot = await FirebaseFirestore.instance
          .collection('permissions')
          .where(FieldPath.documentId, whereIn: uidsInPage)
          .get();
      for (var doc in permissionsSnapshot.docs) {
        permissionRoleMap[doc.id] = doc.data()['role'] ?? 'user';
      }

      for (var doc in rawDocs) {
        String uid = doc.id;
        if (uid == currentUserUid) continue;

        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        String email = data?['email'] ?? '';
        bool canUpload = data?['canUpload'] != false;
        String role = permissionRoleMap[uid] ?? 'user';

        if (!FirebaseManager.getInstance().canVisible(role)) continue;

        finalCleanList.add(UserItem(uid: uid, email: email, canUpload: canUpload, role: role));
      }

      if (rawDocs.length < neededCount) {
        isCloudDrained = true;
      }
    }

    finalCleanList.sort((a, b) {
      int weightA = FirebaseManager.roleWeights[a.role] ?? 2;
      int weightB = FirebaseManager.roleWeights[b.role] ?? 2;
      int cmp = weightA.compareTo(weightB);
      if (cmp == 0) return a.email.compareTo(b.email);
      return cmp;
    });

    if (finalCleanList.length > pageSize) {
      finalCleanList = finalCleanList.sublist(0, pageSize);

      int validDocIndex = -1;
      final lastValidItemUid = finalCleanList.last.uid;
      for (int i = 0; i < allFetchedDocs.length; i++) {
        if (allFetchedDocs[i].id == lastValidItemUid) {
          validDocIndex = i;
          break;
        }
      }
      if (validDocIndex != -1) {
        lastDocument = allFetchedDocs[validDocIndex];
      }
    }

    Log.d("获取用户列表成功: ${finalCleanList.length}");
    return finalCleanList;
  }

  Future<void> refreshByKeyword(String keyword) async {
    rxSearchKeyword.value = keyword;
  }

  Future<void> onConfigSaved(String docId, Map<String, dynamic> updateData) async {
    await FirebaseFirestore.instance.collection('users').doc(docId).update(updateData);
    await refreshData();
  }
}
