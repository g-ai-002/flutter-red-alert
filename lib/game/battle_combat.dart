part of 'battle_state.dart';

/// 索敌与火力：自动索敌、追击、伤害结算，以及防御建筑的自瞄开火。
extension BattleCombat on BattleState {
  /// 发射井蓄能推进；发射井被摧毁时蓄能清零，重新建造需要从头积累。
  void _updateStrike(double dt) {
    for (final team in Team.values) {
      if (!hasBuilding(team, BuildingKind.silo)) {
        _strikeCharge[team] = 0;
        continue;
      }
      final charge = _strikeCharge[team]!;
      if (charge >= 1) continue;
      _strikeCharge[team] = math.min(1, charge + dt / BattleState.strikeChargeSeconds);
      if (_strikeCharge[team]! >= 1 && team == Team.red) {
        addNotice('导弹发射井蓄能完毕，可实施战略打击', level: NoticeLevel.success);
      }
    }
  }

  /// 对 [target] 周围实施战略打击：只杀伤敌方单位与建筑，越靠近中心伤害越高。
  bool launchStrike(Team team, Offset target) {
    if (result != null || !strikeReady(team)) return false;
    _strikeCharge[team] = 0;
    _emit(
      BattleEvent(
        BattleEventKind.missile,
        target.dx,
        target.dy,
        team: team,
        radius: BattleState.strikeRadius,
      ),
    );
    for (final actor in actors) {
      if (!actor.alive || actor.team == team) continue;
      final gap = actor is Building
          ? distanceToRect(target, actor.bounds)
          : actor.distanceToPoint(target) - actor.radius * 0.5;
      if (gap > BattleState.strikeRadius) continue;
      final falloff = 1 - 0.55 * math.max(0, gap) / BattleState.strikeRadius;
      actor.applyDamage((BattleState.strikeDamage * falloff).round());
    }
    addNotice(
      team == Team.red ? '东风快递已抵达，目标区域被夷平' : '蓝军导弹命中我方阵地',
      level: team == Team.red ? NoticeLevel.success : NoticeLevel.warning,
    );
    return true;
  }

  /// 下达攻击指令：目标可以是单位或建筑，武器打不到的目标类型会被忽略。
  void issueAttack(List<Unit> units, int targetId) {
    final target = actorById(targetId);
    if (target == null) return;
    for (final unit in units) {
      if (!unit.alive || unit.isHarvester || unit.spec.isEngineer) continue;
      if (!unit.spec.canTarget(target.isAir)) continue;
      unit
        ..order = UnitOrder.attack
        ..targetId = targetId
        ..repathTimer = 0
        ..clearPath();
    }
  }

  void _acquireIfIdle(Unit unit) {
    if (unit.spec.attack <= 0) return;
    if (unit.targetId != null) return;
    if (unit.repathTimer > 0) return;
    unit.repathTimer = 0.4;
    final target = nearestEnemy(
      unit.team,
      unit.position,
      weapon: unit.spec,
      maxDistance: unit.spec.range + 1.2,
    );
    if (target == null) return;
    unit.targetId = target.id;
  }

  void _engage(Unit unit, Actor target, double dt) {
    // 目标类型与武器不匹配时立即放弃，避免飞行单位被地面火力锁死。
    if (!unit.spec.canTarget(target.isAir)) {
      unit.targetId = null;
      return;
    }
    final distance = _distanceTo(unit, target);
    if (distance < unit.spec.minRange) {
      _retreat(unit, target, dt);
      return;
    }
    if (distance <= unit.spec.range) {
      unit.clearPath();
      _fireAt(unit, target);
      return;
    }
    final approach = _approachTile(unit, target);
    _chase(unit, approach, dt, repath: 0.9);
  }

