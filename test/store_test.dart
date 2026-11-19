import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shokunin_koutei/core/days.dart';
import 'package:shokunin_koutei/core/models.dart';
import 'package:shokunin_koutei/core/schedule.dart';
import 'package:shokunin_koutei/core/store.dart';

import 'support/harness.dart';

void main() {
  test('テンプレートで現場を作る: 工程が順に並び、節目は日数を使わない', () async {
    final st = await openState();
    final s = await st.createSite(tpl('paint'), start: DateTime(2026, 11, 16));
    final c = st.cal.forSite(s);
    expect(s.name, '外壁塗装の現場');
    expect(s.tasks.first.name, '着工');
    expect(c.snap(s.tasks.first.start), DateTime(2026, 11, 16));
    final scaffold = s.tasks.firstWhere((t) => t.name == '足場組立');
    expect(c.snap(scaffold.start), DateTime(2026, 11, 16));
    final wash = s.tasks.firstWhere((t) => t.name == '高圧洗浄');
    expect(c.snap(wash.start), DateTime(2026, 11, 17));
    // 足場1+洗浄1+下地2+下塗1+中塗1+上塗1+付帯2+解体1 = 10稼働日
    // 16,17,18,19,20,21(土),24,25,26,27  ※22日 23祝
    expect(handoverDay(s, st.cal), DateTime(2026, 11, 28));
    expect(s.tasks.every((t) => t.rainStops || t.isMilestone), isTrue);
  });

  test('無料は現場2つまで、Pro は上限なし', () async {
    final st = await openState();
    await st.createSite(tpl('paint'));
    await st.createSite(tpl('roof'));
    expect(st.canAddSite, isFalse);
    expect(() => st.createSite(tpl('water')), throwsA(isA<LimitReached>()));
    await st.archiveSite(st.data.sites.first.id, true);
    expect(st.canAddSite, isTrue);
    await st.grantPro(until: DateTime(2027, 12, 31));
    await st.createSite(tpl('water'));
    await st.createSite(tpl('blank'));
    expect(st.activeSites.length, 3);
  });

  test('雨の日は選んだ現場だけずれて、元に戻せる', () async {
    final st = await openState(pro: true);
    final a = await st.createSite(tpl('paint'), start: DateTime(2026, 11, 16));
    final b = await st.createSite(
      tpl('interior'),
      start: DateTime(2026, 11, 16),
    );
    final endA = handoverDay(a, st.cal);
    final endB = handoverDay(b, st.cal);
    expect(await st.rainDay(DateTime(2026, 11, 18), [a.id]), 1);
    expect(
      handoverDay(st.site(a.id), st.cal),
      st.cal.forSite(st.site(a.id)).addWorkDays(endA!, 1),
    );
    expect(handoverDay(st.site(b.id), st.cal), endB);
    await st.undo();
    expect(handoverDay(st.site(a.id), st.cal), endA);
    expect(st.site(a.id).logs, isEmpty);
  });

  test('自分の休みを足すと、その日に作業がある現場だけ後ろがずれる', () async {
    final st = await openState(pro: true);
    final a = await st.createSite(tpl('water'), start: DateTime(2026, 11, 19));
    final b = await st.createSite(tpl('water'), start: DateTime(2026, 12, 7));
    final endA = handoverDay(a, st.cal)!;
    final endB = handoverDay(b, st.cal)!;
    await st.addOffDay(DateTime(2026, 11, 20));
    expect(st.cal.isWorkDay(DateTime(2026, 11, 20)), isFalse);
    expect(handoverDay(st.site(a.id), st.cal), st.cal.addWorkDays(endA, 1));
    expect(handoverDay(st.site(b.id), st.cal), endB);
  });

  test('前の現場をコピー: 新しい開始日に合わせて並ぶ', () async {
    final st = await openState(pro: true);
    final a = await st.createSite(tpl('roof'), start: DateTime(2026, 11, 16));
    final copy = await st.duplicateSite(a.id, DateTime(2026, 12, 1));
    expect(siteStart(copy, st.cal), DateTime(2026, 12, 1));
    expect(copy.tasks.length, a.tasks.length);
    expect(
      copy.tasks
          .map((t) => t.id)
          .toSet()
          .intersection(a.tasks.map((t) => t.id).toSet()),
      isEmpty,
    );
    expect(copy.logs, isEmpty);
  });

  test('保存して読み直せる（ファイル）', () async {
    final dir = await Directory.systemTemp.createTemp('koutei');
    final st = AppState(repository: Repository(dir), now: testNow);
    await st.load();
    final s = await st.createSite(tpl('exterior'), name: '裏の駐車場');
    await st.rainDay(DateTime(2026, 11, 20), [s.id]);
    await st.updateProfile('屋号', '090-0000-0000');
    final again = AppState(repository: Repository(dir), now: testNow);
    await again.load();
    expect(again.data.sites.single.name, '裏の駐車場');
    expect(again.data.sites.single.logs.single.reason, ShiftReason.rain);
    expect(again.data.sites.single.stopDayKeys, {
      dayKey(DateTime(2026, 11, 20)),
    });
    expect(again.data.profile.company, '屋号');
  });

  test('人・お金の項目を持たない（4.3対策の確認）', () async {
    final st = await openState(pro: true);
    await seedDemo(st);
    final json = st.data.toJson().toString();
    for (final w in [
      'wage',
      'price',
      'amount',
      'worker',
      'person',
      '日当',
      '人工',
      '請求',
    ]) {
      expect(json.contains(w), isFalse, reason: w);
    }
  });
}
