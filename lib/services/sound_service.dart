import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'log_service.dart';
import 'tone_synth.dart';

/// 战场反馈类型，决定提示音与震动的强弱。
enum BattleFeedback { select, command, build, ready, fire, explosion, harvest, victory, defeat }

/// 战场音效与触感反馈，音效全部在运行时合成，三端共用一套实现。
class SoundService {
  SoundService._();

  static bool soundEnabled = true;
  static bool hapticsEnabled = true;

  /// 测试注入的音频出口，非空时不再触碰平台播放器。
  @visibleForTesting
  static void Function(BattleFeedback feedback)? sink;

  static final Map<BattleFeedback, AudioSource> _sources = {};
  static final Map<BattleFeedback, Uint8List> _clips = {};
  static Future<void>? _loading;
  static bool _loadFailed = false;

  /// 各反馈的乐音配方：选中清脆、开火短促、爆炸低沉、胜利上行。
  static const Map<BattleFeedback, List<SynthNote>> _presets = {
    BattleFeedback.select: [
      SynthNote(frequency: 1320, start: 0, duration: 0.05, gain: 0.4),
      SynthNote(frequency: 1760, start: 0.03, duration: 0.06, gain: 0.3),
    ],
    BattleFeedback.command: [
      SynthNote(frequency: 880, start: 0, duration: 0.06, gain: 0.42),
      SynthNote(frequency: 660, start: 0.05, duration: 0.08, gain: 0.3),
    ],
    BattleFeedback.build: [
      SynthNote(frequency: 220, start: 0, duration: 0.16, gain: 0.6, noise: 0.2),
      SynthNote(frequency: 330, start: 0.08, duration: 0.2, gain: 0.4),
      SynthNote(frequency: 494, start: 0.16, duration: 0.22, gain: 0.35),
    ],
    BattleFeedback.ready: [
      SynthNote(frequency: 587, start: 0, duration: 0.09, gain: 0.4),
      SynthNote(frequency: 784, start: 0.09, duration: 0.1, gain: 0.4),
      SynthNote(frequency: 1046, start: 0.18, duration: 0.16, gain: 0.38),
    ],
    BattleFeedback.fire: [
      SynthNote(frequency: 720, start: 0, duration: 0.045, gain: 0.4, noise: 0.75, decay: 6),
      SynthNote(frequency: 180, start: 0, duration: 0.08, noise: 0.3),
    ],
    BattleFeedback.explosion: [
      SynthNote(frequency: 120, start: 0, duration: 0.22, gain: 0.7, noise: 0.85, decay: 4),
      SynthNote(frequency: 62, start: 0.02, duration: 0.34, gain: 0.75, noise: 0.5, decay: 3),
      SynthNote(frequency: 240, start: 0.01, duration: 0.14, gain: 0.3, noise: 0.6),
    ],
    BattleFeedback.harvest: [
      SynthNote(frequency: 392, start: 0, duration: 0.1, gain: 0.3),
      SynthNote(frequency: 523, start: 0.1, duration: 0.14, gain: 0.3),
    ],
    BattleFeedback.victory: [
      SynthNote(frequency: 392, start: 0, duration: 0.2, gain: 0.42),
      SynthNote(frequency: 494, start: 0.16, duration: 0.22, gain: 0.42),
      SynthNote(frequency: 587, start: 0.32, duration: 0.24, gain: 0.44),
      SynthNote(frequency: 784, start: 0.5, duration: 0.5, gain: 0.4),
    ],
    BattleFeedback.defeat: [
      SynthNote(frequency: 330, start: 0, duration: 0.2, gain: 0.42),
      SynthNote(frequency: 262, start: 0.2, duration: 0.24, gain: 0.42),
      SynthNote(frequency: 196, start: 0.44, duration: 0.5, gain: 0.38),
    ],
  };

  static void configure({required bool sound, required bool haptics}) {
    soundEnabled = sound;
    hapticsEnabled = haptics;
  }

  /// 预合成音效并载入 SoLoud 音源；失败时保持静默，不影响对局。
  static Future<void> init() => _ensureLoaded();

  static Future<void> _ensureLoaded() {
    if (_loadFailed || _sources.isNotEmpty) return Future.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) await soloud.init();
      for (final feedback in BattleFeedback.values) {
        _sources[feedback] = await soloud.loadMem(
          'redalert-${feedback.name}.wav',
          await compute(_renderClip, feedback.index),
        );
      }
    } catch (error) {
      _loadFailed = true;
      _disposeAll();
      debugPrint('[SoundService] 音效初始化失败，已静音: $error');
      LogService.warning('音效初始化失败，已静音: $error');
    }
  }

  /// 某个反馈对应的合成音频，供测试校验音效配方。
  @visibleForTesting
  static Uint8List clipOf(BattleFeedback feedback) =>
      _clips.putIfAbsent(feedback, () => synthesizeWav(_presets[feedback]!));

  static void play(BattleFeedback feedback) {
    if (soundEnabled) {
      final target = sink;
      if (target != null) {
        target(feedback);
      } else {
        unawaited(_play(feedback));
      }
    }
    if (!hapticsEnabled) return;
    final haptic = switch (feedback) {
      BattleFeedback.select => HapticFeedback.selectionClick,
      BattleFeedback.command => HapticFeedback.lightImpact,
      BattleFeedback.build => HapticFeedback.mediumImpact,
      BattleFeedback.ready => HapticFeedback.selectionClick,
      BattleFeedback.fire => HapticFeedback.lightImpact,
      BattleFeedback.explosion => HapticFeedback.mediumImpact,
      BattleFeedback.harvest => HapticFeedback.selectionClick,
      BattleFeedback.victory => HapticFeedback.heavyImpact,
      BattleFeedback.defeat => HapticFeedback.vibrate,
    };
    haptic();
  }

  static Future<void> _play(BattleFeedback feedback) async {
    try {
      await _ensureLoaded();
      final source = _sources[feedback];
      if (source == null) return;
      final soloud = SoLoud.instance;
      soloud.stopAudioSource(source);
      soloud.play(source);
    } catch (error) {
      debugPrint('[SoundService] 播放失败: $error');
    }
  }

  static void _disposeAll() {
    final sources = _sources.values.toList();
    _sources.clear();
    for (final source in sources) {
      unawaited(_dispose(source));
    }
  }

  static Future<void> _dispose(AudioSource source) async {
    try {
      await SoLoud.instance.disposeSource(source);
    } catch (_) {
      // 音源已失效时无需再处理。
    }
  }

  @visibleForTesting
  static void reset() {
    sink = null;
    _disposeAll();
    _clips.clear();
    _loading = null;
    _loadFailed = false;
    soundEnabled = true;
    hapticsEnabled = true;
  }
}

/// 在后台 isolate 渲染单个音效，避免启动时在主线程一次性合成全部音频。
Uint8List _renderClip(int index) =>
    synthesizeWav(SoundService._presets[BattleFeedback.values[index]]!);
