import 'package:a_yp_core_mod_laurus_client/milestone/providers/timeline_provider.dart';
import 'package:a_yp_core_mod_laurus_client/milestone/ui/timeline_screen.dart';
import 'package:a_yp_core_mod_laurus_client/milestone/ui/widgets/playhead_widget.dart';
import 'package:a_yp_core_mod_laurus_client/milestone/ui/widgets/time_ruler_widget.dart';
import 'package:a_yp_core_mod_laurus_client/milestone/ui/widgets/timeline_toolbar.dart';
import 'package:a_yp_core_mod_laurus_client/milestone/ui/widgets/track_widget.dart';
import 'package:a_yp_core_mod_laurus_client/milestone/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer';
import 'package:a_yp_core_mod_laurus_client/milestone/utils/synced_scroll_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


// ------------------------------------------------
// 1. URL Argument 및 Screen 정의
// ------------------------------------------------

class MileStoneMapScreenArg {
  final int? paramA;
  final String? paramB;
  final bool hasError;
  final String? errorMessage;

  MileStoneMapScreenArg({this.paramA, this.paramB, this.hasError = false, this.errorMessage});

  factory MileStoneMapScreenArg.error(String msg) {
    return MileStoneMapScreenArg(hasError: true, errorMessage: msg);
  }
}

class MileStoneMapScreen extends StatelessWidget {
  final MileStoneMapScreenArg args;

  MileStoneMapScreen(this.args);

  @override
  Widget build(BuildContext context) {
    // [Fix] Provider 주입: TimelineScreen이 Provider를 찾을 수 있도록 상위에서 감싸줍니다.
    return ChangeNotifierProvider<TimelineProvider>(
      create: (_) => TimelineProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MileStone Map Editor',
        home: TimelineScreen(),
      ),
    );
  }

  static MileStoneMapScreenArg argProc(GoRouterState state) {
    final qp = state.uri.queryParameters;
    final rawA = qp['paramA'];
    if (rawA == null) {
      return MileStoneMapScreenArg.error("필수 파라미터 'paramA' 가 누락되었습니다.");
    }
    final parsedA = int.tryParse(rawA);
    if (parsedA == null) {
      return MileStoneMapScreenArg.error("파라미터 'paramA' 는 int 타입이어야 합니다. 입력값: $rawA");
    }
    final rawB = qp['paramB'];
    String parsedB = "";
    if (rawB != null) {
      parsedB = rawB.toString();
    }
    return MileStoneMapScreenArg(paramA: parsedA, paramB: parsedB);
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
