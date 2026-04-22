// lib/features/research/research_data.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Artık ödeme/stok kontrolleri CurrencyService üzerinden
import 'package:overthrone/core/currency_service.dart' as cur;

/// Sıra: her düğüm bir öncekini en az Lv.5 yaptıktan sonra açılır.
enum ResearchId {
  // Tier 1 – core stats
  hp,
  atk,

  // Tier 2 – advanced stats
  crit,
  trueDmg,
  accuracy,
  evasion,
  // faction starters
  voidAtk,
  elementalHp,

  // Tier 3 – mid-game & more factions
  mechCrit,
  natureDef,
  lightSpeed,
  darkLifesteal,
  def,
  speed,
  healBoost,
  debuffResist,

  // Tier 4 – late game
  energyRegen,
  bossDmg,
  pvpFortitude,
  ultimateMastery,
}

class ResearchCost {
  final int gold, ingot, sigil, core, crown;
  final Duration time;
  const ResearchCost({
    required this.gold,
    required this.ingot,
    required this.sigil,
    required this.core,
    required this.crown,
    required this.time,
  });

  /// Asenkron: stok yeterli mi?
  Future<bool> canPay() async {
    final s = await cur.CurrencyService.throneStocks();
    return s.gold >= gold &&
        s.ingot >= ingot &&
        s.sigil >= sigil &&
        s.core >= core &&
        s.crown >= crown;
  }

  /// Asenkron: materyalleri düş. Başarılıysa true.
  Future<bool> pay() {
    return cur.CurrencyService.spendThroneMats(
      gold: gold,
      ingot: ingot,
      sigil: sigil,
      core: core,
      crown: crown,
    );
  }
}

class ResearchNode {
  final ResearchId id;
  final String title;
  final String subtitle; // UI text like “+1% HP per step”
  final int maxLv;
  final int tier; // 1..4
  int level;

  ResearchNode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.maxLv,
    required this.tier,
    this.level = 0,
  });

  bool get isMax => level >= maxLv;

  /// NEXT level cost (1..max), scales by level and tier.
  ResearchCost nextCost() {
    final next = (level + 1).clamp(1, maxLv);
    final depthMul = 1.0 + 0.35 * (tier - 1); // higher tier → pricier

    final gold = (120000 * depthMul * math.pow(next * 1.0, 0.65)).round();
    final ing = (8 * next * depthMul).round();

    int sigil = 0, core = 0, crown = 0;
    if (tier >= 2) sigil = (next + 1) ~/ 2; // 1,1,2,2,3...
    if (tier >= 3) core = (next + 2) ~/ 3; // 1 at 3/6/9
    if (tier >= 4 && next == maxLv) crown = 1; // finale

    final baseMinutes = 30 + (next - 1) * 30; // 30m .. ~5h
    final time = Duration(minutes: (baseMinutes * depthMul).round());

    return ResearchCost(
      gold: gold,
      ingot: ing,
      sigil: sigil,
      core: core,
      crown: crown,
      time: time,
    );
  }
}

class ResearchQueueItem {
  final ResearchId id;
  final int targetLevel; // research will end at this level
  DateTime endAt; // dynamic (speed up changes this)
  final Duration planned; // constant planned duration (for progress)

  ResearchQueueItem({
    required this.id,
    required this.targetLevel,
    required this.endAt,
    required this.planned,
  });

  Map<String, dynamic> toJson() => {
    'id': id.name,
    'lvl': targetLevel,
    'end': endAt.millisecondsSinceEpoch,
    'plan': planned.inMilliseconds,
  };

