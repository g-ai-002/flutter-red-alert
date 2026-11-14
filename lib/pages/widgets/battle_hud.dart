import 'package:material_ui/material_ui.dart';

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
    if (controller.strikeAiming) {
      return _Banner(
        icon: Icons.rocket_launch,
        color: hudWarning,
        title: '战略打击',
        hint: '点击地图选择打击区域，杀伤半径 4.2 格',
        onCancel: controller.cancelStrikeAim,
      );
    }
    if (controller.isPlacing) return _PlacementBanner(controller: controller);
    final selection = controller.selection;
    if (selection == null) {
      if (controller.state.elapsed > 40) return const SizedBox.shrink();
      return _tip('点选部队后点击地面移动，点击敌军或建筑发起攻击');
    }
    return _SelectionCard(controller: controller, info: selection);
  }
}

Widget _tip(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xCC15140F),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: hudBorderFaint),
    ),
    child: Text(text, style: const TextStyle(fontSize: 11.5, color: Color(0xFFC9BDA9))),
  );
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
                  child: LinearProgressIndicator(
                    value: info.hpRatio,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(3),
                    color: info.team.color,
                    backgroundColor: const Color(0x55201812),
                  ),
                ),
              ],
            ),
          ),
          if (canCommand) ...[
            const SizedBox(width: 6),
            _miniAction(Icons.pan_tool_alt, '停止', controller.stopSelected),
            _miniAction(Icons.select_all, '全选', controller.selectAllSameKind),
            _miniAction(Icons.center_focus_strong, '定位', controller.focusSelection),
          ],
        ],
      ),
    );
  }
}

Widget _miniAction(IconData icon, String label, VoidCallback onTap) {
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

class _PlacementBanner extends StatelessWidget {
  const _PlacementBanner({required this.controller});

  final BattleController controller;

  @override
  Widget build(BuildContext context) {
    final spec = controller.placingSpec;
    if (spec == null) return const SizedBox.shrink();
    final valid = controller.ghostValid;
    return _Banner(
      icon: valid ? Icons.check_circle_outline : Icons.error_outline,
      color: valid ? hudSuccess : hudWarning,
      title: '放置 ${spec.kind.label}',
      hint: valid ? '点击地图确认' : '靠近己方建筑的空地',
      onCancel: controller.cancelPlacement,
    );
  }
}

/// 放置与战略打击共用的操作提示条。
class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.title,
    required this.hint,
    required this.onCancel,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String hint;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: hudPanelSolid.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.67)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hudText),
          ),
          const SizedBox(width: 6),
          Text(hint, style: const TextStyle(fontSize: 10.5, color: hudTextMuted)),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onCancel,
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
            child: _toast(toast.text, toast.level),
          ),
      ],
    );
  }
}

Widget _toast(String text, NoticeLevel level) {
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
