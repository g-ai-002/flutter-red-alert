import 'package:flutter_red_alert/game/entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('中心可接受时直接返回中心', () {
    final tile = searchTile(centerX: 4, centerY: 6, maxRadius: 3, accept: (x, y) => true);
    expect(tile, const TilePoint(4, 6));
  });

  test('按半径由内向外扫描并跳过被拒绝的格子', () {
    final visited = <TilePoint>[];
    final tile = searchTile(
      centerX: 0,
      centerY: 0,
      maxRadius: 3,
      accept: (x, y) {
        visited.add(TilePoint(x, y));
        return x == 2 && y == 1;
      },
    );
    expect(tile, const TilePoint(2, 1));
    expect(visited, contains(const TilePoint(1, 0)));
    expect(visited, contains(const TilePoint(0, 1)));
    expect(
      visited.indexOf(const TilePoint(1, 0)),
      lessThan(visited.indexOf(const TilePoint(2, 1))),
    );
  });

  test('超出最大半径时返回空', () {
    expect(searchTile(centerX: 0, centerY: 0, maxRadius: 2, accept: (x, y) => false), isNull);
  });

  test('负数中心也能正常扫描', () {
    final tile = searchTile(
      centerX: -3,
      centerY: -4,
      maxRadius: 2,
      accept: (x, y) => x == -1 && y == -4,
    );
    expect(tile, const TilePoint(-1, -4));
  });
}
