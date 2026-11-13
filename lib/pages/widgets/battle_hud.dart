import 'package:flutter/material.dart';

import '../../game/battle_controller.dart';
import '../../game/battle_state.dart';
import '../../game/battle_types.dart';
import '../../theme/palette.dart';

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
      return const _Tip(text: '点选部队后点击地面移动，点击敌军或建筑发起攻击');
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
      child: Text(text, style: const TextStyle(fontSize: 11.5, color: Color(0xFFC9BDA9))),
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
        color: hudPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hudBorder),
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: hudText),
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
                        info.count > 1 ? '${info.name} ×${info.count}' : info.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: hudText,
                        ),
                      ),
                    ),
                    if (!isOwn) ...[
                      const SizedBox(width: 4),
                      Text('敌军', style: TextStyle(fontSize: 10, color: info.team.color)),
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
            _MiniAction(icon: Icons.pan_tool_alt, label: '停止', onTap: controller.stopSelected),
            _MiniAction(icon: Icons.select_all, label: '全选', onTap: controller.selectAllSameKind),
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
  const _MiniAction({required this.icon, required this.label, required this.onTap});

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
            Icon(icon, size: 15, color: hudTextSoft),
            Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFFB3A794))),
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
        color: hudPanelSolid.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: valid ? const Color(0xAA6FCF7A) : const Color(0xAAE0604F)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            valid ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: valid ? hudSuccess : hudWarning,
          ),
          const SizedBox(width: 6),
          Text(
            '放置 ${spec.kind.label}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hudText),
          ),
          const SizedBox(width: 6),
          Text(
            valid ? '点击地图确认' : '靠近己方建筑的空地',
            style: const TextStyle(fontSize: 10.5, color: hudTextMuted),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: controller.cancelPlacement,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 28),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: hudTextSoft,
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
      NoticeLevel.info => hudInfo,
      NoticeLevel.warning => hudWarning,
      NoticeLevel.success => hudSuccess,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: hudPanelDeep,
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
          Text(text, style: const TextStyle(fontSize: 11.5, color: Color(0xFFEDE0CA))),
        ],
      ),
    );
  }
}
