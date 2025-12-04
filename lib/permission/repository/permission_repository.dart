import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/permission_models.dart';

class PermissionRepository {
  final FirebaseFirestore _firestore;
  final String projectId;

  PermissionRepository({
    required FirebaseFirestore firestore,
    required this.projectId,
  }) : _firestore = firestore;

  void _log(String method, String message) {
    debugPrint('[PermissionRepository][$method] $message');
  }

  CollectionReference<Map<String, dynamic>> _getCollection() {
    return _firestore
        .collection('laurus')
        .doc('test')
        .collection('projects')
        .doc(projectId)
        .collection('permissions');
  }

  /// [fetchAllPermissions]
  /// 정렬 순서(sortOrder)대로 가져와야 트리 구성 시 순서가 유지됨.
  Future<List<PermissionModel>> fetchAllPermissions() async {
    _log('fetchAllPermissions', 'Fetching with sortOrder...');
    try {
      final snapshot = await _getCollection().orderBy('sortOrder').get();
      return snapshot.docs
          .map((doc) => PermissionModel.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      _log('fetchAllPermissions', 'Error: $e');
      throw Exception('Failed to fetch permissions');
    }
  }

  Future<String> createPermission(PermissionModel permission) async {
    try {
      final docRef = _getCollection().doc();
      await docRef.set(permission.toJson());
      return docRef.id;
    } catch (e) {
      _log('createPermission', 'Error: $e');
      rethrow;
    }
  }

  Future<void> updatePermission(String permissionId, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _getCollection().doc(permissionId).update(data);
    } catch (e) {
      _log('updatePermission', 'Error: $e');
      rethrow;
    }
  }

  /// [updateParentAndOrder]
  /// 이동 및 순서 변경의 핵심 메서드
  Future<void> updateParentAndOrder(String permissionId, String? newParentId, int newSortOrder) async {
    _log('updateParentAndOrder', 'ID: $permissionId -> Parent: $newParentId, Order: $newSortOrder');
    try {
      await _getCollection().doc(permissionId).update({
        'parentId': newParentId,
        'sortOrder': newSortOrder,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _log('updateParentAndOrder', 'Error: $e');
      rethrow;
    }
  }

  Future<void> deletePermission(String permissionId) async {
    try {
      await _getCollection().doc(permissionId).delete();
    } catch (e) {
      _log('deletePermission', 'Error: $e');
      rethrow;
    }
  }
}