  /// 目标进入最近射程时向后拉开距离，给火炮留出开火空间。
  void _retreat(Unit unit, Actor target, double dt) {
    if (unit.repathTimer <= 0 || !unit.hasPath) {
      final dx = unit.x - target.x;
      final dy = unit.y - target.y;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance > 0.01) {
        _repath(
          unit,
          _nearestFreeTile(
            Offset(
              unit.x + dx / distance * unit.spec.minRange,
              unit.y + dy / distance * unit.spec.minRange,
            ),
          ),
          repath: 0.8,
        );
      } else {
        unit.repathTimer = 0.8;
      }
    }
    if (unit.hasPath) _followPath(unit, dt);
  }

  void _fireAt(Unit unit, Actor target) {
    if (unit.fireCooldown > 0) return;
    if (!unit.spec.canTarget(target.isAir)) return;
    if (!_inFiringBand(unit, target)) return;
    _shoot(unit, target, unit.spec);
  }

  /// 冷却、炮口朝向与伤害结算是单位与防御建筑的共同出口。
  void _shoot(Actor attacker, Actor target, WeaponStats spec) {
    attacker.fireCooldown = spec.cooldown / powerFactor(attacker.team);
    attacker.facing = math.atan2(target.y - attacker.y, target.x - attacker.x);
    _applyDamage(
      attacker: attacker,
      target: target,
      attack: spec.attack,
      multiplier: target.isAir ? spec.vsAir : spec.multiplierAgainst(target.armor),
      shell: spec.firesShell,
      splash: spec.splash,
      airstrike: attacker.isAir,
    );
  }

  /// 射程区间判定：既要够得着，也不能贴得太近（火炮最小射程）。
  bool _inFiringBand(Unit unit, Actor target) {
    final distance = _distanceTo(unit, target);
    return distance >= unit.spec.minRange && distance <= unit.spec.range;
  }

  void _applyDamage({
    required Actor attacker,
    required Actor target,
    required int attack,
    required double multiplier,
    required bool shell,
    double splash = 0,
    bool airstrike = false,
  }) {
    final damage = math.max(1, (attack * multiplier).round());
    target.applyDamage(damage);
    _emit(
      BattleEvent(
        airstrike
            ? BattleEventKind.airstrike
            : shell
            ? BattleEventKind.shell
            : BattleEventKind.bullet,
        attacker.x,
        attacker.y,
        tx: target.x,
        ty: target.y,
        team: attacker.team,
      ),
    );
    if (splash > 0) {
      final area = splash + (target.isBuilding ? 0.6 : 0.2);
      final spill = math.max(1, (damage * 0.5).round());
      void splashTo(Iterable<Actor> victims) {
        for (final victim in victims) {
          if (victim == target || !victim.alive || victim.isAir) continue;
          if (victim.distanceToActor(target) > area) continue;
          victim.applyDamage(spill);
        }
      }

      splashTo(unitsOf(attacker.team.opponent));
      splashTo(buildingsOf(attacker.team.opponent));
    }
    if (!target.alive) {
      _emit(
        BattleEvent(
          BattleEventKind.explosion,
          target.x,
          target.y,
          team: attacker.team,
          radius: math.max(splash, target.isBuilding ? 1.5 : 0.8),
        ),
      );
    }
  }

  void _updateBuildings(double dt) {
    for (final building in redBuildings) {
      if (building.alive) _updateDefense(building, dt);
    }
    for (final building in blueBuildings) {
      if (building.alive) _updateDefense(building, dt);
    }
  }

  void _updateDefense(Building building, double dt) {
    building.advanceCombatTimers(dt);
    final spec = building.spec;
    if (!spec.isDefense || building.fireCooldown > 0) return;
    final target = nearestEnemy(
      building.team,
      building.position,
      weapon: spec,
      maxDistance: spec.range,
      building: building,
    );
    if (target == null) return;
    _shoot(building, target, spec);
  }

  /// 射程判定：对建筑按外沿矩形计算，对单位按圆形半径略微放宽。
  double _distanceTo(Actor from, Actor to) {
    if (to is Building) return distanceToRect(from.position, to.bounds) - 0.25;
    return from.distanceToActor(to) - to.radius * 0.4;
  }

  /// 最近的可攻击目标：只遍历敌方网格中射程覆盖的桶，再按距离评分。
  /// 对空武器给空中目标减 1.5 格、建筑加 2.5 格，形成对空与建筑优先级。
  Actor? nearestEnemy(
    Team team,
    Offset from, {
    required WeaponStats weapon,
    required double maxDistance,
    Building? building,
  }) {
    Actor? best;
    var bestScore = double.infinity;

    void consider(Actor actor) {
      if (!actor.alive || !weapon.canTarget(actor.isAir)) return;
      final double distance;
      if (building == null) {
        final dx = actor.x - from.dx;
        final dy = actor.y - from.dy;
        final squared = dx * dx + dy * dy;
        // 先用平方距离排除远处目标，避免为每个候选都开方。
        final reach = maxDistance + actor.radius;
        if (squared > reach * reach) return;
        distance = math.sqrt(squared) - actor.radius * 0.5;
      } else {
        distance = _distanceTo(building, actor);
      }
      if (distance > maxDistance) return;
      final score = distance + (actor.isBuilding ? 2.5 : 0) - (actor.isAir ? 1.5 : 0);
      if (score >= bestScore) return;
      bestScore = score;
      best = actor;
    }

    _targetGrids[team.opponent]!.forEachNear(from.dx, from.dy, maxDistance + 2.5, consider);
    return best;
  }
}

class _ActorGrid {
  _ActorGrid(int mapSize) : _columns = (mapSize / cellSize).ceil() {
    _cells = List.generate(_columns * _columns, (_) => <Actor>[]);
  }

  static const int cellSize = 4;
  final int _columns;
  late final List<List<Actor>> _cells;

  void rebuild(Iterable<Actor> actors, Team team) {
    for (final cell in _cells) {
      cell.clear();
    }
    for (final actor in actors) {
      if (actor.alive && actor.team == team) _add(actor);
    }
  }

  int _cell(double value) => (value / cellSize).floor().clamp(0, _columns - 1).toInt();

  void _add(Actor actor) => _cells[_cell(actor.y) * _columns + _cell(actor.x)].add(actor);

  void forEachNear(double x, double y, double radius, void Function(Actor) visit) {
    final minColumn = _cell(x - radius), maxColumn = _cell(x + radius);
    final minRow = _cell(y - radius), maxRow = _cell(y + radius);
    for (var row = minRow; row <= maxRow; row++) {
      for (var column = minColumn; column <= maxColumn; column++) {
        _cells[row * _columns + column].forEach(visit);
      }
    }
  }
}
