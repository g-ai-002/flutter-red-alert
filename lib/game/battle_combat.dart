part of 'battle_state.dart';

/// 索敌与火力：自动索敌、追击、伤害结算，以及防御建筑的自瞄开火。
extension BattleCombat on BattleState {
  /// 下达攻击指令：目标可以是单位或建筑。
  void issueAttack(List<Unit> units, int targetId) {
    final target = actorById(targetId);
    if (target == null) return;
    for (final unit in units) {
      if (!unit.alive || unit.isHarvester || unit.spec.isEngineer) continue;
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
    final target = nearestEnemy(unit.team, unit.position, maxDistance: unit.spec.range + 1.2);
    if (target == null) return;
    unit.targetId = target.id;
  }

  void _engage(Unit unit, Actor target, double dt) {
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
    if (unit.repathTimer <= 0 || !unit.hasPath) {
      final goal = _approachTile(target);
      final path = goal == null
          ? null
          : _finder.find(TilePoint(unit.x.floor(), unit.y.floor()), goal);
      if (path != null) unit.setPath(path);
      unit.repathTimer = 0.9;
    }
    if (unit.hasPath) {
      _followPath(unit, dt);
    }
  }

  /// 目标进入最近射程时向后拉开距离，给火炮留出开火空间。
  void _retreat(Unit unit, Actor target, double dt) {
    if (unit.repathTimer <= 0 || !unit.hasPath) {
      final dx = unit.x - target.x;
      final dy = unit.y - target.y;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance > 0.01) {
        final goal = _nearestFreeTile(
          Offset(
            unit.x + dx / distance * unit.spec.minRange,
            unit.y + dy / distance * unit.spec.minRange,
          ),
        );
        final path = goal == null
            ? null
            : _finder.find(TilePoint(unit.x.floor(), unit.y.floor()), goal);
        if (path != null) unit.setPath(path);
      }
      unit.repathTimer = 0.8;
    }
    if (unit.hasPath) _followPath(unit, dt);
  }

  void _fireAt(Unit unit, Actor target) {
    if (unit.fireCooldown > 0) return;
    final spec = unit.spec;
    if (!_inFiringBand(unit, target)) return;
    unit.fireCooldown = spec.cooldown / powerFactor(unit.team);
    unit.facing = math.atan2(target.y - unit.y, target.x - unit.x);
    _applyDamage(
      attacker: unit,
      target: target,
      attack: spec.attack,
      multiplier: spec.multiplierAgainst(target.armor),
      shell: spec.armor == ArmorClass.vehicle,
      splash: spec.splash,
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
  }) {
    final damage = math.max(1, (attack * multiplier).round());
    target.applyDamage(damage);
    _emit(
      BattleEvent(
        shell ? BattleEventKind.shell : BattleEventKind.bullet,
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
      for (final victim in unitsOf(attacker.team.opponent)) {
        if (victim == target || !victim.alive) continue;
        if ((victim.position - target.position).distance > area) continue;
        victim.applyDamage(spill);
      }
      for (final victim in buildingsOf(attacker.team.opponent)) {
        if (victim == target || !victim.alive) continue;
        if ((victim.position - target.position).distance > area) continue;
        victim.applyDamage(spill);
      }
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
    building.advanceFlash(dt);
    if (!building.spec.isDefense) return;
    building.fireCooldown = math.max(0, building.fireCooldown - dt);
    if (building.fireCooldown > 0) return;
    final target = nearestEnemy(
      building.team,
      building.position,
      maxDistance: building.spec.range,
      building: building,
    );
    if (target == null) return;
    building.fireCooldown = building.spec.cooldown / powerFactor(building.team);
    building.facing = math.atan2(target.y - building.y, target.x - building.x);
    _applyDamage(
      attacker: building,
      target: target,
      attack: building.spec.attack,
      multiplier: building.spec.multiplierAgainst(target.armor),
      shell: true,
    );
  }

  /// 射程判定：对建筑按外沿矩形计算，对单位按圆形半径略微放宽。
  double _distanceTo(Actor from, Actor to) {
    if (to is Building) {
      final rect = to.bounds;
      final dx = math.max(math.max(rect.left - from.x, 0), from.x - rect.right);
      final dy = math.max(math.max(rect.top - from.y, 0), from.y - rect.bottom);
      return math.sqrt(dx * dx + dy * dy) - 0.25;
    }
    return (from.position - to.position).distance - to.radius * 0.4;
  }

  Actor? nearestEnemy(Team team, Offset from, {double? maxDistance, Building? building}) {
    Actor? best;
    var bestScore = double.infinity;
    for (final actor in unitsOf(team.opponent)) {
      if (!actor.alive) continue;
      final distance = building == null
          ? (actor.position - from).distance - actor.radius * 0.5
          : _distanceTo(building, actor);
      if (maxDistance != null && distance > maxDistance) continue;
      final score = distance;
      if (score < bestScore) {
        bestScore = score;
        best = actor;
      }
    }
    for (final actor in buildingsOf(team.opponent)) {
      if (!actor.alive) continue;
      final distance = building == null
          ? (actor.position - from).distance - actor.radius * 0.5
          : _distanceTo(building, actor);
      if (maxDistance != null && distance > maxDistance) continue;
      // 优先攻击单位，其次建筑。
      final score = distance + 2.5;
      if (score < bestScore) {
        bestScore = score;
        best = actor;
      }
    }
    return best;
  }
}
