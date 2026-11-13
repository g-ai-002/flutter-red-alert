import 'dart:math' as math;
import 'dart:ui';

/// 战场摄像机：以格子为单位记录视野中心与缩放（每格像素数）。
///
/// 所有 HUD 手势先经这里换算成世界坐标，渲染层再按同样的缩放绘制，
/// 保证点击命中与画面一致。
class BattleCamera {
  BattleCamera({
    required this.mapWidth,
    required this.mapHeight,
    this.minTileSize = 8,
    this.maxTileSize = 54,
  });

  final int mapWidth;
  final int mapHeight;
  final double minTileSize;
  final double maxTileSize;

  Offset center = const Offset(0, 0);
  double tileSize = 26;
  Size viewport = Size.zero;

  void updateViewport(Size size) {
    if (size == viewport) return;
    final first = viewport.isEmpty;
    viewport = size;
    if (first) {
      tileSize = initialTileSize();
    }
    clampCenter();
  }

  double initialTileSize() {
    if (viewport.isEmpty) return 26;
    final shortSide = math.min(viewport.width, viewport.height);
    final lower = effectiveMinTileSize;
    final upper = math.max(36.0, lower);
    return (shortSide / 15).clamp(lower, upper).toDouble();
  }

  double get effectiveMinTileSize {
    if (viewport.isEmpty) return minTileSize;
    final fit = math.min(
      viewport.width / mapWidth,
      viewport.height / mapHeight,
    );
    return fit.clamp(minTileSize, maxTileSize).toDouble();
  }

  /// 屏幕坐标换算为格子坐标。
  Offset screenToWorld(Offset screen) =>
      (screen - viewport.center(Offset.zero)) / tileSize + center;

  /// 格子坐标换算为屏幕坐标。
  Offset worldToScreen(Offset world) =>
      (world - center) * tileSize + viewport.center(Offset.zero);

  Rect get visibleWorld {
    final halfW = viewport.width / 2 / tileSize;
    final halfH = viewport.height / 2 / tileSize;
    return Rect.fromLTRB(
      center.dx - halfW,
      center.dy - halfH,
      center.dx + halfW,
      center.dy + halfH,
    );
  }

  void panByScreen(Offset delta) {
    if (tileSize <= 0) return;
    center -= delta / tileSize;
    clampCenter();
  }

  void panByTiles(Offset delta) {
    center += delta;
    clampCenter();
  }

  void focusOn(Offset tile) {
    center = tile;
    clampCenter();
  }

  void zoomAt(Offset focalScreen, double factor) {
    final before = screenToWorld(focalScreen);
    tileSize = (tileSize * factor).clamp(effectiveMinTileSize, maxTileSize);
    final after = screenToWorld(focalScreen);
    center += before - after;
    clampCenter();
  }

  void clampCenter() {
    if (viewport.isEmpty) return;
    final halfW = viewport.width / 2 / tileSize;
    final halfH = viewport.height / 2 / tileSize;
    final x = halfW * 2 >= mapWidth
        ? mapWidth / 2
        : center.dx.clamp(halfW, mapWidth - halfW);
    final y = halfH * 2 >= mapHeight
        ? mapHeight / 2
        : center.dy.clamp(halfH, mapHeight - halfH);
    center = Offset(x.toDouble(), y.toDouble());
  }
}
