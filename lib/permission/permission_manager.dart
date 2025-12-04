import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/foundation.dart';
import 'domain/permission_models.dart';
import 'repository/permission_repository.dart';

class PermissionManager extends ChangeNotifier {
  final PermissionRepository _repository;

  TreeNode<PermissionModel> _rootNode = TreeNode.root();
  bool _isLoading = false;
  PermissionModel? _selectedPermission;

  TreeNode<PermissionModel> get rootNode => _rootNode;
  bool get isLoading => _isLoading;
  PermissionModel? get selectedPermission => _selectedPermission;

  PermissionManager(this._repository);

  void _log(String method, String message) {
    debugPrint('[PermissionManager][$method] $message');
  }

  // ---------------------------------------------------------------------------
  // Tree Logging (Debugging)
  // ---------------------------------------------------------------------------
  void debugLogTree() {
    debugPrint('\n=== 🌳 [Tree Visual vs Model Log] ===');
    if (_rootNode.children.isEmpty) {
      debugPrint('   (Empty Tree)');
    } else {
      _recursiveLog(_rootNode, 0);
    }
    debugPrint('======================================\n');
  }

  void _recursiveLog(TreeNode<PermissionModel> node, int depth) {
    if (!node.isRoot) {
      final data = node.data;
      final indent = '   ' * depth;
      debugPrint('$indent[D:$depth] Order:${data?.sortOrder} | ${data?.title} | (${node.key})');
    }

    // [FIX]: children.values를 TreeNode<PermissionModel>로 명시적 캐스팅
    final sortedChildren = node.children.values.cast<TreeNode<PermissionModel>>().toList()
      ..sort((a, b) => (a.data!.sortOrder).compareTo(b.data!.sortOrder));

    for (final child in sortedChildren) {
      _recursiveLog(child, depth + 1);
    }
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      final allPermissions = await _repository.fetchAllPermissions();
      _buildTree(allPermissions);
      debugLogTree();
    } catch (e) {
      _log('initialize', 'Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _buildTree(List<PermissionModel> permissions) {
    _rootNode = TreeNode.root();
    final Map<String, TreeNode<PermissionModel>> nodeMap = {};

    for (final permission in permissions) {
      nodeMap[permission.permissionId] = TreeNode<PermissionModel>(key: permission.permissionId, data: permission);
    }

    for (final permission in permissions) {
      final node = nodeMap[permission.permissionId]!;
      if (permission.parentId == null || permission.parentId!.isEmpty) {
        _rootNode.add(node);
      } else {
        final parentNode = nodeMap[permission.parentId];
        if (parentNode != null) {
          parentNode.add(node);
        } else {
          _rootNode.add(node); // Orphan 처리
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Drag & Drop Logic (Midpoint & Rebalancing)
  // ---------------------------------------------------------------------------

  /// [Step 2 Constraint] Reparenting is logically disabled for flat structure.
  Future<void> reparentPermission(PermissionModel target, PermissionModel newParent) async {
    _log('reparentPermission', '⚠️ BLOCKED: Flat Tree Constraint enforced. Cannot nest ${target.title} under ${newParent.title}.');
    // 상호작용 제약에 의해 실제 Reparenting 로직은 실행되지 않아야 합니다.
    return;

    /* // Legacy Code Logic Blocked:
    if (target.permissionId == newParent.permissionId) return;
    try {
      final parentNode = _findNodeInTree(_rootNode, newParent.permissionId);
      // ... (기존 로직 생략 없이 유지하되 실행만 차단함)
    } catch (e) { ... }
    */
  }

  Future<void> reorderPermission(PermissionModel target, PermissionModel anchor, bool insertAfter) async {
    if (target.permissionId == anchor.permissionId) return;
    _log('reorderPermission', 'Moving ${target.title} ${insertAfter ? 'After' : 'Before'} ${anchor.title}');

    try {
      // Flat Tree 구조에서는 anchor.parentId가 항상 null(Root)일 가능성이 높으나,
      // 기존 로직은 유연하게 parentId를 추적하므로 그대로 유지합니다.
      final parentId = anchor.parentId;
      final parentNode = (parentId == null || parentId.isEmpty)
          ? _rootNode
          : _findNodeInTree(_rootNode, parentId);

      if (parentNode == null) {
        _log('reorderPermission', 'Parent node not found via ID lookup.');
        return;
      }

      // [FIX]: 캐스팅 후 정렬
      final siblings = parentNode.children.values.cast<TreeNode<PermissionModel>>().toList()
        ..sort((a, b) => (a.data!.sortOrder).compareTo(b.data!.sortOrder));

      int anchorIndex = siblings.indexWhere((n) => n.key == anchor.permissionId);
      if (anchorIndex == -1) return;

      int newOrder;

      if (insertAfter) {
        final currentOrder = anchor.sortOrder;
        if (anchorIndex < siblings.length - 1) {
          final nextNode = siblings[anchorIndex + 1];
          final nextOrder = nextNode.data!.sortOrder;
          newOrder = ((currentOrder + nextOrder) / 2).floor();
        } else {
          newOrder = currentOrder + 1000;
        }
      } else {
        final currentOrder = anchor.sortOrder;
        if (anchorIndex > 0) {
          final prevNode = siblings[anchorIndex - 1];
          final prevOrder = prevNode.data!.sortOrder;
          newOrder = ((prevOrder + currentOrder) / 2).floor();
        } else {
          newOrder = (currentOrder / 2).floor();
          if (newOrder < 1) newOrder = 1;
        }
      }

      _log('reorderPermission', 'Calculated Order: $newOrder (Anchor: ${anchor.sortOrder})');

      bool isCollision = siblings.any((n) => n.data!.sortOrder == newOrder && n.key != target.permissionId);
      bool isGapTooSmall = (anchor.sortOrder - newOrder).abs() < 1;
      bool isInitialCluster = (anchor.sortOrder == newOrder);

      if (isCollision || isGapTooSmall || isInitialCluster) {
        _log('reorderPermission', '⚠️ Collision/Cluster detected. Rebalancing...');
        await _rebalanceSiblings(parentNode, target, anchor, insertAfter);
      } else {
        await _repository.updateParentAndOrder(target.permissionId, parentId, newOrder);
        await initialize();
      }

    } catch (e) {
      _log('reorderPermission', 'Error: $e');
      rethrow;
    }
  }

  Future<void> _rebalanceSiblings(TreeNode<PermissionModel> parentNode, PermissionModel target, PermissionModel anchor, bool insertAfter) async {
    // [FIX]: 캐스팅 후 필터링 및 정렬
    final existingSiblings = parentNode.children.values.cast<TreeNode<PermissionModel>>()
        .where((n) => n.key != target.permissionId)
        .toList()
      ..sort((a, b) => a.data!.sortOrder.compareTo(b.data!.sortOrder));

    int anchorIndex = existingSiblings.indexWhere((n) => n.key == anchor.permissionId);

    int insertIndex = insertAfter ? anchorIndex + 1 : anchorIndex;
    if (insertIndex < 0) insertIndex = 0;
    if (insertIndex > existingSiblings.length) insertIndex = existingSiblings.length;

    List<PermissionModel> newOrderList = [];
    for (int i = 0; i < insertIndex; i++) {
      newOrderList.add(existingSiblings[i].data!);
    }
    newOrderList.add(target);
    for (int i = insertIndex; i < existingSiblings.length; i++) {
      newOrderList.add(existingSiblings[i].data!);
    }

    int nextOrder = 1000;
    List<Future> futures = [];
    String? commonParentId = parentNode.isRoot ? null : parentNode.key;

    for (var model in newOrderList) {
      futures.add(_repository.updateParentAndOrder(model.permissionId, commonParentId, nextOrder));
      nextOrder += 1000;
    }

    await Future.wait(futures);
    await initialize();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  TreeNode<PermissionModel>? _findNodeInTree(TreeNode<PermissionModel> current, String key) {
    if (current.key == key) return current;
    // [FIX]: 캐스팅
    for (var child in current.children.values.cast<TreeNode<PermissionModel>>()) {
      final found = _findNodeInTree(child, key);
      if (found != null) return found;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Basic CRUD
  // ---------------------------------------------------------------------------
  void selectPermission(PermissionModel? permission) {
    _selectedPermission = permission;
    notifyListeners();
  }

  Future<void> addPermission({
    required String title,
    required String description,
    required PermissionType type,
    required PermissionStatus status,
    required int permissionLevel,
    String? parentId, // Parameter kept for signature compatibility but ignored
  }) async {
    // [Step 1 Constraint] 강제 Root 생성
    // 인자로 parentId가 들어오더라도 무조건 null(Root)로 처리합니다.
    const String? enforcedParentId = null;
    _log('addPermission', 'Enforcing Root Creation. Input parentId "$parentId" ignored.');

    // 부모를 무조건 RootNode로 간주
    final parentNode = _rootNode;

    int nextOrder = 1000;
    if (parentNode.children.isNotEmpty) {
      int maxVal = 0;
      // [FIX]: 캐스팅
      for (var child in parentNode.children.values.cast<TreeNode<PermissionModel>>()) {
        if ((child.data?.sortOrder ?? 0) > maxVal) maxVal = child.data!.sortOrder;
      }
      nextOrder = maxVal + 1000;
    }

    final newPermission = PermissionModel(
      permissionId: '',
      projectId: _repository.projectId,
      parentId: enforcedParentId, // [Step 1 Applied]
      title: title,
      description: description,
      type: type,
      status: status,
      sortOrder: nextOrder,
      permissionLevel: permissionLevel,
      permissionLabel: 'Member',
      memberIds: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _repository.createPermission(newPermission);
    await initialize();
  }

  Future<void> updatePermission(PermissionModel updatedModel) async {
    await _repository.updatePermission(updatedModel.permissionId, updatedModel.toJson());
    await initialize();
  }

  Future<void> deletePermission(PermissionModel permission) async {
    await _repository.deletePermission(permission.permissionId);
    if (_selectedPermission?.permissionId == permission.permissionId) _selectedPermission = null;
    await initialize();
  }
}