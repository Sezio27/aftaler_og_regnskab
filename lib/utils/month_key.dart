class MonthKey {
  final int y, m;
  const MonthKey(this.y, this.m);
  @override
  bool operator ==(Object other) =>
      other is MonthKey && other.y == y && other.m == m;
  @override
  int get hashCode => Object.hash(y, m);
  @override
  String toString() => '$MonthKey($y-$m)';
}

class MonthRange {
  final DateTime start;
  final DateTime endInclusive;
  const MonthRange({required this.start, required this.endInclusive});
}
