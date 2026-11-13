import 'package:flutter/material.dart';

import '../../game/battle_controller.dart';
import '../../game/battle_state.dart';
import '../../game/battle_types.dart';

/// 顶部状态栏：资金、电力、部队与用时，右侧为速度、暂停与菜单。
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
    final powerShort = used > produced;
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
                      color: const Color(0xFFD9A94B),
                      compact: compact,
                    ),
                    const SizedBox(width: 6),
                    _StatChip(
                      glyph: '电',
                      value: '$used/$produced',
                      label: '电力',
                      color: powerShort
                          ? const Color(0xFFE0755F)
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
                        color: const Color(0xFFAFA595),
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
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF4EAD6),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
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
              Icon(icon, size: 16, color: const Color(0xFFF4EAD6)),
              if (label != null) ...[
                const SizedBox(width: 2),
                Text(
                  label!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF4EAD6),
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

/// 选中信息 / 建造放置提示条，悬浮在建造栏上方。
class SelectionStrip extends StatelessWidget {
  const SelectionStrip({super.key, required this.controller});

  final BattleController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isPlacing) return _PlacementBanner(controller: controller);
    final selection = controller.selection;
    if (selection == null) {
      if (controller.state.elapsed > 40) return const SizedBox.shrink();
      return const _Tip(
        text: '点选部队后点击地面移动，点击敌军或建筑发起攻击',
      );
    }
    return _SelectionCard(controller: controller, info: selection);
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC15140F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33EFE2C8)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11.5, color: Color(0xFFC9BDA9)),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({required this.controller, required this.info});

  final BattleController controller;
  final SelectionInfo info;

  @override
  Widget build(BuildContext context) {
    final isOwn = info.team == playerTeam;
    final canCommand = controller.canCommandSelection;
    return Container(
      constraints: const BoxConstraints(maxWidth: 430),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0xE6191815),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x44EFE2C8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: info.team.color.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: info.team.color.withValues(alpha: 0.7)),
            ),
            alignment: Alignment.center,
            child: Text(
              info.icon,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF4EAD6),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        info.count > 1
                            ? '${info.name} ×${info.count}'
                            : info.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF4EAD6),
                        ),
                      ),
                    ),
                    if (!isOwn) ...[
                      const SizedBox(width: 4),
                      Text(
                        '敌军',
                        style: TextStyle(
                          fontSize: 10,
                          color: info.team.color,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: 110,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: info.hpRatio,
                      minHeight: 5,
                      backgroundColor: const Color(0x55201812),
                      valueColor: AlwaysStoppedAnimation(info.team.color),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (canCommand) ...[
            const SizedBox(width: 6),
            _MiniAction(
              icon: Icons.pan_tool_alt,
              label: '停止',
              onTap: controller.stopSelected,
            ),
            _MiniAction(
              icon: Icons.select_all,
              label: '全选',
              onTap: controller.selectAllSameKind,
            ),
            _MiniAction(
              icon: Icons.center_focus_strong,
              label: '定位',
              onTap: controller.focusSelection,
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFFD9CBB4)),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: Color(0xFFB3A794)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacementBanner extends StatelessWidget {
  const _PlacementBanner({required this.controller});

  final BattleController controller;

  @override
  Widget build(BuildContext context) {
    final spec = controller.placingSpec;
    if (spec == null) return const SizedBox.shrink();
    final valid = controller.ghostValid;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: const Color(0xE61B1815),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: valid ? const Color(0xAA6FCF7A) : const Color(0xAAE0604F),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            valid ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: valid ? const Color(0xFF8AD694) : const Color(0xFFE0806F),
          ),
          const SizedBox(width: 6),
          Text(
            '放置 ${spec.kind.label}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF4EAD6),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            valid ? '点击地图确认' : '靠近己方建筑的空地',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFFAFA393)),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: controller.cancelPlacement,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 28),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: const Color(0xFFD9CBB4),
            ),
            child: const Text('取消', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

/// 战场浮动提示，最多同时显示三条。
class ToastStack extends StatelessWidget {
  const ToastStack({super.key, required this.controller});

  final BattleController controller;

  @override
  Widget build(BuildContext context) {
    final toasts = controller.toasts;
    if (toasts.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final toast in toasts)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _Toast(text: toast.text, level: toast.level),
          ),
      ],
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.text, required this.level});

  final String text;
  final NoticeLevel level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      NoticeLevel.info => const Color(0xFF9FB3C6),
      NoticeLevel.warning => const Color(0xFFE0806F),
      NoticeLevel.success => const Color(0xFF8AD694),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xE6141310),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFFEDE0CA)),
          ),
        ],
      ),
    );
  }
}
