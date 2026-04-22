// lib/core/power_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart' show ValueNotifier;
import 'package:shared_preferences/shared_preferences.dart';

// Projedeki mevcut yollar:
import 'package:overthrone/features/equipment/equipment_models.dart';
import 'package:overthrone/features/research/research_data.dart';
import 'package:overthrone/features/heroes/hero_data.dart';
import 'package:overthrone/features/heroes/hero_types.dart' show Faction;
import 'package:overthrone/throne/throne_state.dart';
import 'package:overthrone/guild/guild_tech.dart';
import 'package:overthrone/features/heroes/hero_data.dart' as old;

/// ------------------------------------------------------------
/// Ayarlar (tek yerden kalibrasyon)
/// ------------------------------------------------------------
class PowerConfig {
  static const double wHp = 1.00; // 1 HP   = 1 puan
  static const double wAtk = 2.00; // 1 ATK  = 2 puan
  static const double wDef = 2.00; // 1 DEF  = 2 puan
  static const double wSpd = 1.0; // 1 SPD  = 1 puan

  // Görünen ölçek (milyonlara taşımak için)
  static const double displayScale = 420.0;

  // Dövüş yan etkilerini güce çeviren katsayılar
  static const double kCrit = 2.50; // 1 + CR*CD
  static const double kTrueDmg = 3.70;
  static const double kHolyDmg = 3.50;
  static const double kAccuracy = 0.55;
  static const double kEvasion = 0.55;
  static const double kBlock = 1.70;
  static const double kDmgImmunity = 1.70;
  static const double kEnergyRegen = 0.40;
}

/// Gem/Stigmata gibi dış modüller için ortak bonus modeli
class ExtraBonuses {
  double hpPct = 0, atkPct = 0, defPct = 0;
  double speedPct = 0, speedFlat = 0;
  double critRatePct = 0, critDmgPct = 0;
  double accuracyPct = 0, evasionPct = 0, blockPct = 0;
  double trueDmgPct = 0, holyDmgPct = 0, dmgImmunityPct = 0;
  double energyRegenPct = 0, allStatsPct = 0;

  void add(ExtraBonuses o) {
    hpPct += o.hpPct;
    atkPct += o.atkPct;
    defPct += o.defPct;
    speedPct += o.speedPct;
    speedFlat += o.speedFlat;
    critRatePct += o.critRatePct;
    critDmgPct += o.critDmgPct;
    accuracyPct += o.accuracyPct;
    evasionPct += o.evasionPct;
    blockPct += o.blockPct;
    trueDmgPct += o.trueDmgPct;
    holyDmgPct += o.holyDmgPct;
    dmgImmunityPct += o.dmgImmunityPct;
    energyRegenPct += o.energyRegenPct;
    allStatsPct += o.allStatsPct;
  }
}

/// Opsiyonel sağlayıcılar—atanmazsa 0 bonus kabul edilir.
typedef BonusProvider = Future<ExtraBonuses> Function(String heroName);
typedef HeroBasePowerFn = int Function(old.HeroUnit u);

class PowerProviders {
  static Future<List<(old.HeroUnit, String)>> Function() topHeroes = () async =>
      [];

  static Future<ExtraBonuses> Function(String heroName)? gems;
  static Future<ExtraBonuses> Function(String heroName)? stigmata;

  // İstersen ileride kullanmak üzere
  static HeroBasePowerFn? heroBasePower;
}

/// ------------------------------------------------------------
/// Ana Servis (singleton)
/// ------------------------------------------------------------
class PowerService {
  PowerService._();
  static final PowerService I = PowerService._();

  /// Ana ekranda gösterilecek toplam güç (top-6 kahraman toplamı)
  final ValueNotifier<int> totalPower = ValueNotifier<int>(0);
  final ValueNotifier<int> version = ValueNotifier<int>(0);

