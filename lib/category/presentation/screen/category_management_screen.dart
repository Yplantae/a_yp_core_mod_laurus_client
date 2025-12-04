import 'package:a_yp_core_mod_laurus_client/category/presentation/widget/category_edit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/category_models.dart';
import '../../repository/category_repository.dart';
import '../../category_manager.dart';

class CategoryManagementScreenArg {
  final String projectId;
  CategoryManagementScreenArg({required this.projectId});
  factory CategoryManagementScreenArg.error() => CategoryManagementScreenArg(projectId: '');
}

class CategoryManagementScreen extends StatefulWidget {
  final CategoryManagementScreenArg args;
  const CategoryManagementScreen(this.args, {Key? key}) : super(key: key);

  static CategoryManagementScreenArg argProc(GoRouterState state) {
    var projectId = state.uri.queryParameters['projectId'];
    if (projectId == null && state.extra != null && state.extra is Map) {
      projectId = (state.extra as Map)['projectId']?.toString();
    }
    projectId ??= 'default_project_id';
    return CategoryManagementScreenArg(projectId: projectId);
  }

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  late final CategoryRepository _repository;
  late final CategoryManager _manager;
  TreeViewController<CategoryModel, TreeNode<CategoryModel>>? _treeController;

  @override
  void initState() {
    super.initState();
    _repository = CategoryRepository(
      firestore: FirebaseFirestore.instance,
      projectId: widget.args.projectId,
    );
    _manager = CategoryManager(_repository);
    _manager.initialize();
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  bool _isAncestorOf(TreeNode<CategoryModel> potentialAncestor, TreeNode<CategoryModel> node) {
    if (node.parent == null) return false;
    if (node.parent == potentialAncestor) return true;
    return _isAncestorOf(potentialAncestor, node.parent as TreeNode<CategoryModel>);
  }

  // ---------------------------------------------------------------------------
  // Drag & Drop Handling
  // ---------------------------------------------------------------------------
  void _onNodeDrop(TreeNode<CategoryModel> draggedNode, TreeNode<CategoryModel> targetNode, String dropType) {
    final draggedData = draggedNode.data;
    final targetData = targetNode.data;

    if (draggedData == null || targetData == null) return;
    if (draggedNode.key == targetNode.key) return;
    if (_isAncestorOf(draggedNode, targetNode)) {
      Fluttertoast.showToast(msg: "Loop detected: Cannot move ancestor to descendant.");
      return;
    }

    if (dropType == 'reparent') {
      _manager.reparentCategory(draggedData, targetData);
    }
    else if (dropType == 'reorder_top') {
      _manager.reorderCategory(draggedData, targetData, false);
    }
    else if (dropType == 'reorder_bottom') {
      _manager.reorderCategory(draggedData, targetData, true);
    }
  }

  // ---------------------------------------------------------------------------
  // Visual Blocks
  // ---------------------------------------------------------------------------
  Widget _buildDragFeedback(CategoryModel data) {
    return Material(
      elevation: 6,
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.7,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(8)),
          child: Text(data.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade200.withOpacity(0.3),
      ),
    );
  }

