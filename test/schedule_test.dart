import 'package:flutter_test/flutter_test.dart';
import 'package:shokunin_koutei/core/days.dart';
import 'package:shokunin_koutei/core/holidays.dart';
import 'package:shokunin_koutei/core/models.dart';
import 'package:shokunin_koutei/core/schedule.dart';

DateTime d(int m, int day, [int y = 2026]) => DateTime(y, m, day);

Site siteWith(List<Task> tasks) =>
    Site(id: 's', name: 'テスト', colorIndex: 0, tasks: tasks);

void main() {
  final cal = WorkCalendar(HolidaySettings());

  group('祝日', () {
    test('2026年の祝日と振替・国民の休日', () {
      final h = japaneseHolidays(2026);
      expect(h[dayKey(d(1, 12))], '成人の日');
      expect(h[dayKey(d(3, 20))], '春分の日');
      expect(h[dayKey(d(5, 6))], '振替休日'); // 5/3が日曜
      expect(h[dayKey(d(9, 21))], '敬老の日');
      expect(h[dayKey(d(9, 22))], '国民の休日');
      expect(h[dayKey(d(9, 23))], '秋分の日');
      expect(h[dayKey(d(11, 23))], '勤労感謝の日');
      expect(h.length, 18);
    });
    test('2027年', () {
      final h = japaneseHolidays(2027);
      expect(h[dayKey(d(3, 21, 2027))], '春分の日');
      expect(h[dayKey(d(3, 22, 2027))], '振替休日');
      expect(h[dayKey(d(2, 11, 2027))], '建国記念の日');
    });
  });

  group('稼働日', () {
    test('日曜・祝日・年末年始は休み、土曜は既定で稼働', () {
      expect(cal.isWorkDay(d(11, 22)), isFalse); // 日
      expect(cal.isWorkDay(d(11, 23)), isFalse); // 勤労感謝の日
      expect(cal.isWorkDay(d(11, 21)), isTrue); // 土
      expect(cal.offReason(d(12, 30)), '年末年始');
      expect(cal.offReason(d(8, 14)), 'お盆');
    });
    test('土曜休みは全体設定、現場ごとに上書きできる', () {
      final c = WorkCalendar(HolidaySettings(saturday: true));
      expect(c.isWorkDay(d(11, 21)), isFalse);
      final s = siteWith([])..saturdayWork = true;
      expect(c.forSite(s).isWorkDay(d(11, 21)), isTrue);
    });
    test('5稼働日の工程は日曜と祝日を飛ばして終わる', () {
      // 11/19(木)開始: 19,20,21(土),24,25  ※22日・23祝
      final t = Task(id: 't', name: '下地', start: d(11, 19), workDays: 5);
      expect(cal.endOf(t), d(11, 25));
      expect(cal.workDaysOf(t).length, 5);
    });
    test('休みの日に置いた開始は次の稼働日に寄る', () {
      expect(cal.snap(d(11, 22)), d(11, 24));
    });
  });

  group('雨で順延', () {
    Site paint() => siteWith([
      Task(id: 'a', name: '洗浄', start: d(11, 16), workDays: 1),
      Task(id: 'b', name: '下塗り', start: d(11, 17), workDays: 3),
      Task(id: 'c', name: '上塗り', start: d(11, 20), workDays: 2),
      Task(
        id: 'h',
        name: '引渡し',
        start: d(11, 24),
        kind: TaskKind.milestone,
        milestone: MilestoneType.handover,
      ),
    ]);

    test('途中の工程は1日延び、後ろはまとめて1稼働日うしろ', () {
      final s = paint();
      expect(stopSiteOnDay(s, d(11, 18), cal), isTrue);
      final c = cal.forSite(s);
      final byId = {for (final t in s.tasks) t.id: t};
      expect(c.endOf(byId['a']!), d(11, 16)); // 前は動かない
      expect(c.endOf(byId['b']!), d(11, 20)); // 17,19,20
      expect(c.snap(byId['c']!.start), d(11, 21)); // 20→21(土)
      expect(c.endOf(byId['c']!), d(11, 24)); // 21, (22日,23祝), 24
      expect(c.snap(byId['h']!.start), d(11, 25));
      expect(s.logs.single.reason, ShiftReason.rain);
      expect(c.isWorkDay(d(11, 18)), isFalse);
    });

    test('雨の日に始まる予定の工程は次の稼働日から', () {
      final s = paint();
      stopSiteOnDay(s, d(11, 20), cal);
      final c = cal.forSite(s);
      expect(c.snap(s.tasks.firstWhere((t) => t.id == 'c').start), d(11, 21));
    });

    test('休みの日や現場が終わった後は何もしない', () {
      final s = paint();
      expect(stopSiteOnDay(s, d(11, 22), cal), isFalse);
      expect(stopSiteOnDay(s, d(12, 1), cal), isFalse);
      expect(s.logs, isEmpty);
    });
  });

  group('遅れ・ドラッグ', () {
    test('前の業者が2日遅れ: その工程から後ろだけずれる', () {
      final s = siteWith([
        Task(id: 'a', name: '配管', start: d(11, 16), workDays: 2),
        Task(id: 'b', name: 'ボード', start: d(11, 18), workDays: 2),
        Task(id: 'c', name: 'クロス', start: d(11, 20), workDays: 2),
      ]);
      shiftFromTask(s, 'b', 2, cal);
      final c = cal.forSite(s);
      final byId = {for (final t in s.tasks) t.id: t};
      expect(c.snap(byId['a']!.start), d(11, 16));
      expect(c.snap(byId['b']!.start), d(11, 20));
      expect(c.snap(byId['c']!.start), d(11, 24));
      expect(s.logs.single.reason, ShiftReason.previousTrade);
      expect(s.logs.single.days, 2);
    });

    test('ドラッグは後ろもまとめて、ひとつだけも選べる', () {
      Site make() => siteWith([
        Task(id: 'a', name: 'A', start: d(11, 16), workDays: 1),
        Task(id: 'b', name: 'B', start: d(11, 17), workDays: 1),
      ]);
      final s1 = make();
      expect(moveTask(s1, 'a', d(11, 18), cal), 2);
      expect(s1.tasks.map((t) => t.start).toList(), [d(11, 18), d(11, 19)]);
      final s2 = make();
      moveTask(s2, 'a', d(11, 18), cal, carry: false);
      expect(s2.tasks.first.id, 'b');
      expect(s2.tasks.last.start, d(11, 18));
    });

    test('稼働日の距離', () {
      expect(workDayDistance(cal, d(11, 20), d(11, 24)), 2);
      expect(workDayDistance(cal, d(11, 24), d(11, 20)), -2);
    });
  });

  group('空き確認', () {
    final sites = [
      siteWith([Task(id: 'a', name: 'A', start: d(11, 24), workDays: 3)]),
    ];
    test('空いていればそのまま返事', () {
      final a = checkAvailability(sites, d(11, 19), 2, cal);
      expect(a.askedIsFree, isTrue);
      expect(a.replyText, '11/19(木)から2日間入れます（11/20(金)まで）。');
    });
    test('詰まっていれば次に空く日を、ほかの現場名を出さずに', () {
      final a = checkAvailability(sites, d(11, 24), 3, cal);
      expect(a.askedIsFree, isFalse);
      expect(a.firstStart, d(11, 27));
      expect(a.firstEnd, d(11, 30)); // 27,28(土),30
      expect(a.replyText, contains('別の現場が入っています'));
      expect(a.replyText, isNot(contains('テスト')));
    });
    test('前の休みをまたいでも数えられる', () {
      final a = checkAvailability(sites, d(11, 21), 2, cal);
      // 21(土)は空き、22日・23祝は休み、24から詰まる → 27,28
      expect(a.firstStart, d(11, 27));
    });
  });
}
