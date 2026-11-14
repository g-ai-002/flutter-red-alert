import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_red_alert/flame/effects.dart';
import 'package:flutter_red_alert/game/battle_state.dart';
import 'package:flutter_red_alert/game/battle_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('每种战场事件都有对应的特效参数', () {
    final effects = Effects();
    for (final kind in BattleEventKind.values) {
      effects.addEvent(BattleEvent(kind, 1, 2, tx: 3, ty: 4, team: Team.red, radius: 1.2));
    }
    expect(effects.activeCount, BattleEventKind.values.length);
  });

  test('特效按各自时长过期，clear 立即清空', () {
    final effects = Effects();
    effects.addEvent(const BattleEvent(BattleEventKind.bullet, 0, 0, tx: 1, ty: 1));
    effects.addEvent(const BattleEvent(BattleEventKind.unload, 0, 0));
    effects.update(0.2);
    expect(effects.activeCount, 1);
    effects.update(1);
    expect(effects.activeCount, 0);

    effects.addEvent(const BattleEvent(BattleEventKind.explosion, 0, 0));
    effects.clear();
    expect(effects.activeCount, 0);
  });

  test('全部特效可以正常绘制', () {
    final effects = Effects();
    for (final kind in BattleEventKind.values) {
      effects.addEvent(BattleEvent(kind, 2, 3, tx: 4, ty: 5, team: Team.blue, radius: 1.4));
    }
    final recorder = ui.PictureRecorder();
    effects.render(Canvas(recorder), 24);
    recorder.endRecording().dispose();
  });

  test('视野外的特效不参与绘制', () {
    final effects = Effects();
    effects.addEvent(const BattleEvent(BattleEventKind.explosion, 4, 30, radius: 1.2));
    effects.addEvent(const BattleEvent(BattleEventKind.bullet, 40, 4, tx: 42, ty: 6));
    effects.addEvent(const BattleEvent(BattleEventKind.bullet, 33, 2, tx: 40, ty: 2));

    final recorder = ui.PictureRecorder();
    effects.render(Canvas(recorder), 24, view: const Rect.fromLTWH(0, 25, 20, 15));
    recorder.endRecording().dispose();
    expect(effects.drawnCount, 1, reason: '只保留落在视口内的爆炸');
    expect(effects.activeCount, 3);

    final full = ui.PictureRecorder();
    effects.render(Canvas(full), 24);
    full.endRecording().dispose();
    expect(effects.drawnCount, 3, reason: '不传视野时保持原有全量绘制行为');
  });
}
