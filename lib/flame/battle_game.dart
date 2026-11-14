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
import 'fog_painter.dart';
import 'terrain_painter.dart';

/// Flame 渲染与逻辑入口：固定步长推进战场，按摄像机变换绘制地形、单位与特效。
///
/// 交互全部由页面层的手势转成 [BattleController] 指令，这里只负责呈现，
/// 地形缓存、单位造型与放置预览分别由 [TerrainPainter] / [ActorPainter] 完成。
class BattleGame extends FlameGame {
  BattleGame({required this.controller, required this.logicRate})
    : _clock = FixedStepClock(logicRate.step) {
    _terrain = TerrainPainter(controller.state.map);
    _fog = FogPainter(controller.state.vision);
    _actors = ActorPainter(
      state: controller.state,
      selectedIds: controller.selectedIds,
      placement: controller.placement,
    );
    _mapRect = Rect.fromLTWH(
      0,
      0,
      controller.state.map.width.toDouble(),
      controller.state.map.height.toDouble(),
    );
  }

  final BattleController controller;
  final LogicRate logicRate;

  final Effects effects = Effects();
  final FixedStepClock _clock;
  late final TerrainPainter _terrain;
  late final FogPainter _fog;
  late final ActorPainter _actors;

  final Paint _background = Paint()..color = const Color(0xFF0E0F0E);
  final Paint _border = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0xFF3A3630);
  final Paint _edgePaint = Paint();
  late final Rect _mapRect;
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

  /// 战场事件对应的音效，移动与维修保持静默。
  static const Map<BattleEventKind, BattleFeedback> _eventSounds = {
    BattleEventKind.bullet: BattleFeedback.fire,
    BattleEventKind.shell: BattleFeedback.fire,
    BattleEventKind.airstrike: BattleFeedback.fire,
    BattleEventKind.explosion: BattleFeedback.explosion,
    BattleEventKind.build: BattleFeedback.build,
    BattleEventKind.spawn: BattleFeedback.ready,
    BattleEventKind.unload: BattleFeedback.harvest,
  };

  void _consumeEvents() {
    for (final event in state.drainEvents()) {
      effects.addEvent(event);
      final feedback = _eventSounds[event.kind];
      if (feedback == null) continue;
      // 开火声按玩家阵营节流，避免大兵团交火时音效叠成噪音。
      if (feedback == BattleFeedback.fire) {
        if (_fireSoundGap > 0 || event.team != playerTeam) continue;
        _fireSoundGap = 0.12;
      }
      SoundService.play(feedback);
    }
  }

  @override
  void onDispose() {
    effects.clear();
    _terrain.dispose();
    _fog.dispose();
    _actors.dispose();
    super.onDispose();
  }

  @override
  void render(Canvas canvas) {
    final camera = controller.camera;
    if (camera.viewport.isEmpty || camera.tileSize <= 0) return;
    final viewport = Rect.fromLTWH(0, 0, camera.viewport.width, camera.viewport.height);
    canvas.drawRect(viewport, _background);

    final origin = camera.worldToScreen(Offset.zero);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(camera.tileSize);
    canvas.clipRect(_mapRect);
    final visible = camera.visibleWorld.inflate(2);
    _terrain.paint(canvas, visible);
    canvas.drawRect(_mapRect, _border..strokeWidth = 2.4 / camera.tileSize);
    _actors.drawActors(canvas, visible);
    effects.render(canvas, camera.tileSize);
    _fog.paint(canvas);
    _actors.drawGhost(canvas);
    canvas.restore();

    _actors.drawBuildingLabels(canvas, camera);
    _drawEdgeFade(canvas, camera);
    super.render(canvas);
  }

  void _drawEdgeFade(Canvas canvas, BattleCamera camera) {
    final size = camera.viewport;
    if (size.isEmpty) return;
    if (_edgeShaderSize != size) {
      _edgePaint.shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        const [Color(0x88000000), Color(0x00000000), Color(0x00000000), Color(0x99000000)],
        const [0.0, 0.16, 0.78, 1.0],
      );
      _edgeShaderSize = size;
    }
    canvas.drawRect(Offset.zero & size, _edgePaint);
  }
}