  // ---- hero power cache (research / throne / guild versiyonuna bağlı) ----
  final Map<String, int> _heroPowerCache = {};
  String _cacheKey(int heroId, String heroName) =>
      '$heroId|${ResearchLab.I.version.value}|${ThroneState.I.version.value}|${GuildTech.I.version.value}|$heroName';

  void _bumpVersion() {
    // cache temizle + versiyonu artır
    _heroPowerCache.clear();
    version.value = version.value + 1;
  }

  Future<void> load() async {
    totalPower.value = 0;
  }

  /// ID’den tek kahraman gücü (UI yerleri için)
  Future<int> heroPowerById(int id) async {
    final pairs = await PowerProviders.topHeroes(); // [(HeroUnit, label)]
    for (final pair in pairs) {
      final u = pair.$1;
      final label = pair.$2;
      if (u.id == id) {
        return await heroPower(u, label); // aynı formül, aynı ölçek
      }
    }
    return 0;
  }

  // --- ad eşleştirmesi için yardımcı (prefixleri ve boşlukları at) ---
  String _canon(String s) {
    final t = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return t
        .replaceAll('light', '')
        .replaceAll('dark', '')
        .replaceAll('void', '')
        .replaceAll('mech', '')
        .replaceAll('nature', '')
        .replaceAll('elemental', '');
  }

  /// ID ile bulunamazsa ada göre eşleştirerek kahraman gücünü döndürür.
  /// (Defense grid “Halo” der, yeni modeller “Light Halo” diyorsa yakalar.)
  /// HeroesRepo'dan bulup aynı kalibrasyonla gücü hesaplar.
  Future<int> heroPowerByIdOrName(int id, String name) async {
    final key = _cacheKey(id, name);
    final cached = _heroPowerCache[key];
    if (cached != null) return cached;

    // HeroUnit'i repo'dan yakala
    HeroUnit? unit;
    try {
      unit = HeroesRepo.I.all.firstWhere((e) => e.id == id);
    } catch (_) {}
    if (unit == null) return 0;

    final p = await heroPower(unit, name);
    _heroPowerCache[key] = p;
    return p;
  }

  Future<int> heroPowerByLabel(String label) async {
    final pairs = await PowerProviders.topHeroes(); // [(HeroUnit, name)]
    for (final pair in pairs) {
      if (pair.$2 == label) {
        return await heroPower(pair.$1, pair.$2);
      }
    }
    return 0;
  }

