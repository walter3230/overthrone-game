// lib/core/synergy_system.dart
import 'package:overthrone/features/heroes/hero_types.dart';

/// Kahramanlar arası sinerji sistemi - faction bazlı bonuslar
/// X-Heroes / AFK Arena tarzı faction synergy mekanikleri

/// Sinerji seviyesi ve bonus tanımı
class SynergyBonus {
  final String name;
  final String desc;
  final int requiredCount; // Bu faction'dan kaç hero gerekiyor
  final double atkPct;
  final double hpPct;
  final double defPct;
  final double speedPct;
  final double critPct;
  final double extraPowerPct;

  SynergyBonus({
    required this.name,
    required this.desc,
    required this.requiredCount,
    this.atkPct = 0,
    this.hpPct = 0,
    this.defPct = 0,
    this.speedPct = 0,
    this.critPct = 0,
    this.extraPowerPct = 0,
  });
}

/// Faction sinerji tanımları
class FactionSynergies {
  FactionSynergies._();

  /// Her faction için sinerji katmanları (2, 3, 4+ hero ile aktifleşir)
  static final Map<Faction, List<SynergyBonus>> tiers = {
    Faction.elemental: [
      SynergyBonus(
        name: 'Elemental Surge',
        desc: 'ATK +8%, Speed +5%',
        requiredCount: 2,
        atkPct: 8,
        speedPct: 5,
      ),
      SynergyBonus(
        name: 'Elemental Storm',
        desc: 'ATK +15%, Speed +10%, Crit +8%',
        requiredCount: 3,
        atkPct: 15,
        speedPct: 10,
        critPct: 8,
        extraPowerPct: 5,
      ),
      SynergyBonus(
        name: 'Primal Cataclysm',
        desc: 'ATK +22%, Speed +15%, Crit +12%, +10% Power',
        requiredCount: 4,
        atkPct: 22,
        speedPct: 15,
        critPct: 12,
        extraPowerPct: 10,
      ),
    ],
    Faction.dark: [
      SynergyBonus(
        name: 'Shadow Pact',
        desc: 'Crit +10%, ATK +5%',
        requiredCount: 2,
        critPct: 10,
        atkPct: 5,
      ),
      SynergyBonus(
        name: 'Void Darkness',
        desc: 'Crit +18%, ATK +12%, DEF +5%',
        requiredCount: 3,
        critPct: 18,
        atkPct: 12,
        defPct: 5,
        extraPowerPct: 7,
      ),
      SynergyBonus(
        name: 'Eclipse Dominion',
        desc: 'Crit +25%, ATK +18%, DEF +10%, +12% Power',
        requiredCount: 4,
        critPct: 25,
        atkPct: 18,
        defPct: 10,
        extraPowerPct: 12,
      ),
    ],
    Faction.nature: [
      SynergyBonus(
        name: 'Verdant Bond',
        desc: 'HP +10%, DEF +8%',
        requiredCount: 2,
        hpPct: 10,
        defPct: 8,
      ),
      SynergyBonus(
        name: 'Ancient Grove',
        desc: 'HP +18%, DEF +15%, ATK +5%',
        requiredCount: 3,
        hpPct: 18,
        defPct: 15,
        atkPct: 5,
        extraPowerPct: 6,
      ),
      SynergyBonus(
        name: 'World Tree Awakening',
        desc: 'HP +25%, DEF +22%, ATK +10%, +8% Power',
        requiredCount: 4,
        hpPct: 25,
        defPct: 22,
        atkPct: 10,
        extraPowerPct: 8,
      ),
    ],
    Faction.mech: [
      SynergyBonus(
        name: 'Circuit Link',
        desc: 'Speed +8%, ATK +5%',
        requiredCount: 2,
        speedPct: 8,
        atkPct: 5,
      ),
      SynergyBonus(
        name: 'Overclock',
        desc: 'Speed +15%, ATK +10%, Crit +5%',
        requiredCount: 3,
        speedPct: 15,
        atkPct: 10,
        critPct: 5,
        extraPowerPct: 7,
      ),
      SynergyBonus(
        name: 'Titan Protocol',
        desc: 'Speed +22%, ATK +18%, Crit +10%, +10% Power',
        requiredCount: 4,
        speedPct: 22,
        atkPct: 18,
        critPct: 10,
        extraPowerPct: 10,
      ),
    ],
    Faction.voidF: [
      SynergyBonus(
        name: 'Rift Resonance',
        desc: 'ATK +10%, HP +5%',
        requiredCount: 2,
        atkPct: 10,
        hpPct: 5,
      ),
      SynergyBonus(
        name: 'Abyssal Rift',
        desc: 'ATK +18%, HP +10%, Crit +8%',
        requiredCount: 3,
        atkPct: 18,
        hpPct: 10,
        critPct: 8,
        extraPowerPct: 8,
      ),
      SynergyBonus(
        name: 'Singularity',
        desc: 'ATK +25%, HP +15%, Crit +12%, +15% Power',
        requiredCount: 4,
        atkPct: 25,
        hpPct: 15,
        critPct: 12,
        extraPowerPct: 15,
      ),
    ],
    Faction.light: [
      SynergyBonus(
        name: 'Radiant Bond',
        desc: 'HP +8%, DEF +5%, Speed +5%',
        requiredCount: 2,
        hpPct: 8,
        defPct: 5,
        speedPct: 5,
      ),
      SynergyBonus(
        name: 'Divine Shield',
        desc: 'HP +15%, DEF +12%, Speed +8%, ATK +5%',
        requiredCount: 3,
        hpPct: 15,
        defPct: 12,
        speedPct: 8,
        atkPct: 5,
        extraPowerPct: 7,
      ),
      SynergyBonus(
        name: 'Celestial Ascension',
        desc: 'HP +22%, DEF +18%, Speed +12%, ATK +10%, +12% Power',
        requiredCount: 4,
        hpPct: 22,
        defPct: 18,
        speedPct: 12,
        atkPct: 10,
        extraPowerPct: 12,
      ),
    ],
  };

