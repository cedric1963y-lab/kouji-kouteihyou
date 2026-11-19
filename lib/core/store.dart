import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'days.dart';
import 'models.dart';
import 'plan.dart';
import 'schedule.dart';
import 'templates.dart';

/// 端末内の JSON 1ファイルに保存する（オフライン・アカウントなし）
class Repository {
  Repository(this.dir);
  final Directory dir;
  File get _file => File('${dir.path}/koutei.json');

  Future<AppData> load() async {
    if (!await _file.exists()) return AppData();
    try {
      return AppData.fromJson(
        jsonDecode(await _file.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      return AppData();
    }
  }

  Future<void> save(AppData d) async {
    await dir.create(recursive: true);
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(d.toJson()));
    await tmp.rename(_file.path);
  }
}

class LimitReached implements Exception {}

class AppState extends ChangeNotifier {
  AppState({required this.repository, DateTime Function()? now})
    : now = now ?? DateTime.now;

  final Repository repository;
  final DateTime Function() now;
  AppData data = AppData();
  final List<String> _undo = [];
  final _rand = Random();

  DateTime get today => dayOf(now());
  WorkCalendar get cal => WorkCalendar(data.holidays);

  bool get isPro => (data.proUntil != null && data.proUntil!.isAfter(now()));

  List<Site> get activeSites => data.sites.where((s) => !s.archived).toList();
  bool get canAddSite => isPro || activeSites.length < Plan.freeActiveSites;
  bool get canUndo => _undo.isNotEmpty;

  Future<void> load() async {
    data = await repository.load();
    notifyListeners();
  }

  Future<void> _commit() async {
    notifyListeners();
    await repository.save(data);
  }

  void _snapshot() {
    _undo.add(jsonEncode(data.toJson()));
    if (_undo.length > 20) _undo.removeAt(0);
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    data = AppData.fromJson(
      jsonDecode(_undo.removeLast()) as Map<String, dynamic>,
    );
    await _commit();
  }

  String newId() =>
      '${now().microsecondsSinceEpoch.toRadixString(36)}${_rand.nextInt(1 << 20).toRadixString(36)}';

  Site site(String id) => data.sites.firstWhere((s) => s.id == id);

  /// テンプレートから現場を作る（＋ → テンプレ のタップ2回で完成）
  Future<Site> createSite(
    SiteTemplate tpl, {
    DateTime? start,
    String? name,
  }) async {
    if (!canAddSite) throw LimitReached();
    _snapshot();
    final s = Site(
      id: newId(),
      name: (name == null || name.trim().isEmpty)
          ? _defaultName(tpl)
          : name.trim(),
      colorIndex: data.nextColor % 8,
    );
    data.nextColor++;
    final c = cal.forSite(s);
    var cursor = c.snap(start ?? addDays(today, 1));
    for (final st in tpl.steps) {
      if (st.milestone != null) {
        // 節目は日数を使わない（着工は初日、ほかは前の作業の翌稼働日）
        s.tasks.add(
          Task(
            id: newId(),
            name: st.name,
            start: cursor,
            kind: TaskKind.milestone,
            milestone: st.milestone!,
            rainStops: st.rain,
          ),
        );
        continue;
      }
      final t = Task(
        id: newId(),
        name: st.name,
        start: cursor,
        workDays: st.days,
        rainStops: st.rain,
      );
      s.tasks.add(t);
      cursor = c.addWorkDays(c.endOf(t), 1);
    }
    data.sites.add(s);
    await _commit();
    return s;
  }

  String _defaultName(SiteTemplate tpl) {
    final base = tpl.id == 'blank' ? '現場' : '${tpl.label}の現場';
    var n = 1;
    String name() => n == 1 ? base : '$base $n';
    while (data.sites.any((s) => s.name == name())) {
      n++;
    }
    return name();
  }