  Widget _buildDropIndicator(TreeNode<CategoryModel> targetNode, String dropType) {
    return DragTarget<TreeNode<CategoryModel>>(
      builder: (context, candidateData, rejectedData) {
        final isTargeted = candidateData.isNotEmpty;
        return Container(
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            color: isTargeted ? Colors.blue.withOpacity(0.5) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
      onWillAcceptWithDetails: (details) {
        final draggedNode = details.data;
        if (draggedNode.key == targetNode.key) return false;
        if (_isAncestorOf(draggedNode, targetNode)) return false;
        return true;
      },
      onAcceptWithDetails: (details) {
        _onNodeDrop(details.data, targetNode, dropType);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // [CORE UI UPDATE] Node Content Builder
  // ---------------------------------------------------------------------------
  Widget _buildNodeContent(TreeNode<CategoryModel> node, {bool isTargeted = false}) {
    final data = node.data!;
    final isSelected = _manager.selectedCategory?.categoryId == data.categoryId;

    final Color bgColor = isSelected ? Colors.blue.shade50 : (isTargeted ? Colors.blue.withOpacity(0.05) : Colors.white);
    final Color borderColor = isTargeted ? Colors.blueAccent : (isSelected ? Colors.blue : Colors.grey.shade300);

    // 자식 유무 확인 (Leaf 노드인지)
    final bool hasChildren = node.children.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: isTargeted ? 2 : 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 0.0, right: 16.0), // Leading 공간 확보

        // [1] Leading: Explicit Expansion Button
        // 자식이 있을 때만 화살표 표시, 없으면 여백 유지
        leading: hasChildren
            ? IconButton(
          // 상태에 따라 아이콘 변경 (확장됨: 아래쪽, 닫힘: 오른쪽)
          icon: Icon(
            node.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
            color: Colors.blueGrey,
          ),
          onPressed: () {
            // 오직 이 버튼을 눌렀을 때만 확장/축소 토글
            _treeController?.toggleExpansion(node);
          },
          tooltip: node.isExpanded ? 'Collapse' : 'Expand',
        )
            : const SizedBox(width: 48), // Indent maintenance for leaf nodes

        // [2] Node Info
        title: Text(data.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Order: ${data.sortOrder} | Lv.${data.permissionLevel}'),

        // [3] Trailing: Removed (Edit functionality moved to body tap)
        trailing: null,

        // [4] Body Tap: Edit Dialog & Focus
        onTap: () {
          // 1. Focus Selection
          _manager.selectCategory(data);

          // 2. Open Edit Dialog immediately
          debugPrint('>>> Node Tapped (Edit): ${data.title}');
          _showEditDialog(data);

          // Debug Log
          _manager.debugLogTree();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Category Manager"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _manager.initialize),
        ],
      ),
      // Background Tap -> Clear Focus
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          debugPrint('>>> Background Tapped. Clearing Focus.');
          _manager.selectCategory(null);
        },
        child: AnimatedBuilder(
          animation: _manager,
          builder: (context, child) {
            if (_manager.isLoading) return const Center(child: CircularProgressIndicator());
            final root = _manager.rootNode;

            return TreeView.simpleTyped<CategoryModel, TreeNode<CategoryModel>>(
              tree: root,
              showRootNode: false,
              onTreeReady: (c) { _treeController = c; c.expandAllChildren(root); },
              builder: (context, node) {
                final data = node.data;
                if (data == null) return const SizedBox();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDropIndicator(node, 'reorder_top'),

                    LongPressDraggable<TreeNode<CategoryModel>>(
                      data: node,
                      feedback: _buildDragFeedback(data),
                      childWhenDragging: _buildPlaceholder(),
                      child: DragTarget<TreeNode<CategoryModel>>(
                        builder: (context, cand, rej) {
                          return _buildNodeContent(node, isTargeted: cand.isNotEmpty);
                        },
                        onWillAcceptWithDetails: (details) {
                          if (details.data.key == node.key) return false;
                          if (_isAncestorOf(details.data, node)) return false;
                          return true;
                        },
                        onAcceptWithDetails: (details) {
                          _onNodeDrop(details.data, node, 'reparent');
                        },
                      ),
                    ),

                    if (node.isLeaf) _buildDropIndicator(node, 'reorder_bottom'),
                  ],
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(_manager.selectedCategory),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ------------------------------------------------
  // Dialog Actions
  // ------------------------------------------------
  Future<void> _showAddDialog(CategoryModel? parent) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CategoryEditDialog(category: null, parentTitle: parent?.title),
    );

    if (result != null && result['action'] == 'save') {
      final data = result['data'];
      await _manager.addCategory(
        title: data['title'],
        description: data['description'],
        type: data['type'],
        status: data['status'],
        permissionLevel: data['permissionLevel'],
        parentId: parent?.categoryId,
      );
      Fluttertoast.showToast(msg: "Category Created");
    }
  }

  Future<void> _showEditDialog(CategoryModel category) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CategoryEditDialog(category: category),
    );

    if (result != null) {
      if (result['action'] == 'delete') {
        await _manager.deleteCategory(category);
        Fluttertoast.showToast(msg: "Category Deleted");
      }
      else if (result['action'] == 'save') {
        final data = result['data'];
        final updated = category.copyWith(
          title: data['title'],
          description: data['description'],
          type: data['type'],
          status: data['status'],
          permissionLevel: data['permissionLevel'],
        );
        await _manager.updateCategory(updated);
        Fluttertoast.showToast(msg: "Category Updated");
      }
    }
  }
}