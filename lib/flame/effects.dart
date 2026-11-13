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

  void addEvent(BattleEvent event) {
    switch (event.kind) {
      case BattleEventKind.bullet:
        _items.add(
          _Fx(
            kind: _FxKind.tracer,
            x: event.x,
            y: event.y,
            tx: event.tx,
            ty: event.ty,
            duration: 0.1,
          ),
        );
        break;
      case BattleEventKind.shell:
        _items.add(
          _Fx(
            kind: _FxKind.shell,
            x: event.x,
            y: event.y,
            tx: event.tx,
            ty: event.ty,
            duration: 0.24,
          ),
        );
        break;
      case BattleEventKind.explosion:
        _items.add(
          _Fx(
            kind: _FxKind.explosion,
            x: event.x,
            y: event.y,
            duration: 0.6,
            radius: event.radius,
          ),
        );
        break;
      case BattleEventKind.build:
        _items.add(
          _Fx(
            kind: _FxKind.ring,
            x: event.x,
            y: event.y,
            duration: 0.7,
            radius: math.max(1, event.radius),
            team: event.team,
          ),
        );
        break;
      case BattleEventKind.spawn:
        _items.add(
          _Fx(
            kind: _FxKind.ring,
            x: event.x,
            y: event.y,
            duration: 0.45,
            radius: 0.7,
            team: event.team,
          ),
        );
        break;
      case BattleEventKind.unload:
        _items.add(
          _Fx(
            kind: _FxKind.spark,
            x: event.x,
            y: event.y,
            duration: 0.8,
            team: event.team,
          ),
        );
        break;
      case BattleEventKind.move:
        _items.add(
          _Fx(
            kind: _FxKind.ping,
            x: event.x,
            y: event.y,
            duration: 0.6,
            radius: 0.6,
            team: event.team,
          ),
        );
        break;
    }
  }

  void update(double dt) {
    if (_items.isEmpty) return;
    for (final item in _items) {
      item.elapsed += dt;
    }
    _items.removeWhere((item) => item.elapsed >= item.duration);
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
      }
    }
  }

  void clear() => _items.clear();

  void _drawTracer(Canvas canvas, _Fx fx, double t, double tileSize) {
    final paint = Paint()
      ..color = _core.withValues(alpha: 1 - t)
      ..strokeWidth = math.max(0.02, 2.2 / tileSize)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(fx.x, fx.y),
      Offset(fx.tx ?? fx.x, fx.ty ?? fx.y),
      paint,
    );
  }

  void _drawShell(Canvas canvas, _Fx fx, double t) {
    final sx = fx.x;
    final sy = fx.y;
    final ex = fx.tx ?? fx.x;
    final ey = fx.ty ?? fx.y;
    final x = sx + (ex - sx) * t;
    final y = sy + (ey - sy) * t - math.sin(math.pi * t) * 0.35;
    final trail = Paint()
      ..color = _hot.withValues(alpha: 0.55 * (1 - t))
      ..strokeWidth = 0.06
      ..strokeCap = StrokeCap.round;
    final dx = ex - sx;
    final dy = ey - sy;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length > 0.01) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x - dx / length * 0.5, y - dy / length * 0.5),
        trail,
      );
    }
    canvas.drawCircle(Offset(x, y), 0.09, Paint()..color = _core);
  }

  void _drawExplosion(Canvas canvas, _Fx fx, double t) {
    final radius = fx.radius;
    final grow = radius * (0.35 + 1.15 * t);
    canvas.drawCircle(
      Offset(fx.x, fx.y),
      grow,
      Paint()..color = _hot.withValues(alpha: 0.45 * (1 - t)),
    );
    canvas.drawCircle(
      Offset(fx.x, fx.y),
      grow * 0.55,
      Paint()..color = _core.withValues(alpha: 0.7 * (1 - t)),
    );
    final smokePaint = Paint()..color = _smoke.withValues(alpha: 0.5 * (1 - t));
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5 + 0.7;
      final distance = grow * 0.8;
      canvas.drawCircle(
        Offset(
          fx.x + math.cos(angle) * distance,
          fx.y + math.sin(angle) * distance - t * 0.5,
        ),
        grow * 0.32,
        smokePaint,
      );
    }
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.07
      ..color = _hot.withValues(alpha: 0.6 * (1 - t));
    canvas.drawCircle(Offset(fx.x, fx.y), grow * 1.15, ring);
  }

  void _drawRing(Canvas canvas, _Fx fx, double t, double tileSize) {
    final color = fx.team?.color ?? _hot;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.04, 2.0 / tileSize)
      ..color = color.withValues(alpha: 0.75 * (1 - t));
    canvas.drawCircle(Offset(fx.x, fx.y), fx.radius * (0.4 + t), paint);
  }

  void _drawPing(Canvas canvas, _Fx fx, double t, double tileSize) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.03, 1.8 / tileSize)
      ..color = (fx.team?.color ?? _hot).withValues(alpha: 0.8 * (1 - t));
    canvas.drawCircle(Offset(fx.x, fx.y), fx.radius * (0.5 + t * 1.4), paint);
    final dot = Paint()
      ..color = (fx.team?.color ?? _hot).withValues(alpha: 0.9 * (1 - t));
    canvas.drawCircle(Offset(fx.x, fx.y), 0.1 * (1 - t), dot);
  }

  void _drawSpark(Canvas canvas, _Fx fx, double t) {
    final color = (fx.team?.color ?? _hot);
    for (var i = 0; i < 4; i++) {
      final angle = -math.pi / 2 + (i - 1.5) * 0.5;
      final distance = t * 0.9;
      final paint = Paint()
        ..color = color.withValues(alpha: 1 - t)
        ..strokeWidth = 0.06
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(fx.x, fx.y - 0.2),
        Offset(
          fx.x + math.cos(angle) * distance,
          fx.y - 0.2 + math.sin(angle) * distance,
        ),
        paint,
      );
    }
  }
}

enum _FxKind { tracer, shell, explosion, ring, ping, spark }

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