  static ResearchQueueItem? fromJson(Map<String, dynamic> m) {
    try {
      return ResearchQueueItem(
        id: ResearchId.values.firstWhere((e) => e.name == (m['id'] as String)),
        targetLevel: m['lvl'] as int,
        endAt: DateTime.fromMillisecondsSinceEpoch(m['end'] as int),
        planned: Duration(milliseconds: (m['plan'] as num).toInt()),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Quote modelleri (CRYSTAL ile ödeme)
class SpeedUpQuote {
  final int costCrystal;
  final Duration reduce;
  const SpeedUpQuote(this.costCrystal, this.reduce);
}

class FinishNowQuote {
  final int costCrystal;
  const FinishNowQuote(this.costCrystal);
}

/// Tüm araştırmalardan türeyen yüzdelik toplamlar.
class ResearchBonuses {
  double hpPct = 0;
  double atkPct = 0;
  double defPct = 0;
  double speedPct = 0;

  double critPct = 0;
  double allStatsPct = 0;
  double trueDmgPct = 0;
  double accuracyPct = 0;
  double evasionPct = 0;

  // faction lines
  double voidAtkPct = 0;
  double elementalHpPct = 0;
  double mechCritPct = 0;
  double natureDefPct = 0;
  double lightSpeedPct = 0;
  double darkLifestealPct = 0;

  // fancy/late game
  double healBoostPct = 0;
  double debuffResistPct = 0;
  double energyRegenPct = 0;
  double bossDmgPct = 0;
  double pvpFortitudePct = 0;

  void sanitizeSelf() {
    double f(double x) => (x.isNaN || x.isInfinite) ? 0.0 : x;
    hpPct = f(hpPct);
    atkPct = f(atkPct);
    defPct = f(defPct);
    speedPct = f(speedPct);

    critPct = f(critPct);
    trueDmgPct = f(trueDmgPct);
    accuracyPct = f(accuracyPct);
    evasionPct = f(evasionPct);

    voidAtkPct = f(voidAtkPct);
    elementalHpPct = f(elementalHpPct);
    mechCritPct = f(mechCritPct);
    natureDefPct = f(natureDefPct);
    lightSpeedPct = f(lightSpeedPct);
    darkLifestealPct = f(darkLifestealPct);

    healBoostPct = f(healBoostPct);
    debuffResistPct = f(debuffResistPct);
    energyRegenPct = f(energyRegenPct);
    bossDmgPct = f(bossDmgPct);
    pvpFortitudePct = f(pvpFortitudePct);
    allStatsPct = f(allStatsPct);
  }
}

/// Tekil laboratuvar yöneticisi
class ResearchLab {
  ResearchLab._();
  static final ResearchLab I = ResearchLab._();
  static const _kKey = 'research_lab_v5'; // CurrencyService entegrasyonu

  // Crystal fiyatlandırma parametreleri
  static const int _crystalPerHour = 250; // 1 saat = 250 crystal
  static int _ceilHours(Duration d) =>
      ((d.inMinutes + 59) ~/ 60).clamp(0, 1000000);

  /// Linear unlock chain – “önceki ≥ Lv.5” kuralı
  late final List<ResearchNode> nodes = [
    // ---- Tier 1: core starters ----
    ResearchNode(
      id: ResearchId.hp,
      title: 'HP Mastery',
      subtitle: '+1% HP per step',
      maxLv: 10,
      tier: 1,
    ),
    ResearchNode(
      id: ResearchId.atk,
      title: 'Attack Mastery',
      subtitle: '+1% ATK per step',
      maxLv: 10,
      tier: 1,
    ),

    // ---- Tier 2 ----
    ResearchNode(
      id: ResearchId.crit,
      title: 'Critical Ops',
      subtitle: '+1% Crit per step',
      maxLv: 10,
      tier: 2,
    ),
    ResearchNode(
      id: ResearchId.trueDmg,
      title: 'True Damage',
      subtitle: '+1% True DMG per step',
      maxLv: 10,
      tier: 2,
    ),
    ResearchNode(
      id: ResearchId.accuracy,
      title: 'Targeting Systems',
      subtitle: '+1% Accuracy per step',
      maxLv: 10,
      tier: 2,
    ),
    ResearchNode(
      id: ResearchId.evasion,
      title: 'Evasive Protocols',
      subtitle: '+1% Dodge per step',
      maxLv: 10,
      tier: 2,
    ),
    ResearchNode(
      id: ResearchId.voidAtk,
      title: 'Void Mastery',
      subtitle: 'Void heroes: +1% ATK (10 steps)',
      maxLv: 10,
      tier: 2,
    ),
    ResearchNode(
      id: ResearchId.elementalHp,
      title: 'Elemental Ward',
      subtitle: 'Elemental heroes: +1% HP (10 steps)',
      maxLv: 10,
      tier: 2,
    ),

    // ---- Tier 3 ----
    ResearchNode(
      id: ResearchId.mechCrit,
      title: 'Mech Crit Ops',
      subtitle: 'Mech heroes: +1% Crit (10 steps)',
      maxLv: 10,
      tier: 3,
    ),
    ResearchNode(
      id: ResearchId.natureDef,
      title: 'Nature Fortification',
      subtitle: 'Nature heroes: +1% DEF (10 steps)',
      maxLv: 10,
      tier: 3,
    ),
    ResearchNode(
      id: ResearchId.lightSpeed,
      title: 'Light Haste',
      subtitle: 'Light heroes: +1% Speed (10 steps)',
      maxLv: 10,
      tier: 3,
    ),
    ResearchNode(
      id: ResearchId.darkLifesteal,
      title: 'Dark Leeching',
      subtitle: 'Dark heroes: +0.5% Lifesteal (10 steps)',
      maxLv: 10,
      tier: 3,
    ),
    ResearchNode(
      id: ResearchId.def,
      title: 'Defense Protocol',
      subtitle: '+1% DEF per step',
      maxLv: 10,
      tier: 3,
    ),
    ResearchNode(
      id: ResearchId.speed,
      title: 'Haste Program',
      subtitle: '+1% Speed per step',
      maxLv: 10,
      tier: 3,
    ),
    ResearchNode(
      id: ResearchId.healBoost,
      title: 'Medical Uplink',
      subtitle: '+2% Healing done per step',
      maxLv: 10,
      tier: 3,
    ),
    ResearchNode(
      id: ResearchId.debuffResist,
      title: 'Cleanse Matrix',
      subtitle: '+2% Debuff Resist per step',
      maxLv: 10,
      tier: 3,
    ),

    // ---- Tier 4 ----
    ResearchNode(
      id: ResearchId.energyRegen,
      title: 'Energy Regen',
      subtitle: '+1 Energy/turn per step',
      maxLv: 10,
      tier: 4,
    ),
    ResearchNode(
      id: ResearchId.bossDmg,
      title: 'Raid Optimization',
      subtitle: '+2% Boss Damage per step',
      maxLv: 10,
      tier: 4,
    ),
    ResearchNode(
      id: ResearchId.pvpFortitude,
      title: 'PvP Fortitude',
      subtitle: '+1% Damage Reduction (PvP) per step',
      maxLv: 10,
      tier: 4,
    ),
    ResearchNode(
      id: ResearchId.ultimateMastery,
      title: 'Ultimate Mastery',
      subtitle: 'All heroes: +0.5% All Stats per step',
      maxLv: 10,
      tier: 4,
    ),
  ];

  final ValueNotifier<int> version = ValueNotifier<int>(0);
  ResearchQueueItem? active;

  // ---- gating ----
  bool isUnlocked(ResearchNode n) {
    final idx = nodes.indexOf(n);
    if (idx <= 0) return true;
    return nodes[idx - 1].level >= 5; // “Need Lv.5 to unlock the next”
  }

  bool isBusy() => active != null;

  /// UI’de “Start” butonunu kapatmak için temel kontroller.
  /// (Materyal kontrolünü start() içinde yapıyoruz.)
  bool canStart(ResearchNode n) {
    if (isBusy() || n.isMax || !isUnlocked(n)) return false;
    return true;
  }

  Future<bool> start(ResearchNode n) async {
    if (!canStart(n)) return false;
    final cost = n.nextCost();

    // stok yeterli mi ve düşülebiliyor mu?
    final okToPay = await cost.canPay() && await cost.pay();
    if (!okToPay) return false;

    active = ResearchQueueItem(
      id: n.id,
      targetLevel: n.level + 1,
      endAt: DateTime.now().add(cost.time),
      planned: cost.time,
    );
    await _save();
    version.value++;
    return true;
  }

  // ---------- CRYSTAL tabanlı SpeedUp/FinishNow ----------
  SpeedUpQuote? speedUpQuote(Duration amount) {
    final q = active;
    if (q == null || amount <= Duration.zero) return null;
    final now = DateTime.now();
    final remaining = q.endAt.isAfter(now)
        ? q.endAt.difference(now)
        : Duration.zero;
    if (remaining == Duration.zero) return null;

    final reduce = (amount <= remaining) ? amount : remaining;
    final hours = _ceilHours(reduce);
    final cost = hours * _crystalPerHour;
    return SpeedUpQuote(cost, reduce);
  }

  FinishNowQuote? finishNowQuote() {
    final q = active;
    if (q == null) return null;
    final now = DateTime.now();
    final remaining = q.endAt.isAfter(now)
        ? q.endAt.difference(now)
        : Duration.zero;
    if (remaining == Duration.zero) return null;

    final hours = _ceilHours(remaining);
    final cost = hours * _crystalPerHour;
    return FinishNowQuote(cost);
  }

  Future<bool> speedUpPay(Duration amount) async {
    final quote = speedUpQuote(amount);
    if (quote == null) return false;

    final left = await cur.CurrencyService.spendCrystals(quote.costCrystal);
    if (left == null) return false; // bakiye yetersiz

    active!.endAt = active!.endAt.subtract(quote.reduce);
    await _save();
    version.value++;
    await pump();
    return true;
  }

  Future<bool> finishNowPay() async {
    final quote = finishNowQuote();
    if (quote == null) return false;

    final left = await cur.CurrencyService.spendCrystals(quote.costCrystal);
    if (left == null) return false;

    active!.endAt = DateTime.now();
    await _save();
    version.value++;
    await pump();
    return true;
  }

  /// Biten işleri tamamla (sayfa açıldığında ve periyodik timer’da çağır).
  Future<void> pump() async {
    final q = active;
    if (q == null) return;
    if (DateTime.now().isBefore(q.endAt)) return;

    final node = nodes.firstWhere((e) => e.id == q.id);
    node.level = q.targetLevel;
    active = null;
    await _save();
    version.value++;
  }

  ResearchNode byId(ResearchId id) => nodes.firstWhere((e) => e.id == id);

  // ---- persistence ----
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kKey);
    if (raw != null) {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final lvls = (m['lvls'] as Map).cast<String, int>();
      for (final n in nodes) {
        n.level = lvls[n.id.name] ?? 0;
      }
      final q = m['q'] as Map?;
      if (q != null) {
        active = ResearchQueueItem.fromJson(q.cast());
      }
    }
    version.value++;
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kKey,
      jsonEncode({
        'lvls': {for (final n in nodes) n.id.name: n.level},
        'q': active?.toJson(),
      }),
    );
  }

  // ---- bonuses (global) ----
  ResearchBonuses computeBonuses() {
    final b = ResearchBonuses();

    for (final n in nodes) {
      final lv = n.level;
      if (lv <= 0) continue;

      switch (n.id) {
        case ResearchId.hp:
          b.hpPct += 1.0 * lv;
          break;
        case ResearchId.atk:
          b.atkPct += 1.0 * lv;
          break;
        case ResearchId.def:
          b.defPct += 1.0 * lv;
          break;
        case ResearchId.speed:
          b.speedPct += 1.0 * lv;
          break;

        case ResearchId.crit:
          b.critPct += 1.0 * lv;
          break;
        case ResearchId.trueDmg:
          b.trueDmgPct += 0.1 * lv;
          break;
        case ResearchId.accuracy:
          b.accuracyPct += 1.0 * lv;
          break;
        case ResearchId.evasion:
          b.evasionPct += 1.0 * lv;
          break;

        case ResearchId.voidAtk:
          b.voidAtkPct += 1.0 * lv;
          break;
        case ResearchId.elementalHp:
          b.elementalHpPct += 1.0 * lv;
          break;
        case ResearchId.mechCrit:
          b.mechCritPct += 1.0 * lv;
          break;
        case ResearchId.natureDef:
          b.natureDefPct += 1.0 * lv;
          break;
        case ResearchId.lightSpeed:
          b.lightSpeedPct += 1.0 * lv;
          break;
        case ResearchId.darkLifesteal:
          b.darkLifestealPct += 0.5 * lv;
          break;

        case ResearchId.healBoost:
          b.healBoostPct += 2.0 * lv;
          break;
        case ResearchId.debuffResist:
          b.debuffResistPct += 2.0 * lv;
          break;
        case ResearchId.energyRegen:
          b.energyRegenPct += 1.0 * lv;
          break;
        case ResearchId.bossDmg:
          b.bossDmgPct += 2.0 * lv;
          break;
        case ResearchId.pvpFortitude:
          b.pvpFortitudePct += 1.0 * lv;
          break;
        case ResearchId.ultimateMastery:
          b.allStatsPct += 0.1 * lv;
          break;
      }
    }

    b.sanitizeSelf();
    return b;
  }
}
