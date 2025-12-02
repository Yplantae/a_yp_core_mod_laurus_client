import 'package:a_yp_core_mod_laurus_client/milestone/ui/dialogs/task_editor_dialog.dart';
import 'package:a_yp_core_mod_laurus_client/milestone/utils/synced_scroll_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animated_tree_view/animated_tree_view.dart';
import '../providers/timeline_provider.dart';
import '../models/timeline_models.dart';
import '../utils/logger.dart';
import 'widgets/time_ruler_widget.dart';
import 'widgets/track_widget.dart';
import 'widgets/timeline_toolbar.dart';
import 'widgets/playhead_widget.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({Key? key}) : super(key: key);

  @override
  State<TimelineScreen> createState() => TimelineScreenState();
}

class TimelineScreenState extends State<TimelineScreen> {
  late SyncedScrollControllerGroup _syncGroup;
  late ScrollController _rulerController;
  late ScrollController _playheadController;

  // [Req 1-e] Header Width State
  double _headerWidth = 250.0;
  final double _minHeaderWidth = 100.0;
  final double _maxHeaderWidth = 500.0;

  double _bottomPanelHeight = 200.0;
  TreeViewController<TrackData, TrackNode>? _treeController;

  @override
  void initState() {
    super.initState();
    AppLogger.log('[UI-Screen]', 'TimelineScreen Init');
    _syncGroup = SyncedScrollControllerGroup();
    _rulerController = _syncGroup.addAndGet();
    _playheadController = _syncGroup.addAndGet();
  }

