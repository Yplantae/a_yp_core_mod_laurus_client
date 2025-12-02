import 'package:flutter/foundation.dart';

class AppLogger {
  /// [Prefix] Message 형태로 로그를 출력합니다.
  /// release 모드에서는 출력하지 않도록 제어할 수 있습니다.
  static void log(String prefix, String message) {
    if (kDebugMode) {
      // 현재 시간 정보 포함
      final timestamp = DateTime.now().toIso8601String().split('T').last;
      print('[$timestamp] [$prefix] $message');
    }
  }

  static void error(String prefix, String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String().split('T').last;
      print('[$timestamp] [ERROR] [$prefix] $message');
      if (error != null) print('Error: $error');
      if (stackTrace != null) print('StackTrace: $stackTrace');
    }
  }
}