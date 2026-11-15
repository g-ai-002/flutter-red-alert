part of 'battle_state.dart';

/// 单位机动与采矿：编队移动、路径跟随、追击落点与采矿车状态机。
extension BattleMovement on BattleState {
  /// 下达移动指令，按网格阵型分配落点。
  void issueMove(List<Unit> units, Offset destination) {
    final ordered = units.where((u) => u.alive).toList()..sort((a, b) => a.id.compareTo(b.id));
    if (ordered.isEmpty) return;
    final offsets = _formationOffsets(ordered.length);
    final baseTile = TilePoint(destination.dx.floor(), destination.dy.floor());
    var placed = 0;
    for (var i = 0; i < ordered.length; i++) {
      final unit = ordered[i];
      final offset = offsets[i];
      final desired = Offset(baseTile.x + 0.5 + offset.dx, baseTile.y + 0.5 + offset.dy);
      // 空中单位直飞，不参与地面寻路，也不需要空闲格。
      if (unit.isAir) {
        unit
          ..order = UnitOrder.move
          ..targetId = null
          ..destination = desired
          ..clearPath();
        placed++;
        continue;
      }
      final slot = _nearestFreeTile(desired, radius: 2);
      if (slot == null) continue;
      final path = _finder.find(_tileOf(unit), slot);
      if (path == null) continue;
      unit
        ..order = UnitOrder.move
        ..targetId = null
        ..destination = slot.center
        ..setPath(path);
      if (unit.isHarvester) {
        unit.phase = HarvesterPhase.moving;
      }
      placed++;
    }
    if (placed > 0) {
      _emit(
        BattleEvent(BattleEventKind.move, destination.dx, destination.dy, team: ordered.first.team),
      );
    }
  }

  void stopUnits(List<Unit> units) {
    for (final unit in units) {
      if (!unit.alive) continue;
      if (unit.isHarvester) {
        unit.phase = HarvesterPhase.idle;
      }
      unit.clearOrders();
    }
  }

  List<Offset> _formationOffsets(int count) {
    final result = <Offset>[Offset.zero];
    var ring = 1;
    while (result.length < count) {
      for (var dy = -ring; dy <= ring; dy++) {
        for (var dx = -ring; dx <= ring; dx++) {
          if (math.max(dx.abs(), dy.abs()) != ring) continue;
          result.add(Offset(dx.toDouble(), dy.toDouble()));
          if (result.length >= count) break;
        }
        if (result.length >= count) break;
      }
      ring++;
    }
    return result;
  }

  /// 单个单位的每帧行为：采矿车走状态机，其余按攻击 / 移动 / 待命分派。
  void _updateUnit(Unit unit, double dt) {
    unit.advanceCombatTimers(dt);
    unit.repathTimer = math.max(0, unit.repathTimer - dt);
    if (unit.isHarvester) {
      _updateHarvester(unit, dt);
      return;
    }
    if (unit.spec.isEngineer) {
      _updateEngineer(unit, dt);
      return;
    }
    final target = unit.targetId == null ? null : actorById(unit.targetId!);
    if (unit.order == UnitOrder.attack) {
      if (target == null) {
        unit.clearOrders();
      } else {
        _engage(unit, target, dt);
        return;
      }
    }
    if (unit.order == UnitOrder.move) {
      if (unit.isAir) {
        final goal = unit.destination;
        if (goal != null) _flyTowards(unit, goal, dt);
      } else if (unit.hasPath) {
        _followPath(unit, dt);
      } else {
        unit
          ..order = UnitOrder.idle
          ..destination = null
          ..guardPost = unit.position;
      }
      // 行军途中只打射程内、且武器能命中的临时目标，不为它停下脚步。
      if (target != null && unit.spec.canTarget(target.isAir) && _inFiringBand(unit, target)) {
        _fireAt(unit, target);
      } else {
        unit.targetId = null;
      }
      _acquireIfIdle(unit);
      return;
    }
    // 待命：主动迎击警戒圈内的敌军；清空目标后回到驻守点。
    if (target != null && _autoEngageAllowed(unit, target)) {
      _engage(unit, target, dt);
      return;
    }
    unit.targetId = null;
    if (unit.distanceToPoint(unit.guardPost) > 0.9) {
      _returnToPost(unit, dt);
      return;
    }
    _acquireIfIdle(unit);
  }