  /// Tek kahramanın gücü (araştırma+throne+guild+gear+opsiyonel dış modüller)
  Future<int> heroPower(HeroUnit unit, String heroName) async {
    // 1) Base
    double hp = unit.baseHp.toDouble();
    double atk = unit.baseAtk.toDouble();
    double def = unit.baseDef.toDouble();
    double spd = unit.baseSpeed.toDouble();

    // 2) Research Lab
    final rb = ResearchLab.I.computeBonuses();

    // 3) Throne
    final throne = ThroneState.I;

    // 4) Gear (slotlardan)
    final slots = await _EqSlots.loadForHero(heroName);
    final gear = ExtraBonuses()
      ..add(_bonusesFromItem(slots.weapon, _EqSlot.weapon))
      ..add(_bonusesFromItem(slots.ring, _EqSlot.ring))
      ..add(_bonusesFromItem(slots.helmet, _EqSlot.helmet))
      ..add(_bonusesFromItem(slots.armor, _EqSlot.armor));

    // 5) Opsiyonel: gems / stigmata
    final ext = ExtraBonuses();
    if (PowerProviders.gems != null)
      ext.add(await PowerProviders.gems!(heroName));
    if (PowerProviders.stigmata != null)
      ext.add(await PowerProviders.stigmata!(heroName));

    // 6) Yüzdelikleri uygula (AllStats toplamına da dikkat)
    final allStatsPct = rb.allStatsPct + gear.allStatsPct + ext.allStatsPct;

    double hpMul =
        1 +
        (rb.hpPct + gear.hpPct + ext.hpPct + throne.hpBonusPct + allStatsPct) /
            100.0;
    double atkMul =
        1 +
        (rb.atkPct +
                gear.atkPct +
                ext.atkPct +
                throne.atkBonusPct +
                allStatsPct) /
            100.0;
    double defMul =
        1 + (rb.defPct + gear.defPct + ext.defPct + allStatsPct) / 100.0;
    double spdMul =
        1 + (rb.speedPct + gear.speedPct + ext.speedPct + allStatsPct) / 100.0;

    hp *= hpMul;
    atk *= atkMul;
    def *= defMul;
    spd *= spdMul;

    // Helmet vb. düz hız
    spd += gear.speedFlat + ext.speedFlat;

    // 7) Dövüş yan etkileri → çarpan
    final totalCR = ((rb.critPct + gear.critRatePct + ext.critRatePct) / 100.0)
        .clamp(0.0, 1.0);
    final totalCD = ((gear.critDmgPct + ext.critDmgPct) / 100.0);

    double mult = 1.0;
    mult *= (1 + PowerConfig.kCrit * (totalCR * totalCD));

    final trueDmg = rb.trueDmgPct + gear.trueDmgPct + ext.trueDmgPct;
    mult *= (1 + PowerConfig.kTrueDmg * trueDmg / 100.0);

    final holyDmg = gear.holyDmgPct + ext.holyDmgPct;
    mult *= (1 + PowerConfig.kHolyDmg * holyDmg / 100.0);

    mult *=
        (1 +
        PowerConfig.kAccuracy *
            (rb.accuracyPct + gear.accuracyPct + ext.accuracyPct) /
            100.0);
    mult *=
        (1 +
        PowerConfig.kEvasion *
            (rb.evasionPct + gear.evasionPct + ext.evasionPct) /
            100.0);
    mult *= (1 + PowerConfig.kBlock * (gear.blockPct + ext.blockPct) / 100.0);

    final dmgImmu = gear.dmgImmunityPct + ext.dmgImmunityPct;
    mult *= (1 + PowerConfig.kDmgImmunity * dmgImmu / 100.0);

    mult *=
        (1 +
        PowerConfig.kEnergyRegen *
            (rb.energyRegenPct + ext.energyRegenPct) /
            100.0);

    // 8) Faction bazlı research katkıları (örnek basitleştirme)
    final f = unit.faction;
    if (f == Faction.voidF) {
      mult *= (1 + rb.voidAtkPct / 100.0);
    } else if (f == Faction.elemental) {
      mult *= (1 + rb.elementalHpPct / 100.0);
    } else if (f == Faction.mech) {
      mult *= (1 + (rb.mechCritPct / 100.0) * 0.5);
    } else if (f == Faction.nature) {
      mult *= (1 + rb.natureDefPct / 100.0);
    } else if (f == Faction.light) {
      mult *= (1 + rb.lightSpeedPct / 100.0);
    } else if (f == Faction.dark) {
      mult *= (1 + (rb.darkLifestealPct / 100.0) * 0.5);
    }

    // 9) Guild Tech → tekleştirilmiş global çarpan
    mult *= GuildTech.I.powerMultiplier;

    // 10) Ham güç + ölçek
    final raw =
        PowerConfig.wHp * hp +
        PowerConfig.wAtk * atk +
        PowerConfig.wDef * def +
        PowerConfig.wSpd * spd;

    final power = raw * mult * PowerConfig.displayScale;
    return power.isNaN || power.isInfinite ? 0 : power.round();
  }

  /// En güçlü N kahramanın toplam gücü (Commander Power).
  Future<int> teamPower(
    List<(HeroUnit unit, String heroName)> heroes, {
    int topN = 6,
  }) async {
    final list = <int>[];
    for (final h in heroes) {
      list.add(await heroPower(h.$1, h.$2)); // ← 2 POZİSYONEL parametre
    }
    list.sort((a, b) => b.compareTo(a));
    final best = list.take(math.min(topN, list.length));
    return best.fold<int>(0, (s, v) => s + v);
  }

