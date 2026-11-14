import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../game/vision.dart';

/// 战争迷雾图层：未探索区域近乎全黑，已探索但当前不可见的区域压暗。
///
/// 迷雾在世界坐标下按格绘制并缓存为 [ui.Picture]，只在视野版本变化时重建；
/// 同一行连续同类格子合并为一个矩形，降低绘制指令数量。
class FogPainter {
  FogPainter(this.vision);

  final VisionMap vision;

  ui.Picture? _picture;
  int _version = -1;

  static final Paint _unexplored = Paint()..color = const Color(0xF20B0A08);
  static final Paint _remembered = Paint()..color = const Color(0x8C0B0A08);

  void paint(Canvas canvas) {
    if (_version != vision.version) _rebuild();
    final picture = _picture;
    if (picture != null) canvas.drawPicture(picture);
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
    _version = -1;
  }

  void _rebuild() {
    dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var y = 0; y < vision.height; y++) {
      var runStart = -1;
      var runUnexplored = false;
      void flush(int end) {
        if (runStart < 0) return;
        canvas.drawRect(
          Rect.fromLTWH(
            runStart.toDouble(),
            y.toDouble(),
            (end - runStart).toDouble() + 0.01,
            1.01,
          ),
          runUnexplored ? _unexplored : _remembered,
        );
      }

      for (var x = 0; x < vision.width; x++) {
        if (vision.isVisible(x, y)) {
          flush(x);
          runStart = -1;
          continue;
        }
        final unexplored = !vision.isExplored(x, y);
        if (runStart >= 0 && unexplored != runUnexplored) {
          flush(x);
          runStart = x;
          runUnexplored = unexplored;
        } else if (runStart < 0) {
          runStart = x;
          runUnexplored = unexplored;
        }
      }
      flush(vision.width);
    }
    _picture = recorder.endRecording();
    _version = vision.version;
  }
}
