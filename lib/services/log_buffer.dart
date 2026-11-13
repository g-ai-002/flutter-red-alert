/// 定长环形日志缓冲：超过容量后丢弃最早一行。
///
/// IO 与 Web 日志共用这一份实现，避免两边各自维护截取逻辑。
class LogRingBuffer {
  LogRingBuffer(this.capacity) : assert(capacity > 0);

  final int capacity;
  final List<String> _lines = [];

  int get length => _lines.length;

  /// 按写入顺序返回当前日志行。
  List<String> get lines => List.unmodifiable(_lines);

  void add(String line) {
    _lines.add(line);
    if (_lines.length > capacity) _lines.removeAt(0);
  }

  /// 最近 [count] 行；不足时返回全部。
  List<String> recent(int count) {
    if (count <= 0) return const [];
    if (_lines.length <= count) return List.of(_lines);
    return _lines.sublist(_lines.length - count);
  }

  void clear() => _lines.clear();
}
