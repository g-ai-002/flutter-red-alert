import 'package:flutter/material.dart';

import '../game/battle_types.dart';

/// 赤色黎明的基础配色：军绿、沙土、钢铁与赤红。
const Color appRed = Color(0xFFC8382B);
const Color appRedDeep = Color(0xFF8E241B);
const Color appGold = Color(0xFFD9A94B);
const Color appSteel = Color(0xFF39424B);
const Color appSand = Color(0xFFF1E6D2);
const Color appNight = Color(0xFF121110);

/// 地形基础色，渲染与迷你地图共用。
Color terrainColor(TerrainKind kind) => switch (kind) {
  TerrainKind.grass => const Color(0xFF4C6B3C),
  TerrainKind.dirt => const Color(0xFF7A6547),
  TerrainKind.road => const Color(0xFF5A5852),
  TerrainKind.ore => const Color(0xFF7A6547),
  TerrainKind.water => const Color(0xFF2C5369),
  TerrainKind.rock => const Color(0xFF55524C),
};

/// 地形高光色，用于绘制纹理与迷你地图的明暗。
Color terrainHighlight(TerrainKind kind) => switch (kind) {
  TerrainKind.grass => const Color(0xFF5F7F4A),
  TerrainKind.dirt => const Color(0xFF8D7656),
  TerrainKind.road => const Color(0xFF6C6A63),
  TerrainKind.ore => const Color(0xFFD9A94B),
  TerrainKind.water => const Color(0xFF3C6A82),
  TerrainKind.rock => const Color(0xFF6A665E),
};
