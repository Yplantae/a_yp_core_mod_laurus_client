import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/timeline_provider.dart';
import '../../utils/logger.dart';

class TimelineToolbar extends StatelessWidget {
  const TimelineToolbar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimelineProvider>();
    final zoom = provider.zoomLevel;
    final scale = provider.currentViewScale.toString().split('.').last.toUpperCase();

    return Container(
      height: 50,
      color: Colors.grey[850],
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Add Track',
            onPressed: () => provider.addTrack('New Track'),
          ),
          const VerticalDivider(width: 20, color: Colors.grey),
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white70),
            tooltip: 'Calendar Settings',
            onPressed: () => _showSettingsDialog(context, provider),
          ),
          const VerticalDivider(width: 20, color: Colors.grey),
          const Text('Drag:', style: TextStyle(color: Colors.white70)),
          const SizedBox(width: 8),
          LongPressDraggable<Map<String, dynamic>>(
            data: {
              'type': 'NewBoxFactory',
              'duration': const Duration(days: 3),
            },
            delay: const Duration(milliseconds: 100),
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: 80, height: 30,
                color: Colors.blueAccent.withOpacity(0.7),
                alignment: Alignment.center,
                child: const Text('3 Days', style: TextStyle(color: Colors.white)),
              ),
            ),
            child: const Chip(
              label: Text('3 Days', style: TextStyle(fontSize: 10)),
              backgroundColor: Colors.grey,
            ),
          ),
          const Spacer(),
          Text(scale, style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          const Icon(Icons.zoom_out, color: Colors.white54, size: 20),
          SizedBox(
            width: 150,
            child: Slider(
              value: zoom,
              min: 0.0,
              max: 500.0,
              activeColor: Colors.blueAccent,
              inactiveColor: Colors.grey[700],
              onChanged: (val) => provider.setZoomLevel(val),
            ),
          ),
          const Icon(Icons.zoom_in, color: Colors.white54, size: 20),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, TimelineProvider provider) {
    final config = provider.project.calendarConfig;

    showDialog(
      context: context,
      builder: (ctx) {
        bool excludeWeekends = config.excludeWeekends;
        bool excludeHolidays = config.excludeHolidays;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text('Calendar Settings', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('Exclude Weekends (Visual Only)', style: TextStyle(color: Colors.white70)),
                    value: excludeWeekends,
                    onChanged: (val) => setState(() => excludeWeekends = val!),
                  ),
                  CheckboxListTile(
                    title: const Text('Exclude Holidays', style: TextStyle(color: Colors.white70)),
                    value: excludeHolidays,
                    onChanged: (val) => setState(() => excludeHolidays = val!),
                  ),
                  const SizedBox(height: 10),
                  const Text('Working Hours: 09:00 - 18:00 (Fixed)', style: TextStyle(color: Colors.grey)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    provider.updateCalendarConfig(
                      excludeWeekends: excludeWeekends,
                      excludeHolidays: excludeHolidays,
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}