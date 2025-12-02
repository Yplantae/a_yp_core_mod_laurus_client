import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/timeline_models.dart';
import '../../providers/timeline_provider.dart';
import '../../utils/logger.dart';
import '../../utils/time_converter.dart';
import '../dialogs/task_editor_dialog.dart'; // [Changed]
import 'time_box_widget.dart';

class TimeBoxInteractor extends StatelessWidget {
  final TimeBoxData boxData;
  final String trackId;
  final double height;
  final TimeConverter converter;

  const TimeBoxInteractor({
    Key? key,
    required this.boxData,
    required this.trackId,
    required this.height,
    required this.converter,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double leftPos = converter.dateTimeToPixels(boxData.startTime);
    final double width = converter.durationToPixels(boxData.duration);

    // [New] Selection Style
    final isSelected = context.select<TimelineProvider, bool>((p) => p.selectedBoxId == boxData.id);
    final border = isSelected ? Border.all(color: Colors.yellowAccent, width: 2) : null;

    final dragData = {
      'type': 'TimeBox',
      'boxId': boxData.id,
      'fromTrackId': trackId,
      'duration': boxData.duration,
    };

    return Positioned(
      left: leftPos,
      top: 2,
      height: height - 4,
      width: width,
      child: GestureDetector(
        onTap: () {
          // [New] Select Box
          context.read<TimelineProvider>().selectTimeBox(boxData.id);
        },
        onDoubleTap: () => _openEditor(context),
        child: Container(
          // Selection Wrapper
          foregroundDecoration: BoxDecoration(
              border: border,
              borderRadius: BorderRadius.circular(4)
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: LongPressDraggable<Map<String, dynamic>>(
                  data: dragData,
                  delay: const Duration(milliseconds: 200),
                  feedback: Material(
                    color: Colors.transparent,
                    child: Opacity(opacity: 0.7, child: _buildContent()),
                  ),
                  childWhenDragging: Opacity(opacity: 0.3, child: _buildContent()),
                  child: _buildContent(), // Move removed from here, handled by wrapper Draggable or track
                ),
              ),
              // Resize Handles (Left/Right) - Same as before...
              _buildResizeHandle(context, true),
              _buildResizeHandle(context, false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return TimeBoxWidget(
      boxData: boxData,
      converter: converter,
      height: height - 4,
    );
  }

  Widget _buildResizeHandle(BuildContext context, bool isLeft) {
    return Positioned(
      left: isLeft ? 0 : null, right: isLeft ? null : 0,
      top: 0, bottom: 0, width: 10,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) => isLeft ? _handleResizeLeft(context, d) : _handleResizeRight(context, d),
        child: MouseRegion(cursor: SystemMouseCursors.resizeLeftRight, child: Container(color: Colors.transparent)),
      ),
    );
  }

  void _handleResizeLeft(BuildContext context, DragUpdateDetails details) {
    // ... (Same logic)
    final durationDelta = converter.pixelsToDuration(details.delta.dx);
    final endTime = boxData.startTime.add(boxData.duration);
    var newStart = boxData.startTime.add(durationDelta);
    var newDuration = endTime.difference(newStart);
    if(newDuration < const Duration(minutes: 1)) {
      newDuration = const Duration(minutes: 1);
      newStart = endTime.subtract(newDuration);
    }
    context.read<TimelineProvider>().updateTimeBox(boxData.id, newStart, newDuration);
  }

  void _handleResizeRight(BuildContext context, DragUpdateDetails details) {
    // ... (Same logic)
    final durationDelta = converter.pixelsToDuration(details.delta.dx);
    context.read<TimelineProvider>().updateTimeBox(boxData.id, boxData.startTime, boxData.duration + durationDelta);
  }

  void _openEditor(BuildContext context) async {
    final provider = context.read<TimelineProvider>();
    // [Changed] Open TaskEditorDialog in Edit Mode
    final result = await showDialog(
        context: context,
        builder: (_) => TaskEditorDialog(
          initialStart: boxData.startTime,
          initialDuration: boxData.duration,
          initialTitle: boxData.title,
          initialDesc: boxData.description,
          initialGrade: boxData.grade,
          initialColor: boxData.color,
        )
    );

    if (result != null) {
      final updatedBox = boxData.copyWith(
          title: result['title'],
          description: result['desc'],
          startTime: result['start'],
          duration: result['duration'],
          grade: result['grade'],
          color: result['color']
      );
      provider.replaceTimeBox(boxData.id, updatedBox);
    }
  }
}