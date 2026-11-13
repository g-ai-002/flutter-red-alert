import 'dart:math' as math;
import 'dart:ui';

import '../game/battle_state.dart';
import '../game/battle_types.dart';

/// 战场特效层：曳光弹、炮弹、爆炸、建造与出兵光环，全部在世界坐标（格）绘制。
class Effects {
  Effects();

  final List<_Fx> _items = [];

  static const Color _hot = Color(0xFFFFB04A);
  static const Color _core = Color(0xFFFFE7B0);
  static const Color _smoke = Color(0xFF35302B);

  /// 特效绘制复用两支画笔：填充与描边，避免每帧为每个特效新建 Paint。
  final Paint _fill = Paint();
  final Paint _stroke = Paint()..strokeCap = StrokeCap.round;

  void addEvent(BattleEvent event) {
    final fx = switch (event.kind) {
      BattleEventKind.bullet => _Fx(
        kind: _FxKind.tracer,
        x: event.x,
        y: event.y,
        tx: event.tx,
        ty: event.ty,
        duration: 0.1,
      ),
      BattleEventKind.shell => _Fx(
        kind: _FxKind.shell,
        x: event.x,
        y: event.y,
        tx: event.tx,
        ty: event.ty,
        duration: 0.24,
      ),
      BattleEventKind.explosion => _Fx(
        kind: _FxKind.explosion,
        x: event.x,
        y: event.y,
        duration: 0.6,
        radius: event.radius,
      ),
      BattleEventKind.build => _Fx(
        kind: _FxKind.ring,
        x: event.x,
        y: event.y,
        duration: 0.7,
        radius: math.max(1, event.radius),
        team: event.team,
      ),
      BattleEventKind.spawn => _Fx(
        kind: _FxKind.ring,
        x: event.x,
        y: event.y,
        duration: 0.45,
        radius: 0.7,
        team: event.team,
      ),
      BattleEventKind.unload => _Fx(
        kind: _FxKind.spark,
        x: event.x,
        y: event.y,
        duration: 0.8,
        team: event.team,
      ),
      BattleEventKind.move => _Fx(
        kind: _FxKind.ping,
        x: event.x,
        y: event.y,
        duration: 0.6,
        radius: 0.6,
        team: event.team,
      ),
      BattleEventKind.repair => _Fx(kind: _FxKind.repair, x: event.x, y: event.y, duration: 0.5),
    };
    _items.add(fx);
  }

  void update(double dt) {
    for (var index = _items.length - 1; index >= 0; index--) {
      final item = _items[index];
      item.elapsed += dt;
      if (item.elapsed < item.duration) continue;
      // 原地交换删除，保持剩余特效顺序稳定且不产生临时闭包。
      _items[index] = _items.last;
      _items.removeLast();
    }
  }

  void render(Canvas canvas, double tileSize) {
    if (_items.isEmpty) return;
    for (final item in _items) {
      final t = (item.elapsed / item.duration).clamp(0.0, 1.0);
      switch (item.kind) {
        case _FxKind.tracer:
          _drawTracer(canvas, item, t, tileSize);
          break;
        case _FxKind.shell:
          _drawShell(canvas, item, t);
          break;
        case _FxKind.explosion:
          _drawExplosion(canvas, item, t);
          break;
        case _FxKind.ring:
          _drawRing(canvas, item, t, tileSize);
          break;
        case _FxKind.ping:
          _drawPing(canvas, item, t, tileSize);
          break;
        case _FxKind.spark:
          _drawSpark(canvas, item, t);
          break;
        case _FxKind.repair:
          _drawRepair(canvas, item, t);
          break;
      }
    }
  }

  void clear() => _items.clear();

  void _drawTracer(Canvas canvas, _Fx fx, double t, double tileSize) {
    canvas.drawLine(
      Offset(fx.x, fx.y),
      Offset(fx.tx ?? fx.x, fx.ty ?? fx.y),
      _stroke
        ..color = _core.withValues(alpha: 1 - t)
        ..strokeWidth = math.max(0.02, 2.2 / tileSize),
    );
  }

