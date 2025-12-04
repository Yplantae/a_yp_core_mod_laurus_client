import 'package:cloud_firestore/cloud_firestore.dart';

/// [PermissionType]
enum PermissionType {
  general, department, taskForce, projectTeam, info
}

/// [PermissionStatus]
enum PermissionStatus {
  active, hidden, archived, deleted
}

/// [PermissionModel]
class PermissionModel {
  final String permissionId;
  final String projectId;
  final String? parentId; // Root인 경우 null 혹은 empty

  final String title;
  final String description;
  final String? iconUrl;

  final PermissionType type;
  final PermissionStatus status;

  final int sortOrder; // 정렬 핵심 필드
  final int permissionLevel;
  final String permissionLabel;

  final List<String> memberIds;

  final DateTime createdAt;
  final DateTime updatedAt;

  const PermissionModel({
    required this.permissionId,
    required this.projectId,
    this.parentId,
    required this.title,
    required this.description,
    this.iconUrl,
    required this.type,
    required this.status,
    required this.sortOrder,
    required this.permissionLevel,
    required this.permissionLabel,
    required this.memberIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PermissionModel.fromJson(Map<String, dynamic> json, String docId) {
    return PermissionModel(
      permissionId: docId,
      projectId: json['projectId'] as String? ?? '',
      parentId: json['parentId'] as String?,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      iconUrl: json['iconUrl'] as String?,
      type: PermissionType.values.firstWhere(
              (e) => e.name == json['type'], orElse: () => PermissionType.general),
      status: PermissionStatus.values.firstWhere(
              (e) => e.name == json['status'], orElse: () => PermissionStatus.active),
      sortOrder: json['sortOrder'] as int? ?? 0,
      permissionLevel: json['permissionLevel'] as int? ?? 1000,
      permissionLabel: json['permissionLabel'] as String? ?? 'Member',
      memberIds: (json['memberIds'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'projectId': projectId,
      'parentId': parentId,
      'title': title,
      'description': description,
      'iconUrl': iconUrl,
      'type': type.name,
      'status': status.name,
      'sortOrder': sortOrder,
      'permissionLevel': permissionLevel,
      'permissionLabel': permissionLabel,
      'memberIds': memberIds,
      'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  PermissionModel copyWith({
    String? title,
    String? description,
    String? parentId,
    String? iconUrl,
    PermissionType? type,
    PermissionStatus? status,
    int? sortOrder,
    int? permissionLevel,
    String? permissionLabel,
    List<String>? memberIds,
  }) {
    return PermissionModel(
      permissionId: this.permissionId,
      projectId: this.projectId,
      parentId: parentId ?? this.parentId,
      title: title ?? this.title,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      type: type ?? this.type,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      permissionLevel: permissionLevel ?? this.permissionLevel,
      permissionLabel: permissionLabel ?? this.permissionLabel,
      memberIds: memberIds ?? this.memberIds,
      createdAt: this.createdAt,
      updatedAt: DateTime.now(),
    );
  }
}