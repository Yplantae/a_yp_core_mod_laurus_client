import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer';

// ------------------------------------------------
// 1. URL Argument 및 Screen 정의
// ------------------------------------------------

class GroupManagementScreenArg {
  final int? paramA;
  final String? paramB;
  final bool hasError;
  final String? errorMessage;

  GroupManagementScreenArg({this.paramA, this.paramB, this.hasError = false, this.errorMessage});

  factory GroupManagementScreenArg.error(String msg) {
    return GroupManagementScreenArg(hasError: true, errorMessage: msg);
  }
}

class GroupManagementScreen extends StatelessWidget {
  final GroupManagementScreenArg args;

  GroupManagementScreen(this.args);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MileStone Map Editor',
      home: GroupManagementPage(this.args),
    );
  }

  static GroupManagementScreenArg argProc(GoRouterState state) {
    final qp = state.uri.queryParameters;
    final rawA = qp['paramA'];
    if (rawA == null) {
      return GroupManagementScreenArg.error("필수 파라미터 'paramA' 가 누락되었습니다.");
    }
    final parsedA = int.tryParse(rawA);
    if (parsedA == null) {
      return GroupManagementScreenArg.error("파라미터 'paramA' 는 int 타입이어야 합니다. 입력값: $rawA");
    }
    final rawB = qp['paramB'];
    String parsedB = "";
    if (rawB != null) {
      parsedB = rawB.toString();
    }
    return GroupManagementScreenArg(paramA: parsedA, paramB: parsedB);
  }
}

// ------------------------------------------------
// 2. 커스텀 데이터 모델 및 Enum
// ------------------------------------------------

class CustomNodeData {
  final String title;
  final String description;
  final NodeType type;
  final NodeStatus status;

  CustomNodeData({
    required this.title,
    required this.description,
    required this.type,
    required this.status,
  });
}

enum NodeType { milestone, task, subtask, info }
enum NodeStatus { todo, inProgress, done, blocked }

const Uuid uuid = Uuid();

// CustomNodeData 타입을 사용하는 TreeNode 정의
typedef CustomTreeNode = TreeNode<CustomNodeData>;

// ------------------------------------------------
// 3. Undo/Redo Action 정의 (순서 변경 시 Index 저장)
// ------------------------------------------------

enum MoveType { reparent, reorder }

class NodeMoveAction {
  final CustomTreeNode node;
  final CustomTreeNode? oldParent;
  final CustomTreeNode? newParent;
  final MoveType type;
  final int? oldIndex;

  NodeMoveAction({
    required this.node,
    required this.oldParent,
    required this.newParent,
    required this.type,
    this.oldIndex,
  });
}

// ------------------------------------------------
// 4. Tree View Page 구현
// ------------------------------------------------

class GroupManagementPage extends StatefulWidget {
  final GroupManagementScreenArg args;

  GroupManagementPage(this.args);

  @override
  State<GroupManagementPage> createState() => _GroupManagementPageState();
}

class _GroupManagementPageState extends State<GroupManagementPage> {
  bool _dialogShown = false;
  TreeViewController<CustomNodeData, CustomTreeNode>? _controller;
  CustomTreeNode? _selectedNode;
  late CustomTreeNode _tree;

  final List<NodeMoveAction> _undoStack = [];
  final List<NodeMoveAction> _redoStack = [];

  // ------------------------------------------------
  // 4. 노드 관계 확인 및 로그 헬퍼 함수
  // ------------------------------------------------

  bool _isAncestorOf(CustomTreeNode potentialAncestor, CustomTreeNode node) {
    if (node.parent == null) return false;
    if (node.parent == potentialAncestor) return true;
    return _isAncestorOf(potentialAncestor, node.parent as CustomTreeNode);
  }

  void _logTreeStructure(CustomTreeNode root, {int depth = 0}) {
    if (depth == 0) {
      log("----------------------------------------------------------------------------------------------------");
      log("🌳 현재 트리 구조 로그 (Depth, Key, Title, Parent Key, Children Keys) 🌳");
      log("----------------------------------------------------------------------------------------------------");
    }

    final parentKey = root.parent?.key ?? "N/A (Root)";
    final indent = '  ' * depth;
    final childrenKeys = root.children.keys.toList();

    log("$indent[D:$depth] Key: ${root.key}, Title: ${root.data?.title}, Parent: $parentKey, Children Keys: $childrenKeys");

    root.children.forEach((key, childNode) {
      _logTreeStructure(childNode as CustomTreeNode, depth: depth + 1);
    });

    if (depth == 0) {
      log("----------------------------------------------------------------------------------------------------");
    }
  }

