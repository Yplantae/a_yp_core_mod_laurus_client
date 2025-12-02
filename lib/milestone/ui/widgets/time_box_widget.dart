import 'package:flutter/material.dart';
import '../../models/timeline_models.dart';
import '../../utils/time_converter.dart';

class TimeBoxWidget extends StatelessWidget {
  final TimeBoxData boxData;
  final TimeConverter converter;
  final double height;

  const TimeBoxWidget({
    Key? key,
    required this.boxData,
    required this.converter,
    this.height = 60.0,
  }) : super(key: key);

  String _formatDateTime(DateTime dt) {
    return "${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2,'0')}";
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return "${d.inDays}d ${d.inHours%24}h";
    return "${d.inHours}h ${d.inMinutes%60}m";
  }

  Color _gradeColor(TaskGrade grade) {
    switch(grade) {
      case TaskGrade.S: return Colors.purpleAccent;
      case TaskGrade.A: return Colors.blueAccent;
      case TaskGrade.B: return Colors.green;
      case TaskGrade.C: return Colors.orange;
      case TaskGrade.D: return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = converter.durationToPixels(boxData.duration);
    final displayWidth = width < 2.0 ? 2.0 : width;

    final boxColor = Colors.grey[800]!;
    final accentColor = _gradeColor(boxData.grade);

    return Container(
      width: displayWidth,
      height: height,
      decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: accentColor, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 2, offset: const Offset(1, 1))
          ]
      ),
      child: Stack(
        children: [
          if (boxData.snapshotImage != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Opacity(
                  opacity: 0.2,
                  child: Image.memory(boxData.snapshotImage!, fit: BoxFit.cover),
                ),
              ),
            ),

          // [Fix] RenderFlex Safety using LayoutBuilder
          Padding(
            padding: const EdgeInsets.all(4),
            child: LayoutBuilder(
                builder: (context, constraints) {
                  // 공간이 너무 좁으면 Compact View
                  if (width < 60 || constraints.maxHeight < 30) {
                    return Center(
                        child: Text(
                            boxData.title,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis
                        )
                    );
                  }
                  return _buildFullView(constraints, accentColor);
                }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullView(BoxConstraints constraints, Color accentColor) {
    // 가용 높이에 따라 표시 요소 결정
    bool showDesc = constraints.maxHeight > 55; // 높이가 충분할 때만 설명 표시
    bool showTime = constraints.maxHeight > 40; // 높이가 어느정도 되면 시간 표시

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Title Row
        Row(
          children: [
            Icon(IconData(boxData.iconPoint, fontFamily: 'MaterialIcons'), color: accentColor, size: 12),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                  boxData.title,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis
              ),
            ),
          ],
        ),

        if (showDesc) ...[
          const SizedBox(height: 2),
          Expanded( // [Fix] Use Expanded to consume available space properly
            child: Text(
              boxData.description,
              style: const TextStyle(color: Colors.grey, fontSize: 9),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ] else
          const Spacer(), // Push bottom row down

        if (showTime) ...[
          const Divider(height: 4, color: Colors.white12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "${_formatDateTime(boxData.startTime)}",
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatDuration(boxData.duration),
                style: TextStyle(color: accentColor, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ]
      ],
    );
  }
}