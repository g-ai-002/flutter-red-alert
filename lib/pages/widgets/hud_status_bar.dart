import 'package:flutter/material.dart';

import '../../game/battle_controller.dart';
import '../../game/battle_types.dart';
import '../../theme/palette.dart';

/// 顶部状态栏：资金、电力、部队与用时，右侧为雷达、导弹、速度、暂停与菜单。
class BattleStatusBar extends StatelessWidget {
  const BattleStatusBar({
    super.key,
    required this.controller,
    required this.onPause,
    required this.onMenu,
  });

  final BattleController controller;
  final VoidCallback onPause;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final used = state.powerUsed(playerTeam);
    final produced = state.powerProduced(playerTeam);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        return Row(
          children: [
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _statChip('资', '${state.creditsOf(playerTeam)}', '资金', hudGold, compact),
                    const SizedBox(width: 6),
                    _statChip(
                      '电',
                      '$used/$produced',
                      '电力',
                      used > produced ? hudWarning : hudPower,
                      compact,
                    ),
                    const SizedBox(width: 6),
                    _statChip('兵', '${state.armySize(playerTeam)}', '部队', hudTroops, compact),
                    if (!compact) ...[
                      const SizedBox(width: 6),
                      _statChip('时', controller.elapsedText, '用时', hudTextMuted, false),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _radarButton(controller),
            const SizedBox(width: 4),
            _strikeButton(controller),
            const SizedBox(width: 4),
            _hudButton(
              Icons.speed,
              controller.cycleSpeed,
              label: controller.speed >= 2 ? '×2' : '×1',
              highlight: controller.speed >= 2,
            ),
            const SizedBox(width: 4),
            _hudButton(controller.paused ? Icons.play_arrow : Icons.pause, onPause),
            const SizedBox(width: 4),
            _hudButton(Icons.menu, onMenu),
          ],
        );
      },
    );
  }
}

Widget _statChip(String glyph, String value, String label, Color color, bool compact) {
  return Container(
    height: 30,
    padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9),
    decoration: BoxDecoration(
      color: const Color(0xD9181714),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: hudBorderFaint),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          glyph,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: hudText,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF928878))),
        ],
      ],
    ),
  );
}

/// 雷达按钮：显示扫描中 / 可扫描 / 冷却秒数三种状态。
Widget _radarButton(BattleController controller) {
  final state = controller.state;
  final online = state.hasBuilding(playerTeam, BuildingKind.hq);
  final label = !online
      ? '离线'
      : state.radarActive
      ? '扫描中'
      : state.radarReady
      ? '雷达'
      : '${state.radarCooldown.ceil()}s';
  return _hudButton(
    Icons.radar,
    controller.triggerRadar,
    label: label,
    highlight: online && (state.radarActive || state.radarReady),
  );
}

/// 战略打击按钮：未建发射井为「导弹」，蓄能中显示百分比，就绪后可进入瞄准。
Widget _strikeButton(BattleController controller) {
  final state = controller.state;
  final label = controller.strikeAiming
      ? '瞄准'
      : !state.hasBuilding(playerTeam, BuildingKind.silo)
      ? '导弹'
      : controller.strikeReady
      ? '发射'
      : '${(controller.strikeProgress * 100).round()}%';
  return _hudButton(
    Icons.rocket_launch,
    controller.toggleStrikeAiming,
    label: label,
    highlight: controller.strikeAiming || controller.strikeReady,
  );
}

Widget _hudButton(IconData icon, VoidCallback onTap, {String? label, bool highlight = false}) {
  return Material(
    color: highlight ? const Color(0x66D9A94B) : const Color(0xD9181714),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: highlight ? const Color(0xAAE8C271) : hudBorderFaint),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: hudText),
            if (label != null) ...[
              const SizedBox(width: 2),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: hudText),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