  /// Research + Throne + Guild + (gems/stigmata) dahil
  /// en güçlü 6 kahramanın toplam gücünü hesaplar.
  Future<void> recomputeTop6FromRepo() async {
    final pairs = await PowerProviders.topHeroes(); // null olamaz

    if (pairs.isEmpty) {
      totalPower.value = 0;
      return;
    }

    final powers = <int>[];
    for (final pair in pairs) {
      powers.add(await heroPower(pair.$1, pair.$2));
    }
    powers.sort((a, b) => b.compareTo(a));
    final sum = powers.take(6).fold<int>(0, (s, v) => s + v);

    totalPower.value = sum;
  }

  bool _listenersAttached = false;

  /// Research / Throne / Guild değişince komutan gücünü otomatik hesapla
  void attachListeners() {
    if (_listenersAttached) return;
    void hook() {
      _bumpVersion(); // <— yeni
      recomputeTop6FromRepo();
    }

    ResearchLab.I.version.addListener(hook);
    ThroneState.I.version.addListener(hook);
    GuildTech.I.version.addListener(hook);
    _listenersAttached = true;
  }
}

/// “1.6M” / “23.4K” biçimi (gerekirse)
String fmt(int v) {
  if (v >= 1000000000) return '${(v / 1000000000).toStringAsFixed(1)}B';
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return '$v';
}

/// ------------------------------------------------------------
/// Yardımcılar – Gear
/// ------------------------------------------------------------
double _rarityFactor(EqRarity r) => switch (r) {
  EqRarity.elite => .45,
  EqRarity.epic => .65,
  EqRarity.legendary => .85,
  EqRarity.mythic => 1.00,
};

enum _EqSlot { weapon, ring, helmet, armor }

class _EqSlots {
  final EqItem? weapon, ring, helmet, armor;
  _EqSlots({this.weapon, this.ring, this.helmet, this.armor});

  static Future<_EqSlots> loadForHero(String heroName) async {
    final p = await SharedPreferences.getInstance();
    EqItem? read(String key) {
      final raw = p.getString(key);
      if (raw == null || raw.trim().isEmpty) return null;
      try {
        return EqItem.fromJson(
          (jsonDecode(raw) as Map).cast<String, dynamic>(),
        );
      } catch (_) {
        return null;
      }
    }

    return _EqSlots(
      weapon: read('eq_weapon_$heroName'),
      ring: read('eq_ring_$heroName'),
      helmet: read('eq_helmet_$heroName'),
      armor: read('eq_armor_$heroName'),
    );
  }
}

ExtraBonuses _bonusesFromItem(EqItem? it, _EqSlot slot) {
  final b = ExtraBonuses();
  if (it == null) return b;
  final t = _rarityFactor(it.rarity);

  switch (slot) {
    case _EqSlot.weapon:
      b.atkPct += (0.08 + 0.02 * it.level) * t * 100;
      b.critRatePct += (0.02 * t + 0.002 * it.level) * 100;
      b.critDmgPct += (0.18 * t + 0.02 * it.level) * 100;
      if (it.setKind == 'void') b.trueDmgPct += 2;
      if (it.setKind == 'light') {
        b.holyDmgPct += 5;
        b.energyRegenPct += 5;
      }
      break;

    case _EqSlot.ring:
      b.atkPct += (0.04 * t + 0.01 * it.level) * 100;
      b.critRatePct += (0.01 * t + 0.001 * it.level) * 100;
      b.critDmgPct += (0.12 * t + 0.02 * it.level) * 100;
      if (it.setKind == 'void') b.trueDmgPct += 2;
      if (it.setKind == 'light') b.holyDmgPct += 3;
      break;

    case _EqSlot.helmet:
      b.speedFlat += (4 + it.level).toDouble();
      b.accuracyPct += (0.01 * t + 0.002 * it.level) * 100;
      if (it.setKind == 'void') b.trueDmgPct += 1;
      if (it.setKind == 'light') b.holyDmgPct += 2;
      break;

    case _EqSlot.armor:
      b.hpPct += (0.06 + 0.02 * it.level) * t * 100;
      b.defPct += (0.06 + 0.02 * it.level) * t * 100;
      b.blockPct += (0.02 * (1 + it.level / 10) * t) * 100;
      if (it.setKind == 'void') b.dmgImmunityPct += 2;
      if (it.setKind == 'light') b.holyDmgPct += 3;
      break;
  }
  return b;
}

