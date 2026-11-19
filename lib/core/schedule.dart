import 'days.dart';
import 'holidays.dart';
import 'models.dart';

/// 休みの判定。全体の休み + 現場ごとの止まった日（雨など）。
class WorkCalendar {
  WorkCalendar(this.settings, {this.site});
  final HolidaySettings settings;
  final Site? site;

  WorkCalendar forSite(Site s) => WorkCalendar(settings, site: s);

  /// 全体の休み（日曜・祝日・お盆など）の理由。稼働日なら null。
  String? offReason(DateTime d) {
    if (settings.extraOff.contains(dayKey(d))) return '休み';
    final sat = site?.saturdayWork != null
        ? !(site!.saturdayWork!)
        : settings.saturday;
    if (d.weekday == DateTime.sunday && settings.sunday) return '日曜';
    if (d.weekday == DateTime.saturday && sat) return '土曜';
    if (settings.nationalHolidays) {
      final h = holidayName(d);
      if (h != null) return h;
    }
    if (settings.obon && d.month == 8 && d.day >= 13 && d.day <= 16) {
      return 'お盆';
    }
    if (settings.newYear &&
        ((d.month == 12 && d.day >= 29) || (d.month == 1 && d.day <= 3))) {
      return '年末年始';
    }
    return null;
  }

  bool isStopped(DateTime d) =>
      site != null && site!.stopDayKeys.contains(dayKey(d));

  bool isWorkDay(DateTime d) => offReason(d) == null && !isStopped(d);

  /// d が休みなら次の稼働日へ
  DateTime snap(DateTime d) {
    var x = dayOf(d);
    for (var i = 0; i < 400 && !isWorkDay(x); i++) {
      x = addDays(x, 1);
    }
    return x;
  }

  /// 稼働日で n 日進める（負なら戻す）。n=0 は snap と同じ。
  DateTime addWorkDays(DateTime d, int n) {
    var x = dayOf(d);
    if (n == 0) return snap(x);
    final step = n > 0 ? 1 : -1;
    var left = n.abs();
    var guard = 0;
    while (left > 0 && guard++ < 2000) {
      x = addDays(x, step);
      if (isWorkDay(x)) left--;
    }
    return x;
  }

  /// 工程の最終日
  DateTime endOf(Task t) {
    final s = snap(t.start);
    if (t.isMilestone) return s;
    return addWorkDays(s, t.workDays - 1);
  }

  /// 工程が作業する日（稼働日だけ）
  List<DateTime> workDaysOf(Task t) {
    final out = <DateTime>[];
    var d = snap(t.start);
    final n = t.isMilestone ? 1 : t.workDays;
    for (var guard = 0; out.length < n && guard < 2000; guard++) {
      if (isWorkDay(d)) out.add(d);
      d = addDays(d, 1);
    }
    return out;
  }

  /// その日に作業がある工程
  bool occupies(Task t, DateTime d) {
    if (!isWorkDay(d)) return false;
    final s = snap(t.start);
    return !d.isBefore(s) && !d.isAfter(endOf(t));
  }
}

/// 現場の始まり・終わり
DateTime? siteStart(Site s, WorkCalendar cal) {
  final c = cal.forSite(s);
  DateTime? best;
  for (final t in s.tasks) {
    final d = c.snap(t.start);
    if (best == null || d.isBefore(best)) best = d;
  }
  return best;
}

DateTime? siteEnd(Site s, WorkCalendar cal) {
  final c = cal.forSite(s);
  DateTime? best;
  for (final t in s.tasks) {
    final d = c.endOf(t);
    if (best == null || d.isAfter(best)) best = d;
  }
  return best;
}

/// 引渡し（節目）があればその日、なければ最終日
DateTime? handoverDay(Site s, WorkCalendar cal) {
  final c = cal.forSite(s);
  for (final t in s.tasks) {
    if (t.isMilestone && t.milestone == MilestoneType.handover) {
      return c.snap(t.start);
    }
  }
  return siteEnd(s, cal);
}

void sortTasks(Site s, WorkCalendar cal) {
  final c = cal.forSite(s);
  final order = {for (var i = 0; i < s.tasks.length; i++) s.tasks[i].id: i};
  s.tasks.sort((a, b) {
    final x = c.snap(a.start).compareTo(c.snap(b.start));
    if (x != 0) return x;
    return order[a.id]!.compareTo(order[b.id]!);
  });
}

/// 雨などで「その日の現場が止まった」。
/// その日にかかっている工程は1日延び、その日以降に始まる工程は
/// まとめて1稼働日うしろへ。
bool stopSiteOnDay(
  Site s,
  DateTime day,
  WorkCalendar cal, {
  ShiftReason reason = ShiftReason.rain,
}) {
  day = dayOf(day);
  final before = cal.forSite(s);
  if (!before.isWorkDay(day)) return false;
  final affected = s.tasks.any((t) => !before.endOf(t).isBefore(day));
  if (!affected) return false;
  final starts = {for (final t in s.tasks) t.id: before.snap(t.start)};
  s.logs.add(ShiftLog(day: day, days: 1, reason: reason, stopDay: true));
  final after = cal.forSite(s);
  for (final t in s.tasks) {
    final st = starts[t.id]!;
    if (sameDay(st, day)) {
      t.start = after.snap(day); // 止まった日に始まる予定だった → 次の稼働日
    } else if (st.isAfter(day)) {
      t.start = after.addWorkDays(st, 1); // 後ろの工程はまとめて1日うしろ
    }
    // その日をまたぐ工程は、稼働日の数そのままで自然に1日延びる
  }
  sortTasks(s, cal);
  return true;
}

