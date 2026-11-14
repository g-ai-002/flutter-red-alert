part of 'battle_state.dart';

/// 建筑放置与出生点：地形、重叠、基地距离校验，以及双方共用的生成入口。
extension BattleConstruction on BattleState {
  /// 放置校验：地形可建、无重叠、且不远离己方建筑。
  bool canPlaceBuilding(
    BuildingSpec spec,
    int tileX,
    int tileY, {
    Team? team,
    bool requireNearBase = true,
  }) {
    if (tileX < 0 || tileY < 0) return false;
    if (tileX + spec.width > map.width || tileY + spec.height > map.height) {
      return false;
    }
    for (var y = tileY; y < tileY + spec.height; y++) {
      for (var x = tileX; x < tileX + spec.width; x++) {
        if (!map.buildable(x, y)) return false;
        if (buildingAt(x, y) != null) return false;
      }
    }
    if (!requireNearBase || team == null) return true;
    final center = Offset(tileX + spec.width / 2, tileY + spec.height / 2);
    for (final building in buildingsOf(team)) {
      final limit = building.spec.kind == BuildingKind.hq ? 9.0 : 7.0;
      if (rectGap(center, building.bounds) <= limit) return true;
    }
    return false;
  }

  /// 找到离己方基地最近的可放置位置，供 AI 与「自动选址」使用。
  TilePoint? findPlacement(BuildingSpec spec, Team team, {int maxRadius = 12}) {
    final base = map.baseOf(team);
    return searchTile(
      centerX: base.dx.floor(),
      centerY: base.dy.floor(),
      maxRadius: maxRadius,
      accept: (x, y) => canPlaceBuilding(spec, x, y, team: team),
    );
  }

  Building? placeReadyStructure(Team team, BuildingKind kind) {
    if (!hasReadyStructure(team, kind)) return null;
    final spec = buildingSpecs[kind]!;
    final spot = findPlacement(spec, team);
    if (spot == null) return null;
    _readyStructures[team]!.remove(kind);
    return _completeBuilding(team, kind, spot.x, spot.y);
  }

  /// 尝试在指定格放置已就绪的建筑。
  Building? placeStructureAt(Team team, BuildingKind kind, int tileX, int tileY) {
    if (!hasReadyStructure(team, kind)) return null;
    final spec = buildingSpecs[kind]!;
    if (!canPlaceBuilding(spec, tileX, tileY, team: team)) return null;
    _readyStructures[team]!.remove(kind);
    return _completeBuilding(team, kind, tileX, tileY);
  }

  Building _completeBuilding(Team team, BuildingKind kind, int tileX, int tileY) {
    final building = _spawnBuilding(team, kind, tileX, tileY);
    _emit(
      BattleEvent(
        BattleEventKind.build,
        building.x,
        building.y,
        team: team,
        radius: building.radius,
      ),
    );
    if (team == Team.red) {
      addNotice('${kind.label}建造完成', level: NoticeLevel.success);
    }
    return building;
  }

  Building _spawnBuilding(Team team, BuildingKind kind, int tileX, int tileY) {
    final building = Building(
      id: _nextId++,
      team: team,
      spec: buildingSpecs[kind]!,
      tileX: tileX,
      tileY: tileY,
    );
    actors.add(building);
    _byId[building.id] = building;
    buildingsOf(team).add(building);
    _trackBuilding(building, 1);
    structureVersion++;
    for (var y = tileY; y < tileY + building.spec.height; y++) {
      for (var x = tileX; x < tileX + building.spec.width; x++) {
        if (!map.inBounds(x, y)) continue;
        _occupancy[y * map.width + x] = building;
      }
    }
    return building;
  }

  Unit _spawnUnit(Team team, UnitKind kind, Offset at) {
    final tile = _nearestFreeTile(at, radius: 6) ?? TilePoint(at.dx.floor(), at.dy.floor());
    final unit = Unit(
      id: _nextId++,
      team: team,
      spec: unitSpecs[kind]!,
      x: tile.x + 0.5,
      y: tile.y + 0.5,
    );
    unit.facing = team == Team.red ? -math.pi / 4 : math.pi * 3 / 4;
    actors.add(unit);
    _byId[unit.id] = unit;
    unitsOf(team).add(unit);
    _trackArmy(unit, 1);
    return unit;
  }

  /// 在建筑周围寻找空位，优先朝基地外侧（地图中心方向）。
  TilePoint? findSpawnTile(Building building) => searchTile(
    centerX: (building.tileX + building.spec.width / 2).floor(),
    centerY: (building.tileY + building.spec.height / 2).floor(),
    maxRadius: 6,
    accept: (x, y) => map.inBounds(x, y) && !isBlocked(x, y),
  );
}
