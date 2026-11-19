import 'models.dart';

class TemplateStep {
  const TemplateStep(this.name, this.days, {this.rain = false, this.milestone});
  final String name;
  final int days;
  final bool rain;
  final MilestoneType? milestone;
}

class SiteTemplate {
  const SiteTemplate(this.id, this.label, this.icon, this.steps);
  final String id;
  final String label;
  final String icon;
  final List<TemplateStep> steps;
}

/// 職種別のひな形。日数は目安（稼働日）。あとからタップで変えられる。
const siteTemplates = <SiteTemplate>[
  SiteTemplate('paint', '外壁塗装', '🎨', [
    TemplateStep('着工', 1, milestone: MilestoneType.start),
    TemplateStep('足場組立', 1, rain: true),
    TemplateStep('高圧洗浄', 1, rain: true),
    TemplateStep('下地補修・養生', 2, rain: true),
    TemplateStep('下塗り', 1, rain: true),
    TemplateStep('中塗り', 1, rain: true),
    TemplateStep('上塗り', 1, rain: true),
    TemplateStep('付帯部塗装', 2, rain: true),
    TemplateStep('完了立会い', 1, milestone: MilestoneType.witness),
    TemplateStep('足場解体', 1, rain: true),
    TemplateStep('引渡し', 1, milestone: MilestoneType.handover),
  ]),
  SiteTemplate('roof', '屋根工事', '🏠', [
    TemplateStep('着工', 1, milestone: MilestoneType.start),
    TemplateStep('足場組立', 1, rain: true),
    TemplateStep('既存撤去', 2, rain: true),
    TemplateStep('下地・ルーフィング', 2, rain: true),
    TemplateStep('屋根材葺き', 3, rain: true),
    TemplateStep('板金・棟', 1, rain: true),
    TemplateStep('足場解体', 1, rain: true),
    TemplateStep('引渡し', 1, milestone: MilestoneType.handover),
  ]),
  SiteTemplate('interior', '内装リフォーム', '🪚', [
    TemplateStep('家具移動のお願い', 1, milestone: MilestoneType.request),
    TemplateStep('養生・解体', 2),
    TemplateStep('設備配管', 2),
    TemplateStep('電気配線', 1),
    TemplateStep('下地・ボード', 3),
    TemplateStep('クロス・床', 3),
    TemplateStep('器具付け', 1),
    TemplateStep('クリーニング', 1),
    TemplateStep('引渡し', 1, milestone: MilestoneType.handover),
  ]),
  SiteTemplate('water', '水回り交換', '🚿', [
    TemplateStep('着工', 1, milestone: MilestoneType.start),
    TemplateStep('解体・撤去', 1),
    TemplateStep('給排水配管', 1),
    TemplateStep('本体設置', 2),
    TemplateStep('内装仕上げ', 1),
    TemplateStep('引渡し', 1, milestone: MilestoneType.handover),
  ]),
  SiteTemplate('exterior', '外構', '🧱', [
    TemplateStep('着工', 1, milestone: MilestoneType.start),
    TemplateStep('掘削・土工', 2, rain: true),
    TemplateStep('基礎', 3, rain: true),
    TemplateStep('ブロック・フェンス', 3, rain: true),
    TemplateStep('土間コン', 2, rain: true),
    TemplateStep('清掃', 1),
    TemplateStep('引渡し', 1, milestone: MilestoneType.handover),
  ]),
  SiteTemplate('carpenter', '新築（大工）', '🔨', [
    TemplateStep('上棟', 1, milestone: MilestoneType.start, rain: true),
    TemplateStep('屋根・防水', 3, rain: true),
    TemplateStep('金物検査', 1, milestone: MilestoneType.inspection),
    TemplateStep('外壁下地', 5, rain: true),
    TemplateStep('内部造作', 15),
    TemplateStep('仕上げ', 8),
    TemplateStep('完了検査', 1, milestone: MilestoneType.inspection),
    TemplateStep('引渡し', 1, milestone: MilestoneType.handover),
  ]),
  SiteTemplate('blank', '白紙から', '📝', [TemplateStep('作業', 3)]),
];

/// 工程を足すときに出す候補（タップで入る）
const taskNameSuggestions = [
  '足場組立',
  '足場解体',
  '解体',
  '養生',
  '下地',
  '塗装',
  '防水',
  'シーリング',
  '板金',
  '配管',
  '電気',
  'ボード',
  'クロス',
  '床',
  'クリーニング',
  '検査',
];
