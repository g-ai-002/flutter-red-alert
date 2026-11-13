import 'package:flutter_red_alert/services/log_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('超过容量后丢弃最早的行', () {
    final buffer = LogRingBuffer(3);
    for (var i = 0; i < 5; i++) {
      buffer.add('line $i');
    }
    expect(buffer.length, 3);
    expect(buffer.lines, ['line 2', 'line 3', 'line 4']);
  });

  test('最近日志不足时返回全部', () {
    final buffer = LogRingBuffer(5)
      ..add('a')
      ..add('b');
    expect(buffer.recent(10), ['a', 'b']);
    expect(buffer.recent(1), ['b']);
    expect(buffer.recent(0), isEmpty);
  });

  test('清空后重新累计', () {
    final buffer = LogRingBuffer(2)
      ..add('a')
      ..add('b')
      ..add('c');
    buffer.clear();
    expect(buffer.length, 0);
    buffer.add('d');
    expect(buffer.recent(2), ['d']);
  });
}
