import 'dart:async';

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

  Worker? _searchWorker;
  Timer? _searchTimer;
  int _searchVersion = 0;

  String get currentUserUid => Get.find<AuthController>().user!.uid;

  @override
  void onInit() {
    super.onInit();

    isSuperAdmin = FirebaseManager.getInstance().isAdmin();

    _fetchGlobalStats();

    _searchWorker = ever(rxSearchKeyword, (String keyword) {
      if (isClosed) return;

      final version = ++_searchVersion;
      _searchTimer?.cancel();

      _searchTimer = Timer(const Duration(milliseconds: 500), () => unawaited(_commitSearch(keyword, version)));
    });

    // BasePageView does not trigger the initial request.
    if (list.isEmpty && totalCount.value == null) {
      unawaited(refreshData());
    }
  }

  @override
  void onClose() {
    _searchVersion++;
    _searchTimer?.cancel();
    _searchWorker?.dispose();
    super.onClose();
  }

  /// The only entry point allowed to reset the cursor. The base class internally
  /// may call `fetchNetworkData` multiple times while assembling a single page,
  /// so its `page` argument does not represent "the user navigated to page N".
  /// Resetting based on `page == 1` inside `fetchNetworkData` would be incorrect.
  @override
  Future<void> refreshData() async {
    lastDocument = null;
    await super.refreshData();
  }

  Future<void> _commitSearch(String keyword, int version) async {
    while (!isClosed && version == _searchVersion) {
      final active = activePageOperation;
      if (active == null) break;
      await active;
    }

    if (isClosed || version != _searchVersion || keyword == searchKeyword) {
      return;
    }

    // Only the latest still-valid search intent may reset the directory.
    searchKeyword = keyword;
    await refreshData();
  }

  /// Global statistics. Reads the whole `users` and `permissions` collections
  /// once and tallies role counts locally so a missing role field falls back
  /// to `user` without an extra round trip.
  Future<void> _fetchGlobalStats() async {
    if (isClosed) return;

    try {
      final firestore = FirebaseFirestore.instance;

      final results = await Future.wait([
        firestore.collection('users').get(),
        firestore.collection('permissions').get(),
      ]);

      if (isClosed) return;

      final usersSnapshot = results[0];
      final permissionsSnapshot = results[1];

      var admin = 0;
      var manager = 0;
      var user = 0;

      final permissionRoles = <String, String>{};

      for (final doc in permissionsSnapshot.docs) {
        final data = doc.data();
        final role = (data['role'] as String?)?.trim();

        if (role != null && role.isNotEmpty) {
          permissionRoles[doc.id] = role;
        }
      }

      for (final doc in usersSnapshot.docs) {
        final role = permissionRoles[doc.id] ?? 'user';

        switch (role) {
          case 'admin':
            admin++;
            break;
          case 'manager':
            manager++;
            break;
          default:
            user++;
            break;
        }
      }

      if (isClosed) return;

      adminCount.value = admin;
      managerCount.value = manager;
      userCount.value = user;
      totalCount.value = usersSnapshot.docs.length;
    } catch (e, stackTrace) {
      Log.e('[UserMgr] failed to fetch global stats: $e', stackTrace);
    }
  }

  /// One query per call; the page-assembly loop is handled by the base class.
  /// Cursor always belongs to the `users` collection; role and `canUpload` are
  /// resolved per row from the optional `permissions` document.
  @override
  Future<List<UserItem>> fetchNetworkData(int page, int pageSize) async {
    if (isClosed) return [];

    final visibleRoles = FirebaseManager.getInstance().visibleRoles();

    if (visibleRoles.isEmpty) {
      return [];
    }

    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('users').orderBy('email').limit(pageSize);

    if (searchKeyword.isNotEmpty) {
      final start = searchKeyword.toLowerCase();

      final end = start.substring(0, start.length - 1) + String.fromCharCode(start.codeUnitAt(start.length - 1) + 1);

      q = q.where('email', isGreaterThanOrEqualTo: start).where('email', isLessThan: end);
    }

    final cursor = lastDocument;

    if (cursor != null) {
      q = q.startAfterDocument(cursor);
    }

    final snap = await q.get();

    if (isClosed) return [];

    if (snap.docs.isEmpty) {
      return [];
    }

    lastDocument = snap.docs.last;

    final selfUid = currentUserUid;

    final userDocs = snap.docs.where((doc) => doc.id != selfUid).toList(growable: false);

    if (userDocs.isEmpty) {
      return [];
    }

    // permissions/{uid} is optional.
    // A missing permissions document means the user is a normal user.
    final permissionDocs = <String, Map<String, dynamic>>{};

    for (var i = 0; i < userDocs.length; i += 30) {
      final batch = userDocs.skip(i).take(30).toList(growable: false);

      final futures = batch.map((doc) => FirebaseFirestore.instance.collection('permissions').doc(doc.id).get());

      final results = await Future.wait(futures);

      for (var j = 0; j < results.length; j++) {
        final permission = results[j];

        if (permission.exists) {
          permissionDocs[userDocs[i + j].id] = permission.data() ?? {};
        }
      }
    }

    final items = <UserItem>[];

    for (final doc in userDocs) {
      final data = doc.data();
      final permissionData = permissionDocs[doc.id];

      final role = (permissionData?['role'] as String?)?.trim().isNotEmpty == true
          ? (permissionData!['role'] as String).trim()
          : 'user';

      if (!visibleRoles.contains(role)) {
        continue;
      }

      final canUpload = permissionData?['canUpload'] != null
          ? permissionData!['canUpload'] != false
          : data['canUpload'] != false;

      items.add(UserItem(uid: doc.id, email: (data['email'] as String?) ?? '', canUpload: canUpload, role: role));
    }

    return items;
  }

  Future<void> refreshByKeyword(String keyword) async {
    if (isClosed || keyword == rxSearchKeyword.value) return;

    _searchVersion++;
    _searchTimer?.cancel();
    rxSearchKeyword.value = keyword;
  }

  Future<void> onConfigSaved(String docId, Map<String, dynamic> updateData) async {
    if (isClosed) return;

    await FirebaseFirestore.instance.collection('users').doc(docId).update(updateData);

    if (isClosed) return;

    await refreshData();
  }
}
