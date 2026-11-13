import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/production_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('目录覆盖全部建筑与单位且 id 唯一', () {
    final ids = ProductionCatalog.all.map((item) => item.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(
      ProductionCatalog.all.where((item) => item.isBuilding).map((item) => item.building).toSet(),
      BuildingKind.values.toSet(),
    );
    expect(
      ProductionCatalog.all.where((item) => !item.isBuilding).map((item) => item.unit).toSet(),
      UnitKind.values.toSet(),
    );
  });

  test('分类顺序与建造栏展示一致', () {
    expect(ProductionCatalog.of(ProductionCategory.structure).map((i) => i.id), [
      'power',
      'refinery',
      'barracks',
      'factory',
      'tower',
      'hq',
    ]);
    expect(ProductionCatalog.of(ProductionCategory.infantry).map((i) => i.id), ['rifle', 'rocket']);
    expect(ProductionCatalog.of(ProductionCategory.armor).map((i) => i.id), [
      'harvester',
      'lightTank',
      'heavyTank',
    ]);
  });

  test('目录条目直接取自参数表', () {
    final rifle = ProductionCatalog.byId('rifle')!;
    expect(rifle.name, unitSpecs[UnitKind.rifle]!.name);
    expect(rifle.icon, unitSpecs[UnitKind.rifle]!.icon);
    expect(rifle.cost, unitSpecs[UnitKind.rifle]!.cost);
    expect(rifle.seconds, unitSpecs[UnitKind.rifle]!.buildSeconds);
    expect(rifle.requires, unitSpecs[UnitKind.rifle]!.requires);
    expect(rifle.category, unitSpecs[UnitKind.rifle]!.category);

    final barracks = ProductionCatalog.byId('barracks')!;
    expect(barracks.name, buildingSpecs[BuildingKind.barracks]!.name);
    expect(barracks.cost, buildingSpecs[BuildingKind.barracks]!.cost);
    expect(barracks.seconds, buildingSpecs[BuildingKind.barracks]!.buildSeconds);
    expect(barracks.requires, buildingSpecs[BuildingKind.barracks]!.requires);
  });

  test('未知 id 与跨分类查询都返回空', () {
    expect(ProductionCatalog.byId('nope'), isNull);
  });
}
