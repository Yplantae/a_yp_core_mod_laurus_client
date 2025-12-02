import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/timeline_provider.dart';
import '../../utils/logger.dart';
import '../../utils/time_converter.dart';
import '../../models/timeline_models.dart';

class TimeRulerWidget extends StatelessWidget {
  final ScrollController scrollController;
  final double totalWidth;

  const TimeRulerWidget({
    Key? key,
    required this.scrollController,
    this.totalWidth = 50000.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Provider의 변경사항(Zoom, Config, ProjectStart)을 구독
    final provider = context.watch<TimelineProvider>();
    final converter = provider.converter;
    final config = provider.project.calendarConfig;

    // [Fix] Painter에게 전달할 "변하는 값(ZoomLevel)" 추출
    // 이 값이 변경되면 Painter는 다시 그려야 함을 인지합니다.
    final currentZoom = provider.zoomLevel;

    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: CustomPaint(
        size: Size(totalWidth, 40),
        painter: _SmartRulerPainter(
          converter: converter,
          config: config,
          visibleZoomLevel: currentZoom, // [Key Fix] Repaint Trigger
          backgroundColor: Colors.grey[900]!,
          tickColor: Colors.grey[400]!,
          textColor: Colors.white,
          weekendColor: Colors.red.withOpacity(0.1), // 주말/휴일 배경색
        ),
      ),
    );
  }
}

class _SmartRulerPainter extends CustomPainter {
  final TimeConverter converter;
  final CalendarConfig config;
  final double visibleZoomLevel; // [New] 줌 레벨 변경 감지용

  final Color backgroundColor;
  final Color tickColor;
  final Color textColor;
  final Color weekendColor;

  _SmartRulerPainter({
    required this.converter,
    required this.config,
    required this.visibleZoomLevel,
    required this.backgroundColor,
    required this.tickColor,
    required this.textColor,
    required this.weekendColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 배경 채우기
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.0;

    final weekendPaint = Paint()..color = weekendColor;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // 2. ViewScale에 따른 그리기 전략 수립
    final scale = converter.currentScale;
    final start = converter.projectStartDate;
    final endPixels = size.width;

    // DateTime 루프를 위한 변수들
    DateTime current = start;

    // 루프 안전장치
    int safetyCount = 0;

    // 무한 루프 방지용 안전 장치 (화면 너비 기준 종료)
    while (converter.dateTimeToPixels(current) <= endPixels) {
      safetyCount++;
      if (safetyCount > 20000) break; // 과도한 줌 아웃 시 보호

      final x = converter.dateTimeToPixels(current);

      // A. 비업무일(주말) 배경 그리기 (Day View 이상일 때만 의미 있음)
      if (scale == ViewScale.day || scale == ViewScale.week || scale == ViewScale.month) {
        if (_isWeekend(current) || _isHoliday(current)) {
          // 하루치 너비 계산
          final nextDayX = converter.dateTimeToPixels(current.add(const Duration(days: 1)));
          final width = nextDayX - x;
          canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), weekendPaint);
        }
      }

      // B. 눈금 및 텍스트 그리기
      _drawTickAndText(canvas, x, current, scale, size.height, tickPaint, textPainter);

      // C. 다음 틱으로 이동 (Semantic Step)
      current = _nextStep(current, scale);
    }
  }

  void _drawTickAndText(
      Canvas canvas, double x, DateTime date, ViewScale scale, double height,
      Paint tickPaint, TextPainter textPainter
      ) {
    // Major Tick Height
    double tickH = 15.0;
    bool showText = true;
    String text = "";

    // 텍스트 포맷팅 로직
    switch (scale) {
      case ViewScale.year:
        text = "${date.year}";
        // 1월 1일만 Major Tick
        if (date.month != 1 || date.day != 1) {
          tickH = 8.0; showText = false;
        }
        break;
      case ViewScale.month:
      // 매월 1일
        if (date.day == 1) {
          text = "${date.year}.${date.month}";
        } else {
          tickH = 5.0; showText = false;
        }
        break;
      case ViewScale.week:
      // 월요일마다 표시
        if (date.weekday == DateTime.monday) {
          text = "${date.month}/${date.day} (Mon)";
        } else {
          tickH = 5.0; showText = false;
        }
        break;
      case ViewScale.day:
      // 매일 표시
        text = "${date.day} ${_weekdayShort(date.weekday)}";
        break;
      case ViewScale.hour:
      // 매 시간
        if (date.minute == 0) {
          text = "${date.hour}:00";
        } else {
          tickH = 5.0; showText = false;
        }
        break;
      case ViewScale.minute:
        if (date.second == 0) {
          text = "${date.hour}:${date.minute}";
        } else {
          tickH = 5.0; showText = false;
        }
        break;
    }

    // Draw Tick
    canvas.drawLine(Offset(x, height - tickH), Offset(x, height), tickPaint);

    // Draw Text
    if (showText) {
      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(color: textColor, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + 4, height - tickH - 12));
    }
  }

  // 뷰 스케일에 따른 다음 시간 계산
  DateTime _nextStep(DateTime current, ViewScale scale) {
    switch (scale) {
      case ViewScale.year:
        return DateTime(current.year + 1, 1, 1);
      case ViewScale.month:
        if (current.month == 12) return DateTime(current.year + 1, 1, 1);
        return DateTime(current.year, current.month + 1, 1);
      case ViewScale.week:
        return current.add(const Duration(days: 1));
      case ViewScale.day:
        return current.add(const Duration(days: 1));
      case ViewScale.hour:
        return current.add(const Duration(hours: 1));
      case ViewScale.minute:
        return current.add(const Duration(minutes: 1));
    }
  }

  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  bool _isHoliday(DateTime date) {
    for (var h in config.holidays) {
      if (h.date.year == date.year && h.date.month == date.month && h.date.day == date.day) {
        return true;
      }
    }
    return false;
  }

  String _weekdayShort(int weekday) {
    const list = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return list[weekday - 1];
  }

  @override
  bool shouldRepaint(covariant _SmartRulerPainter old) {
    // [Key Fix] Converter 객체 주소가 같아도, visibleZoomLevel이 다르면 다시 그림
    return old.visibleZoomLevel != visibleZoomLevel ||
        old.config != config ||
        old.converter != converter;
  }
}