import 'package:flutter/material.dart';
import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:uuid/uuid.dart';
import '../models/timeline_models.dart';
import '../utils/time_converter.dart';
import '../utils/logger.dart';

// [New] 드래그 앤 드롭 시 타겟 노드 기준 어느 위치에 놓였는지 구분
enum DropSlot {
  above, // 타겟의 위 (형제)
  center, // 타겟의 안쪽 (자식)
  below  // 타겟의 아래 (형제)
}

class TimelineProvider extends ChangeNotifier {
  late TimelineProject _project;
  late TimeConverter _converter;
  late DateTime _currentDateTime;

  TrackNode? _selectedTrackNode;

  // 현재 화면에 렌더링 검사된 작업 목록
  List<TimeBoxData> _inspectedTasks = [];

  // [Fix] UI 강제 리빌드를 위한 레이아웃 버전 키
  int _layoutVersion = 0;

  // [Fix] 노드 확장 상태 관리 (TreeNode.isExpanded가 Read-only일 경우 대비)
  final Set<String> _expandedNodeKeys = {};

  String? _focusedTrackId;
  String? _selectedBoxId;

  String? get focusedTrackId => _focusedTrackId;
  String? get selectedBoxId => _selectedBoxId;
  int get layoutVersion => _layoutVersion;

  TimelineProvider() {
    AppLogger.log('[Provider]', 'Constructor called');
    _init();
  }

  // --- Getters ---
  TimelineProject get project => _project;
  TimeConverter get converter => _converter;
  DateTime get currentDateTime => _currentDateTime;
  TrackNode? get selectedTrackNode => _selectedTrackNode;
  List<TimeBoxData> get inspectedTasks => _inspectedTasks;

  double get zoomLevel => _converter.currentZoomLevel;
  ViewScale get currentViewScale => _converter.currentScale;

  // --- Initialization ---
  void _init() {
    AppLogger.log('[Provider]', 'Initializing Project Data');
    _project = TimelineProject.createDefault();
    _converter = TimeConverter(
        projectStart: _project.projectStartDate,
        config: _project.calendarConfig
    );
    _currentDateTime = _project.projectStartDate;

    final root = _project.rootTrackNode;
    _selectedTrackNode = root;

    // 초기 샘플 데이터
    final groupA = TrackNode(key: 'group_a', data: TrackData.create(title: 'Development Phase'));
    root.add(groupA);
    groupA.add(TrackNode(key: 'track_a1', data: TrackData.create(title: 'Frontend')));
    groupA.add(TrackNode(key: 'track_a2', data: TrackData.create(title: 'Backend')));
    root.add(TrackNode(key: 'track_b', data: TrackData.create(title: 'Design')));

    _focusedTrackId = 'track_a1';

    // [Fix] 초기 그룹 노드들을 펼침 상태로 등록
    _expandedNodeKeys.add('group_a');
    // Root의 다른 자식들도 필요하면 추가

    // [Debug] 초기 상태 트리 출력
    _logTreeStructure("Initial State");
  }

  // --- Expansion State Management ---
  bool isNodeExpanded(String key) => _expandedNodeKeys.contains(key);

  void setNodeExpanded(String key, bool expanded) {
    if (expanded) {
      _expandedNodeKeys.add(key);
    } else {
      _expandedNodeKeys.remove(key);
    }
    // Note: 여기서는 notifyListeners()를 호출하지 않아도 됨 (UI interaction이 주도하므로)
    // 하지만 상태 동기화를 확실히 하려면 호출해도 무방함.
  }

  // --- Viewport & Zoom ---
  void updateViewportWidth(double width) {
    _converter.updateViewportWidth(width);
  }

  void setZoomDays(double days) {
    _converter.setZoom(days);
    notifyListeners();
  }

  void setZoomLevel(double sliderValue) {
    if (sliderValue <= 0.1) sliderValue = 0.1;
    double days = 500.0 / sliderValue;
    setZoomDays(days);
  }

  void zoomIn() {
    setZoomDays(_converter.visibleDays * 0.8);
  }

  void zoomOut() {
    setZoomDays(_converter.visibleDays * 1.2);
  }

  void seekTo(DateTime dt) {
    if (_currentDateTime != dt) {
      _currentDateTime = dt;
      _updateInspection();
      notifyListeners();
    }
  }

  // --- Selection ---
  void setFocusedTrack(String? trackId) {
    if (_focusedTrackId != trackId) {
      _focusedTrackId = trackId;
      if (trackId != null) {
        final node = _findNodeById(_project.rootTrackNode, trackId);
        if (node != null) _selectedTrackNode = node;
      }
      notifyListeners();
    }
  }

