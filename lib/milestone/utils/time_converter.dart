import '../models/timeline_models.dart';
import '../utils/logger.dart';

enum ViewScale { year, month, week, day, hour, minute }

class TimeConverter {
  DateTime _projectStartDate;
  CalendarConfig _config;

  double _pixelsPerMs = 0.00001;
  ViewScale _currentScale = ViewScale.day;
  double _viewportWidth = 1000.0;
  double _zoomVisibleDays = 10.0;

  TimeConverter({
    required DateTime projectStart,
    required CalendarConfig config
  }) : _projectStartDate = projectStart, _config = config {
    _recalculateScale();
  }

  DateTime get projectStartDate => _projectStartDate;
  double get pixelsPerMs => _pixelsPerMs;
  ViewScale get currentScale => _currentScale;
  double get visibleDays => _zoomVisibleDays;

  // Slider 호환 (0.0 ~ 500.0)
  // 값이 클수록 Zoom In (Days 작아짐)
  double get currentZoomLevel {
    if (_zoomVisibleDays <= 0.001) return 500.0;
    // Mapping: Days=10 -> Slider=50, Days=1 -> Slider=500
    // Formula: Slider = 500 / Days (Simple inverse)
    // Clamp result to prevent slider crash
    double val = 500.0 / _zoomVisibleDays;
    return val.clamp(0.0, 500.0);
  }

  void updateViewportWidth(double width) {
    if (width > 0 && (width - _viewportWidth).abs() > 1.0) {
      _viewportWidth = width;
      _recalculateScale();
    }
  }

  void updateConfig(CalendarConfig newConfig) {
    _config = newConfig;
    _recalculateScale();
  }

  // [Fix] Safe Zoom Setting
  void setZoom(double zoomDays) {
    // 1시간(0.041일) ~ 10년(3650일) 범위 제한
    // 너무 작은 값은 RenderFlex Error 및 Memory 폭주 유발
    double safeDays = zoomDays.clamp(0.04, 3650.0);

    if ((_zoomVisibleDays - safeDays).abs() > 0.0001) {
      _zoomVisibleDays = safeDays;
      _recalculateScale();
    }
  }

  void _recalculateScale() {
    if (_zoomVisibleDays <= 0) return;

    // Safety check for viewport
    double safeWidth = _viewportWidth < 100 ? 100 : _viewportWidth;

    const double msPerDay = 24.0 * 3600.0 * 1000.0;
    _pixelsPerMs = safeWidth / (_zoomVisibleDays * msPerDay);

    // Update ViewScale hint
    if (_zoomVisibleDays > 365) _currentScale = ViewScale.year;
    else if (_zoomVisibleDays > 60) _currentScale = ViewScale.month;
    else if (_zoomVisibleDays > 14) _currentScale = ViewScale.week;
    else if (_zoomVisibleDays > 1.5) _currentScale = ViewScale.day;
    else _currentScale = ViewScale.hour;

    AppLogger.log('Converter', 'Scale Update: Days=${_zoomVisibleDays.toStringAsFixed(2)}, Scale=$_currentScale');
  }

  double dateTimeToPixels(DateTime dt) {
    final diff = dt.difference(_projectStartDate);
    return diff.inMilliseconds.toDouble() * _pixelsPerMs;
  }

  DateTime pixelsToDateTime(double px) {
    if (_pixelsPerMs == 0) return _projectStartDate;
    double ms = px / _pixelsPerMs;
    return _projectStartDate.add(Duration(milliseconds: ms.round()));
  }

  double durationToPixels(Duration duration) {
    return duration.inMilliseconds * _pixelsPerMs;
  }

  Duration pixelsToDuration(double px) {
    if (_pixelsPerMs == 0) return Duration.zero;
    return Duration(milliseconds: (px / _pixelsPerMs).round());
  }
}