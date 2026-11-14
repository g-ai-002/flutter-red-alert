import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../game/battle_state.dart';
import '../game/battle_types.dart';

/// 战场特效层：曳光弹、炮弹、爆炸、建造与出兵光环，全部在世界坐标（格）绘制。
class Effects {
  Effects();

  final List<_Fx> _items = [];
  int _drawn = 0;

  static const Color _hot = Color(0xFFFFB04A);
  static const Color _core = Color(0xFFFFE7B0);
  static const Color _smoke = Color(0xFF35302B);

  /// 特效绘制复用两支画笔：填充与描边，避免每帧为每个特效新建 Paint。
  final Paint _fill = Paint();
  final Paint _stroke = Paint()..strokeCap = StrokeCap.round;

  /// 事件到特效的固定参数：只看表就能知道每种事件的时长、半径与颜色。
  static const Map<BattleEventKind, _FxSpec> _specs = {
    BattleEventKind.bullet: _FxSpec(_FxKind.tracer, 0.1),
    BattleEventKind.shell: _FxSpec(_FxKind.shell, 0.24),
    BattleEventKind.airstrike: _FxSpec(_FxKind.airstrike, 0.34, tint: true),
    BattleEventKind.missile: _FxSpec(_FxKind.missile, 1.1, radius: 4.2, tint: true),
    BattleEventKind.explosion: _FxSpec(_FxKind.explosion, 0.6),
    BattleEventKind.build: _FxSpec(_FxKind.ring, 0.7, minRadius: 1, tint: true),
    BattleEventKind.spawn: _FxSpec(_FxKind.ring, 0.45, radius: 0.7, tint: true),
    BattleEventKind.unload: _FxSpec(_FxKind.spark, 0.8, tint: true),
    BattleEventKind.move: _FxSpec(_FxKind.ping, 0.6, radius: 0.6, tint: true),
    BattleEventKind.repair: _FxSpec(_FxKind.repair, 0.5),
  };

