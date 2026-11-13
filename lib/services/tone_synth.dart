import 'dart:math' as math;
import 'dart:typed_data';

/// 音效采样率：短促提示音用 22.05 kHz 足够，数据量约为 44.1 kHz 的一半。
const int kSynthSampleRate = 22050;

/// 单枚乐音：正弦基频叠加二、三次谐波，可混入噪声模拟金属与爆裂质感。
class SynthNote {
  const SynthNote({
    required this.frequency,
    required this.start,
    required this.duration,
    this.gain = 0.5,
    this.noise = 0,
    this.decay = 3.2,
  });

  /// 基频（Hz）。
  final double frequency;

  /// 相对整段音效的起始时间（秒）。
  final double start;

  /// 持续时长（秒）。
  final double duration;

  /// 音量，0 到 1。
  final double gain;

  /// 混入的噪声比例，用于表现爆炸与枪声。
  final double noise;

  /// 指数衰减速度，越大收得越快。
  final double decay;
}

/// 纯 Dart 音效合成：把若干乐音渲染成 16 位单声道 WAV 字节。
///
/// 音效全部在运行时生成，代码仓库与安装包都不携带音频文件。
Uint8List synthesizeWav(
  List<SynthNote> notes, {
  int sampleRate = kSynthSampleRate,
}) {
  const tailSeconds = 0.04;
  final seconds = notes.fold<double>(
    0,
    (longest, note) => math.max(longest, note.start + note.duration),
  );
  final totalSamples = ((seconds + tailSeconds) * sampleRate).round();
  final mix = Float64List(totalSamples);
  final random = math.Random(20261114);

  for (final note in notes) {
    final offset = (note.start * sampleRate).round();
    final count = (note.duration * sampleRate).round();
    final attack = math.max(1, (0.003 * sampleRate).round());
    final release = math.max(1, (0.006 * sampleRate).round());
    final gain = note.gain / 1.44;
    for (var i = 0; i < count; i++) {
      final index = offset + i;
      if (index >= totalSamples) break;
      final progress = i / count;
      final envelope =
          math.min(1, i / attack) *
          math.min(1, (count - i) / release) *
          math.exp(-note.decay * progress);
      final phase = 2 * math.pi * note.frequency * (i / sampleRate);
      final tone =
          math.sin(phase) +
          0.32 * math.sin(2 * phase) +
          0.12 * math.sin(3 * phase);
      final hit = note.noise * (random.nextDouble() * 2 - 1);
      mix[index] += envelope * (tone * gain + hit);
    }
  }

  return _encodePcm(mix, sampleRate);
}

/// 背景音乐采样率与循环长度：军鼓行进 + 五声音阶号角，16 秒一循环。
const int kMusicSampleRate = 16000;
const double kMusicLoopSeconds = 16;

class _PluckNote {
  const _PluckNote({
    required this.start,
    required this.frequency,
    required this.duration,
    this.gain = 0.4,
    this.damp = 1.2,
    this.bright = 0.42,
  });

  final double start;
  final double frequency;
  final double duration;
  final double gain;
  final double damp;
  final double bright;
}

class _DrumHit {
  const _DrumHit({
    required this.start,
    this.gain = 0.5,
    this.noise = 0.5,
    this.tone = 120,
    this.length = 0.18,
  });

  final double start;
  final double gain;
  final double noise;
  final double tone;
  final double length;
}

/// 低音铺底与号角旋律，全部为相对循环起点的秒数。
const List<_PluckNote> _musicNotes = [
  // 低音鼓点式的根音
  _PluckNote(start: 0, frequency: 73.42, duration: 3.8, gain: 0.5, damp: 0.7),
  _PluckNote(start: 4, frequency: 73.42, duration: 3.8, gain: 0.44, damp: 0.7),
  _PluckNote(start: 8, frequency: 87.31, duration: 3.8, gain: 0.5, damp: 0.7),
  _PluckNote(start: 12, frequency: 65.41, duration: 3.8, gain: 0.5, damp: 0.7),
  _PluckNote(start: 0, frequency: 146.83, duration: 3.6, gain: 0.22, damp: 0.5),
  _PluckNote(start: 8, frequency: 174.61, duration: 3.6, gain: 0.22, damp: 0.5),
  // 号角主题
  _PluckNote(start: 0.0, frequency: 293.66, duration: 0.9, gain: 0.42, bright: 0.6),
  _PluckNote(start: 0.9, frequency: 349.23, duration: 0.9, gain: 0.42, bright: 0.6),
  _PluckNote(start: 1.8, frequency: 440.00, duration: 1.6, gain: 0.46, bright: 0.6),
  _PluckNote(start: 3.5, frequency: 392.00, duration: 0.8, gain: 0.38, bright: 0.6),
  _PluckNote(start: 4.3, frequency: 349.23, duration: 0.8, gain: 0.36, bright: 0.6),
  _PluckNote(start: 5.1, frequency: 293.66, duration: 1.8, gain: 0.42, bright: 0.6),
  _PluckNote(start: 7.0, frequency: 261.63, duration: 0.9, gain: 0.36, bright: 0.6),
  _PluckNote(start: 7.9, frequency: 293.66, duration: 1.6, gain: 0.4, bright: 0.6),
  _PluckNote(start: 9.8, frequency: 349.23, duration: 0.9, gain: 0.42, bright: 0.6),
  _PluckNote(start: 10.7, frequency: 440.00, duration: 0.9, gain: 0.46, bright: 0.6),
  _PluckNote(start: 11.6, frequency: 523.25, duration: 1.8, gain: 0.5, bright: 0.6),
  _PluckNote(start: 13.6, frequency: 392.00, duration: 0.8, gain: 0.38, bright: 0.6),
  _PluckNote(start: 14.4, frequency: 349.23, duration: 1.4, gain: 0.4, bright: 0.6),
];

