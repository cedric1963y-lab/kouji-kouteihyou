import 'days.dart';

/// 工程の種類。人・人工・お金は持たない（期間と節目だけ）。
enum TaskKind { work, milestone }

/// 節目の種類
enum MilestoneType { start, inspection, witness, request, handover, other }

extension MilestoneTypeLabel on MilestoneType {
  String get label => switch (this) {
    MilestoneType.start => '着工',
    MilestoneType.inspection => '検査',
    MilestoneType.witness => '立会い',
    MilestoneType.request => 'お願い',
    MilestoneType.handover => '引渡し',
    MilestoneType.other => '節目',
  };
}

/// ずらした理由
enum ShiftReason { rain, previousTrade, material, client, other }

extension ShiftReasonLabel on ShiftReason {
  String get label => switch (this) {
    ShiftReason.rain => '雨',
    ShiftReason.previousTrade => '前の業者の遅れ',
    ShiftReason.material => '材料待ち',
    ShiftReason.client => 'お客さんの都合',
    ShiftReason.other => 'その他',
  };
  String get icon => switch (this) {
    ShiftReason.rain => '☂',
    ShiftReason.previousTrade => '⏳',
    ShiftReason.material => '📦',
    ShiftReason.client => '🏠',
    ShiftReason.other => '・',
  };
}

class Task {
  Task({
    required this.id,
    required this.name,
    required this.start,
    this.workDays = 1,
    this.kind = TaskKind.work,
    this.milestone = MilestoneType.other,
    this.rainStops = false,
    this.tentative = false,
    this.note = '',
  });

  final String id;
  String name;
  DateTime start;

  /// 稼働日の数（休みの日は数えない）
  int workDays;
  TaskKind kind;
  MilestoneType milestone;

  /// 雨で止まる工程（外の作業）
  bool rainStops;

  /// 仮押さえ
  bool tentative;
  String note;

  bool get isMilestone => kind == TaskKind.milestone;

  Task copy() => Task.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'start': dayKey(start),
    'workDays': workDays,
    'kind': kind.name,
    'milestone': milestone.name,
    'rainStops': rainStops,
    'tentative': tentative,
    'note': note,
  };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: j['id'] as String,
    name: j['name'] as String,
    start: parseDayKey(j['start'] as String),
    workDays: (j['workDays'] as num?)?.toInt() ?? 1,
    kind: TaskKind.values.byName(j['kind'] as String? ?? 'work'),
    milestone: MilestoneType.values.byName(
      j['milestone'] as String? ?? 'other',
    ),
    rainStops: j['rainStops'] as bool? ?? false,
    tentative: j['tentative'] as bool? ?? false,
    note: j['note'] as String? ?? '',
  );
}

/// 順延の記録（雨の日・遅れ）。送る画像の下にも載る。
class ShiftLog {
  ShiftLog({
    required this.day,
    required this.days,
    required this.reason,
    this.stopDay = false,
  });

  final DateTime day;
  final int days;
  final ShiftReason reason;

  /// その日まるごと現場が止まった（雨の日など）
  final bool stopDay;

  Map<String, dynamic> toJson() => {
    'day': dayKey(day),
    'days': days,
    'reason': reason.name,
    'stopDay': stopDay,
  };
  factory ShiftLog.fromJson(Map<String, dynamic> j) => ShiftLog(
    day: parseDayKey(j['day'] as String),
    days: (j['days'] as num).toInt(),
    reason: ShiftReason.values.byName(j['reason'] as String),
    stopDay: j['stopDay'] as bool? ?? false,
  );
}

class Site {
  Site({
    required this.id,
    required this.name,
    required this.colorIndex,
    List<Task>? tasks,
    List<ShiftLog>? logs,
    this.memo = '',
    this.saturdayWork,
    this.archived = false,
  }) : tasks = tasks ?? [],
       logs = logs ?? [];

  final String id;
  String name;
  int colorIndex;
  final List<Task> tasks;
  final List<ShiftLog> logs;