  /// 自动迎敌只在驻守点附近的警戒圈内生效；手动攻击不受此限制。
  bool _autoEngageAllowed(Unit unit, Actor target) {
    final post = unit.guardPost;
    return target.distanceToPoint(post) <= unit.guardRadius + 1.5 &&
        unit.distanceToPoint(post) <= unit.guardRadius + 4;
  }

  /// 回到驻守点：与追击共用寻路与低空直飞，抵达后重新进入自动索敌。
  void _returnToPost(Unit unit, double dt) {
    final post = unit.guardPost;
    if (unit.isAir) {
      _flyTowards(unit, post, dt, finish: false);
      return;
    }
    if (unit.repathTimer <= 0 || !unit.hasPath) {
      _repath(unit, _nearestFreeTile(post, radius: 2), repath: 0.8);
    }
    if (unit.hasPath) _followPath(unit, dt);
  }

  /// 工程兵：玩家指定的移动优先，空闲时自动维修附近受损的己方单位与建筑。
  void _updateEngineer(Unit unit, double dt) {
    if (unit.order == UnitOrder.move) {
      if (unit.hasPath) {
        _followPath(unit, dt);
        return;
      }
      unit
        ..order = UnitOrder.idle
        ..destination = null;
    }
    // 沿用仍在受损的目标；没有可沿用目标时隔 0.4 秒再扫一次，避免每个逻辑步全表扫描。
    final current = unit.targetId == null ? null : actorById(unit.targetId!);
    final damaged = current != null && current.hp < current.maxHp;
    if (!damaged && unit.repathTimer > 0) return;
    if (!damaged) unit.repathTimer = 0.4;
    final target = damaged ? current : _repairTarget(unit);
    if (target == null) {
      unit
        ..targetId = null
        ..clearPath();
      return;
    }
    unit.targetId = target.id;
    final gap = _distanceTo(unit, target);
    if (gap > unit.spec.range) {
      _chase(unit, _approachTile(unit, target), dt, repath: 0.8);
      return;
    }
    unit.clearPath();
    unit.facing = math.atan2(target.y - unit.y, target.x - unit.x);
    unit.workCarry += unit.spec.repair * dt;
    final healed = unit.workCarry.floor();
    if (healed <= 0) return;
    unit.workCarry -= healed;
    target.hp = math.min(target.maxHp, target.hp + healed);
    unit.miningTimer -= dt;
    if (unit.miningTimer <= 0) {
      unit.miningTimer = 0.5;
      _emit(BattleEvent(BattleEventKind.repair, target.x, target.y, team: unit.team));
    }
  }

  /// 最近的待修目标：优先距离近的，建筑与车辆一视同仁。
  /// 只扫己方名单，敌方单位与建筑不需要参与维修判定。
  Actor? _repairTarget(Unit unit) {
    Actor? best;
    var bestDistance = double.infinity;
    void consider(Iterable<Actor> candidates) {
      for (final actor in candidates) {
        if (!actor.alive || actor == unit || actor.hp >= actor.maxHp) continue;
        final distance = unit.distanceToActor(actor);
        if (distance > 16 || distance >= bestDistance) continue;
        bestDistance = distance;
        best = actor;
      }
    }

    consider(unitsOf(unit.team));
    consider(buildingsOf(unit.team));
    return best;
  }

  TilePoint _tileOf(Unit unit) => TilePoint(unit.x.floor(), unit.y.floor());

  /// 重算到 [goal] 的路径；[goal] 为空表示无法抵达，仅重置计时避免每步重算。
  ///
  /// 追击与后撤会周期性重算，但目标格、地形与建筑占位都没变时路径依旧有效，
  /// 此时只重置计时器，跳过整次 A* 搜索与路径数组分配。
  void _repath(Unit unit, TilePoint? goal, {required double repath}) {
    final reusable =
        goal != null &&
        unit.hasPath &&
        unit.pathGoal == goal &&
        unit.pathMapVersion == map.version &&
        unit.pathStructureVersion == structureVersion;
    if (!reusable) {
      final path = goal == null ? null : _finder.find(_tileOf(unit), goal);
      if (path != null) {
        unit
          ..setPath(path)
          ..pathGoal = goal
          ..pathMapVersion = map.version
          ..pathStructureVersion = structureVersion;
      }
    }
    unit.repathTimer = repath;
  }