  /// 前の現場をコピー（日付は新しい開始日に合わせる）
  Future<Site> duplicateSite(String id, DateTime start) async {
    if (!canAddSite) throw LimitReached();
    _snapshot();
    final src = site(id);
    final copy = Site.fromJson(
      src.toJson()
        ..['id'] = newId()
        ..['name'] = '${src.name}（コピー）'
        ..['logs'] = []
        ..['colorIndex'] = data.nextColor % 8,
    );
    data.nextColor++;
    final c = cal.forSite(copy);
    final first = siteStart(src, cal) ?? today;
    final to = c.snap(start);
    final n = workDayDistance(c, first, to);
    for (final t in copy.tasks) {
      t.start = c.addWorkDays(c.snap(t.start), n);
    }
    final fresh = [
      for (final t in copy.tasks) Task.fromJson(t.toJson()..['id'] = newId()),
    ];
    copy.tasks
      ..clear()
      ..addAll(fresh);
    data.sites.add(copy);
    await _commit();
    return copy;
  }

  Future<void> updateSite(String id, void Function(Site s) edit) async {
    _snapshot();
    edit(site(id));
    await _commit();
  }

  Future<void> deleteSite(String id) async {
    _snapshot();
    data.sites.removeWhere((s) => s.id == id);
    await _commit();
  }

  Future<void> archiveSite(String id, bool archived) async {
    if (!archived && !canAddSite) throw LimitReached();
    _snapshot();
    site(id).archived = archived;
    await _commit();
  }

  Future<Task> addTask(String siteId, Task t) async {
    _snapshot();
    final s = site(siteId);
    s.tasks.add(t);
    sortTasks(s, cal);
    await _commit();
    return t;
  }

  Future<void> updateTask(String siteId, Task edited) async {
    _snapshot();
    final s = site(siteId);
    final i = s.tasks.indexWhere((t) => t.id == edited.id);
    if (i >= 0) s.tasks[i] = edited;
    sortTasks(s, cal);
    await _commit();
  }

  Future<void> deleteTask(String siteId, String taskId) async {
    _snapshot();
    site(siteId).tasks.removeWhere((t) => t.id == taskId);
    await _commit();
  }

  /// 雨の日: 選んだ現場をその日止めて、後ろをまとめて1日ずらす。
  /// 実際にずれた現場の数を返す。
  Future<int> rainDay(
    DateTime day,
    Iterable<String> siteIds, {
    ShiftReason reason = ShiftReason.rain,
  }) async {
    _snapshot();
    var n = 0;
    for (final id in siteIds) {
      if (stopSiteOnDay(site(id), day, cal, reason: reason)) n++;
    }
    if (n == 0) {
      _undo.removeLast();
      return 0;
    }
    await _commit();
    return n;
  }

  /// 止めた日を取り消す（ずらした分は元に戻さない。戻すなら undo）
  Future<void> clearStopDay(String siteId, DateTime day) async {
    _snapshot();
    site(siteId).logs.removeWhere((l) => l.stopDay && sameDay(l.day, day));
    await _commit();
  }

  /// 前の業者の遅れなど: この工程から後ろを n 日ずらす
  Future<void> delayFrom(
    String siteId,
    String taskId,
    int n,
    ShiftReason reason,
  ) async {
    _snapshot();
    shiftFromTask(site(siteId), taskId, n, cal, reason: reason);
    await _commit();
  }

  /// ドラッグ: 後ろもまとめて動かす
  Future<int> dragTask(
    String siteId,
    String taskId,
    DateTime newStart, {
    bool carry = true,
  }) async {
    _snapshot();
    final n = moveTask(site(siteId), taskId, newStart, cal, carry: carry);
    if (n == 0) {
      _undo.removeLast();
      return 0;
    }
    await _commit();
    return n;
  }

  /// この日を休みにする（全現場）。その日に作業があった現場は後ろを1日ずらす。
  Future<void> addOffDay(DateTime day) async {
    _snapshot();
    final before = WorkCalendar(
      HolidaySettings.fromJson(data.holidays.toJson()),
    );
    data.holidays.extraOff.add(dayKey(day));
    final after = cal;
    for (final s in activeSites) {
      pushAfterNewOffDay(s, day, before, after);
    }
    await _commit();
  }

  Future<void> removeOffDay(DateTime day) async {
    _snapshot();
    data.holidays.extraOff.remove(dayKey(day));
    await _commit();
  }

  Future<void> updateHolidays(void Function(HolidaySettings h) edit) async {
    _snapshot();
    edit(data.holidays);
    await _commit();
  }

  Future<void> updateProfile(String company, String contact) async {
    data.profile
      ..company = company
      ..contact = contact;
    await _commit();
  }

  Future<void> grantPro({required DateTime until}) async {
    data.proUntil = until;
    await _commit();
  }
}
