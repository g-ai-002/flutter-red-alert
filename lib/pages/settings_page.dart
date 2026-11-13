import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/battle_types.dart';
import '../game/logic_rate.dart';
import '../providers/settings_provider.dart';
import '../services/file_system_service.dart';
import '../services/log_service.dart';
import '../utils/constants.dart';
import '../utils/platform_info.dart';

/// 设置：主题、音效、音乐、震动、逻辑刷新率、默认难度与日志。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _Group(
            title: '外观与声音',
            children: [
              SwitchListTile(
                title: const Text('深色模式'),
                subtitle: const Text('战场氛围更统一'),
                value: settings.darkMode,
                onChanged: settings.setDarkMode,
              ),
              SwitchListTile(
                title: const Text('音效'),
                subtitle: const Text('开火、爆炸、建造与提示音'),
                value: settings.soundEnabled,
                onChanged: settings.setSoundEnabled,
              ),
              SwitchListTile(
                title: const Text('背景音乐'),
                subtitle: const Text('运行时合成的军鼓行进曲'),
                value: settings.musicEnabled,
                onChanged: settings.setMusicEnabled,
              ),
              SwitchListTile(
                title: const Text('震动反馈'),
                subtitle: const Text('选择、建造与爆炸时轻微震动'),
                value: settings.hapticsEnabled,
                onChanged: settings.setHapticsEnabled,
              ),
            ],
          ),
          const SizedBox(height: 12),
          RadioGroup<LogicRate>(
            groupValue: settings.logicRate,
            onChanged: (value) {
              if (value != null) settings.setLogicRate(value);
            },
            child: _Group(
              title: '战场逻辑刷新率',
              children: [
                for (final rate in LogicRate.values)
                  RadioListTile<LogicRate>(
                    title: Text(rate.label),
                    subtitle: Text(_rateHint(rate)),
                    value: rate,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          RadioGroup<BattleDifficulty>(
            groupValue: settings.difficulty,
            onChanged: (value) {
              if (value != null) settings.setDifficulty(value);
            },
            child: _Group(
              title: '默认战役难度',
              children: [
                for (final difficulty in BattleDifficulty.values)
                  RadioListTile<BattleDifficulty>(
                    title: Text(difficulty.label),
                    subtitle: Text(difficulty.description),
                    value: difficulty,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Group(
            title: '日志',
            children: [
              ListTile(
                title: const Text('查看最近日志'),
                subtitle: const Text('出问题时把日志文件提供给开发者定位'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLogs(context),
              ),
              if (isDesktopPlatform)
                ListTile(
                  title: const Text('打开日志目录'),
                  trailing: const Icon(Icons.folder_open),
                  onTap: () async {
                    final path = await FileSystemService.instance.getLogRootPath();
                    final opened = await FileSystemService.instance.openDirectory(path);
                    if (!context.mounted) return;
                    if (!opened) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('无法打开目录：$path')));
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '${AppConstants.appName} v${AppConstants.version} · 本地单机',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF8B8172)),
          ),
        ],
      ),
    );
  }

  String _rateHint(LogicRate rate) {
    return switch (rate) {
      LogicRate.hz30 => '低功耗，适合老设备',
      LogicRate.hz60 => '默认，性能与顺滑度均衡',
      LogicRate.hz120 => '高刷屏更顺滑，耗电略高',
    };
  }

  Future<void> _showLogs(BuildContext context) async {
    final path = await FileSystemService.instance.getLogRootPath();
    final lines = LogService.getRecentLogs(300);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('最近日志'),
        content: SizedBox(
          width: 560,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (path.isNotEmpty) Text(path, style: const TextStyle(fontSize: 10)),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12110E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      lines.isEmpty ? '暂无日志' : lines.join('\n'),
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.5,
                        fontFamily: 'monospace',
                        color: Color(0xFFD9CBB4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('关闭')),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