  @override
  void initState() {
    super.initState();

    final rootData = CustomNodeData(
      title: '프로젝트 루트',
      description: '트리 구조의 최상위 노드입니다.',
      type: NodeType.milestone,
      status: NodeStatus.todo,
    );

    _tree = CustomTreeNode(key: 'root_key', data: rootData);
    _selectedNode = _tree;

    final nodeA = CustomTreeNode(
      key: 'A',
      data: CustomNodeData(
          title: '마일스톤 A',
          description: '첫 번째 주요 목표',
          type: NodeType.milestone,
          status: NodeStatus.inProgress),
    );

    _tree.add(nodeA);
    _tree.add(CustomTreeNode(
        key: 'B',
        data: CustomNodeData(
            title: '마일스톤 B',
            description: '두 번째 주요 목표',
            type: NodeType.milestone,
            status: NodeStatus.todo)));

    if (_tree.children.isNotEmpty) {
      _tree.children.values.first.add(CustomTreeNode(
          key: 'A1',
          data: CustomNodeData(
              title: 'A의 첫 번째 Task',
              description: '세부 작업 1',
              type: NodeType.task,
              status: NodeStatus.inProgress)));
    }

    _logTreeStructure(_tree);
  }

  // ------------------------------------------------
  // 5. 노드 추가/삭제
  // ------------------------------------------------

  void _addNode(CustomTreeNode parent, String title, String description,
      NodeType type, NodeStatus status) {
    final newNodeData = CustomNodeData(
        title: title, description: description, type: type, status: status);

    final newNode = CustomTreeNode(key: uuid.v4(), data: newNodeData);

    setState(() {
      parent.add(newNode);
      _controller?.expandNode(parent);
      _selectedNode = newNode;
    });

    Fluttertoast.showToast(
        msg: "'$title' 노드가 추가되었습니다.", gravity: ToastGravity.TOP);
  }