/// 军鼓与底鼓的行进节奏。
const List<_DrumHit> _drumHits = [
  _DrumHit(start: 0, gain: 0.55, noise: 0.28, tone: 92, length: 0.26),
  _DrumHit(start: 1.0, gain: 0.22, noise: 0.5, tone: 190, length: 0.1),
  _DrumHit(start: 2.0, gain: 0.4, noise: 0.34, tone: 110, length: 0.2),
  _DrumHit(start: 2.5, gain: 0.24, noise: 0.5, tone: 200, length: 0.1),
  _DrumHit(start: 3.0, gain: 0.34, noise: 0.4, tone: 130, length: 0.16),
  _DrumHit(start: 4.0, gain: 0.55, noise: 0.28, tone: 92, length: 0.26),
  _DrumHit(start: 5.0, gain: 0.22, noise: 0.5, tone: 190, length: 0.1),
  _DrumHit(start: 6.0, gain: 0.4, noise: 0.34, tone: 110, length: 0.2),
  _DrumHit(start: 6.5, gain: 0.24, noise: 0.5, tone: 200, length: 0.1),
  _DrumHit(start: 7.0, gain: 0.34, noise: 0.4, tone: 130, length: 0.16),
  _DrumHit(start: 8.0, gain: 0.55, noise: 0.28, tone: 92, length: 0.26),
  _DrumHit(start: 9.0, gain: 0.22, noise: 0.5, tone: 190, length: 0.1),
  _DrumHit(start: 10.0, gain: 0.4, noise: 0.34, tone: 110, length: 0.2),
  _DrumHit(start: 10.5, gain: 0.24, noise: 0.5, tone: 200, length: 0.1),
  _DrumHit(start: 11.0, gain: 0.34, noise: 0.4, tone: 130, length: 0.16),
  _DrumHit(start: 12.0, gain: 0.55, noise: 0.28, tone: 92, length: 0.26),
  _DrumHit(start: 13.0, gain: 0.22, noise: 0.5, tone: 190, length: 0.1),
  _DrumHit(start: 14.0, gain: 0.4, noise: 0.34, tone: 110, length: 0.2),
  _DrumHit(start: 14.5, gain: 0.24, noise: 0.5, tone: 200, length: 0.1),
  _DrumHit(start: 15.0, gain: 0.42, noise: 0.42, tone: 120, length: 0.22),
];

/// 合成背景音乐：号角旋律叠加低音与军鼓，首尾淡入淡出后无缝循环。
Uint8List synthesizeMusicWav({int sampleRate = kMusicSampleRate}) {
  final totalSamples = (kMusicLoopSeconds * sampleRate).round();
  final mix = Float64List(totalSamples);
  final random = math.Random(20261105);

  for (final note in _musicNotes) {
    final offset = (note.start * sampleRate).round();
    final count = math.min(
      (note.duration * sampleRate).round(),
      totalSamples - offset,
    );
    if (count <= 0) continue;
    final attack = math.max(1, (0.004 * sampleRate).round());
    for (var i = 0; i < count; i++) {
      final time = i / sampleRate;
      final envelope = math.min(1, i / attack) * math.exp(-note.damp * time);
      final phase = 2 * math.pi * note.frequency * time;
      final tone =
          math.sin(phase) +
          0.34 * math.sin(2.002 * phase) +
          0.14 * math.sin(3.006 * phase) +
          0.05 * math.sin(4.011 * phase);
      final pick = (random.nextDouble() * 2 - 1) * 0.16 * math.exp(-70 * time);
      mix[offset + i] += envelope * note.gain * (tone * note.bright + pick);
    }
  }

  for (final drum in _drumHits) {
    final offset = (drum.start * sampleRate).round();
    final count = math.min(
      (drum.length * sampleRate).round(),
      totalSamples - offset,
    );
    for (var i = 0; i < count; i++) {
      final time = i / sampleRate;
      final envelope = math.exp(-26 * time);
      final noise = (random.nextDouble() * 2 - 1) * drum.noise;
      final body = math.sin(2 * math.pi * drum.tone * time) * 0.6;
      mix[offset + i] += drum.gain * envelope * (noise + body);
    }
  }

  var peak = 0.0;
  for (final value in mix) {
    final magnitude = value.abs();
    if (magnitude > peak) peak = magnitude;
  }
  final scale = peak > 0 ? 0.78 / peak : 1.0;
  final edge = (0.025 * sampleRate).round();
  for (var i = 0; i < totalSamples; i++) {
    final fadeIn = i < edge ? i / edge : 1.0;
    final fadeOut = i >= totalSamples - edge ? (totalSamples - i) / edge : 1.0;
    mix[i] *= scale * fadeIn * fadeOut;
  }
  return _encodePcm(mix, sampleRate);
}

/// 把 [-1,1] 的浮点混音编码为 16 位单声道 WAV。
Uint8List _encodePcm(Float64List mix, int sampleRate) {
  final totalSamples = mix.length;
  final data = ByteData(44 + totalSamples * 2);
  _writeAscii(data, 0, 'RIFF');
  data.setUint32(4, 36 + totalSamples * 2, Endian.little);
  _writeAscii(data, 8, 'WAVE');
  _writeAscii(data, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  _writeAscii(data, 36, 'data');
  data.setUint32(40, totalSamples * 2, Endian.little);

  for (var i = 0; i < totalSamples; i++) {
    final sample = (mix[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(44 + i * 2, sample, Endian.little);
  }
  return data.buffer.asUint8List();
}

void _writeAscii(ByteData data, int offset, String text) {
  for (var i = 0; i < text.length; i++) {
    data.setUint8(offset + i, text.codeUnitAt(i));
  }
}
