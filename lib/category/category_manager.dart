import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/foundation.dart';
import 'domain/category_models.dart';
import 'repository/category_repository.dart';

class CategoryManager extends ChangeNotifier {
  final CategoryRepository _repository;

  TreeNode<CategoryModel> _rootNode = TreeNode.root();
  bool _isLoading = false;
  CategoryModel? _selectedCategory;

  TreeNode<CategoryModel> get rootNode => _rootNode;
  bool get isLoading => _isLoading;
  CategoryModel? get selectedCategory => _selectedCategory;

  CategoryManager(this._repository);

  void _log(String method, String message) {
    debugPrint('[CategoryManager][$method] $message');
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

  void _recursiveLog(TreeNode<CategoryModel> node, int depth) {
    if (!node.isRoot) {
      final data = node.data;
      final indent = '   ' * depth;
      debugPrint('$indent[D:$depth] Order:${data?.sortOrder} | ${data?.title} | (${node.key})');
    }

    // [FIX]: children.values를 TreeNode<CategoryModel>로 명시적 캐스팅
    final sortedChildren = node.children.values.cast<TreeNode<CategoryModel>>().toList()
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
      final allCategorys = await _repository.fetchAllCategorys();
      _buildTree(allCategorys);
      debugLogTree();
    } catch (e) {
      _log('initialize', 'Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _buildTree(List<CategoryModel> categorys) {
    _rootNode = TreeNode.root();
    final Map<String, TreeNode<CategoryModel>> nodeMap = {};

    for (final category in categorys) {
      nodeMap[category.categoryId] = TreeNode<CategoryModel>(key: category.categoryId, data: category);
    }

    for (final category in categorys) {
      final node = nodeMap[category.categoryId]!;
      if (category.parentId == null || category.parentId!.isEmpty) {
        _rootNode.add(node);
      } else {
        final parentNode = nodeMap[category.parentId];
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

  Future<void> reparentCategory(CategoryModel target, CategoryModel newParent) async {
    if (target.categoryId == newParent.categoryId) return;
    _log('reparentCategory', 'Moving ${target.title} into ${newParent.title}');

    try {
      final parentNode = _findNodeInTree(_rootNode, newParent.categoryId);

      int maxOrder = 0;
      if (parentNode != null && parentNode.children.isNotEmpty) {
        // [FIX]: 캐스팅 추가
        for (var child in parentNode.children.values.cast<TreeNode<CategoryModel>>()) {
          final order = child.data?.sortOrder ?? 0;
          if (order > maxOrder) maxOrder = order;
        }
      }

      final newOrder = (maxOrder == 0) ? 1000 : maxOrder + 1000;

      await _repository.updateParentAndOrder(target.categoryId, newParent.categoryId, newOrder);
      await initialize();
    } catch (e) {
      _log('reparentCategory', 'Error: $e');
      rethrow;
    }
  }

  Future<void> reorderCategory(CategoryModel target, CategoryModel anchor, bool insertAfter) async {
    if (target.categoryId == anchor.categoryId) return;
    _log('reorderCategory', 'Moving ${target.title} ${insertAfter ? 'After' : 'Before'} ${anchor.title}');

    try {
      final parentId = anchor.parentId;
      final parentNode = (parentId == null || parentId.isEmpty)
          ? _rootNode
          : _findNodeInTree(_rootNode, parentId);

      if (parentNode == null) {
        _log('reorderCategory', 'Parent node not found via ID lookup.');
        return;
      }

      // [FIX]: 캐스팅 후 정렬
      final siblings = parentNode.children.values.cast<TreeNode<CategoryModel>>().toList()
        ..sort((a, b) => (a.data!.sortOrder).compareTo(b.data!.sortOrder));

      int anchorIndex = siblings.indexWhere((n) => n.key == anchor.categoryId);
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

      _log('reorderCategory', 'Calculated Order: $newOrder (Anchor: ${anchor.sortOrder})');

      bool isCollision = siblings.any((n) => n.data!.sortOrder == newOrder && n.key != target.categoryId);
      bool isGapTooSmall = (anchor.sortOrder - newOrder).abs() < 1;
      bool isInitialCluster = (anchor.sortOrder == newOrder);

      if (isCollision || isGapTooSmall || isInitialCluster) {
        _log('reorderCategory', '⚠️ Collision/Cluster detected. Rebalancing...');
        await _rebalanceSiblings(parentNode, target, anchor, insertAfter);
      } else {
        await _repository.updateParentAndOrder(target.categoryId, parentId, newOrder);
        await initialize();
      }

    } catch (e) {
      _log('reorderCategory', 'Error: $e');
      rethrow;
    }
  }

  Future<void> _rebalanceSiblings(TreeNode<CategoryModel> parentNode, CategoryModel target, CategoryModel anchor, bool insertAfter) async {
    // [FIX]: 캐스팅 후 필터링 및 정렬
    final existingSiblings = parentNode.children.values.cast<TreeNode<CategoryModel>>()
        .where((n) => n.key != target.categoryId)
        .toList()
      ..sort((a, b) => a.data!.sortOrder.compareTo(b.data!.sortOrder));

    int anchorIndex = existingSiblings.indexWhere((n) => n.key == anchor.categoryId);

    int insertIndex = insertAfter ? anchorIndex + 1 : anchorIndex;
    if (insertIndex < 0) insertIndex = 0;
    if (insertIndex > existingSiblings.length) insertIndex = existingSiblings.length;

    List<CategoryModel> newOrderList = [];
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
      futures.add(_repository.updateParentAndOrder(model.categoryId, commonParentId, nextOrder));
      nextOrder += 1000;
    }

    await Future.wait(futures);
    await initialize();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  TreeNode<CategoryModel>? _findNodeInTree(TreeNode<CategoryModel> current, String key) {
    if (current.key == key) return current;
    // [FIX]: 캐스팅
    for (var child in current.children.values.cast<TreeNode<CategoryModel>>()) {
      final found = _findNodeInTree(child, key);
      if (found != null) return found;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Basic CRUD
  // ---------------------------------------------------------------------------
  void selectCategory(CategoryModel? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<void> addCategory({
    required String title,
    required String description,
    required CategoryType type,
    required CategoryStatus status,
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
      for (var child in parentNode.children.values.cast<TreeNode<CategoryModel>>()) {
        if ((child.data?.sortOrder ?? 0) > maxVal) maxVal = child.data!.sortOrder;
      }
      nextOrder = maxVal + 1000;
    }

    final newCategory = CategoryModel(
      categoryId: '',
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
    await _repository.createCategory(newCategory);
    await initialize();
  }

  Future<void> updateCategory(CategoryModel updatedModel) async {
    await _repository.updateCategory(updatedModel.categoryId, updatedModel.toJson());
    await initialize();
  }

  Future<void> deleteCategory(CategoryModel category) async {
    await _repository.deleteCategory(category.categoryId);
    if (_selectedCategory?.categoryId == category.categoryId) _selectedCategory = null;
    await initialize();
  }
}