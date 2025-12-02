import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:animated_tree_view/animated_tree_view.dart';
import '../utils/logger.dart';

const _uuid = Uuid();

enum TaskGrade { S, A, B, C, D }

typedef TrackNode = TreeNode<TrackData>;

class CalendarConfig {
  final bool excludeWeekends;
  final bool excludeHolidays;
  final List<HolidayData> holidays;
  final int workHourStart;
  final int workHourEnd;

  CalendarConfig({
    this.excludeWeekends = false,
    this.excludeHolidays = false,
    this.holidays = const [],
    this.workHourStart = 9,
    this.workHourEnd = 18,
  });

  factory CalendarConfig.defaultConfig() {
    return CalendarConfig(
      excludeWeekends: true,
      excludeHolidays: true,
      holidays: [
        HolidayData(name: "New Year's Day", date: DateTime(2026, 1, 1)),
      ],
    );
  }

  CalendarConfig copyWith({
    bool? excludeWeekends,
    bool? excludeHolidays,
    List<HolidayData>? holidays,
    int? workHourStart,
    int? workHourEnd,
  }) {
    return CalendarConfig(
      excludeWeekends: excludeWeekends ?? this.excludeWeekends,
      excludeHolidays: excludeHolidays ?? this.excludeHolidays,
      holidays: holidays ?? this.holidays,
      workHourStart: workHourStart ?? this.workHourStart,
      workHourEnd: workHourEnd ?? this.workHourEnd,
    );
  }
}

class HolidayData {
  final String name;
  final DateTime date;
  HolidayData({required this.name, required this.date});
}

class TimelineProject {
  final String id;
  final String title;
  final TrackNode rootTrackNode;
  final DateTime projectStartDate;
  final CalendarConfig calendarConfig;

  TimelineProject({
    required this.id,
    required this.title,
    required this.rootTrackNode,
    required this.projectStartDate,
    required this.calendarConfig,
  });

  factory TimelineProject.createDefault() {
    AppLogger.log('Model', 'Creating Default Project');
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    final rootData = TrackData(id: 'root', title: 'Root', boxes: []);
    final rootNode = TrackNode(key: 'root_key', data: rootData);

    return TimelineProject(
      id: _uuid.v4(),
      title: 'New Project',
      rootTrackNode: rootNode,
      projectStartDate: todayMidnight,
      calendarConfig: CalendarConfig.defaultConfig(),
    );
  }
}

class TrackData {
  final String id;
  String title;
  String description;
  Color? color;

  // [New] Track Height (Resizable)
  double height;

  final List<TimeBoxData> boxes;

  TrackData({
    required this.id,
    required this.title,
    required this.boxes,
    this.description = '',
    this.color,
    this.height = 60.0, // Default Height
  });

  factory TrackData.create({String title = 'New Track'}) {
    return TrackData(id: _uuid.v4(), title: title, boxes: []);
  }

  TrackData copyWith({
    String? title,
    List<TimeBoxData>? boxes,
    String? description,
    Color? color,
    double? height,
  }) {
    return TrackData(
      id: id,
      title: title ?? this.title,
      boxes: boxes ?? this.boxes,
      description: description ?? this.description,
      color: color ?? this.color,
      height: height ?? this.height,
    );
  }
}

class TimeBoxData {
  final String id;
  final DateTime startTime;
  final Duration duration;

  String title;
  String description;
  int iconPoint;
  TaskGrade grade;
  Color? color;
  final Uint8List? snapshotImage;

  TimeBoxData({
    required this.id,
    required this.startTime,
    required this.duration,
    this.title = 'Task',
    this.description = '',
    this.iconPoint = 0xe88a,
    this.grade = TaskGrade.B,
    this.color,
    this.snapshotImage,
  });

  factory TimeBoxData.create({
    required DateTime start,
    required Duration duration,
    String title = 'Task',
  }) {
    final id = _uuid.v4();
    return TimeBoxData(
      id: id,
      startTime: start,
      duration: duration,
      title: title,
      description: '',
      iconPoint: 0xe88a,
      grade: TaskGrade.B,
    );
  }

  DateTime get endTime => startTime.add(duration);

  TimeBoxData copyWith({
    DateTime? startTime,
    Duration? duration,
    String? title,
    String? description,
    int? iconPoint,
    TaskGrade? grade,
    Color? color,
    Uint8List? snapshotImage,
  }) {
    return TimeBoxData(
      id: this.id,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      title: title ?? this.title,
      description: description ?? this.description,
      iconPoint: iconPoint ?? this.iconPoint,
      grade: grade ?? this.grade,
      color: color ?? this.color,
      snapshotImage: snapshotImage ?? this.snapshotImage,
    );
  }
}