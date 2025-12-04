import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/group_models.dart';

class GroupRepository {
  final FirebaseFirestore _firestore;
  final String projectId;

  GroupRepository({
    required FirebaseFirestore firestore,
    required this.projectId,
  }) : _firestore = firestore;

  void _log(String method, String message) {
    debugPrint('[GroupRepository][$method] $message');
  }

  CollectionReference<Map<String, dynamic>> _getCollection() {
    return _firestore
        .collection('laurus')
        .doc('test')
        .collection('projects')
        .doc(projectId)
        .collection('groups');
  }

  /// [fetchAllGroups]
  /// 정렬 순서(sortOrder)대로 가져와야 트리 구성 시 순서가 유지됨.
  Future<List<GroupModel>> fetchAllGroups() async {
    _log('fetchAllGroups', 'Fetching with sortOrder...');
    try {
      final snapshot = await _getCollection().orderBy('sortOrder').get();
      return snapshot.docs
          .map((doc) => GroupModel.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      _log('fetchAllGroups', 'Error: $e');
      throw Exception('Failed to fetch groups');
    }
  }

  Future<String> createGroup(GroupModel group) async {
    try {
      final docRef = _getCollection().doc();
      await docRef.set(group.toJson());
      return docRef.id;
    } catch (e) {
      _log('createGroup', 'Error: $e');
      rethrow;
    }
  }

  Future<void> updateGroup(String groupId, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _getCollection().doc(groupId).update(data);
    } catch (e) {
      _log('updateGroup', 'Error: $e');
      rethrow;
    }
  }

  /// [updateParentAndOrder]
  /// 이동 및 순서 변경의 핵심 메서드
  Future<void> updateParentAndOrder(String groupId, String? newParentId, int newSortOrder) async {
    _log('updateParentAndOrder', 'ID: $groupId -> Parent: $newParentId, Order: $newSortOrder');
    try {
      await _getCollection().doc(groupId).update({
        'parentId': newParentId,
        'sortOrder': newSortOrder,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _log('updateParentAndOrder', 'Error: $e');
      rethrow;
    }
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      await _getCollection().doc(groupId).delete();
    } catch (e) {
      _log('deleteGroup', 'Error: $e');
      rethrow;
    }
  }
}