  @override
  void dispose() {
    _syncGroup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimelineProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(provider.project.title),
        backgroundColor: Colors.grey[850],
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final laneWidth = constraints.maxWidth - _headerWidth - 6.0;
          provider.updateViewportWidth(laneWidth > 0 ? laneWidth : 100);

          return Column(
            children: [
              const TimelineToolbar(),
              const Divider(height: 1, color: Colors.grey),

              // 1. Ruler Area
              SizedBox(
                height: 40,
                child: Row(
                  children: [
                    Container(
                      width: _headerWidth,
                      color: Colors.grey[850],
                      alignment: Alignment.center,
                      child: const Text("Tracks", style: TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(width: 6.0),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) => _handleSeek(context, d.localPosition.dx),
                        onHorizontalDragUpdate: (d) => _handleSeek(context, d.localPosition.dx),
                        child: TimeRulerWidget(scrollController: _rulerController, totalWidth: 50000),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.grey),

              // 2. Main Timeline
              Expanded(
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      if (event.scrollDelta.dy > 0) provider.zoomOut();
                      else if (event.scrollDelta.dy < 0) provider.zoomIn();
                    }
                  },
                  child: Stack(
                    children: [
                      TreeView.simple(
                        // [Critical Fix] Provider의 layoutVersion이 바뀌면 TreeView를 강제로 다시 그림
                        // 이를 통해 데이터 변경 후 잔상(Ghosting) 문제를 해결함
                        key: ValueKey(provider.layoutVersion),

                        tree: provider.project.rootTrackNode,
                        showRootNode: false,
                        expansionBehavior: ExpansionBehavior.scrollToLastChild,
                        onTreeReady: (controller) {
                          _treeController = controller;
                          // 리빌드 시 트리가 접히는 것을 방지하기 위해 전체 확장 (필요시 제거 가능)
                          controller.expandAllChildren(provider.project.rootTrackNode);
                        },
                        builder: (context, node) {
                          final trackNode = node as TrackNode;
                          final rowHeight = trackNode.data?.height ?? 60.0;
                          return _buildResizableRow(context, provider, trackNode, rowHeight);
                        },
                      ),
                      Positioned(
                        left: _headerWidth + 6.0,
                        top: 0, bottom: 0, right: 0,
                        child: PlayheadWidget(scrollController: _playheadController, height: 5000),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Inspection Panel
              GestureDetector(
                onVerticalDragUpdate: (d) {
                  setState(() {
                    _bottomPanelHeight -= d.delta.dy;
                    if (_bottomPanelHeight < 50) _bottomPanelHeight = 50;
                    if (_bottomPanelHeight > 400) _bottomPanelHeight = 400;
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpDown,
                  child: Container(height: 5, color: Colors.grey[700]),
                ),
              ),
              Container(
                height: _bottomPanelHeight,
                color: Colors.grey[850],
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Tasks at Playhead", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ListView.builder(
                        itemCount: provider.inspectedTasks.length,
                        itemBuilder: (ctx, idx) {
                          final task = provider.inspectedTasks[idx];
                          return Card(
                            color: Colors.grey[800],
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.task, color: task.color ?? Colors.blueAccent),
                              title: Text(task.title, style: const TextStyle(color: Colors.white)),
                              subtitle: Text("${task.startTime} ~ ${task.endTime} (${task.grade.name})", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                            ),
                          );
                        },
                      ),
                    )
                  ],
                ),
              )
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _handleFabClick(context, provider),
      ),
    );
  }

  Widget _buildResizableRow(BuildContext context, TimelineProvider provider, TrackNode node, double height) {
    // 1. [Req 3] Indent 계산
    final double indent = (node.level * 20.0).clamp(0.0, _headerWidth - 50.0);

    // 2. Feedback Widget (드래그 시 보이는 반투명 Row)
    Widget feedbackWidget = Material(
      color: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: height,
        color: Colors.grey[900]!.withOpacity(0.9),
        child: Row(
          children: [
            Container(
              width: _headerWidth,
              padding: EdgeInsets.only(left: indent),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey[700]!)),
              ),
              child: _buildHeaderContent(context, provider, node, isFeedback: true),
            ),
            const SizedBox(width: 6.0),
            Expanded(
              child: IgnorePointer(
                child: TrackWidget(
                  track: node.data!,
                  scrollController: ScrollController(initialScrollOffset: _rulerController.hasClients ? _rulerController.offset : 0),
                  height: height,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // [Critical Fix] KeyedSubtree: 각 노드에 고유 키를 부여하여 위치 변경 시 위젯 식별 보장
    return KeyedSubtree(
      key: ValueKey(node.key),
      child: Builder(
        builder: (rowContext) {
          return LongPressDraggable<TrackNode>(
            data: node,
            delay: const Duration(milliseconds: 150),
            feedback: feedbackWidget,
            childWhenDragging: Opacity(
                opacity: 0.3,
                child: _buildRowContent(rowContext, provider, node, height, indent)
            ),
            child: DragTarget<TrackNode>(
              onWillAccept: (incoming) => incoming != null && incoming != node,
              onAcceptWithDetails: (details) {
                final renderBox = rowContext.findRenderObject() as RenderBox;
                final localOffset = renderBox.globalToLocal(details.offset);
                final y = localOffset.dy;
                final h = renderBox.size.height;

                DropSlot slot;
                if (y < h * 0.25) slot = DropSlot.above;
                else if (y > h * 0.75) slot = DropSlot.below;
                else slot = DropSlot.center;

                provider.moveTrackNodeWithSlot(details.data, node, slot);
              },
              builder: (ctx, candidates, rejects) {
                Color? feedbackColor;
                if (candidates.isNotEmpty) {
                  feedbackColor = Colors.blue.withOpacity(0.1);
                }
                return Container(
                  color: feedbackColor,
                  child: _buildRowContent(rowContext, provider, node, height, indent),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildRowContent(BuildContext context, TimelineProvider provider, TrackNode node, double height, double indent) {
    return Stack(
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
          ),
          child: Row(
            children: [
              // Header
              Container(
                width: _headerWidth,
                padding: EdgeInsets.only(left: indent),
                child: _buildHeaderContent(context, provider, node),
              ),

              // Splitter
              _buildVerticalSplitter(),

              // Body
              Expanded(
                child: TrackWidget(
                  track: node.data!,
                  scrollController: _syncGroup.addAndGet(),
                  height: height,
                  contentWidth: 50000,
                ),
              ),
            ],
          ),
        ),

        // Bottom Resizer
        Positioned(
          left: 0, right: 0, bottom: 0, height: 6,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeRow,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (d) {
                final newHeight = height + d.delta.dy;
                if (newHeight >= 40) {
                  provider.updateTrackData(node.data!.id, height: newHeight);
                }
              },
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.bottomCenter,
                child: Container(height: 1, color: Colors.transparent),
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildVerticalSplitter() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) {
        setState(() {
          _headerWidth += d.delta.dx;
          if (_headerWidth < _minHeaderWidth) _headerWidth = _minHeaderWidth;
          if (_headerWidth > _maxHeaderWidth) _headerWidth = _maxHeaderWidth;
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 6.0,
          color: Colors.black26,
          child: Center(child: Container(width: 1, color: Colors.grey[700])),
        ),
      ),
    );
  }

  Widget _buildHeaderContent(BuildContext context, TimelineProvider provider, TrackNode node, {bool isFeedback = false}) {
    final isFocused = provider.focusedTrackId == node.data?.id;

    return Container(
      color: (!isFeedback && isFocused) ? Colors.blue.withOpacity(0.2) : Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            child: node.children.isNotEmpty
                ? InkWell(
              onTap: () {
                if (!isFeedback && _treeController != null) _treeController!.toggleExpansion(node);
              },
              child: Icon(node.isExpanded ? Icons.expand_more : Icons.chevron_right, size: 16, color: Colors.white70),
            )
                : null,
          ),
          const SizedBox(width: 4),
          Icon(Icons.drag_indicator, size: 16, color: isFeedback ? Colors.white : Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if(!isFeedback) provider.setFocusedTrack(node.data?.id);
              },
              onDoubleTap: () {
                if(!isFeedback) _showTrackEditDialog(context, provider, node);
              },
              child: Text(
                node.data?.title ?? 'Untitled',
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTrackEditDialog(BuildContext context, TimelineProvider provider, TrackNode node) {
    final controller = TextEditingController(text: node.data?.title);
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("Edit Track", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Title", labelStyle: TextStyle(color: Colors.grey))
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                provider.updateTrackData(node.data!.id, title: controller.text);
                Navigator.pop(ctx);
              },
              child: const Text("Save"),
            )
          ],
        )
    );
  }

  void _handleSeek(BuildContext context, double localDx) {
    final provider = context.read<TimelineProvider>();
    final scrollOffset = _rulerController.hasClients ? _rulerController.offset : 0.0;
    final absoluteX = scrollOffset + localDx;
    final dateTime = provider.converter.pixelsToDateTime(absoluteX);
    provider.seekTo(dateTime);
  }

  void _handleFabClick(BuildContext context, TimelineProvider provider) async {
    if (provider.focusedTrackId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a track to add task')));
      return;
    }
    final startTime = provider.calculateSmartStartTime();
    final result = await showDialog(
        context: context,
        builder: (_) => TaskEditorDialog(
            initialStart: startTime,
            initialDuration: const Duration(days: 3)
        )
    );
    if (result != null) {
      provider.addTimeBox(
          provider.focusedTrackId!,
          result['start'],
          result['duration'],
          title: result['title'],
          desc: result['desc'],
          color: result['color']
      );
      final targetPx = provider.converter.dateTimeToPixels(result['start']);
      if (_rulerController.hasClients) {
        double offset = targetPx - 300;
        if(offset < 0) offset = 0;
        _rulerController.animateTo(offset, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
    }
  }
}