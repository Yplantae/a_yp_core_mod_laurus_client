import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/foundation.dart';
import 'domain/group_models.dart';
import 'repository/group_repository.dart';

class GroupManager extends ChangeNotifier {
  final GroupRepository _repository;

  TreeNode<GroupModel> _rootNode = TreeNode.root();
  bool _isLoading = false;
  GroupModel? _selectedGroup;

  TreeNode<GroupModel> get rootNode => _rootNode;
  bool get isLoading => _isLoading;
  GroupModel? get selectedGroup => _selectedGroup;

  GroupManager(this._repository);

  void _log(String method, String message) {
    debugPrint('[GroupManager][$method] $message');
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

  void _recursiveLog(TreeNode<GroupModel> node, int depth) {
    if (!node.isRoot) {
      final data = node.data;
      final indent = '   ' * depth;
      debugPrint('$indent[D:$depth] Order:${data?.sortOrder} | ${data?.title} | (${node.key})');
    }

    // [FIX]: children.values를 TreeNode<GroupModel>로 명시적 캐스팅
    final sortedChildren = node.children.values.cast<TreeNode<GroupModel>>().toList()
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
      final allGroups = await _repository.fetchAllGroups();
      _buildTree(allGroups);
      debugLogTree();
    } catch (e) {
      _log('initialize', 'Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _buildTree(List<GroupModel> groups) {
    _rootNode = TreeNode.root();
    final Map<String, TreeNode<GroupModel>> nodeMap = {};

    for (final group in groups) {
      nodeMap[group.groupId] = TreeNode<GroupModel>(key: group.groupId, data: group);
    }

    for (final group in groups) {
      final node = nodeMap[group.groupId]!;
      if (group.parentId == null || group.parentId!.isEmpty) {
        _rootNode.add(node);
      } else {
        final parentNode = nodeMap[group.parentId];
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

  Future<void> reparentGroup(GroupModel target, GroupModel newParent) async {
    if (target.groupId == newParent.groupId) return;
    _log('reparentGroup', 'Moving ${target.title} into ${newParent.title}');

    try {
      final parentNode = _findNodeInTree(_rootNode, newParent.groupId);

      int maxOrder = 0;
      if (parentNode != null && parentNode.children.isNotEmpty) {
        // [FIX]: 캐스팅 추가
        for (var child in parentNode.children.values.cast<TreeNode<GroupModel>>()) {
          final order = child.data?.sortOrder ?? 0;
          if (order > maxOrder) maxOrder = order;
        }
      }

      final newOrder = (maxOrder == 0) ? 1000 : maxOrder + 1000;

      await _repository.updateParentAndOrder(target.groupId, newParent.groupId, newOrder);
      await initialize();
    } catch (e) {
      _log('reparentGroup', 'Error: $e');
      rethrow;
    }
  }

  Future<void> reorderGroup(GroupModel target, GroupModel anchor, bool insertAfter) async {
    if (target.groupId == anchor.groupId) return;
    _log('reorderGroup', 'Moving ${target.title} ${insertAfter ? 'After' : 'Before'} ${anchor.title}');

    try {
      final parentId = anchor.parentId;
      final parentNode = (parentId == null || parentId.isEmpty)
          ? _rootNode
          : _findNodeInTree(_rootNode, parentId);

      if (parentNode == null) {
        _log('reorderGroup', 'Parent node not found via ID lookup.');
        return;
      }

      // [FIX]: 캐스팅 후 정렬
      final siblings = parentNode.children.values.cast<TreeNode<GroupModel>>().toList()
        ..sort((a, b) => (a.data!.sortOrder).compareTo(b.data!.sortOrder));

      int anchorIndex = siblings.indexWhere((n) => n.key == anchor.groupId);
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

      _log('reorderGroup', 'Calculated Order: $newOrder (Anchor: ${anchor.sortOrder})');

      bool isCollision = siblings.any((n) => n.data!.sortOrder == newOrder && n.key != target.groupId);
      bool isGapTooSmall = (anchor.sortOrder - newOrder).abs() < 1;
      bool isInitialCluster = (anchor.sortOrder == newOrder);

      if (isCollision || isGapTooSmall || isInitialCluster) {
        _log('reorderGroup', '⚠️ Collision/Cluster detected. Rebalancing...');
        await _rebalanceSiblings(parentNode, target, anchor, insertAfter);
      } else {
        await _repository.updateParentAndOrder(target.groupId, parentId, newOrder);
        await initialize();
      }

    } catch (e) {
      _log('reorderGroup', 'Error: $e');
      rethrow;
    }
  }

  Future<void> _rebalanceSiblings(TreeNode<GroupModel> parentNode, GroupModel target, GroupModel anchor, bool insertAfter) async {
    // [FIX]: 캐스팅 후 필터링 및 정렬
    final existingSiblings = parentNode.children.values.cast<TreeNode<GroupModel>>()
        .where((n) => n.key != target.groupId)
        .toList()
      ..sort((a, b) => a.data!.sortOrder.compareTo(b.data!.sortOrder));

    int anchorIndex = existingSiblings.indexWhere((n) => n.key == anchor.groupId);

    int insertIndex = insertAfter ? anchorIndex + 1 : anchorIndex;
    if (insertIndex < 0) insertIndex = 0;
    if (insertIndex > existingSiblings.length) insertIndex = existingSiblings.length;

    List<GroupModel> newOrderList = [];
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
      futures.add(_repository.updateParentAndOrder(model.groupId, commonParentId, nextOrder));
      nextOrder += 1000;
    }

    await Future.wait(futures);
    await initialize();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  TreeNode<GroupModel>? _findNodeInTree(TreeNode<GroupModel> current, String key) {
    if (current.key == key) return current;
    // [FIX]: 캐스팅
    for (var child in current.children.values.cast<TreeNode<GroupModel>>()) {
      final found = _findNodeInTree(child, key);
      if (found != null) return found;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Basic CRUD
  // ---------------------------------------------------------------------------
  void selectGroup(GroupModel? group) {
    _selectedGroup = group;
    notifyListeners();
  }

  Future<void> addGroup({
    required String title,
    required String description,
    required GroupType type,
    required GroupStatus status,
    required int permissionLevel,
    String? parentId,
  }) async {
    final parentNode = (parentId == null)
        ? _rootNode
        : _findNodeInTree(_rootNode, parentId);

    int nextOrder = 1000;
    if (parentNode != null && parentNode.children.isNotEmpty) {
      int maxVal = 0;
      // [FIX]: 캐스팅
      for (var child in parentNode.children.values.cast<TreeNode<GroupModel>>()) {
        if ((child.data?.sortOrder ?? 0) > maxVal) maxVal = child.data!.sortOrder;
      }
      nextOrder = maxVal + 1000;
    }

    final newGroup = GroupModel(
      groupId: '',
      projectId: _repository.projectId,
      parentId: parentId,
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
    await _repository.createGroup(newGroup);
    await initialize();
  }

  Future<void> updateGroup(GroupModel updatedModel) async {
    await _repository.updateGroup(updatedModel.groupId, updatedModel.toJson());
    await initialize();
  }

  Future<void> deleteGroup(GroupModel group) async {
    await _repository.deleteGroup(group.groupId);
    if (_selectedGroup?.groupId == group.groupId) _selectedGroup = null;
    await initialize();
  }
}