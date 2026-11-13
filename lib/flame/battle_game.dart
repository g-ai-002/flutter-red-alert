import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/battle_camera.dart';
import '../game/battle_controller.dart';
import '../game/battle_state.dart';
import '../game/logic_rate.dart';
import '../services/sound_service.dart';
import 'actor_painter.dart';
import 'effects.dart';
import 'terrain_painter.dart';

/// Flame 渲染与逻辑入口：固定步长推进战场，按摄像机变换绘制地形、单位与特效。
///
/// 交互全部由页面层的手势转成 [BattleController] 指令，这里只负责呈现，
/// 地形缓存、单位造型与放置预览分别由 [TerrainPainter] / [ActorPainter] 完成。
class BattleGame extends FlameGame {
  BattleGame({required this.controller, required this.logicRate})
    : _clock = FixedStepClock(logicRate.step) {
    _terrain = TerrainPainter(controller.state.map);
    _actors = ActorPainter(
      state: controller.state,
      selectedIds: controller.selectedIds,
      placement: controller.placement,
    );
  }

  final BattleController controller;
  final LogicRate logicRate;

  final Effects effects = Effects();
  final FixedStepClock _clock;
  late final TerrainPainter _terrain;
  late final ActorPainter _actors;

  ui.Shader? _edgeShader;
  Size _edgeShaderSize = Size.zero;
  double _fireSoundGap = 0;

  BattleState get state => controller.state;

  @override
  Color backgroundColor() => const Color(0xFF0E0F0E);

  @override
  Future<void> onLoad() async {
    controller.camera.updateViewport(Size(size.x, size.y));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    controller.camera.updateViewport(Size(size.x, size.y));
  }

  @override
  void update(double dt) {
    final step = dt.clamp(0.0, 0.1);
    effects.update(step);
    if (_fireSoundGap > 0) _fireSoundGap -= step;
    if (!controller.paused) {
      _clock.advance(step, controller.tick);
      _consumeEvents();
    }
    super.update(dt);
  }

  void _consumeEvents() {
    for (final event in state.drainEvents()) {
      effects.addEvent(event);
      switch (event.kind) {
        case BattleEventKind.bullet:
        case BattleEventKind.shell:
          if (_fireSoundGap <= 0 && event.team == playerTeam) {
            _fireSoundGap = 0.12;
            SoundService.play(BattleFeedback.fire);
          }
          break;
        case BattleEventKind.explosion:
          SoundService.play(BattleFeedback.explosion);
          break;
        case BattleEventKind.build:
          SoundService.play(BattleFeedback.build);
          break;
        case BattleEventKind.spawn:
          SoundService.play(BattleFeedback.ready);
          break;
        case BattleEventKind.unload:
          SoundService.play(BattleFeedback.harvest);
          break;
        case BattleEventKind.move:
          break;
      }
    }
  }

  @override
  void onDispose() {
    effects.clear();
    _terrain.dispose();
    _actors.dispose();
    super.onDispose();
  }

  @override
  void render(Canvas canvas) {
    final camera = controller.camera;
    if (camera.viewport.isEmpty || camera.tileSize <= 0) return;
    final viewport = Rect.fromLTWH(
      0,
      0,
      camera.viewport.width,
      camera.viewport.height,
    );
    canvas.drawRect(viewport, Paint()..color = const Color(0xFF0E0F0E));

    final origin = camera.worldToScreen(Offset.zero);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(camera.tileSize);
    final mapRect = Rect.fromLTWH(
      0,
      0,
      state.map.width.toDouble(),
      state.map.height.toDouble(),
    );
    canvas.clipRect(mapRect);
    _terrain.paint(canvas);
    canvas.drawRect(
      mapRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 / camera.tileSize
        ..color = const Color(0xFF3A3630),
    );
    _actors.drawActors(canvas);
    _actors.drawGhost(canvas);
    effects.render(canvas, camera.tileSize);
    canvas.restore();

    _actors.drawBuildingLabels(canvas, camera);
    _drawEdgeFade(canvas, camera);
    super.render(canvas);
  }

  void _drawEdgeFade(Canvas canvas, BattleCamera camera) {
    final size = camera.viewport;
    if (size.isEmpty) return;
    if (_edgeShader == null || _edgeShaderSize != size) {
      _edgeShader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        const [
          Color(0x88000000),
          Color(0x00000000),
          Color(0x00000000),
          Color(0x99000000),
        ],
        const [0.0, 0.16, 0.78, 1.0],
      );
      _edgeShaderSize = size;
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = _edgeShader,
    );
  }
}
