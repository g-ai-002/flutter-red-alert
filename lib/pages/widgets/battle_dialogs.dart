import 'package:flutter/material.dart';

import '../../game/battle_controller.dart';
import '../../game/battle_types.dart';
import '../../theme/palette.dart';

/// 对局结算：胜利或失败、用时与操作按钮。
Future<void> showBattleResultDialog(
  BuildContext context, {
  required BattleResult result,
  required String elapsed,
  required String difficulty,
  required VoidCallback onRestart,
  required VoidCallback onHome,
}) {
  final victory = result == BattleResult.victory;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      backgroundColor: const Color(0xFF1B1915),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x55D9A94B)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (victory ? appGold : appRed).withValues(alpha: 0.16),
                  border: Border.all(
                    color: victory ? const Color(0xFFD9A94B) : appRed,
                  ),
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
                  color: Color(0xFFF4EAD6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                victory ? '蓝军基地已被彻底摧毁，黎明属于赤军。' : '赤军基地失守，整顿旗鼓再来一次。',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB7AA97)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _ResultStat(label: '难度', value: difficulty),
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
                        foregroundColor: const Color(0xFFD9CBB4),
                        side: const BorderSide(color: Color(0x55584F41)),
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
        ),
      ),
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
          color: const Color(0xFF232019),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x334F483C)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF9C9180)),
            ),
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
    builder: (context) => Dialog(
      backgroundColor: const Color(0xFF1B1915),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x44D9A94B)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '暂停',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: Color(0xFFF4EAD6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${state.difficulty.label} · ${controller.elapsedText}'
                ' · 资金 ${state.creditsOf(playerTeam)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFAFA393)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    controller.setPaused(false);
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: appRed,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('继续战斗'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onGuide,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD9CBB4),
                    side: const BorderSide(color: Color(0x55584F41)),
                  ),
                  child: const Text('玩法说明'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onRestart,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD9CBB4),
                    side: const BorderSide(color: Color(0x55584F41)),
                  ),
                  child: const Text('重新开始'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onHome,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB7AA97),
                  ),
                  child: const Text('返回主菜单'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
