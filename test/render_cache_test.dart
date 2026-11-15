import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_red_alert/flame/building_art.dart';
import 'package:flutter_red_alert/flame/paint_utils.dart';
import 'package:flutter_red_alert/flame/unit_art.dart';
import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_red_alert/game/entity.dart';
import 'package:material_ui/material_ui.dart';

Canvas _recorder() => Canvas(ui.PictureRecorder());

void main() {
  final outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.055;

  group('造型缓存', () {
    test('相同类型与阵营的建筑复用一个造型', () {
      final state = BattleState.create();
      final art = BuildingArt(ArtBrush());
      final hq = state.redBuildings.firstWhere((b) => b.spec.kind == BuildingKind.hq);
      art.paint(_recorder(), hq, outline);
      art.paint(_recorder(), hq, outline);
      expect(art.cachedPictures, 1);

      final blueHq = state.blueBuildings.firstWhere((b) => b.spec.kind == BuildingKind.hq);
      art.paint(_recorder(), blueHq, outline);
      expect(art.cachedPictures, 2);
      art.dispose();
      expect(art.cachedPictures, 0);
    });

    test('炮塔因炮管转向不进入缓存', () {
      final state = BattleState.create();
      final art = BuildingArt(ArtBrush());
      final tower = state.spawnBuildingForTest(Team.red, BuildingKind.tower, 12, 32);
      art.paint(_recorder(), tower, outline);
      expect(art.cachedPictures, 0);
    });

    test('步兵缓存身体与武器两张造型，坦克只需一张', () {
      final art = UnitArt(ArtBrush());
      final rifle = Unit(id: 1, team: Team.red, spec: unitSpecs[UnitKind.rifle]!, x: 1, y: 1);
      art.paint(_recorder(), rifle, outline);
      art.paint(_recorder(), rifle, outline);
      expect(art.cachedPictures, 2);

      final tank = Unit(id: 2, team: Team.red, spec: unitSpecs[UnitKind.heavyTank]!, x: 2, y: 2);
      art.paint(_recorder(), tank, outline);
      expect(art.cachedPictures, 3);
      art.dispose();
      expect(art.cachedPictures, 0);
    });

    test('全部单位与建筑造型均可绘制', () {
      final units = UnitArt(ArtBrush());
      var id = 0;
      for (final team in Team.values) {
        for (final kind in UnitKind.values) {
          final unit = Unit(id: ++id, team: team, spec: unitSpecs[kind]!, x: 1, y: 1);
          units.paint(_recorder(), unit, outline);
        }
      }
      expect(units.cachedPictures, greaterThan(0));
      units.dispose();

      final buildings = BuildingArt(ArtBrush());
      for (final team in Team.values) {
        for (final kind in BuildingKind.values) {
          final building = Building(
            id: ++id,
            team: team,
            spec: buildingSpecs[kind]!,
            tileX: 0,
            tileY: 0,
          );
          buildings.paint(_recorder(), building, outline);
        }
      }
      expect(buildings.cachedPictures, greaterThan(0));
      buildings.dispose();
    });
  });
}
