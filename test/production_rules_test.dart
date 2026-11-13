import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('未知 id 返回明确的阻塞原因', () {
    final state = BattleState.create();
    expect(
      state.productionBlocker(Team.red, ProductionCategory.structure, 'nope'),
      '未知建筑',
    );
    expect(
      state.productionBlocker(Team.red, ProductionCategory.infantry, 'nope'),
      '未知单位',
    );
  });

  test('生产项分类必须与队列分类一致', () {
    final state = BattleState.create();
    expect(
      state.productionBlocker(Team.red, ProductionCategory.infantry, 'power'),
      '分类不匹配',
    );
    expect(
      state.startProduction(Team.red, ProductionCategory.armor, 'rifle'),
      isFalse,
    );
  });

  test('缺少生产建筑与前置建筑时给出对应提示', () {
    final state = BattleState.create();
    expect(
      state.productionBlocker(Team.red, ProductionCategory.armor, 'lightTank'),
      '需要战车工厂',
    );
    expect(
      state.productionBlocker(Team.red, ProductionCategory.infantry, 'rifle'),
      '需要兵营',
    );
    // 已有精炼厂，战车工厂可以排产。
    expect(
      state.productionBlocker(Team.red, ProductionCategory.structure, 'factory'),
      isNull,
    );
    expect(
      state.canProduce(Team.red, ProductionCategory.armor, 'lightTank'),
      isFalse,
    );
  });

  test('指挥中心被摧毁后只能用残存建筑重建', () {
    final state = BattleState.create();
    final hq = state.buildingsOf(Team.red).firstWhere(
      (b) => b.spec.kind == BuildingKind.hq,
    );
    hq.hp = 0;
    state.update(1 / 60);

    expect(
      state.productionBlocker(Team.red, ProductionCategory.structure, 'barracks'),
      '需要指挥中心',
    );
    expect(
      state.productionBlocker(Team.red, ProductionCategory.structure, 'hq'),
      isNull,
    );
  });

  test('基地建筑全灭后无法再重建指挥中心', () {
    final state = BattleState.create();
    for (final building in state.buildingsOf(Team.red)) {
      building.hp = 0;
    }
    state.update(1 / 60);
    expect(state.buildingsOf(Team.red), isEmpty);
    expect(
      state.productionBlocker(Team.red, ProductionCategory.structure, 'hq'),
      '基地已失守',
    );
    expect(
      state.startProduction(Team.red, ProductionCategory.structure, 'hq'),
      isFalse,
    );
  });
}
