part of 'battle_state.dart';

/// 单位机动与采矿：编队移动、路径跟随、追击落点与采矿车状态机。
extension BattleMovement on BattleState {
  /// 下达移动指令，按网格阵型分配落点。
  void issueMove(List<Unit> units, Offset destination) {
    final ordered = units.where((u) => u.alive).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (ordered.isEmpty) return;
    final offsets = _formationOffsets(ordered.length);
    final baseTile = TilePoint(destination.dx.floor(), destination.dy.floor());
    var placed = 0;
    for (var i = 0; i < ordered.length; i++) {
      final unit = ordered[i];
      final offset = offsets[i];
      final slot = _nearestFreeTile(
        Offset(baseTile.x + 0.5 + offset.dx, baseTile.y + 0.5 + offset.dy),
        radius: 2,
      );
      if (slot == null) continue;
      final path = _finder.find(
        TilePoint(unit.x.floor(), unit.y.floor()),
        slot,
      );
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
        BattleEvent(
          BattleEventKind.move,
          destination.dx,
          destination.dy,
          team: ordered.first.team,
        ),
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
    unit.advanceFlash(dt);
    unit.fireCooldown = math.max(0, unit.fireCooldown - dt);
    unit.repathTimer = math.max(0, unit.repathTimer - dt);
    if (unit.isHarvester) {
      _updateHarvester(unit, dt);
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
      if (unit.hasPath) {
        _followPath(unit, dt);
      } else {
        unit.order = UnitOrder.idle;
        unit.destination = null;
      }
      // 行军途中只打射程内的临时目标，不为它停下脚步。
      if (target != null && _distanceTo(unit, target) <= unit.spec.range) {
        _fireAt(unit, target);
      } else {
        unit.targetId = null;
      }
      _acquireIfIdle(unit);
      return;
    }
    // 待命：有目标就原地开火，目标消失在射程外则清空。
    if (target != null) {
      final distance = _distanceTo(unit, target);
      if (distance <= unit.spec.range) {
        _fireAt(unit, target);
      } else {
        unit.targetId = null;
      }
    }
    _acquireIfIdle(unit);
  }

  void _followPath(Unit unit, double dt) {
    final waypoint = unit.nextWaypoint;
    if (waypoint == null) return;
    final tx = waypoint.x + 0.5;
    final ty = waypoint.y + 0.5;
    final dx = tx - unit.x;
    final dy = ty - unit.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    final speed =
        unit.spec.speed * map.speedFactor(waypoint.x, waypoint.y) * dt;
    if (distance <= speed || distance < 0.02) {
      unit
        ..x = tx
        ..y = ty
        ..pathIndex = unit.pathIndex + 1;
      return;
    }
    unit
      ..x += dx / distance * speed
      ..y += dy / distance * speed
      ..facing = math.atan2(dy, dx);
  }

  void _updateHarvester(Unit unit, double dt) {
    switch (unit.phase) {
      case HarvesterPhase.moving:
        _followPath(unit, dt);
        if (!unit.hasPath) {
          unit
            ..phase = HarvesterPhase.idle
            ..repathTimer = 0;
        }
        break;
      case HarvesterPhase.idle:
        if (unit.repathTimer > 0) return;
        unit.repathTimer = 0.8;
        final refinery = nearestRefinery(unit.team, unit.position);
        if (refinery == null) {
          unit.repathTimer = 3;
          return;
        }
        final ore = nearestOre(unit.position);
        if (ore == null) {
          unit.repathTimer = 4;
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
          unit.phase = HarvesterPhase.idle;
          unit.repathTimer = 0;
          return;
        }
        if ((unit.position - ore.center).distance > 1.6) {
          unit
            ..phase = HarvesterPhase.idle
            ..repathTimer = 0.6;
          return;
        }
        unit
          ..phase = HarvesterPhase.mining
          ..miningTimer = 1.4;
        break;
      case HarvesterPhase.mining:
        final ore = unit.oreTile;
        if (ore == null) {
          unit.phase = HarvesterPhase.idle;
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
        final refinery = unit.refineryId == null
            ? null
            : actorById(unit.refineryId!);
        if (refinery == null) {
          unit.phase = HarvesterPhase.idle;
          unit.repathTimer = 0;
          return;
        }
        final earned = unit.unload();
        if (earned > 0) {
          final multiplier = unit.team == Team.blue ? difficulty.aiIncome : 1.0;
          final income = (earned * multiplier).round();
          _addCredits(unit.team, income);
          _emit(
            BattleEvent(
              BattleEventKind.unload,
              unit.x,
              unit.y,
              team: unit.team,
              radius: 0.4,
            ),
          );
          if (unit.team == Team.red) {
            addNotice('采矿车入库 +$income', level: NoticeLevel.success);
          }
        }
        final ore = nearestOre(unit.position);
        if (ore == null) {
          unit.phase = HarvesterPhase.idle;
          unit.repathTimer = 2;
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
      unit.phase = HarvesterPhase.idle;
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
    final path = _finder.find(TilePoint(unit.x.floor(), unit.y.floor()), goal);
    if (path == null) {
      unit.clearPath();
    } else {
      unit.setPath(path);
    }
  }

  /// 攻击建筑时找贴近外沿的可站立格，避免单位卡在建筑中心。
  TilePoint? _approachTile(Actor target) {
    if (target is! Building) {
      return TilePoint(target.x.floor(), target.y.floor());
    }
    return searchTile(
      centerX: target.x.floor(),
      centerY: target.y.floor(),
      maxRadius: 5,
      accept: (x, y) {
        if (x < 0 || y < 0 || x >= map.width || y >= map.height) return false;
        if (isBlocked(x, y)) return false;
        return _rectGap(Offset(x + 0.5, y + 0.5), target.bounds) <= 0.6;
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
