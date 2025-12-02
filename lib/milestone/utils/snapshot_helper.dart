import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'logger.dart';

class SnapshotHelper {
  /// GlobalKey가 연결된 RepaintBoundary를 캡처하여 PNG ByteData로 반환
  static Future<Uint8List?> capturePng(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        AppLogger.error('Util-Snap', 'Boundary is null');
        return null;
      }

      // 픽셀 비율 1.0 (너무 크면 메모리 이슈, 썸네일용이므로 1.0 or 0.5 적당)
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        AppLogger.log('Util-Snap', 'Snapshot captured: ${byteData.lengthInBytes} bytes');
        return byteData.buffer.asUint8List();
      }
    } catch (e, stack) {
      AppLogger.error('Util-Snap', 'Capture Failed', e, stack);
    }
    return null;
  }
}