/// Ekranda gördüğün final stat’lardan gücü hesaplamak için snapshot
class StatSnapshot {
  final double hp, atk, def, spd;
  final double critRatePct, critDmgPct;
  final double accuracyPct, dodgePct, blockPct;
  final double dmgImmunityPct, holyDmgPct, trueDmgPct;
  final double energyRegenPct;

  const StatSnapshot({
    required this.hp,
    required this.atk,
    required this.def,
    required this.spd,
    this.critRatePct = 0,
    this.critDmgPct = 0,
    this.accuracyPct = 0,
    this.dodgePct = 0,
    this.blockPct = 0,
    this.dmgImmunityPct = 0,
    this.holyDmgPct = 0,
    this.trueDmgPct = 0,
    this.energyRegenPct = 0,
  });
}

/// Hangi kalemin ne kadar güç getirdiğini görmek için
class PowerBreakdown {
  final int total;
  final Map<String, int> parts;
  const PowerBreakdown(this.total, this.parts);
}

/// Ekrandaki final stat değerlerinden güç hesapla (milyon ölçekli)
PowerBreakdown powerFromStats(StatSnapshot s) {
  // 1) ham katkılar
  final hpPow = PowerConfig.wHp * s.hp;
  final atkPow = PowerConfig.wAtk * s.atk;
  final defPow = PowerConfig.wDef * s.def;
  final spdPow = PowerConfig.wSpd * s.spd;
  final raw = hpPow + atkPow + defPow + spdPow;

  // 2) yüzde tabanlı dövüş etkileri → çarpan
  double mult = 1.0;

  // crit etkisi: 1 + CR * CD (basitleştirilmiş)
  final cr = (s.critRatePct / 100.0).clamp(0, 1);
  final cd = (s.critDmgPct / 100.0);
  mult *= (1 + PowerConfig.kCrit * (cr * cd));

  mult *= (1 + PowerConfig.kAccuracy * s.accuracyPct / 100.0);
  mult *= (1 + PowerConfig.kEvasion * s.dodgePct / 100.0);
  mult *= (1 + PowerConfig.kBlock * s.blockPct / 100.0);
  mult *= (1 + PowerConfig.kDmgImmunity * s.dmgImmunityPct / 100.0);
  mult *= (1 + PowerConfig.kTrueDmg * s.trueDmgPct / 100.0);
  mult *= (1 + PowerConfig.kHolyDmg * s.holyDmgPct / 100.0);
  mult *= (1 + PowerConfig.kEnergyRegen * s.energyRegenPct / 100.0);

  // 3) toplam ve ölçek
  final total = (raw * mult * PowerConfig.displayScale).round();

  // Breakdown (yaklaşık): çarpanı ham parçaya orantılı dağıt
  double share(double base) => (base / raw) * total;
  final parts = <String, int>{
    'HP': share(hpPow).round(),
    'ATK': share(atkPow).round(),
    'DEF': share(defPow).round(),
    'SPD': share(spdPow).round(),
    'Crit/Other Mult':
        (total - (share(hpPow) + share(atkPow) + share(defPow) + share(spdPow)))
            .round(),
  };

  return PowerBreakdown(total, parts);
}
