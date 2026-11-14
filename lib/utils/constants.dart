/// 界面共用的中文字体回退链：优先军事风格的思源系列，其次各平台常见字体。
const List<String> kCjkFontFallback = [
  'Microsoft YaHei UI',
  'PingFang SC',
  'Noto Sans CJK SC',
  'Noto Sans SC',
  'Source Han Sans CN',
];

/// Web 端字体：CanvasKit 没有系统中文字体回退，使用 soup_fonts 的思源黑体。
const String kWebFontFamily = 'SourceHanSansCN';

class AppConstants {
  AppConstants._();

  static const String appName = '赤色黎明';
  static const String version = '0.5.1';
  static const String tagline = '单机即时战略';

  static const String prefKeyDarkMode = 'dark_mode';
  static const String prefKeySound = 'sound_enabled';
  static const String prefKeyMusic = 'music_enabled';
  static const String prefKeyHaptics = 'haptics_enabled';
  static const String prefKeyLogicRate = 'logic_rate';
  static const String prefKeyDifficulty = 'battle_difficulty';
  static const String prefKeyWins = 'stats_wins';
  static const String prefKeyLosses = 'stats_losses';
  static const String prefKeyBestSeconds = 'stats_best_seconds';
  static const String prefKeyCampaign = 'campaign_completed';
}