  void addEvent(BattleEvent event) {
    final spec = _specs[event.kind]!;
    _items.add(
      _Fx(
        kind: spec.kind,
        x: event.x,
        y: event.y,
        tx: event.tx,
        ty: event.ty,
        duration: spec.duration,
        radius: math.max(spec.minRadius ?? event.radius, spec.radius ?? event.radius),
        team: spec.tint ? event.team : null,
      ),
    );
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

  /// 绘制全部存活特效；传入 [view] 时跳过视野外的条目，
  /// 大兵团在其他区域交火时不再为看不见的弹道与爆炸录制指令。
  void render(Canvas canvas, double tileSize, {Rect? view}) {
    _drawn = 0;
    if (_items.isEmpty) return;
    for (final item in _items) {
      if (view != null && !_inView(item, view)) continue;
      _drawn++;
      final t = (item.elapsed / item.duration).clamp(0.0, 1.0);
      switch (item.kind) {
        case _FxKind.tracer:
          _drawTracer(canvas, item, t, tileSize);
          break;
        case _FxKind.shell:
          _drawShell(canvas, item, t);
          break;
        case _FxKind.airstrike:
          _drawAirstrike(canvas, item, t);
          break;
        case _FxKind.missile:
          _drawMissile(canvas, item, t);
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

  /// 弹道类特效横跨起点与落点，按两者的包围盒（含半径与飞散余量）裁剪。
  bool _inView(_Fx fx, Rect view) {
    final left = math.min(fx.x, fx.tx ?? fx.x) - fx.radius - 1;
    final right = math.max(fx.x, fx.tx ?? fx.x) + fx.radius + 1;
    final top = math.min(fx.y, fx.ty ?? fx.y) - fx.radius - 1;
    final bottom = math.max(fx.y, fx.ty ?? fx.y) + fx.radius + 1;
    return right >= view.left && left <= view.right && bottom >= view.top && top <= view.bottom;
  }

  void clear() => _items.clear();

  /// 当前存活的特效数量，供渲染调试与测试断言。
  int get activeCount => _items.length;

  /// 上一帧实际绘制的特效数量，用于验证视野裁剪。
  @visibleForTesting
  int get drawnCount => _drawn;

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

  /// 直升机扫射：两道平行弹道扑向目标，到位后炸开一小圈烟尘。
  void _drawAirstrike(Canvas canvas, _Fx fx, double t) {
    final ex = fx.tx ?? fx.x;
    final ey = fx.ty ?? fx.y;
    final dx = ex - fx.x;
    final dy = ey - fx.y;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length <= 0.01) return;
    final nx = -dy / length * 0.1;
    final ny = dx / length * 0.1;
    final progress = math.min(1.0, t * 2.4);
    final x = fx.x + dx * progress;
    final y = fx.y + dy * progress;
    final paint = _stroke
      ..color = _core.withValues(alpha: 1 - t * 0.7)
      ..strokeWidth = math.max(0.02, 1.8);
    canvas.drawLine(Offset(x + nx, y + ny), Offset(ex + nx, ey + ny), paint);
    canvas.drawLine(Offset(x - nx, y - ny), Offset(ex - nx, ey - ny), paint);
    if (t > 0.45) {
      canvas.drawCircle(
        Offset(ex, ey),
        0.18 + (t - 0.45) * 1.2,
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.06
          ..color = _hot.withValues(alpha: (1 - t) * 0.7),
      );
    }
  }

  /// 战略导弹：弹头从高空坠落并拖出尾焰，落地后炸开火球、浓烟与冲击波。
  void _drawMissile(Canvas canvas, _Fx fx, double t) {
    final target = Offset(fx.x, fx.y);
    final fall = math.min(1.0, t * 1.7);
    final head = Offset(fx.x, fx.y - 18 * (1 - fall));
    canvas.drawLine(
      Offset(head.dx, head.dy - 3.2),
      head,
      _stroke
        ..color = _hot.withValues(alpha: 0.85 * fall)
        ..strokeWidth = 0.16,
    );
    canvas.drawCircle(head, 0.16 + 0.2 * fall, _fill..color = _core);
    if (fall < 1) {
      canvas.drawCircle(
        target,
        fx.radius * 0.35,
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.06
          ..color = const Color(0x88FFD9B0),
      );
      return;
    }
    final impact = ((t - 1 / 1.7) / (1 - 1 / 1.7)).clamp(0.0, 1.0);
    final grow = fx.radius * (0.2 + impact);
    canvas.drawCircle(target, grow, _fill..color = _hot.withValues(alpha: 0.5 * (1 - impact)));
    canvas.drawCircle(
      target,
      grow * 0.5,
      _fill..color = _core.withValues(alpha: 0.85 * (1 - impact)),
    );
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5 + 0.4;
      canvas.drawCircle(
        Offset(
          target.dx + math.cos(angle) * grow * 0.75,
          target.dy + math.sin(angle) * grow * 0.75 - impact * 0.6,
        ),
        grow * 0.28,
        _fill..color = _smoke.withValues(alpha: 0.55 * (1 - impact)),
      );
    }
    canvas.drawCircle(
      target,
      fx.radius * (0.3 + impact),
      _stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.1
        ..color = _hot.withValues(alpha: 0.7 * (1 - impact)),
    );
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

enum _FxKind { tracer, shell, airstrike, missile, explosion, ring, ping, spark, repair }

/// 事件到特效的固定参数：[radius] / [minRadius] 为空时沿用事件半径，
/// [tint] 表示用事件所属阵营色绘制。
class _FxSpec {
  const _FxSpec(this.kind, this.duration, {this.radius, this.minRadius, this.tint = false});

  final _FxKind kind;
  final double duration;
  final double? radius;
  final double? minRadius;
  final bool tint;
}

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