  void _deleteNode(CustomTreeNode node) {
    if (node.isRoot) {
      Fluttertoast.showToast(msg: "Root 노드는 삭제할 수 없습니다.");
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('노드 삭제 확인'),
        content: Text("정말로 '${node.data?.title}' 노드와 모든 하위 노드를 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedNode = node.parent as CustomTreeNode?;
                node.delete();
              });
              Navigator.of(ctx).pop();
              Fluttertoast.showToast(
                  msg: "'${node.data?.title}' 노드가 삭제되었습니다.");
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _onNodeTap(CustomTreeNode node) {
    setState(() {
      _selectedNode = node;
    });
    _controller?.toggleExpansion(node);
    Fluttertoast.showToast(
        msg: "'${node.data?.title}' 노드가 선택되었습니다.",
        toastLength: Toast.LENGTH_SHORT);
  }

  // ------------------------------------------------
  // 6. Drag & Drop 및 Undo/Redo 로직 (수정됨)
  // ------------------------------------------------

  void _executeNodeReorder(CustomTreeNode fromNode, CustomTreeNode targetNode) {
    final parent = targetNode.parent as CustomTreeNode?;
    if (parent == null) return;

    final oldParent = fromNode.parent as CustomTreeNode?;
    final oldIndex = oldParent?.children.keys.toList().indexOf(fromNode.key) ?? -1;

    setState(() {
      oldParent?.remove(fromNode);

      final currentChildrenKeys = parent.children.keys.toList();
      final targetIndex = currentChildrenKeys.indexOf(targetNode.key);

      currentChildrenKeys.remove(fromNode.key);
      currentChildrenKeys.insert(targetIndex, fromNode.key);

      // ⭐️ Map 순서 강제
      final Map<String, CustomTreeNode> newChildren = {};
      for (var key in currentChildrenKeys) {
        if (key == fromNode.key) {
          newChildren[key] = fromNode;
        } else {
          newChildren[key] = parent.children[key] as CustomTreeNode;
        }
      }
      parent.children
        ..clear()
        ..addAll(newChildren);

      fromNode.parent = parent;

      _controller?.expandNode(parent);
      _selectedNode = fromNode;

      _undoStack.add(NodeMoveAction(
        node: fromNode,
        oldParent: oldParent,
        newParent: parent,
        type: MoveType.reorder,
        oldIndex: oldIndex,
      ));
      _redoStack.clear();
    });

    _logTreeStructure(_tree);
    Fluttertoast.showToast(msg: "'${fromNode.data?.title}' 노드가 순서 변경되었습니다.", gravity: ToastGravity.TOP);
  }

  void _executeNodeReparent(CustomTreeNode fromNode, CustomTreeNode toNode) {
    final oldParent = fromNode.parent as CustomTreeNode?;

    setState(() {
      oldParent?.remove(fromNode);
      toNode.add(fromNode);
      _controller?.expandNode(toNode);
      _selectedNode = fromNode;

      _undoStack.add(NodeMoveAction(
        node: fromNode,
        oldParent: oldParent,
        newParent: toNode,
        type: MoveType.reparent,
      ));
      _redoStack.clear();
    });

    _logTreeStructure(_tree);
    Fluttertoast.showToast(
        msg: "'${fromNode.data?.title}' 노드가 '${toNode.data?.title}' 하위로 이동했습니다.",
        gravity: ToastGravity.TOP);
  }

  void _onNodeDrop(CustomTreeNode fromNode, CustomTreeNode toNode, String dropType) {
    if (fromNode == toNode || _isAncestorOf(fromNode, toNode)) {
      Fluttertoast.showToast(msg: "유효하지 않은 이동입니다.", gravity: ToastGravity.CENTER);
      return;
    }

    if (dropType == 'reparent') {
      _executeNodeReparent(fromNode, toNode);
    } else if (dropType == 'reorder') {
      _executeNodeReorder(fromNode, toNode);
    }
  }

  // ------------------------------------------------
  // Undo/Redo
  // ------------------------------------------------

  void undo() {
    if (_undoStack.isEmpty) return;

    final action = _undoStack.removeLast();

    setState(() {
      action.newParent?.remove(action.node);
      final oldParent = action.oldParent;
      if (oldParent != null) {
        oldParent.add(action.node);
        _controller?.expandNode(oldParent);
      } else {
        _tree.add(action.node);
      }
      _selectedNode = action.node;
      _redoStack.add(action);
    });

    _logTreeStructure(_tree);
    Fluttertoast.showToast(msg: "Undo: 실행 취소되었습니다. (순서 복구는 제한됨)", gravity: ToastGravity.TOP);
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    final action = _redoStack.removeLast();

    if (action.newParent != null) {
      _executeNodeReparent(action.node, action.newParent!);
      _undoStack.removeLast();
      _undoStack.add(action);
    }

    _logTreeStructure(_tree);
    Fluttertoast.showToast(msg: "Redo: 재실행되었습니다.", gravity: ToastGravity.TOP);
  }

  // ------------------------------------------------
  // Drag & Drop 헬퍼
  // ------------------------------------------------

  Widget _buildDragFeedback(CustomTreeNode node) {
    return Material(
      elevation: 6,
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.7,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(node.data!.title,
              style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(
            color: Colors.blueGrey, style: BorderStyle.solid, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade200.withOpacity(0.3),
      ),
    );
  }

  Widget _buildDropIndicator(CustomTreeNode targetNode) {
    return DragTarget<CustomTreeNode>(
      builder: (context, candidateData, rejectedData) {
        final isTargeted = candidateData.isNotEmpty;
        return Container(
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          color: isTargeted ? Colors.blue.withOpacity(0.5) : Colors.transparent,
        );
      },
      onWillAcceptWithDetails: (details) {
        final draggedNode = details.data;
        final targetParent = targetNode.parent as CustomTreeNode?;
        if (targetParent == null) return false;
        if (draggedNode == targetNode) return false;
        if (_isAncestorOf(draggedNode, targetNode)) return false;
        return true;
      },
      onAcceptWithDetails: (details) {
        final draggedNode = details.data;
        _onNodeDrop(draggedNode, targetNode, 'reorder');
      },
    );
  }

  Widget _buildNodeItem(CustomTreeNode node, bool isSelected, {bool isTargeted = false}) {
    final data = node.data!;
    final Color borderColor = isTargeted ? Colors.blueAccent : (isSelected ? Colors.blue : Colors.grey.shade300);
    final double borderWidth = isTargeted ? 2 : (isSelected ? 2 : 1);
    final Color bgColor = isSelected ? Colors.blue.shade50 : (isTargeted ? Colors.blue.withOpacity(0.05) : Colors.white);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(data.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${data.type.toString().split('.').last} | Status: ${data.status.toString().split('.').last}'),
            Text(data.description, style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        trailing: !node.isRoot
            ? IconButton(
          icon: const Icon(Icons.remove_circle, color: Colors.red),
          onPressed: () => _deleteNode(node),
          tooltip: '노드 삭제',
        )
            : null,
        onTap: () => _onNodeTap(node),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("마일스톤 맵 편집 (Tree View)"),
        actions: [
          IconButton(onPressed: _undoStack.isNotEmpty ? undo : null, icon: const Icon(Icons.undo)),
          IconButton(onPressed: _redoStack.isNotEmpty ? redo : null, icon: const Icon(Icons.redo)),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          setState(() { _selectedNode = _tree; });
          Fluttertoast.showToast(msg: "Root 노드가 선택되었습니다.", toastLength: Toast.LENGTH_SHORT);
        },
        child: TreeView.simpleTyped<CustomNodeData, CustomTreeNode>(
          tree: _tree,
          showRootNode: true,
          onTreeReady: (controller) {
            _controller = controller as TreeViewController<CustomNodeData, CustomTreeNode>;
            controller.expandAllChildren(_tree);
          },
          builder: (context, node) {
            final customNode = node as CustomTreeNode;

            if (customNode.isRoot) {
              return _buildNodeItem(customNode, _selectedNode?.key == customNode.key);
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropIndicator(customNode),
                LongPressDraggable<CustomTreeNode>(
                  data: customNode,
                  feedback: _buildDragFeedback(customNode),
                  childWhenDragging: _buildPlaceholder(),
                  child: DragTarget<CustomTreeNode>(
                    builder: (context, candidateData, rejectedData) {
                      final isTargeted = candidateData.isNotEmpty;
                      return _buildNodeItem(customNode, _selectedNode?.key == customNode.key, isTargeted: isTargeted);
                    },
                    onWillAcceptWithDetails: (details) {
                      final draggedNode = details.data;
                      if (draggedNode == customNode) return false;
                      if (_isAncestorOf(draggedNode, customNode)) return false;
                      return true;
                    },
                    onAcceptWithDetails: (details) {
                      final draggedNode = details.data;
                      _onNodeDrop(draggedNode, customNode, 'reparent');
                    },
                  ),
                ),
                if (customNode.isLeaf) _buildDropIndicator(customNode),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNodeDialog(context),
        tooltip: '하위 노드 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddNodeDialog(BuildContext context) {
    final parentNode = _selectedNode ?? _tree;

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    NodeType selectedType = NodeType.milestone;
    NodeStatus selectedStatus = NodeStatus.todo;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sCtx, setState) {
            return AlertDialog(
              title: Text('노드 추가: ${parentNode.data?.title ?? 'Root'} 하위'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                    TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
                    DropdownButtonFormField<NodeType>(
                      decoration: const InputDecoration(labelText: 'Type'),
                      value: selectedType,
                      items: NodeType.values.map((type) => DropdownMenuItem(value: type, child: Text(type.toString().split('.').last))).toList(),
                      onChanged: (NodeType? newValue) { setState(() { selectedType = newValue!; }); },
                    ),
                    DropdownButtonFormField<NodeStatus>(
                      decoration: const InputDecoration(labelText: 'Status'),
                      value: selectedStatus,
                      items: NodeStatus.values.map((status) => DropdownMenuItem(value: status, child: Text(status.toString().split('.').last))).toList(),
                      onChanged: (NodeStatus? newValue) { setState(() { selectedStatus = newValue!; }); },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('취소')),
                TextButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      _addNode(parentNode, titleController.text,descriptionController.text, selectedType, selectedStatus);
                      _logTreeStructure(_tree);
                      Navigator.of(ctx).pop();
                    } else {
                      Fluttertoast.showToast(msg: "Title을 입력해주세요.");
                    }
                  },
                  child: const Text('생성'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
