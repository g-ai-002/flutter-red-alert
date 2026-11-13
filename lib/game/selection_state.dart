import 'dart:ui';

import 'battle_state.dart';
import 'battle_types.dart';
import 'entity.dart';

/// 选中集合：只保存 id，按需从战场状态解析单位与建筑。
///
/// 点选、框选、全选同类与选中摘要都在这里完成，控制器只负责音效、指令与提示。
class SelectionState {
  SelectionState({required this.state, required this.team});

  final BattleState state;
  final Team team;
  final Set<int> ids = {};

  List<Unit> get units => state.selectableUnits(team, ids);

  List<Actor> get actors => [for (final id in ids) ?state.actorById(id)];

  /// 当前选中的指挥官信息；多选时汇总生命值。
  SelectionInfo? get summary {
    final selected = actors;
    if (selected.isEmpty) return null;
    final first = selected.first;
    if (selected.length == 1) {
      return SelectionInfo(
        name: first.displayName,
        icon: first is Unit ? first.spec.icon : (first as Building).spec.icon,
        hp: first.hp,
        maxHp: first.maxHp,
        team: first.team,
        isBuilding: first.isBuilding,
        count: 1,
      );
    }
    final sameName = selected.every((actor) => actor.displayName == first.displayName);
    var hp = 0;
    var maxHp = 0;
    for (final actor in selected) {
      hp += actor.hp;
      maxHp += actor.maxHp;
    }
    return SelectionInfo(
      name: sameName ? first.displayName : '混编部队',
      icon: sameName ? (first is Unit ? first.spec.icon : (first as Building).spec.icon) : '编',
      hp: hp,
      maxHp: maxHp,
      team: first.team,
      isBuilding: false,
      count: selected.length,
    );
  }

  /// 只有全部为玩家单位时才接受移动与攻击指令。
  bool get canCommand {
    final selected = actors;
    return selected.isNotEmpty && selected.every((actor) => actor is Unit && actor.team == team);
  }

  void clear() => ids.clear();

  void replace(int id) {
    ids
      ..clear()
      ..add(id);
  }

  /// 追加选择；已选中则取消。返回是否仍处于选中状态。
  bool toggle(int id) {
    if (!ids.remove(id)) ids.add(id);
    return ids.contains(id);
  }

  /// 点选世界坐标上的目标；返回命中的目标，未命中返回 null。
  Actor? selectAt(Offset world, {bool additive = false}) {
    final hit = state.actorAt(world);
    if (hit == null || !state.isVisibleToPlayer(hit)) return null;
    selectActor(hit, additive: additive);
    return hit;
  }

  /// 选中一个已知目标；追加模式下再次点击会取消选择。
  void selectActor(Actor actor, {bool additive = false}) {
    if (additive) {
      toggle(actor.id);
    } else {
      replace(actor.id);
    }
  }

  /// 框选：只选中矩形内的己方单位，建筑不参与框选。
  void selectRect(Rect worldRect, {bool additive = false}) {
    if (!additive) ids.clear();
    for (final unit in state.unitsOf(team)) {
      if (!unit.alive) continue;
      if (worldRect.contains(unit.position)) ids.add(unit.id);
    }
  }

  /// 全选同类：单选时选中全部同型单位，采矿车选全部采矿车，建筑则选全部部队。
  void selectAllSameKind() {
    final selected = actors;
    if (selected.isEmpty) return;
    final first = selected.first;
    ids.clear();
    if (first is! Unit) {
      for (final unit in state.unitsOf(team)) {
        ids.add(unit.id);
      }
      return;
    }
    for (final unit in state.unitsOf(team)) {
      if (unit.isHarvester == first.isHarvester &&
          (first.isHarvester || unit.spec.kind == first.spec.kind)) {
        ids.add(unit.id);
      }
    }
  }

  /// 移除已阵亡或已不存在的目标。
  void prune() => ids.removeWhere((id) => state.actorById(id) == null);
}
