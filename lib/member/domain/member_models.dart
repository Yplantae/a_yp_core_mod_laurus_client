import 'package:flutter/foundation.dart';

/// [MemberStatus]
/// Member 의 수명 주기 및 상태를 정의하는 Enum.
enum MemberStatus {
  uninvited,
  invited,
  registrationPending,
  registrationCompleted,
  active, // 정상 활동
  warning,
  restricted,
  temporarySuspension,
  permanentSuspension,
  banned,
  deactivated, // 탈퇴
  retention, // 법적 보관
  deleted // 영구 삭제
}

/// [MemberModel]
/// Project Bounded Context 내에서 사용자를 정의하는 Core Entity.
class MemberModel {
  final String memberId; // UUID v4 (Document ID)
  final String uid; // Global User ID (Foreign Key)
  final String nickName;
  final String message;
  final List<String> profileImageUrls;
  final MemberStatus status;
  final int permissionLevel; // 1000 ~ 9000
  final String permissionLabel;
  final DateTime joinedAt;
  final List<String> groupIds; // 소속된 Group ID 목록

  const MemberModel({
    required this.memberId,
    required this.uid,
    required this.nickName,
    required this.message,
    required this.profileImageUrls,
    required this.status,
    required this.permissionLevel,
    required this.permissionLabel,
    required this.joinedAt,
    required this.groupIds,
  });

  /// Firestore Map -> Object 변환
  factory MemberModel.fromJson(Map<String, dynamic> json, String docId) {
    try {
      return MemberModel(
        memberId: docId,
        uid: json['uid'] as String? ?? '',
        nickName: json['nickName'] as String? ?? 'Unknown',
        message: json['message'] as String? ?? '',
        profileImageUrls: (json['profileImageUrls'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
            [],
        status: _parseStatus(json['status'] as String?),
        permissionLevel: json['permissionLevel'] as int? ?? 1000,
        permissionLabel: json['permissionLabel'] as String? ?? 'Member',
        joinedAt: json['joinedAt'] != null
            ? (json['joinedAt'] as dynamic).toDate()
            : DateTime.now(),
        groupIds: (json['groupIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
            [],
      );
    } catch (e, stack) {
      debugPrint('[MemberModel] Error parsing JSON for ID $docId: $e\n$stack');
      rethrow;
    }
  }

  /// Object -> Firestore Map 변환
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'nickName': nickName,
      'message': message,
      'profileImageUrls': profileImageUrls,
      'status': status.name,
      'permissionLevel': permissionLevel,
      'permissionLabel': permissionLabel,
      'joinedAt': joinedAt,
      'groupIds': groupIds,
    };
  }

  /// Enum Parsing Helper
  static MemberStatus _parseStatus(String? value) {
    if (value == null) return MemberStatus.uninvited;
    return MemberStatus.values.firstWhere(
          (e) => e.name == value,
      orElse: () => MemberStatus.uninvited,
    );
  }

  /// CopyWith 패턴 (상태 변경 시 불변성 유지)
  MemberModel copyWith({
    String? nickName,
    String? message,
    List<String>? profileImageUrls,
    MemberStatus? status,
    int? permissionLevel,
    String? permissionLabel,
    List<String>? groupIds,
  }) {
    return MemberModel(
      memberId: this.memberId,
      uid: this.uid,
      nickName: nickName ?? this.nickName,
      message: message ?? this.message,
      profileImageUrls: profileImageUrls ?? this.profileImageUrls,
      status: status ?? this.status,
      permissionLevel: permissionLevel ?? this.permissionLevel,
      permissionLabel: permissionLabel ?? this.permissionLabel,
      joinedAt: this.joinedAt,
      groupIds: groupIds ?? this.groupIds,
    );
  }
}