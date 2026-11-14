import 'package:flutter/material.dart';

import '../../game/battle_controller.dart';
import '../../game/battle_types.dart';
import '../../theme/palette.dart';

/// 对局结算：胜利或失败、用时与操作按钮。
Future<void> showBattleResultDialog(
  BuildContext context, {
  required BattleResult result,
  required String elapsed,
  required String mode,
  required VoidCallback onRestart,
  required VoidCallback onHome,
  String? note,
  String? message,
}) {
  final victory = result == BattleResult.victory;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _HudDialog(
      maxWidth: 360,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (victory ? appGold : appRed).withValues(alpha: 0.16),
            border: Border.all(color: victory ? hudGold : appRed),
          ),
          child: Icon(
            victory ? Icons.military_tech : Icons.local_fire_department,
            size: 30,
            color: victory ? appGold : appRed,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          victory ? '战斗胜利' : '战斗失败',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: hudText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message ?? (victory ? '蓝军基地已被彻底摧毁，黎明属于赤军。' : '赤军基地失守，整顿旗鼓再来一次。'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: hudTextWarm),
        ),
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(
            note,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: hudGoldBright,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            _ResultStat(label: '模式', value: mode),
            _ResultStat(label: '用时', value: elapsed),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onHome,
                style: OutlinedButton.styleFrom(
                  foregroundColor: hudTextSoft,
                  side: const BorderSide(color: hudBorderDeep),
                ),
                child: const Text('返回主菜单'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: onRestart,
                style: FilledButton.styleFrom(
                  backgroundColor: appRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('再战一次'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: hudPanelAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x334F483C)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9C9180))),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEDE0CA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 暂停菜单：继续、重新开始、返回主菜单与玩法说明。
Future<void> showPauseDialog(
  BuildContext context, {
  required BattleController controller,
  required VoidCallback onRestart,
  required VoidCallback onHome,
  required VoidCallback onGuide,
}) {
  final state = controller.state;
  return showDialog<void>(
    context: context,
    builder: (context) => _HudDialog(
      maxWidth: 340,
      children: [
        const Text(
          '暂停',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            color: hudText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${state.difficulty.label} · ${controller.elapsedText}'
          ' · 资金 ${state.creditsOf(playerTeam)}',
          style: const TextStyle(fontSize: 11, color: hudTextMuted),
        ),
        if (state.mission != null) ...[
          const SizedBox(height: 3),
          Text(
            '目标：${state.mission!.objectiveText}',
            style: const TextStyle(fontSize: 11, color: hudBronze),
          ),
        ],
        const SizedBox(height: 16),
        _PauseAction(
          label: '继续战斗',
          filled: true,
          onPressed: () {
            controller.setPaused(false);
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 8),
        _PauseAction(label: '玩法说明', onPressed: onGuide),
        const SizedBox(height: 8),
        _PauseAction(label: '重新开始', onPressed: onRestart),
        const SizedBox(height: 8),
        _PauseAction(label: '返回主菜单', text: true, onPressed: onHome),
      ],
    ),
  );
}

/// 结算与暂停共用的对话框骨架：深色面板、金色描边与统一内边距。
class _HudDialog extends StatelessWidget {
  const _HudDialog({required this.maxWidth, required this.children});

  final double maxWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: hudPanelSolid,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: hudBorderGold),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _PauseAction extends StatelessWidget {
  const _PauseAction({
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.text = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final bool text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: switch ((filled, text)) {
        (true, _) => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(backgroundColor: appRed, foregroundColor: Colors.white),
          child: Text(label),
        ),
        (_, true) => TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(foregroundColor: hudTextWarm),
          child: Text(label),
        ),
        _ => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: hudTextSoft,
            side: const BorderSide(color: hudBorderDeep),
          ),
          child: Text(label),
        ),
      },
    );
  }
}