  void _drawShell(Canvas canvas, _Fx fx, double t) {
    final sx = fx.x;
    final sy = fx.y;
    final ex = fx.tx ?? fx.x;
    final ey = fx.ty ?? fx.y;
    final x = sx + (ex - sx) * t;
    final y = sy + (ey - sy) * t - math.sin(math.pi * t) * 0.35;
    final trail = _stroke
      ..color = _hot.withValues(alpha: 0.55 * (1 - t))
      ..strokeWidth = 0.06;
    final dx = ex - sx;
    final dy = ey - sy;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length > 0.01) {
      canvas.drawLine(Offset(x, y), Offset(x - dx / length * 0.5, y - dy / length * 0.5), trail);
    }
    canvas.drawCircle(Offset(x, y), 0.09, _fill..color = _core);
  }

  void _drawExplosion(Canvas canvas, _Fx fx, double t) {
    final radius = fx.radius;
    final grow = radius * (0.35 + 1.15 * t);
    canvas.drawCircle(
      Offset(fx.x, fx.y),
      grow,
      _fill..color = _hot.withValues(alpha: 0.45 * (1 - t)),
    );
    canvas.drawCircle(
      Offset(fx.x, fx.y),
      grow * 0.55,
      _fill..color = _core.withValues(alpha: 0.7 * (1 - t)),
    );
    final smokePaint = _fill..color = _smoke.withValues(alpha: 0.5 * (1 - t));
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5 + 0.7;
      final distance = grow * 0.8;
      canvas.drawCircle(
        Offset(fx.x + math.cos(angle) * distance, fx.y + math.sin(angle) * distance - t * 0.5),
        grow * 0.32,
        smokePaint,
      );
    }
    canvas.drawCircle(
      Offset(fx.x, fx.y),
      grow * 1.15,
      _stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.07
        ..color = _hot.withValues(alpha: 0.6 * (1 - t)),
    );
  }

  void _drawRing(Canvas canvas, _Fx fx, double t, double tileSize) {
    final color = fx.team?.color ?? _hot;
    canvas.drawCircle(
      Offset(fx.x, fx.y),
      fx.radius * (0.4 + t),
      _stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.04, 2.0 / tileSize)
        ..color = color.withValues(alpha: 0.75 * (1 - t)),
    );
  }

  void _drawPing(Canvas canvas, _Fx fx, double t, double tileSize) {
    final color = fx.team?.color ?? _hot;
    canvas.drawCircle(
      Offset(fx.x, fx.y),
      fx.radius * (0.5 + t * 1.4),
      _stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.03, 1.8 / tileSize)
        ..color = color.withValues(alpha: 0.8 * (1 - t)),
    );
    canvas.drawCircle(
      Offset(fx.x, fx.y),
      0.1 * (1 - t),
      _fill..color = color.withValues(alpha: 0.9 * (1 - t)),
    );
  }

  void _drawSpark(Canvas canvas, _Fx fx, double t) {
    final color = (fx.team?.color ?? _hot);
    for (var i = 0; i < 4; i++) {
      final angle = -math.pi / 2 + (i - 1.5) * 0.5;
      final distance = t * 0.9;
      canvas.drawLine(
        Offset(fx.x, fx.y - 0.2),
        Offset(fx.x + math.cos(angle) * distance, fx.y - 0.2 + math.sin(angle) * distance),
        _stroke
          ..color = color.withValues(alpha: 1 - t)
          ..strokeWidth = 0.06,
      );
    }
  }

  /// 维修火花：目标上方浮起一个绿色十字。
  void _drawRepair(Canvas canvas, _Fx fx, double t) {
    final paint = _stroke
      ..color = const Color(0xFF8AD694).withValues(alpha: 1 - t)
      ..strokeWidth = 0.05;
    final y = fx.y - 0.5 - t * 0.35;
    const size = 0.09;
    canvas.drawLine(Offset(fx.x - size, y), Offset(fx.x + size, y), paint);
    canvas.drawLine(Offset(fx.x, y - size), Offset(fx.x, y + size), paint);
  }
}

enum _FxKind { tracer, shell, explosion, ring, ping, spark, repair }

class _Fx {
  _Fx({
    required this.kind,
    required this.x,
    required this.y,
    required this.duration,
    this.tx,
    this.ty,
    this.radius = 0.5,
    this.team,
  });

  final _FxKind kind;
  final double x;
  final double y;
  final double? tx;
  final double? ty;
  final double duration;
  final double radius;
  final Team? team;
  double elapsed = 0;
}