  void selectTimeBox(String? boxId) {
    if (_selectedBoxId != boxId) {
      _selectedBoxId = boxId;
      if (boxId != null) _findTrackByBoxId(_project.rootTrackNode, boxId);
      notifyListeners();
    }
  }

  void selectTrack(TrackNode node) {
    _selectedTrackNode = node;
    _focusedTrackId = node.data?.id;
    notifyListeners();
  }

  // --- Calendar Config ---
  void updateCalendarConfig({
    bool? excludeWeekends,
    bool? excludeHolidays,
    int? workStart,
    int? workEnd,
  }) {
    AppLogger.log('[Provider]', 'Update Calendar Config');
    final newConfig = _project.calendarConfig.copyWith(
      excludeWeekends: excludeWeekends,
      excludeHolidays: excludeHolidays,
      workHourStart: workStart,
      workHourEnd: workEnd,
    );

    _project = TimelineProject(
        id: _project.id,
        title: _project.title,
        rootTrackNode: _project.rootTrackNode,
        projectStartDate: _project.projectStartDate,
        calendarConfig: newConfig
    );
    _converter.updateConfig(newConfig);
    notifyListeners();
  }

  // --- Helper Methods ---
  DateTime calculateSmartStartTime() {
    if (_selectedBoxId != null) {
      TimeBoxData? box = _findBoxRecursive(_project.rootTrackNode, _selectedBoxId!);
      if (box != null) return box.endTime;
    }
    return _currentDateTime;
  }

  void _findTrackByBoxId(TrackNode node, String boxId) {
    if (node.data != null) {
      if (node.data!.boxes.any((b) => b.id == boxId)) {
        _focusedTrackId = node.data!.id;
        return;
      }
    }
    for (var child in node.children.values) {
      _findTrackByBoxId(child as TrackNode, boxId);
    }
  }

  void _updateInspection() {
    _inspectedTasks.clear();
    _inspectRecursive(_project.rootTrackNode, _currentDateTime);
  }

  void _inspectRecursive(TrackNode node, DateTime time) {
    if (node.data != null) {
      for (var box in node.data!.boxes) {
        if (time.isAfter(box.startTime) && time.isBefore(box.endTime)) {
          _inspectedTasks.add(box);
        } else if (time.isAtSameMomentAs(box.startTime)) {
          _inspectedTasks.add(box);
        }
      }
    }
    for (var child in node.children.values) {
      _inspectRecursive(child as TrackNode, time);
    }
  }

  // ==========================================================
  // [Req 1-d] Track Operations Improvements
  // ==========================================================

  void addTrack(String title) {
    TrackNode targetParent = _project.rootTrackNode;

    if (_focusedTrackId != null) {
      TrackNode? focused = _findNodeById(_project.rootTrackNode, _focusedTrackId!);
      if (focused != null) {
        targetParent = focused;
      }
    }

    final newTrackData = TrackData.create(title: title);
    final newNode = TrackNode(key: const Uuid().v4(), data: newTrackData);

    targetParent.add(newNode);

    // [Fix] 추가된 노드의 부모는 반드시 펼쳐져 있어야 함
    if(targetParent != _project.rootTrackNode) {
      _expandedNodeKeys.add(targetParent.key);
    }

    // [Fix] 구조 변경 시 버전 증가 및 로그 출력
    _layoutVersion++;
    AppLogger.log('[Provider]', 'Track Added: "$title" to "${targetParent.data?.title ?? 'Root'}"');
    _logTreeStructure("After Add Track");

    notifyListeners();
  }

  void updateTrackData(String trackId, {String? title, String? description, Color? color, double? height}) {
    final node = _findNodeById(_project.rootTrackNode, trackId);
    if (node != null && node.data != null) {
      node.data = node.data!.copyWith(
          title: title,
          description: description,
          color: color,
          height: height
      );
      notifyListeners();
    }
  }