/// 「前の業者が遅れた」など: この工程から後ろを n 稼働日ずらす（負で前倒し）。
void shiftFromTask(
  Site s,
  String taskId,
  int n,
  WorkCalendar cal, {
  ShiftReason reason = ShiftReason.previousTrade,
  bool log = true,
}) {
  final c = cal.forSite(s);
  final target = s.tasks.firstWhere((t) => t.id == taskId);
  final from = c.snap(target.start);
  final starts = {for (final t in s.tasks) t.id: c.snap(t.start)};
  for (final t in s.tasks) {
    if (!starts[t.id]!.isBefore(from)) {
      t.start = c.addWorkDays(starts[t.id]!, n);
    }
  }
  if (log && n != 0) {
    s.logs.add(ShiftLog(day: from, days: n, reason: reason));
  }
  sortTasks(s, cal);
}

/// ドラッグで1つの工程を動かす。carry=true なら後ろの工程も同じだけ。
/// 動かした稼働日数を返す。
int moveTask(
  Site s,
  String taskId,
  DateTime newStart,
  WorkCalendar cal, {
  bool carry = true,
}) {
  final c = cal.forSite(s);
  final t = s.tasks.firstWhere((x) => x.id == taskId);
  final from = c.snap(t.start);
  final to = c.snap(newStart);
  final n = workDayDistance(c, from, to);
  if (n == 0) return 0;
  if (carry) {
    shiftFromTask(s, taskId, n, cal, log: false);
  } else {
    t.start = to;
    sortTasks(s, cal);
  }
  return n;
}

/// from → to が稼働日でいくつか（to が前なら負）
int workDayDistance(WorkCalendar c, DateTime from, DateTime to) {
  if (sameDay(from, to)) return 0;
  final forward = to.isAfter(from);
  var n = 0;
  var d = from;
  var guard = 0;
  while (!sameDay(d, to) && guard++ < 2000) {
    d = addDays(d, forward ? 1 : -1);
    if (c.isWorkDay(d)) n++;
  }
  return forward ? n : -n;
}

/// その日、どこかの現場で作業がある？（仮押さえも含む）
class DayLoad {
  DayLoad(this.day, this.off, this.sites, this.tentativeOnly);
  final DateTime day;
  final String? off;
  final List<Site> sites;
  final bool tentativeOnly;
  bool get free => off == null && sites.isEmpty;
}

DayLoad loadOn(List<Site> sites, DateTime day, WorkCalendar cal) {
  final busy = <Site>[];
  var tentativeOnly = true;
  for (final s in sites.where((s) => !s.archived)) {
    final c = cal.forSite(s);
    final hits = s.tasks.where((t) => !t.isMilestone && c.occupies(t, day));
    if (hits.isNotEmpty) {
      busy.add(s);
      if (hits.any((t) => !t.tentative)) tentativeOnly = false;
    }
  }
  return DayLoad(
    day,
    cal.offReason(day),
    busy,
    busy.isNotEmpty && tentativeOnly,
  );
}

/// 「○日から入れる？」の答え
class Availability {
  Availability({
    required this.asked,
    required this.needed,
    required this.askedIsFree,
    required this.firstStart,
    required this.firstEnd,
    required this.busyOnAsked,
  });
  final DateTime asked;
  final int needed;

  /// 聞かれた日から needed 稼働日ぶん空いている
  final bool askedIsFree;
  final DateTime? firstStart;
  final DateTime? firstEnd;
  final List<Site> busyOnAsked;

  /// LINE にそのまま貼れる返事（ほかの現場名は出さない）
  String get replyText {
    final span = needed == 1 ? '' : '$needed日間';
    if (askedIsFree && firstStart != null && firstEnd != null) {
      final until = needed == 1 ? '' : '（${md(firstEnd!)}まで）';
      return '${md(firstStart!)}から$span入れます$until。';
    }
    if (firstStart == null) {
      return '${md(asked)}からはしばらく予定が詰まっています。確認してまた連絡します。';
    }
    return '${md(asked)}は別の現場が入っています。'
        '${md(firstStart!)}からなら$span入れます。';
  }
}

Availability checkAvailability(
  List<Site> sites,
  DateTime asked,
  int needed,
  WorkCalendar cal, {
  int horizon = 120,
}) {
  asked = dayOf(asked);
  DateTime? runStart;
  DateTime? runEnd;
  var run = 0;
  bool askedFree = false;
  for (var i = 0; i < horizon; i++) {
    final d = addDays(asked, i);
    final l = loadOn(sites, d, cal);
    if (l.off != null) continue; // 休みの日は数えないが途切れさせない
    if (l.sites.isEmpty) {
      runStart ??= d;
      run++;
      if (run >= needed) {
        runEnd = d;
        break;
      }
    } else {
      runStart = null;
      run = 0;
    }
  }
  if (runEnd != null) {
    final askedWork = cal.snap(asked);
    askedFree = sameDay(runStart!, askedWork);
  }
  return Availability(
    asked: asked,
    needed: needed,
    askedIsFree: askedFree,
    firstStart: runEnd == null ? null : runStart,
    firstEnd: runEnd,
    busyOnAsked: loadOn(sites, asked, cal).sites,
  );
}

/// 全体の休みを足す前後で、その日に作業があった現場の後ろを1日ずらす。
/// （休みの日をまたぐ工程は稼働日の数そのままで自然に延びる）
void pushAfterNewOffDay(
  Site s,
  DateTime day,
  WorkCalendar before,
  WorkCalendar after,
) {
  final b = before.forSite(s);
  final a = after.forSite(s);
  final occupied = s.tasks.any((t) => !t.isMilestone && b.occupies(t, day));
  if (!occupied) return;
  for (final t in s.tasks) {
    final st = b.snap(t.start);
    if (st.isAfter(day)) t.start = a.addWorkDays(st, 1);
  }
  sortTasks(s, after);
}
