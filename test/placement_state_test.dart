import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/entity.dart';
import 'package:flutter_red_alert/game/placement_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BattleState readyState() {
    final state = BattleState.create();
    state.startProduction(
      Team.red,
      ProductionCategory.structure,
      BuildingKind.barracks.name,
    );
    for (var t = 0.0; t < 13; t += 1 / 60) {
      state.update(1 / 60);
    }
    expect(
      state.readyStructuresOf(Team.red),
      contains(BuildingKind.barracks),
    );
    return state;
  }

  test('放到可建位置后提交并退出放置模式', () {
    final state = readyState();
    final placement = PlacementState(state: state, team: Team.red);
    final spec = buildingSpecs[BuildingKind.barracks]!;
    final spot = state.findPlacement(spec, Team.red);
    expect(spot, isNotNull);

    placement.begin(
      BuildingKind.barracks,
      Offset(spot!.x + spec.width / 2, spot.y + spec.height / 2),
    );
    expect(placement.active, isTrue);
    expect(placement.kind, BuildingKind.barracks);
    expect(placement.tile, spot);
    expect(placement.valid, isTrue);

    final building = placement.commit();
    expect(building, isNotNull);
    expect(building!.spec.kind, BuildingKind.barracks);
    expect(placement.active, isFalse);
    expect(state.countBuildings(Team.red, BuildingKind.barracks), 1);
  });

  test('起点不可建时自动换到基地附近的可建位置', () {
    final state = readyState();
    final placement = PlacementState(state: state, team: Team.red);
    placement.begin(BuildingKind.barracks, const Offset(0, 0));
    expect(placement.valid, isTrue);
    expect(placement.tile, isNot(equals(const TilePoint(0, 0))));
  });

  test('不可建位置提交失败并保留预览，取消后清空', () {
    final state = readyState();
    final placement = PlacementState(state: state, team: Team.red)
      ..begin(BuildingKind.barracks, const Offset(2, 2));
    placement.moveTo(const Offset(1, 1));
    expect(placement.valid, isFalse);
    expect(placement.commit(), isNull);
    expect(placement.active, isTrue);
    expect(state.countBuildings(Team.red, BuildingKind.barracks), 0);

    placement.cancel();
    expect(placement.active, isFalse);
    expect(placement.tile, isNull);
  });

  test('未就绪的建筑不能通过放置接口落地', () {
    final state = BattleState.create();
    final spec = buildingSpecs[BuildingKind.tower]!;
    final spot = state.findPlacement(spec, Team.red);
    expect(spot, isNotNull);
    final placement = PlacementState(state: state, team: Team.red)
      ..begin(
        BuildingKind.tower,
        Offset(spot!.x + spec.width / 2, spot.y + spec.height / 2),
      );
    expect(placement.valid, isTrue);
    expect(placement.commit(), isNull);
    expect(state.countBuildings(Team.red, BuildingKind.tower), 0);
  });
}
