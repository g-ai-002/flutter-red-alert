import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/battle_types.dart';
import '../providers/settings_provider.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/navigation.dart';
import 'battle_page.dart';
import 'campaign_page.dart';
import 'guide_page.dart';
import 'settings_page.dart';
import 'widgets/war_room_background.dart';

/// 主菜单：标题、战役难度、开始按钮与战绩概览。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final stats = settings.stats;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.4, -0.7),
            radius: 1.4,
            colors: [Color(0xFF3A1D15), Color(0xFF1A1512), Color(0xFF0E0D0B)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: WarRoomPainter())),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 20, vertical: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: wide
                            ? Row(
                                children: [
                                  const Expanded(child: _Intro(wide: true)),
                                  const SizedBox(width: 40),
                                  SizedBox(
                                    width: 380,
                                    child: _CommandPanel(settings: settings, stats: stats),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const _Intro(wide: false),
                                  const SizedBox(height: 20),
                                  _CommandPanel(settings: settings, stats: stats),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: appRed.withValues(alpha: 0.16),
                border: Border.all(color: appRed.withValues(alpha: 0.7)),
              ),
              child: const Icon(Icons.star, size: 16, color: appRed),
            ),
            const SizedBox(width: 8),
            const Text(
              AppConstants.tagline,
              style: TextStyle(fontSize: 12, letterSpacing: 4, color: hudBronze),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          AppConstants.appName,
          style: TextStyle(
            fontSize: wide ? 56 : 42,
            fontWeight: FontWeight.w800,
            letterSpacing: wide ? 10 : 8,
            color: const Color(0xFFF6EDDC),
            shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 18, offset: Offset(0, 4))],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: wide ? 460 : 340,
          child: Text(
            '开采矿石、建设基地、训练装甲集群。'
            '在中国边境的荒原上，指挥赤军摧毁蓝军的前哨与指挥中心。',
            textAlign: wide ? TextAlign.left : TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.7, color: hudTextWarm),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _tag(Icons.engineering, '建造基地'),
            _tag(Icons.local_shipping, '采矿经济'),
            _tag(Icons.shield_moon, '装甲集群'),
            _tag(Icons.rocket_launch, '战略打击'),
          ],
        ),
      ],
    );
  }
}

Widget _tag(IconData icon, String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0x55161410),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x33C8A97A)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: hudBronze),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 11.5, color: Color(0xFFCFC3B0))),
      ],
    ),
  );
}

class _CommandPanel extends StatelessWidget {
  const _CommandPanel({required this.settings, required this.stats});

  final SettingsProvider settings;
  final BattleStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xE6191714),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hudBorderGold),
        boxShadow: const [BoxShadow(color: hudShadow, blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '战役难度',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: hudBronze,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final difficulty in BattleDifficulty.values) ...[
                Expanded(
                  child: _difficultyButton(
                    difficulty,
                    settings.difficulty == difficulty,
                    () => settings.setDifficulty(difficulty),
                  ),
                ),
                if (difficulty != BattleDifficulty.values.last) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            settings.difficulty.description,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9C9180)),
          ),
          const SizedBox(height: 16),
          _startRow(context, settings.difficulty),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => pushPage(context, const GuidePage()),
                  icon: const Icon(Icons.menu_book, size: 16),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: hudTextSoft,
                    side: const BorderSide(color: hudBorderDeep),
                    minimumSize: const Size(0, 40),
                  ),
                  label: const Text('玩法说明'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                height: 40,
                child: OutlinedButton(
                  onPressed: () => pushPage(context, const SettingsPage()),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: hudTextSoft,
                    side: const BorderSide(color: hudBorderDeep),
                  ),
                  child: const Icon(Icons.settings, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: hudBorderSoft, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              _stat('胜场', '${stats.wins}'),
              _stat('负场', '${stats.losses}'),
              _stat('胜率', '${(stats.winRate * 100).round()}%'),
              _stat('最快', stats.bestSeconds == null ? '—' : formatDuration(stats.bestSeconds!)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '${AppConstants.appName} v${AppConstants.version} · 本地单机，无需联网',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Color(0xFF6E6558)),
          ),
        ],
      ),
    );
  }
}

Widget _difficultyButton(BattleDifficulty difficulty, bool selected, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: selected ? const Color(0xCC8E241B) : hudPanelAlt,
        border: Border.all(color: selected ? hudGoldBright : const Color(0x44584F41)),
      ),
      child: Text(
        difficulty.label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? const Color(0xFFFFF2DC) : hudTextWarm,
        ),
      ),
    ),
  );
}

Widget _startRow(BuildContext context, BattleDifficulty difficulty) {
  return SizedBox(
    height: 54,
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: FilledButton(
            onPressed: () {
              SoundService.play(BattleFeedback.command);
              pushPage(context, const CampaignPage());
            },
            style: FilledButton.styleFrom(
              backgroundColor: appRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, size: 24),
                SizedBox(width: 4),
                Text(
                  '开始战役',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 2),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: OutlinedButton(
            onPressed: () {
              SoundService.play(BattleFeedback.command);
              pushPage(context, BattlePage(difficulty: difficulty));
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFF0E2CA),
              side: const BorderSide(color: Color(0x88D9A94B)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.zero,
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '遭遇战',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
                Text('自由对战', style: TextStyle(fontSize: 9, color: hudTextWarm)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _stat(String label, String value) {
  return Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFFEDE0CA),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: hudTextDim)),
      ],
    ),
  );
}
