import 'package:flutter/material.dart';

import '../../game/battle_controller.dart';
import '../../game/battle_types.dart';
import '../../theme/palette.dart';

/// 顶部状态栏：资金、电力、部队与用时，右侧为雷达、速度、暂停与菜单。
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
                    _StatChip(
                      glyph: '资',
                      value: '${state.creditsOf(playerTeam)}',
                      label: '资金',
                      color: hudGold,
                      compact: compact,
                    ),
                    const SizedBox(width: 6),
                    _StatChip(
                      glyph: '电',
                      value: '$used/$produced',
                      label: '电力',
                      color: used > produced
                          ? hudWarning
                          : const Color(0xFF7FB7C9),
                      compact: compact,
                    ),
                    const SizedBox(width: 6),
                    _StatChip(
                      glyph: '兵',
                      value: '${state.armySize(playerTeam)}',
                      label: '部队',
                      color: const Color(0xFFC9B79B),
                      compact: compact,
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 6),
                      _StatChip(
                        glyph: '时',
                        value: controller.elapsedText,
                        label: '用时',
                        color: hudTextMuted,
                        compact: false,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _RadarButton(controller: controller),
            const SizedBox(width: 4),
            _HudButton(
              icon: Icons.speed,
              label: controller.speed >= 2 ? '×2' : '×1',
              onTap: controller.cycleSpeed,
              highlight: controller.speed >= 2,
            ),
            const SizedBox(width: 4),
            _HudButton(
              icon: controller.paused ? Icons.play_arrow : Icons.pause,
              onTap: onPause,
            ),
            const SizedBox(width: 4),
            _HudButton(icon: Icons.menu, onTap: onMenu),
          ],
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.glyph,
    required this.value,
    required this.label,
    required this.color,
    required this.compact,
  });

  final String glyph;
  final String value;
  final String label;
  final Color color;
  final bool compact;

  static const TextStyle _valueStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: hudText,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9),
      decoration: BoxDecoration(
        color: const Color(0xD9181714),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33EFE2C8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            glyph,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(value, style: _valueStyle),
          if (!compact) ...[
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF928878)),
            ),
          ],
        ],
      ),
    );
  }
}

/// 雷达按钮：显示扫描中 / 可扫描 / 冷却秒数三种状态。
class _RadarButton extends StatelessWidget {
  const _RadarButton({required this.controller});

  final BattleController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final online = state.hasBuilding(playerTeam, BuildingKind.hq);
    final label = !online
        ? '离线'
        : state.radarActive
        ? '扫描中'
        : state.radarReady
        ? '雷达'
        : '${state.radarCooldown.ceil()}s';
    return _HudButton(
      icon: Icons.radar,
      label: label,
      highlight: online && (state.radarActive || state.radarReady),
      onTap: controller.triggerRadar,
    );
  }
}

class _HudButton extends StatelessWidget {
  const _HudButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
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
            border: Border.all(
              color: highlight
                  ? const Color(0xAAE8C271)
                  : const Color(0x33EFE2C8),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: hudText),
              if (label != null) ...[
                const SizedBox(width: 2),
                Text(
                  label!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: hudText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
