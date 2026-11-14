import 'package:flutter/material.dart';

import '../game/battle_types.dart';

/// 赤色黎明的基础配色：军绿、沙土、钢铁与赤红。
const Color appRed = Color(0xFFC8382B);
const Color appGold = Color(0xFFD9A94B);

/// HUD 语义色：面板、描边与文字层级，界面组件不再各自写死颜色值。
const Color hudPanel = Color(0xE6191815);
const Color hudPanelDeep = Color(0xE6141310);
const Color hudPanelSolid = Color(0xFF1B1915);
const Color hudPanelAlt = Color(0xFF232019);
const Color hudCardTop = Color(0xFF2F2C25);
const Color hudCardBottom = Color(0xFF23211C);
const Color hudCardReadyTop = Color(0xFF5A4520);
const Color hudCardReadyBottom = Color(0xFF33280F);
const Color hudBorder = Color(0x44EFE2C8);
const Color hudBorderFaint = Color(0x33EFE2C8);
const Color hudBorderSoft = Color(0x33584F41);
const Color hudBorderDeep = Color(0x55584F41);
const Color hudBorderGold = Color(0x44D9A94B);
const Color hudShadow = Color(0x66000000);
const Color hudText = Color(0xFFF4EAD6);
const Color hudTextSoft = Color(0xFFD9CBB4);
const Color hudTextMuted = Color(0xFFAFA393);
const Color hudTextFaint = Color(0xFF9C9384);
const Color hudTextDim = Color(0xFF8B8172);
const Color hudTextWarm = Color(0xFFB7AA97);
const Color hudGold = Color(0xFFD9A94B);
const Color hudGoldBright = Color(0xFFE8C271);
const Color hudGoldVeil = Color(0x33D9A94B);
const Color hudBronze = Color(0xFFC8A97A);
const Color hudSuccess = Color(0xFF8AD694);
const Color hudWarning = Color(0xFFE0806F);
const Color hudInfo = Color(0xFF9FB3C6);
const Color hudDanger = Color(0xFFE0755F);
const Color hudPower = Color(0xFF7FB7C9);
const Color hudTroops = Color(0xFFC9B79B);

/// 建造预览色：世界坐标的放置框与 HUD 提示条共用同一组语义色。
const Color hudBuildOk = Color(0xFF6FCF7A);
const Color hudBuildNo = Color(0xFFE0604F);

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
