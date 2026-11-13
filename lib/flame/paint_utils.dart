import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 明暗调整：正值提亮、负值压暗，地形与载具共用。
Color shadeColor(Color color, double amount) {
  if (amount >= 0) return Color.lerp(color, Colors.white, amount)!;
  return Color.lerp(color, Colors.black, -amount)!;
}

/// 稳定的伪随机噪声，保证同一格在每次重绘时纹理一致。
double hashNoise(int x, int y) {
  final value = math.sin(x * 12.9898 + y * 78.233) * 43758.5453;
  return value - value.floor();
}
