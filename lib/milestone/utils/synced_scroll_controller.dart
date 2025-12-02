import 'package:a_yp_core_mod_laurus_client/milestone/utils/logger.dart';
import 'package:flutter/material.dart';

/// [UI-Sync] 여러 ScrollController를 동기화하여 관리하는 그룹
/// 하나의 컨트롤러가 움직이면 그룹에 등록된 모든 컨트롤러를 동일한 offset으로 이동시킵니다.
class SyncedScrollControllerGroup {
  final List<ScrollController> _controllers = [];
  double _currentOffset = 0.0;

  SyncedScrollControllerGroup() {
    AppLogger.log('UI-Sync', 'SyncedScrollControllerGroup Created');
  }

  /// 새로운 컨트롤러를 생성하여 그룹에 등록하고 반환합니다.
  ScrollController addAndGet() {
    final controller = ScrollController(initialScrollOffset: _currentOffset);
    _controllers.add(controller);

    // 리스너 등록: 스크롤 발생 시 다른 컨트롤러 동기화
    controller.addListener(() {
      // 스크롤 중인 주체가 자신일 때만 전파 (무한 루프 방지)
      if (controller.position.isScrollingNotifier.value) {
        _syncScrolls(controller);
      }
    });

    return controller;
  }

  /// 특정 컨트롤러의 오프셋을 다른 모든 컨트롤러에 전파
  void _syncScrolls(ScrollController master) {
    if (!master.hasClients) return;

    final offset = master.offset;
    if (offset != _currentOffset) {
      _currentOffset = offset;

      for (var controller in _controllers) {
        if (controller != master && controller.hasClients) {
          controller.jumpTo(_currentOffset);
        }
      }
    }
  }

  /// 모든 컨트롤러 해제
  void dispose() {
    AppLogger.log('UI-Sync', 'Disposing ${_controllers.length} controllers');
    for (var controller in _controllers) {
      controller.dispose();
    }
    _controllers.clear();
  }
}