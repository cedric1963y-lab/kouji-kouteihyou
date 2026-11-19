import 'days.dart';

/// Japanese national holidays (内閣府の現行ルール、2020年以降)。
/// 春分・秋分は近似式（1980〜2099年で有効）。
Map<String, String> japaneseHolidays(int year) {
  final h = <String, String>{};
  void fixed(int m, int d, String n) => h[dayKey(DateTime(year, m, d))] = n;
  DateTime nthMonday(int m, int n) {
    var d = DateTime(year, m, 1);
    while (d.weekday != DateTime.monday) {
      d = addDays(d, 1);
    }
    return addDays(d, 7 * (n - 1));
  }

  fixed(1, 1, '元日');
  h[dayKey(nthMonday(1, 2))] = '成人の日';
  fixed(2, 11, '建国記念の日');
  fixed(2, 23, '天皇誕生日');
  final y = year - 1980;
  final spring = (20.8431 + 0.242194 * y - (y ~/ 4)).floor();
  final autumn = (23.2488 + 0.242194 * y - (y ~/ 4)).floor();
  fixed(3, spring, '春分の日');
  fixed(4, 29, '昭和の日');
  fixed(5, 3, '憲法記念日');
  fixed(5, 4, 'みどりの日');
  fixed(5, 5, 'こどもの日');
  h[dayKey(nthMonday(7, 3))] = '海の日';
  fixed(8, 11, '山の日');
  h[dayKey(nthMonday(9, 3))] = '敬老の日';
  fixed(9, autumn, '秋分の日');
  h[dayKey(nthMonday(10, 2))] = 'スポーツの日';
  fixed(11, 3, '文化の日');
  fixed(11, 23, '勤労感謝の日');

  // 国民の休日: 祝日に挟まれた平日
  for (var d = DateTime(year, 1, 2); d.year == year; d = addDays(d, 1)) {
    final k = dayKey(d);
    if (h.containsKey(k) || d.weekday == DateTime.sunday) continue;
    if (h.containsKey(dayKey(addDays(d, -1))) &&
        h.containsKey(dayKey(addDays(d, 1)))) {
      h[k] = '国民の休日';
    }
  }
  // 振替休日: 日曜の祝日の次の、祝日でない日
  final base = Map<String, String>.from(h);
  for (final k in base.keys) {
    final d = parseDayKey(k);
    if (d.weekday != DateTime.sunday) continue;
    var n = addDays(d, 1);
    while (h.containsKey(dayKey(n))) {
      n = addDays(n, 1);
    }
    h[dayKey(n)] = '振替休日';
  }
  return h;
}

final _cache = <int, Map<String, String>>{};
String? holidayName(DateTime d) =>
    (_cache[d.year] ??= japaneseHolidays(d.year))[dayKey(d)];