  /// 追击：到达重算间隔或路径走完时重新寻路，然后跟随当前路径。
  /// 空中单位跳过 A*，直接朝目标格中心飞行并周期性刷新落点。
  void _chase(Unit unit, TilePoint? goal, double dt, {required double repath}) {
    if (unit.isAir) {
      if (goal == null) {
        unit.destination = null;
        return;
      }
      if (unit.repathTimer <= 0 || unit.destination == null) {
        unit
          ..destination = goal.center
          ..repathTimer = repath;
      }
      _flyTowards(unit, unit.destination!, dt, finish: false);
      return;
    }
    if (unit.repathTimer <= 0 || !unit.hasPath) _repath(unit, goal, repath: repath);
    if (unit.hasPath) _followPath(unit, dt);
  }

  /// 低空直飞：忽略地形与建筑占位，抵达终点后按需结束移动指令。
  void _flyTowards(Unit unit, Offset goal, double dt, {bool finish = true}) {
    if (!_stepTowards(unit, goal, unit.spec.speed * dt) || !finish) return;
    unit
      ..order = UnitOrder.idle
      ..destination = null
      ..guardPost = unit.position;
  }

  void _followPath(Unit unit, double dt) {
    final waypoint = unit.nextWaypoint;
    if (waypoint == null) return;
    final factor = unit.isAir ? 1.0 : map.speedFactor(waypoint.x, waypoint.y);
    if (_stepTowards(unit, waypoint.center, unit.spec.speed * factor * dt)) {
      unit.pathIndex += 1;
    }
  }

  /// 朝 [goal] 前进一步，抵达该点时对齐坐标并返回 true；地面与空中单位共用。
  bool _stepTowards(Unit unit, Offset goal, double speed) {
    final dx = goal.dx - unit.x;
    final dy = goal.dy - unit.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (unit.team == Team.red) _visionDirty = true;
    if (distance <= speed || distance < 0.05) {
      unit
        ..x = goal.dx
        ..y = goal.dy;
      return true;
    }
    unit
      ..x += dx / distance * speed
      ..y += dy / distance * speed
      ..facing = math.atan2(dy, dx);
    return false;
  }

  /// 采矿车回到待命，并按需推迟下一次寻矿。
  void _idleHarvester(Unit unit, {double delay = 0}) {
    unit
      ..phase = HarvesterPhase.idle
      ..repathTimer = delay;
  }

  void _updateHarvester(Unit unit, double dt) {
    switch (unit.phase) {
      case HarvesterPhase.moving:
        _followPath(unit, dt);
        if (!unit.hasPath) _idleHarvester(unit);
        break;
      case HarvesterPhase.idle:
        if (unit.repathTimer > 0) return;
        unit.repathTimer = 0.8;
        final refinery = nearestRefinery(unit.team, unit.position);
        if (refinery == null) {
          _idleHarvester(unit, delay: 3);
          return;
        }
        final ore = nearestOre(unit.position);
        if (ore == null) {
          _idleHarvester(unit, delay: 4);
          return;
        }
        unit
          ..oreTile = ore
          ..phase = HarvesterPhase.toOre;
        _pathTo(unit, ore.center);
        break;
      case HarvesterPhase.toOre:
        _followPath(unit, dt);
        if (unit.hasPath) return;
        final ore = unit.oreTile;
        if (ore == null || map.oreAt(ore.x, ore.y) <= 0) {
          _idleHarvester(unit);
          return;
        }
        if ((unit.position - ore.center).distance > 1.6) {
          _idleHarvester(unit, delay: 0.6);
          return;
        }
        unit
          ..phase = HarvesterPhase.mining
          ..miningTimer = 1.4;
        break;
      case HarvesterPhase.mining:
        final ore = unit.oreTile;
        if (ore == null) {
          _idleHarvester(unit);
          return;
        }
        unit.miningCarry += 180 * dt;
        final amount = unit.miningCarry.floor();
        unit.miningCarry -= amount;
        final mined = map.mine(ore.x, ore.y, amount);
        unit.cargo = math.min(unit.spec.capacity, unit.cargo + mined);
        if (unit.full) {
          _sendToRefinery(unit);
          return;
        }
        if (mined <= 0) {
          // 当前矿格采空，换最近的矿。
          final next = nearestOre(unit.position);
          if (next == null) {
            _sendToRefinery(unit);
          } else {
            unit.oreTile = next;
            unit.phase = HarvesterPhase.toOre;
            _pathTo(unit, next.center);
          }
        }
        break;
      case HarvesterPhase.toRefinery:
        _followPath(unit, dt);
        if (unit.hasPath) return;
        unit
          ..phase = HarvesterPhase.unloading
          ..miningTimer = 0.5;
        break;
      case HarvesterPhase.unloading:
        unit.miningTimer -= dt;
        if (unit.miningTimer > 0) return;
        final refinery = unit.refineryId == null ? null : actorById(unit.refineryId!);
        if (refinery == null) {
          _idleHarvester(unit);
          return;
        }
        final earned = unit.unload();
        if (earned > 0) {
          final multiplier = unit.team == Team.blue ? difficulty.aiIncome : 1.0;
          final income = (earned * multiplier).round();
          addCredits(unit.team, income);
          _emit(BattleEvent(BattleEventKind.unload, unit.x, unit.y, team: unit.team, radius: 0.4));
          if (unit.team == Team.red) {
            addNotice('采矿车入库 +$income', level: NoticeLevel.success);
          }
        }
        final ore = nearestOre(unit.position);
        if (ore == null) {
          _idleHarvester(unit, delay: 2);
        } else {
          unit
            ..oreTile = ore
            ..phase = HarvesterPhase.toOre
            ..repathTimer = 0;
          _pathTo(unit, ore.center);
        }
        break;
    }
  }

