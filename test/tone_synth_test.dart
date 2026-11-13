import 'dart:typed_data';

import 'package:flutter_red_alert/services/tone_synth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('合成音效是合法的 16 位单声道 WAV', () {
    final wav = synthesizeWav(const [
      SynthNote(frequency: 880, start: 0, duration: 0.08),
    ]);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(wav.length, greaterThan(44));
    final data = ByteData.sublistView(wav);
    expect(data.getUint16(22, Endian.little), 1, reason: '单声道');
    expect(data.getUint16(34, Endian.little), 16, reason: '16 位采样');
  });

  test('背景音乐循环长度符合设定', () {
    final wav = synthesizeMusicWav();
    final data = ByteData.sublistView(wav);
    final sampleRate = data.getUint32(24, Endian.little);
    final dataSize = data.getUint32(40, Endian.little);
    expect(sampleRate, kMusicSampleRate);
    expect(dataSize / 2 / sampleRate, closeTo(kMusicLoopSeconds, 0.05));
  });
}
