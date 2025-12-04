import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/member_models.dart';

/// [MemberRepository]
/// Firestore 의 Members Collection 에 대한 CRUD 를 담당.
class MemberRepository {
  final FirebaseFirestore _firestore;
  final String projectId;

  MemberRepository({
    required FirebaseFirestore firestore,
    required this.projectId,
  }) : _firestore = firestore;

  /// Collection Reference Helper
  CollectionReference<Map<String, dynamic>> _getCollection() {
    return _firestore.collection('laurus').doc('test').collection('projects').doc(projectId).collection('members');
  }

  /// [fetchMembersByStatus]
  /// 탭 전환 시 호출되는 1차 필터링 메서드.
  Future<List<MemberModel>> fetchMembersByStatus(MemberStatus status) async {
    final logPrefix = '[MemberRepository][fetchMembersByStatus]';
    debugPrint('$logPrefix Start fetching for Status: ${status.name} (Project: $projectId)');

    try {
      // 1. Status Based Query
      final querySnapshot = await _getCollection()
          .where('status', isEqualTo: status.name)
          .orderBy('joinedAt', descending: true)
          .get();

      debugPrint('$logPrefix Fetched ${querySnapshot.docs.length} docs.');

      // 2. Map to Model
      final members = querySnapshot.docs.map((doc) {
        return MemberModel.fromJson(doc.data(), doc.id);
      }).toList();

      return members;
    } catch (e, stack) {
      debugPrint('$logPrefix Error: $e\n$stack');
      throw Exception('Failed to fetch members: $e');
    }
  }

  /// [updateMemberStatus]
  /// 멤버 상태 변경
  Future<void> updateMemberStatus(String memberId, MemberStatus newStatus) async {
    final logPrefix = '[MemberRepository][updateMemberStatus]';
    debugPrint('$logPrefix ID: $memberId -> NewStatus: ${newStatus.name}');

    try {
      await _getCollection().doc(memberId).update({
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('$logPrefix Update Success.');
    } catch (e) {
      debugPrint('$logPrefix Error: $e');
      throw Exception('Failed to update status');
    }
  }
}