import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/timeline_models.dart';
import '../../providers/timeline_provider.dart';
import '../../utils/logger.dart';
import 'time_box_interactor.dart';

class TrackWidget extends StatelessWidget {
  final TrackData track;
  final ScrollController scrollController;
  final double height;
  final double contentWidth;

  const TrackWidget({
    Key? key,
    required this.track,
    required this.scrollController,
    required this.height,
    this.contentWidth = 50000.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimelineProvider>();
    final converter = provider.converter;

    final isFocused = provider.focusedTrackId == track.id;
    final bgColor = isFocused ? Colors.grey[800]! : Colors.grey[850]!;
    final borderColor = isFocused ? Colors.blueAccent.withOpacity(0.5) : Colors.transparent;

    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
      ),
      child: GestureDetector(
        onTap: () => provider.setFocusedTrack(track.id),

        onHorizontalDragUpdate: (details) {
          if (scrollController.hasClients) {
            final current = scrollController.offset;
            scrollController.jumpTo(current - details.delta.dx);
          }
        },

        child: SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: DragTarget<Map<String, dynamic>>(
            onWillAccept: (data) => data?['type'] == 'TimeBox' || data?['type'] == 'NewBoxFactory',
            onAcceptWithDetails: (details) => _handleDrop(context, details, provider),
            builder: (context, candidateData, rejectedData) {
              Color overlayColor = Colors.transparent;
              if (candidateData.isNotEmpty) overlayColor = Colors.blue.withOpacity(0.1);

              return Container(
                width: contentWidth,
                height: height,
                color: overlayColor,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // TimeBoxes
                    ...track.boxes.map((box) {
                      return TimeBoxInteractor(
                        key: ValueKey(box.id),
                        boxData: box,
                        trackId: track.id,
                        height: height,
                        converter: converter,
                      );
                    }).toList(),

                    // Drop Zone (Invisible fill)
                    Positioned.fill(
                      child: DragTarget<Map<String, dynamic>>(
                        onWillAccept: (data) => true,
                        onAcceptWithDetails: (details) => _handleDrop(context, details, provider),
                        builder: (ctx, cand, rej) => const SizedBox.shrink(),
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleDrop(BuildContext context, DragTargetDetails<Map<String, dynamic>> details, TimelineProvider provider) {
    final data = details.data;
    final type = data['type'];
    final renderBox = context.findRenderObject() as RenderBox;
    final localOffset = renderBox.globalToLocal(details.offset);
    double dropX = localOffset.dx;
    if (dropX < 0) dropX = 0;

    // Absolute Time Calculation
    final scrollOffset = scrollController.offset;
    double absoluteX = scrollOffset + dropX;

    final dropTime = provider.converter.pixelsToDateTime(absoluteX);

    if (type == 'TimeBox') {
      provider.moveBoxToTrack(data['boxId'], data['fromTrackId'], track.id, dropTime);
    } else if (type == 'NewBoxFactory') {
      final Duration duration = data['duration'] ?? const Duration(days: 3);
      provider.addTimeBox(track.id, dropTime, duration);
    }
  }
}