  // ==========================================================
  // [Req 2] 상세 로깅 및 중복 방지, 순서 제어 로직 적용
  // ==========================================================
  void moveTrackNodeWithSlot(TrackNode sourceNode, TrackNode targetNode, DropSlot slot) {
    if (sourceNode == targetNode) return;

    // Cyclic Check
    var p = targetNode.parent;
    while (p != null) {
      if (p == sourceNode) {
        AppLogger.error('[Provider-Move]', 'Fail: Cyclic Dependency Detected');
        return;
      }
      p = p.parent;
    }

    final oldParent = sourceNode.parent;
    final String sourceTitle = sourceNode.data?.title ?? 'Unknown';
    final String targetTitle = targetNode.data?.title ?? 'Unknown';

    AppLogger.log('[Provider-Move]', '--- MOVE START ---');
    AppLogger.log('[Provider-Move]', 'Moving Node: "$sourceTitle"');
    AppLogger.log('[Provider-Move]', 'Target Node: "$targetTitle" (Slot: $slot)');

    // [Debug] 이동 전 트리 상태 출력
    _logTreeStructure("Before Move");

    // 1. [Fix] 기존 부모에서 명시적으로 제거
    if (oldParent != null) {
      oldParent.remove(sourceNode);
      AppLogger.log('[Provider-Move]', 'Removed from old parent (${oldParent.children.length} remaining)');
    }

    // 2. 새로운 위치에 삽입 (순서 제어 포함)
    switch (slot) {
      case DropSlot.center:
        targetNode.add(sourceNode); // 자식으로 추가 (맨 뒤)
        // [Fix] 자식으로 들어갔으므로 타겟 노드는 펼쳐져야 함 (Set 업데이트)
        _expandedNodeKeys.add(targetNode.key);
        AppLogger.log('[Provider-Move]', 'Added as Child');
        break;

      case DropSlot.above:
        _insertSibling(targetNode, sourceNode, isAfter: false);
        // 형제로 들어갔으므로 타겟의 부모가 펼쳐져야 함
        if(targetNode.parent != null && targetNode.parent != _project.rootTrackNode) {
          _expandedNodeKeys.add(targetNode.parent!.key);
        }
        AppLogger.log('[Provider-Move]', 'Inserted Above Sibling');
        break;

      case DropSlot.below:
        _insertSibling(targetNode, sourceNode, isAfter: true);
        if(targetNode.parent != null && targetNode.parent != _project.rootTrackNode) {
          _expandedNodeKeys.add(targetNode.parent!.key);
        }
        AppLogger.log('[Provider-Move]', 'Inserted Below Sibling');
        break;
    }

    AppLogger.log('[Provider-Move]', '--- MOVE END ---');

    // [Fix] 뷰 강제 갱신을 위해 버전 증가
    _layoutVersion++;

    // [Debug] 이동 후 트리 상태 출력
    _logTreeStructure("After Move");

    notifyListeners();
  }

  void moveTrackNode(TrackNode node, TrackNode target, {bool isReparent = false}) {
    moveTrackNodeWithSlot(node, target, DropSlot.center);
  }

  /// [Fix] Map 기반 트리에서 순서를 보장하기 위해
  /// 형제 노드들을 모두 꺼내 재배열한 뒤 부모에 다시 넣는 방식 사용
  void _insertSibling(TrackNode target, TrackNode source, {required bool isAfter}) {
    final parent = target.parent;
    if (parent == null) {
      _project.rootTrackNode.add(source);
      return;
    }

    // 1. 현재 자식들의 리스트 복사 (순서 유지)
    final List<TrackNode> siblings = parent.children.values.map((e) => e as TrackNode).toList();

    // 2. 타겟 인덱스 찾기
    final int targetIndex = siblings.indexWhere((node) => node == target);
    if (targetIndex == -1) {
      parent.add(source); // Fallback
      return;
    }

    // 3. 새로운 위치 계산 및 리스트에 삽입
    final int insertIndex = isAfter ? targetIndex + 1 : targetIndex;

    // 리스트 범위 안전장치
    if (insertIndex >= siblings.length) {
      siblings.add(source);
    } else {
      siblings.insert(insertIndex, source);
    }

    // 4. [Critical] 부모 노드 초기화 후 순서대로 재삽입
    parent.clear(); // 모든 자식 제거

    for (final node in siblings) {
      parent.add(node);
    }

    // [Fix] 부모 펼침 상태 유지
    if(parent != _project.rootTrackNode) {
      _expandedNodeKeys.add(parent.key);
    }
  }

  // ==========================================================
  // Debugging Helper
  // ==========================================================
  void _logTreeStructure(String tag) {
    StringBuffer sb = StringBuffer();
    sb.writeln("\n=== TREE DUMP [$tag] ===");
    _printNodeRecursive(_project.rootTrackNode, 0, sb);
    sb.writeln("============================\n");
    AppLogger.log('[Tree-Dump]', sb.toString());
  }

  void _printNodeRecursive(TrackNode node, int level, StringBuffer sb) {
    String indent = "  " * level;
    String title = node.data?.title ?? "ROOT";
    String key = node.key;
    String childCount = "${node.children.length}";

    if (node == _project.rootTrackNode) {
      sb.writeln("$indent[ROOT] (Children: $childCount)");
    } else {
      sb.writeln("$indent- $title (Key: $key) [Child: $childCount]");
    }

    for (var child in node.children.values) {
      _printNodeRecursive(child as TrackNode, level + 1, sb);
    }
  }

