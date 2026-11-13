import 'dart:ui';

import 'battle_state.dart';
import 'battle_types.dart';
import 'entity.dart';

/// 建筑放置流程：记录待放置的建筑、预览中心与落点合法性。
///
/// 只做状态与校验，音效、提示与日志由控制器负责，便于单独测试。
class PlacementState {
  PlacementState({required this.state, required this.team});

  final BattleState state;
  final Team team;

  BuildingKind? _kind;
  Offset? _center;

  bool get active => _kind != null;

  BuildingKind? get kind => _kind;

  BuildingSpec? get spec => _kind == null ? null : buildingSpecs[_kind!];

  /// 预览左上角格。
  TilePoint? get tile {
    final spec = this.spec;
    final center = _center;
    if (spec == null || center == null) return null;
    return TilePoint(
      (center.dx - spec.width / 2).round(),
      (center.dy - spec.height / 2).round(),
    );
  }

  bool get valid {
    final spec = this.spec;
    final tile = this.tile;
    if (spec == null || tile == null) return false;
    return state.canPlaceBuilding(spec, tile.x, tile.y, team: team);
  }

  /// 开始放置：预览落在 [focus]，不可建时在基地附近就近选址。
  void begin(BuildingKind kind, Offset focus) {
    _kind = kind;
    _move(focus);
    final spec = this.spec!;
    if (valid) return;
    final spot = state.findPlacement(spec, team, maxRadius: 10);
    if (spot == null) return;
    _center = Offset(spot.x + spec.width / 2, spot.y + spec.height / 2);
  }

  void moveTo(Offset world) {
    if (!active) return;
    _move(world);
  }

  void cancel() {
    _kind = null;
    _center = null;
  }

  /// 提交放置；不合法时返回 null，成功后自动退出放置模式。
  Building? commit() {
    final kind = _kind;
    final tile = this.tile;
    if (kind == null || tile == null || !valid) return null;
    final building = state.placeStructureAt(team, kind, tile.x, tile.y);
    if (building != null) cancel();
    return building;
  }

  void _move(Offset world) {
    _center = Offset(
      world.dx.clamp(0, state.map.width.toDouble()),
      world.dy.clamp(0, state.map.height.toDouble()),
    );
  }
}
