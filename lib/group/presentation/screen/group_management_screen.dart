import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/group_models.dart';
import '../../repository/group_repository.dart';
import '../../group_manager.dart';
import '../widget/group_edit_dialog.dart';

class GroupManagementScreenArg {
  final String projectId;
  GroupManagementScreenArg({required this.projectId});
  factory GroupManagementScreenArg.error() => GroupManagementScreenArg(projectId: '');
}

class GroupManagementScreen extends StatefulWidget {
  final GroupManagementScreenArg args;
  const GroupManagementScreen(this.args, {Key? key}) : super(key: key);

  static GroupManagementScreenArg argProc(GoRouterState state) {
    var projectId = state.uri.queryParameters['projectId'];
    if (projectId == null && state.extra != null && state.extra is Map) {
      projectId = (state.extra as Map)['projectId']?.toString();
    }
    projectId ??= 'default_project_id';
    return GroupManagementScreenArg(projectId: projectId);
  }

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  late final GroupRepository _repository;
  late final GroupManager _manager;
  TreeViewController<GroupModel, TreeNode<GroupModel>>? _treeController;

  @override
  void initState() {
    super.initState();
    _repository = GroupRepository(
      firestore: FirebaseFirestore.instance,
      projectId: widget.args.projectId,
    );
    _manager = GroupManager(_repository);
    _manager.initialize();
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  bool _isAncestorOf(TreeNode<GroupModel> potentialAncestor, TreeNode<GroupModel> node) {
    if (node.parent == null) return false;
    if (node.parent == potentialAncestor) return true;
    return _isAncestorOf(potentialAncestor, node.parent as TreeNode<GroupModel>);
  }

  // ---------------------------------------------------------------------------
  // Drag & Drop Handling
  // ---------------------------------------------------------------------------
  void _onNodeDrop(TreeNode<GroupModel> draggedNode, TreeNode<GroupModel> targetNode, String dropType) {
    final draggedData = draggedNode.data;
    final targetData = targetNode.data;

    if (draggedData == null || targetData == null) return;
    if (draggedNode.key == targetNode.key) return;
    if (_isAncestorOf(draggedNode, targetNode)) {
      Fluttertoast.showToast(msg: "Loop detected: Cannot move ancestor to descendant.");
      return;
    }

    if (dropType == 'reparent') {
      _manager.reparentGroup(draggedData, targetData);
    }
    else if (dropType == 'reorder_top') {
      _manager.reorderGroup(draggedData, targetData, false);
    }
    else if (dropType == 'reorder_bottom') {
      _manager.reorderGroup(draggedData, targetData, true);
    }
  }

  // ---------------------------------------------------------------------------
  // Visual Blocks
  // ---------------------------------------------------------------------------
  Widget _buildDragFeedback(GroupModel data) {
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

  Widget _buildDropIndicator(TreeNode<GroupModel> targetNode, String dropType) {
    return DragTarget<TreeNode<GroupModel>>(
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
  Widget _buildNodeContent(TreeNode<GroupModel> node, {bool isTargeted = false}) {
    final data = node.data!;
    final isSelected = _manager.selectedGroup?.groupId == data.groupId;

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
          _manager.selectGroup(data);

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
        title: const Text("Group Manager"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _manager.initialize),
        ],
      ),
      // Background Tap -> Clear Focus
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          debugPrint('>>> Background Tapped. Clearing Focus.');
          _manager.selectGroup(null);
        },
        child: AnimatedBuilder(
          animation: _manager,
          builder: (context, child) {
            if (_manager.isLoading) return const Center(child: CircularProgressIndicator());
            final root = _manager.rootNode;

            return TreeView.simpleTyped<GroupModel, TreeNode<GroupModel>>(
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

                    LongPressDraggable<TreeNode<GroupModel>>(
                      data: node,
                      feedback: _buildDragFeedback(data),
                      childWhenDragging: _buildPlaceholder(),
                      child: DragTarget<TreeNode<GroupModel>>(
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
        onPressed: () => _showAddDialog(_manager.selectedGroup),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ------------------------------------------------
  // Dialog Actions
  // ------------------------------------------------
  Future<void> _showAddDialog(GroupModel? parent) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => GroupEditDialog(group: null, parentTitle: parent?.title),
    );

    if (result != null && result['action'] == 'save') {
      final data = result['data'];
      await _manager.addGroup(
        title: data['title'],
        description: data['description'],
        type: data['type'],
        status: data['status'],
        permissionLevel: data['permissionLevel'],
        parentId: parent?.groupId,
      );
      Fluttertoast.showToast(msg: "Group Created");
    }
  }

  Future<void> _showEditDialog(GroupModel group) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => GroupEditDialog(group: group),
    );

    if (result != null) {
      if (result['action'] == 'delete') {
        await _manager.deleteGroup(group);
        Fluttertoast.showToast(msg: "Group Deleted");
      }
      else if (result['action'] == 'save') {
        final data = result['data'];
        final updated = group.copyWith(
          title: data['title'],
          description: data['description'],
          type: data['type'],
          status: data['status'],
          permissionLevel: data['permissionLevel'],
        );
        await _manager.updateGroup(updated);
        Fluttertoast.showToast(msg: "Group Updated");
      }
    }
  }
}