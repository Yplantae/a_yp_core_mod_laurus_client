import 'package:cloud_firestore/cloud_firestore.dart';

/// [CategoryType]
enum CategoryType {
  general, department, taskForce, projectTeam, info
}

/// [CategoryStatus]
enum CategoryStatus {
  active, hidden, archived, deleted
}

/// [CategoryModel]
class CategoryModel {
  final String categoryId;
  final String projectId;
  final String? parentId; // Root인 경우 null 혹은 empty

  final String title;
  final String description;
  final String? iconUrl;

  final CategoryType type;
  final CategoryStatus status;

  final int sortOrder; // 정렬 핵심 필드
  final int permissionLevel;
  final String permissionLabel;

  final List<String> memberIds;

  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryModel({
    required this.categoryId,
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

  factory CategoryModel.fromJson(Map<String, dynamic> json, String docId) {
    return CategoryModel(
      categoryId: docId,
      projectId: json['projectId'] as String? ?? '',
      parentId: json['parentId'] as String?,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      iconUrl: json['iconUrl'] as String?,
      type: CategoryType.values.firstWhere(
              (e) => e.name == json['type'], orElse: () => CategoryType.general),
      status: CategoryStatus.values.firstWhere(
              (e) => e.name == json['status'], orElse: () => CategoryStatus.active),
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

  CategoryModel copyWith({
    String? title,
    String? description,
    String? parentId,
    String? iconUrl,
    CategoryType? type,
    CategoryStatus? status,
    int? sortOrder,
    int? permissionLevel,
    String? permissionLabel,
    List<String>? memberIds,
  }) {
    return CategoryModel(
      categoryId: this.categoryId,
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