  /// 駐車場・鍵など
  String memo;

  /// null=全体の設定に従う
  bool? saturdayWork;
  bool archived;

  Set<String> get stopDayKeys => {
    for (final l in logs)
      if (l.stopDay) dayKey(l.day),
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorIndex': colorIndex,
    'tasks': [for (final t in tasks) t.toJson()],
    'logs': [for (final l in logs) l.toJson()],
    'memo': memo,
    'saturdayWork': saturdayWork,
    'archived': archived,
  };
  factory Site.fromJson(Map<String, dynamic> j) => Site(
    id: j['id'] as String,
    name: j['name'] as String,
    colorIndex: (j['colorIndex'] as num).toInt(),
    tasks: [
      for (final t in (j['tasks'] as List? ?? []))
        Task.fromJson(Map<String, dynamic>.from(t as Map)),
    ],
    logs: [
      for (final l in (j['logs'] as List? ?? []))
        ShiftLog.fromJson(Map<String, dynamic>.from(l as Map)),
    ],
    memo: j['memo'] as String? ?? '',
    saturdayWork: j['saturdayWork'] as bool?,
    archived: j['archived'] as bool? ?? false,
  );
}

class HolidaySettings {
  HolidaySettings({
    this.sunday = true,
    this.saturday = false,
    this.nationalHolidays = true,
    this.obon = true,
    this.newYear = true,
    Set<String>? extraOff,
  }) : extraOff = extraOff ?? {};

  bool sunday;
  bool saturday;
  bool nationalHolidays;
  bool obon;
  bool newYear;

  /// 自分の休み（全現場共通）
  final Set<String> extraOff;

  Map<String, dynamic> toJson() => {
    'sunday': sunday,
    'saturday': saturday,
    'nationalHolidays': nationalHolidays,
    'obon': obon,
    'newYear': newYear,
    'extraOff': extraOff.toList()..sort(),
  };
  factory HolidaySettings.fromJson(Map<String, dynamic> j) => HolidaySettings(
    sunday: j['sunday'] as bool? ?? true,
    saturday: j['saturday'] as bool? ?? false,
    nationalHolidays: j['nationalHolidays'] as bool? ?? true,
    obon: j['obon'] as bool? ?? true,
    newYear: j['newYear'] as bool? ?? true,
    extraOff: {for (final e in (j['extraOff'] as List? ?? [])) e as String},
  );
}

class Profile {
  Profile({this.company = '', this.contact = ''});
  String company;
  String contact;
  Map<String, dynamic> toJson() => {'company': company, 'contact': contact};
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    company: j['company'] as String? ?? '',
    contact: j['contact'] as String? ?? '',
  );
}

class AppData {
  AppData({
    List<Site>? sites,
    HolidaySettings? holidays,
    Profile? profile,
    this.proUntil,
    this.nextColor = 0,
  }) : sites = sites ?? [],
       holidays = holidays ?? HolidaySettings(),
       profile = profile ?? Profile();

  final List<Site> sites;
  final HolidaySettings holidays;
  final Profile profile;
  DateTime? proUntil;
  int nextColor;

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'sites': [for (final s in sites) s.toJson()],
    'holidays': holidays.toJson(),
    'profile': profile.toJson(),
    'proUntil': proUntil?.toIso8601String(),
    'nextColor': nextColor,
  };
  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
    sites: [
      for (final s in (j['sites'] as List? ?? []))
        Site.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
    holidays: HolidaySettings.fromJson(
      Map<String, dynamic>.from(j['holidays'] as Map? ?? {}),
    ),
    profile: Profile.fromJson(
      Map<String, dynamic>.from(j['profile'] as Map? ?? {}),
    ),
    proUntil: j['proUntil'] == null
        ? null
        : DateTime.parse(j['proUntil'] as String),
    nextColor: (j['nextColor'] as num?)?.toInt() ?? 0,
  );
}
