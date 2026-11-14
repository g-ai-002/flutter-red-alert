import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/mission.dart';
import '../providers/settings_provider.dart';
import '../services/sound_service.dart';
import '../theme/palette.dart';
import '../utils/navigation.dart';
import 'battle_page.dart';

/// 战役列表：按顺序解锁五关，展示目标、难度与通关状态。
class CampaignPage extends StatelessWidget {
  const CampaignPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final completed = campaignMissions
        .where((mission) => settings.isMissionCompleted(mission.id))
        .length;
    return Scaffold(
      backgroundColor: const Color(0xFF12110E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1814),
        surfaceTintColor: Colors.transparent,
        title: const Text('战役模式', style: TextStyle(fontSize: 17, letterSpacing: 3)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '已通关 $completed/${campaignMissions.length}',
                style: const TextStyle(fontSize: 12, color: hudBronze),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: campaignMissions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final mission = campaignMissions[index];
                return _MissionCard(
                  index: index,
                  mission: mission,
                  completed: settings.isMissionCompleted(mission.id),
                  unlocked: settings.isMissionUnlocked(mission),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.index,
    required this.mission,
    required this.completed,
    required this.unlocked,
  });

  final int index;
  final GameMission mission;
  final bool completed;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final accent = completed
        ? hudSuccess
        : unlocked
        ? hudGoldBright
        : const Color(0xFF6E6558);
    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: InkWell(
        onTap: unlocked ? () => _start(context) : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xF21B1915),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: accent.withValues(alpha: 0.6)),
                    ),
                    child: Icon(
                      completed
                          ? Icons.check
                          : unlocked
                          ? Icons.flag
                          : Icons.lock,
                      size: 18,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mission.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: hudText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mission.subtitle,
                          style: const TextStyle(fontSize: 11, color: hudTextMuted),
                        ),
                      ],
                    ),
                  ),
                  _Chip(text: mission.objective.label, color: accent),
                  const SizedBox(width: 6),
                  _Chip(text: mission.difficulty.label, color: const Color(0xFF9FB3C6)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                mission.brief,
                style: const TextStyle(fontSize: 12, height: 1.6, color: Color(0xFFC4B8A4)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.track_changes, size: 14, color: hudBronze),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      mission.objectiveText,
                      style: const TextStyle(fontSize: 11.5, color: hudTextSoft),
                    ),
                  ),
                  Text(
                    completed
                        ? '已通关 · 可再战'
                        : unlocked
                        ? '点击出击'
                        : '通关上一关后解锁',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accent),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _start(BuildContext context) {
    SoundService.play(BattleFeedback.command);
    pushPage(context, BattlePage(difficulty: mission.difficulty, mission: mission));
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}
