import 'dart:ui';

import 'package:flutter_red_alert/game/battle_camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('屏幕与世界坐标互逆', () {
    final camera = BattleCamera(mapWidth: 44, mapHeight: 44)
      ..updateViewport(const Size(800, 480))
      ..focusOn(const Offset(20, 20));
    const screen = Offset(300, 200);
    final world = camera.screenToWorld(screen);
    final back = camera.worldToScreen(world);
    expect(back.dx, closeTo(screen.dx, 0.001));
    expect(back.dy, closeTo(screen.dy, 0.001));
  });

  test('视野中心被限制在地图范围内', () {
    final camera = BattleCamera(mapWidth: 44, mapHeight: 44)..updateViewport(const Size(400, 400));
    camera.focusOn(const Offset(-100, -100));
    expect(camera.center.dx, greaterThanOrEqualTo(0));
    expect(camera.center.dy, greaterThanOrEqualTo(0));
    camera.focusOn(const Offset(100, 100));
    expect(camera.center.dx, lessThanOrEqualTo(44));
    expect(camera.center.dy, lessThanOrEqualTo(44));
  });

  test('缩放以焦点为中心并限制倍率', () {
    final camera = BattleCamera(mapWidth: 44, mapHeight: 44)
      ..updateViewport(const Size(800, 480))
      ..focusOn(const Offset(22, 22));
    const focal = Offset(600, 300);
    final before = camera.screenToWorld(focal);
    camera.zoomAt(focal, 1.6);
    final after = camera.screenToWorld(focal);
    expect((after - before).distance, lessThan(0.25));
    camera.zoomAt(focal, 100);
    expect(camera.tileSize, lessThanOrEqualTo(camera.maxTileSize));
    camera.zoomAt(focal, 0.001);
    expect(camera.tileSize, greaterThanOrEqualTo(camera.minTileSize));
  });

  test('平移按像素换算为格子', () {
    final camera = BattleCamera(mapWidth: 44, mapHeight: 44)
      ..updateViewport(const Size(400, 400))
      ..tileSize = 20
      ..focusOn(const Offset(22, 22));
    final center = camera.center;
    camera.panByScreen(const Offset(100, 40));
    expect(camera.center.dx, closeTo(center.dx - 5, 0.001));
    expect(camera.center.dy, closeTo(center.dy - 2, 0.001));
  });
}