  /// Cross-faction sinerjileri (2 farklı faction'dan belirli kombinasyonlar)
  static final List<CrossFactionSynergy> crossSynergies = [
    CrossFactionSynergy(
      factionA: Faction.voidF,
      factionB: Faction.light,
      name: 'Twilight Balance',
      desc: 'ATK +10%, DEF +10%',
      requiredFromEach: 1,
      atkPct: 10,
      defPct: 10,
    ),
    CrossFactionSynergy(
      factionA: Faction.dark,
      factionB: Faction.elemental,
      name: 'Chaos Magic',
      desc: 'Crit +12%, ATK +8%',
      requiredFromEach: 1,
      critPct: 12,
      atkPct: 8,
    ),
    CrossFactionSynergy(
      factionA: Faction.nature,
      factionB: Faction.mech,
      name: 'Bio-Mech Fusion',
      desc: 'HP +10%, Speed +8%',
      requiredFromEach: 1,
      hpPct: 10,
      speedPct: 8,
    ),
    CrossFactionSynergy(
      factionA: Faction.light,
      factionB: Faction.nature,
      name: 'Sacred Grove',
      desc: 'HP +12%, DEF +8%',
      requiredFromEach: 1,
      hpPct: 12,
      defPct: 8,
    ),
    CrossFactionSynergy(
      factionA: Faction.voidF,
      factionB: Faction.dark,
      name: 'Null Shadow',
      desc: 'ATK +15%, Crit +8%',
      requiredFromEach: 1,
      atkPct: 15,
      critPct: 8,
    ),
  ];

  /// Verilen kahraman listesinden aktif sinerjileri hesapla
  static List<ActiveSynergy> compute(List<Faction> factions) {
    final result = <ActiveSynergy>[];

    // Faction sayılarını hesapla
    final counts = <Faction, int>{};
    for (final f in factions) {
      counts[f] = (counts[f] ?? 0) + 1;
    }

    // Her faction için aktif sinerji katmanlarını bul
    for (final f in Faction.values) {
      final count = counts[f] ?? 0;
      if (count < 2) continue;

      final tiers = FactionSynergies.tiers[f] ?? [];
      SynergyBonus? best;
      for (final t in tiers) {
        if (count >= t.requiredCount) best = t;
      }

      if (best != null) {
        result.add(ActiveSynergy(
          faction: f,
          heroCount: count,
          bonus: best,
        ));
      }
    }

    // Cross-faction sinerjileri
    for (final cs in crossSynergies) {
      final countA = counts[cs.factionA] ?? 0;
      final countB = counts[cs.factionB] ?? 0;
      if (countA >= cs.requiredFromEach && countB >= cs.requiredFromEach) {
        result.add(ActiveSynergy(
          faction: cs.factionA,
          heroCount: countA + countB,
          bonus: SynergyBonus(
            name: cs.name,
            desc: cs.desc,
            requiredCount: cs.requiredFromEach * 2,
            atkPct: cs.atkPct,
            hpPct: cs.hpPct,
            defPct: cs.defPct,
            speedPct: cs.speedPct,
            critPct: cs.critPct,
          ),
          isCrossFaction: true,
          crossFaction: cs.factionB,
        ));
      }
    }

    return result;
  }
}

/// Cross-faction sinerji tanımı
class CrossFactionSynergy {
  final Faction factionA;
  final Faction factionB;
  final String name;
  final String desc;
  final int requiredFromEach;
  final double atkPct;
  final double hpPct;
  final double defPct;
  final double speedPct;
  final double critPct;

  CrossFactionSynergy({
    required this.factionA,
    required this.factionB,
    required this.name,
    required this.desc,
    required this.requiredFromEach,
    this.atkPct = 0,
    this.hpPct = 0,
    this.defPct = 0,
    this.speedPct = 0,
    this.critPct = 0,
  });
}

/// Aktif sinerji sonucu
class ActiveSynergy {
  final Faction faction;
  final int heroCount;
  final SynergyBonus bonus;
  final bool isCrossFaction;
  final Faction? crossFaction;

  ActiveSynergy({
    required this.faction,
    required this.heroCount,
    required this.bonus,
    this.isCrossFaction = false,
    this.crossFaction,
  });
}

/// Sinerji toplam bonus hesaplayıcı
class SynergyCalculator {
  /// Verilen aktif sinerjilerin toplam bonusunu hesapla
  static SynergyTotalBonus sum(List<ActiveSynergy> synergies) {
    final total = SynergyTotalBonus();
    for (final s in synergies) {
      total.atkPct += s.bonus.atkPct;
      total.hpPct += s.bonus.hpPct;
      total.defPct += s.bonus.defPct;
      total.speedPct += s.bonus.speedPct;
      total.critPct += s.bonus.critPct;
      total.extraPowerPct += s.bonus.extraPowerPct;
    }
    return total;
  }
}

class SynergyTotalBonus {
  double atkPct = 0;
  double hpPct = 0;
  double defPct = 0;
  double speedPct = 0;
  double critPct = 0;
  double extraPowerPct = 0;

  bool get hasAnyBonus =>
      atkPct > 0 || hpPct > 0 || defPct > 0 || speedPct > 0 || critPct > 0;
}