  void _sendToRefinery(Unit unit) {
    final refinery = nearestRefinery(unit.team, unit.position);
    if (refinery == null) {
      _idleHarvester(unit);
      return;
    }
    unit
      ..refineryId = refinery.id
      ..phase = HarvesterPhase.toRefinery;
    final spot = findSpawnTile(refinery);
    if (spot != null) {
      _pathTo(unit, spot.center);
    } else {
      unit.clearPath();
    }
  }

  void _pathTo(Unit unit, Offset target) {
    final goal = _nearestFreeTile(target, radius: 3);
    if (goal == null) {
      unit.clearPath();
      return;
    }
    final path = _finder.find(_tileOf(unit), goal);
    if (path == null) {
      unit.clearPath();
    } else {
      unit.setPath(path);
    }
  }

  /// 攻击建筑时找贴近外沿的可站立格，避免单位卡在建筑中心；
  /// 空中单位直接飞到目标所在格。
  TilePoint? _approachTile(Unit unit, Actor target) {
    final center = TilePoint(target.x.floor(), target.y.floor());
    if (unit.isAir || target is! Building) return center;
    return searchTile(
      centerX: center.x,
      centerY: center.y,
      maxRadius: 5,
      accept: (x, y) {
        if (x < 0 || y < 0 || x >= map.width || y >= map.height) return false;
        if (isBlocked(x, y)) return false;
        return rectGap(Offset(x + 0.5, y + 0.5), target.bounds) <= 0.6;
      },
    );
  }

  TilePoint? _nearestFreeTile(Offset point, {int radius = 4}) => searchTile(
    centerX: point.dx.floor(),
    centerY: point.dy.floor(),
    maxRadius: radius,
    accept: (x, y) => map.inBounds(x, y) && !isBlocked(x, y),
  );

  TilePoint? nearestOre(Offset from, {int maxDistance = 80}) {
    TilePoint? best;
    var bestDistance = double.infinity;
    final limit = maxDistance * maxDistance;
    for (final index in map.oreIndices) {
      final x = index % map.width;
      final y = index ~/ map.width;
      final dx = x + 0.5 - from.dx;
      final dy = y + 0.5 - from.dy;
      final distance = dx * dx + dy * dy;
      if (distance > limit) continue;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = TilePoint(x, y);
      }
    }
    return best;
  }

  Building? nearestRefinery(Team team, Offset from) {
    Building? best;
    var bestDistance = double.infinity;
    for (final building in buildingsOf(team)) {
      if (building.spec.kind != BuildingKind.refinery) continue;
      final distance = (building.position - from).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = building;
      }
    }
    return best;
  }
}
