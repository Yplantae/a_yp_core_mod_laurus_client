import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/permission_models.dart';
import '../../repository/permission_repository.dart';
import '../../permission_manager.dart';
import '../widget/permission_edit_dialog.dart';

class PermissionManagementScreenArg {
  final String projectId;
  PermissionManagementScreenArg({required this.projectId});
  factory PermissionManagementScreenArg.error() => PermissionManagementScreenArg(projectId: '');
}

class PermissionManagementScreen extends StatefulWidget {
  final PermissionManagementScreenArg args;
  const PermissionManagementScreen(this.args, {Key? key}) : super(key: key);

  static PermissionManagementScreenArg argProc(GoRouterState state) {
    var projectId = state.uri.queryParameters['projectId'];
    if (projectId == null && state.extra != null && state.extra is Map) {
      projectId = (state.extra as Map)['projectId']?.toString();
    }
    projectId ??= 'default_project_id';
    return PermissionManagementScreenArg(projectId: projectId);
  }

  @override
  State<PermissionManagementScreen> createState() => _PermissionManagementScreenState();
}

class _PermissionManagementScreenState extends State<PermissionManagementScreen> {
  late final PermissionRepository _repository;
  late final PermissionManager _manager;
  TreeViewController<PermissionModel, TreeNode<PermissionModel>>? _treeController;

  @override
  void initState() {
    super.initState();
    _repository = PermissionRepository(
      firestore: FirebaseFirestore.instance,
      projectId: widget.args.projectId,
    );
    _manager = PermissionManager(_repository);
    _manager.initialize();
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  bool _isAncestorOf(TreeNode<PermissionModel> potentialAncestor, TreeNode<PermissionModel> node) {
    if (node.parent == null) return false;
    if (node.parent == potentialAncestor) return true;
    return _isAncestorOf(potentialAncestor, node.parent as TreeNode<PermissionModel>);
  }

  // ---------------------------------------------------------------------------
  // Drag & Drop Handling
  // ---------------------------------------------------------------------------
  void _onNodeDrop(TreeNode<PermissionModel> draggedNode, TreeNode<PermissionModel> targetNode, String dropType) {
    final draggedData = draggedNode.data;
    final targetData = targetNode.data;

    if (draggedData == null || targetData == null) return;
    if (draggedNode.key == targetNode.key) return;
    if (_isAncestorOf(draggedNode, targetNode)) {
      Fluttertoast.showToast(msg: "Loop detected: Cannot move ancestor to descendant.");
      return;
    }

    if (dropType == 'reparent') {
      // [Step 2 Constraint] 이 코드는 onWillAccept 차단으로 인해 호출되지 않아야 하지만,
      // 이중 방어 차원에서 실행하지 않음.
      debugPrint('[UI] Reparenting blocked by policy.');
    }
    else if (dropType == 'reorder_top') {
      _manager.reorderPermission(draggedData, targetData, false);
    }
    else if (dropType == 'reorder_bottom') {
      _manager.reorderPermission(draggedData, targetData, true);
    }
  }

  // ---------------------------------------------------------------------------
  // Visual Blocks
  // ---------------------------------------------------------------------------
  Widget _buildDragFeedback(PermissionModel data) {
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

  Widget _buildDropIndicator(TreeNode<PermissionModel> targetNode, String dropType) {
    return DragTarget<TreeNode<PermissionModel>>(
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
  Widget _buildNodeContent(TreeNode<PermissionModel> node, {bool isTargeted = false}) {
    final data = node.data!;
    final isSelected = _manager.selectedPermission?.permissionId == data.permissionId;

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
        // (구조 유지를 위해 코드 그대로 둠)
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
          _manager.selectPermission(data);

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
        title: const Text("Permission Manager"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _manager.initialize),
        ],
      ),
      // Background Tap -> Clear Focus
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          debugPrint('>>> Background Tapped. Clearing Focus.');
          _manager.selectPermission(null);
        },
        child: AnimatedBuilder(
          animation: _manager,
          builder: (context, child) {
            if (_manager.isLoading) return const Center(child: CircularProgressIndicator());
            final root = _manager.rootNode;

            return TreeView.simpleTyped<PermissionModel, TreeNode<PermissionModel>>(
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

                    LongPressDraggable<TreeNode<PermissionModel>>(
                      data: node,
                      feedback: _buildDragFeedback(data),
                      childWhenDragging: _buildPlaceholder(),
                      child: DragTarget<TreeNode<PermissionModel>>(
                        builder: (context, cand, rej) {
                          // [Step 2] 시각적으로도 Target 효과를 끄거나 유지할 수 있으나,
                          // 여기서는 onWillAccept가 false이므로 cand는 항상 비어있게 됨.
                          return _buildNodeContent(node, isTargeted: cand.isNotEmpty);
                        },
                        onWillAcceptWithDetails: (details) {
                          // [Step 2 Constraint]
                          // 노드 내부(Center)로의 드롭 = Nesting(Reparenting)을 원천 차단.
                          // 항상 false를 반환하여 '이곳은 유효한 드롭 존이 아님'을 선언.
                          return false;
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
        onPressed: () => _showAddDialog(_manager.selectedPermission),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ------------------------------------------------
  // Dialog Actions
  // ------------------------------------------------
  Future<void> _showAddDialog(PermissionModel? parent) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PermissionEditDialog(permission: null, parentTitle: parent?.title),
    );

    if (result != null && result['action'] == 'save') {
      final data = result['data'];
      await _manager.addPermission(
        title: data['title'],
        description: data['description'],
        type: data['type'],
        status: data['status'],
        permissionLevel: data['permissionLevel'],
        parentId: parent?.permissionId, // [Step 1] Manager 내부에서 이 값은 무시됨.
      );
      Fluttertoast.showToast(msg: "Permission Created");
    }
  }

  Future<void> _showEditDialog(PermissionModel permission) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PermissionEditDialog(permission: permission),
    );

    if (result != null) {
      if (result['action'] == 'delete') {
        await _manager.deletePermission(permission);
        Fluttertoast.showToast(msg: "Permission Deleted");
      }
      else if (result['action'] == 'save') {
        final data = result['data'];
        final updated = permission.copyWith(
          title: data['title'],
          description: data['description'],
          type: data['type'],
          status: data['status'],
          permissionLevel: data['permissionLevel'],
        );
        await _manager.updatePermission(updated);
        Fluttertoast.showToast(msg: "Permission Updated");
      }
    }
  }
}