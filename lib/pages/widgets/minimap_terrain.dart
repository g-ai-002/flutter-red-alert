import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../game/terrain.dart';
import '../../game/vision.dart';
import '../../theme/palette.dart';

/// 迷你地图地形图层缓存：地形或迷雾版本变化时才重建 [ui.Picture]。
///
/// 地形按 2 格采样，兼顾清晰度与绘制开销；迷雾直接叠在同一张图上，
/// 单位与视野框由迷你地图在每次 HUD 刷新时单独绘制。
class MinimapTerrainCache {
  ui.Picture? _picture;
  Size _size = Size.zero;
  int _mapVersion = -1;
  int _visionVersion = -1;

  static const Color _oreColor = hudGold;

  ui.Picture? pictureFor({required GameMap map, required VisionMap vision, required Size size}) {
    if (_picture != null &&
        _size == size &&
        _mapVersion == map.version &&
        _visionVersion == vision.version) {
      return _picture;
    }
    dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final sx = size.width / map.width;
    final sy = size.height / map.height;
    final fill = Paint();
    for (var y = 0; y < map.height; y += 2) {
      for (var x = 0; x < map.width; x += 2) {
        final kind = map.terrainAt(x, y);
        final rect = Rect.fromLTWH(x * sx, y * sy, sx * 2.1, sy * 2.1);
        canvas.drawRect(rect, fill..color = terrainColor(kind).withValues(alpha: 0.95));
        if (map.oreAt(x, y) > 0) {
          canvas.drawCircle(rect.center, sx * 0.9, fill..color = _oreColor);
        }
        if (!vision.isExplored(x, y)) {
          canvas.drawRect(rect, fill..color = const Color(0xF20B0A08));
        } else if (!vision.isVisible(x, y)) {
          canvas.drawRect(rect, fill..color = const Color(0x800B0A08));
        }
      }
    }
    _picture = recorder.endRecording();
    _size = size;
    _mapVersion = map.version;
    _visionVersion = vision.version;
    return _picture;
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
    _size = Size.zero;
    _mapVersion = -1;
    _visionVersion = -1;
  }
}
