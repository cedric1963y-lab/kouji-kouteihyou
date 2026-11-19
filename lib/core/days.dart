/// Date-only helpers. Every date in the app is a local midnight DateTime.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime parseDayKey(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

const weekdayJa = ['月', '火', '水', '木', '金', '土', '日'];
String wd(DateTime d) => weekdayJa[d.weekday - 1];

/// 11/24(火)
String md(DateTime d) => '${d.month}/${d.day}(${wd(d)})';

/// 24日（火）
String dayJa(DateTime d) => '${d.day}日（${wd(d)}）';