  // --- TimeBox Operations ---
  TrackNode? _findNodeById(TrackNode root, String trackId) {
    if (root.data?.id == trackId) return root;
    for (var child in root.children.values) {
      final found = _findNodeById(child as TrackNode, trackId);
      if (found != null) return found;
    }
    return null;
  }

  TrackNode? findNodeById(TrackNode root, String trackId) => _findNodeById(root, trackId);

  TimeBoxData? _findBoxRecursive(TrackNode node, String boxId) {
    if (node.data != null) {
      final found = node.data!.boxes.where((b) => b.id == boxId);
      if (found.isNotEmpty) return found.first;
    }
    for (var child in node.children.values) {
      final res = _findBoxRecursive(child as TrackNode, boxId);
      if (res != null) return res;
    }
    return null;
  }

  void addTimeBox(String trackId, DateTime start, Duration duration, {String title = 'New Task', String desc = '', Color? color}) {
    final node = _findNodeById(_project.rootTrackNode, trackId);
    if (node == null) return;

    final trackData = node.data!;
    final newBox = TimeBoxData.create(start: start, duration: duration, title: title)
        .copyWith(description: desc, color: color);

    final updatedBoxes = List<TimeBoxData>.from(trackData.boxes)..add(newBox);
    node.data = trackData.copyWith(boxes: updatedBoxes);

    _focusedTrackId = trackId;
    _selectedBoxId = newBox.id;

    notifyListeners();
  }

  void updateTimeBox(String boxId, DateTime newStart, Duration newDuration) {
    _updateBoxRecursive(_project.rootTrackNode, boxId, newStart, newDuration);
    notifyListeners();
  }

  void moveBoxToTrack(String boxId, String fromTrackId, String targetTrackId, DateTime newStartTime) {
    final sourceNode = _findNodeById(_project.rootTrackNode, fromTrackId);
    final targetNode = _findNodeById(_project.rootTrackNode, targetTrackId);
    if (sourceNode == null || targetNode == null) return;

    TimeBoxData? boxToMove;
    final sourceBoxes = sourceNode.data!.boxes;
    final boxIdx = sourceBoxes.indexWhere((b) => b.id == boxId);

    if (boxIdx != -1) {
      boxToMove = sourceBoxes[boxIdx];
      final newSourceBoxes = List<TimeBoxData>.from(sourceBoxes)..removeAt(boxIdx);
      sourceNode.data = sourceNode.data!.copyWith(boxes: newSourceBoxes);
    }

    if (boxToMove == null) return;

    final updatedBox = boxToMove.copyWith(startTime: newStartTime);
    final newTargetBoxes = List<TimeBoxData>.from(targetNode.data!.boxes)..add(updatedBox);
    targetNode.data = targetNode.data!.copyWith(boxes: newTargetBoxes);

    _focusedTrackId = targetTrackId;
    _selectedBoxId = boxId;

    notifyListeners();
  }

  void replaceTimeBox(String boxId, TimeBoxData newBox) {
    _replaceBoxRecursive(_project.rootTrackNode, boxId, newBox);
    notifyListeners();
  }

  bool _updateBoxRecursive(TrackNode node, String boxId, DateTime start, Duration dur) {
    final track = node.data;
    if (track == null) return false;
    final idx = track.boxes.indexWhere((b) => b.id == boxId);
    if (idx != -1) {
      final box = track.boxes[idx];
      final newBox = box.copyWith(startTime: start, duration: dur);
      final newBoxes = List<TimeBoxData>.from(track.boxes);
      newBoxes[idx] = newBox;
      node.data = track.copyWith(boxes: newBoxes);
      return true;
    }
    for (var child in node.children.values) {
      if (_updateBoxRecursive(child as TrackNode, boxId, start, dur)) return true;
    }
    return false;
  }

  bool _replaceBoxRecursive(TrackNode node, String boxId, TimeBoxData newBoxData) {
    final track = node.data;
    if (track == null) return false;
    final idx = track.boxes.indexWhere((b) => b.id == boxId);
    if (idx != -1) {
      final newBoxes = List<TimeBoxData>.from(track.boxes);
      newBoxes[idx] = newBoxData;
      node.data = track.copyWith(boxes: newBoxes);
      return true;
    }
    for (var child in node.children.values) {
      if (_replaceBoxRecursive(child as TrackNode, boxId, newBoxData)) return true;
    }
    return false;
  }
}