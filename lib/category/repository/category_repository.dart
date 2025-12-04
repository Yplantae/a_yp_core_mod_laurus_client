import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/category_models.dart';

class CategoryRepository {
  final FirebaseFirestore _firestore;
  final String projectId;

  CategoryRepository({
    required FirebaseFirestore firestore,
    required this.projectId,
  }) : _firestore = firestore;

  void _log(String method, String message) {
    debugPrint('[CategoryRepository][$method] $message');
  }

  CollectionReference<Map<String, dynamic>> _getCollection() {
    return _firestore
        .collection('laurus')
        .doc('test')
        .collection('projects')
        .doc(projectId)
        .collection('categorys');
  }

  /// [fetchAllCategorys]
  /// 정렬 순서(sortOrder)대로 가져와야 트리 구성 시 순서가 유지됨.
  Future<List<CategoryModel>> fetchAllCategorys() async {
    _log('fetchAllCategorys', 'Fetching with sortOrder...');
    try {
      final snapshot = await _getCollection().orderBy('sortOrder').get();
      return snapshot.docs
          .map((doc) => CategoryModel.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      _log('fetchAllCategorys', 'Error: $e');
      throw Exception('Failed to fetch categorys');
    }
  }

  Future<String> createCategory(CategoryModel category) async {
    try {
      final docRef = _getCollection().doc();
      await docRef.set(category.toJson());
      return docRef.id;
    } catch (e) {
      _log('createCategory', 'Error: $e');
      rethrow;
    }
  }

  Future<void> updateCategory(String categoryId, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _getCollection().doc(categoryId).update(data);
    } catch (e) {
      _log('updateCategory', 'Error: $e');
      rethrow;
    }
  }

  /// [updateParentAndOrder]
  /// 이동 및 순서 변경의 핵심 메서드
  Future<void> updateParentAndOrder(String categoryId, String? newParentId, int newSortOrder) async {
    _log('updateParentAndOrder', 'ID: $categoryId -> Parent: $newParentId, Order: $newSortOrder');
    try {
      await _getCollection().doc(categoryId).update({
        'parentId': newParentId,
        'sortOrder': newSortOrder,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _log('updateParentAndOrder', 'Error: $e');
      rethrow;
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      await _getCollection().doc(categoryId).delete();
    } catch (e) {
      _log('deleteCategory', 'Error: $e');
      rethrow;
    }
  }
}