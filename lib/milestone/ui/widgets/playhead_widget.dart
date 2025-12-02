import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/timeline_provider.dart';
import '../../utils/logger.dart';

class PlayheadWidget extends StatelessWidget {
  final ScrollController scrollController; // 가로 스크롤 동기화용
  final double height; // 전체 타임라인 높이

  const PlayheadWidget({
    Key? key,
    required this.scrollController,
    required this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimelineProvider>();

    // [Fix] DateTime 기반으로 변경
    final currentDt = provider.currentDateTime;
    final converter = provider.converter;

    // [Fix] DateTime -> Pixels 변환
    final double leftPosition = converter.dateTimeToPixels(currentDt);

    return IgnorePointer(
      child: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Container(
          width: 50000.0, // 전체 캔버스 크기 (TimeRuler와 일치해야 함)
          height: height,
          alignment: Alignment.centerLeft,
          child: Stack(
            children: [
              Positioned(
                left: leftPosition,
                top: 0,
                bottom: 0,
                child: Column(
                  children: [
                    // Head
                    Container(
                      width: 15,
                      height: 15,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    // Line
                    Expanded(
                      child: Container(
                        width: 2,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}