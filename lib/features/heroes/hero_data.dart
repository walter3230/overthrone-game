import 'package:flutter/material.dart';
import '../research/research_data.dart';
import 'hero_portrait.dart';
import 'hero_types.dart' show Role, Faction;

// -----------------------------
// Model
// -----------------------------
class HeroUnit {
  final int id;
  final String name;
  final Color a, b; // card gradient / accent
  final int baseHp;
  final int baseAtk;
  final int baseDef;
  final int baseSpeed;
  final Faction faction;

  const HeroUnit({
    required this.id,
    required this.name,
    required this.a,
    required this.b,
    required this.faction,
    required this.baseHp,
    required this.baseAtk,
    required this.baseDef,
    required this.baseSpeed,
  });

  /// Eski kodlarla uyum: bazı UI’ler h.power okuyor olabilir.
  /// Artık power = araştırma etkileri uygulanmış efektif güç.
  int get power => effectivePower();

  /// Basit taban güç formülü (araştırma etkisiz)
  int get basePower =>
      baseHp + (baseAtk * 2) + (baseDef * 15 ~/ 10) + (baseSpeed * 3);

  /// Araştırma bonuslarını gerçek statlara uygula → efektif güç
  int effectivePower() {
    final b = ResearchLab.I.computeBonuses();

    // Yüzdelik bufflar
    double hp = baseHp * (1 + b.hpPct / 100.0);
    double atk = baseAtk * (1 + b.atkPct / 100.0);
    double def = baseDef * (1 + b.defPct / 100.0);
    double spd = baseSpeed * (1 + b.speedPct / 100.0);

    // Kritik/All-stats gibi global minör etkileri güce çarpan olarak yedir
    double multiplier = 1.0;
    multiplier += b.critPct / 200.0; // %10 crit ~ %5 power etkisi
    multiplier += b.allStatsPct / 100.0; // “all stats” doğrudan %power

    // Fraksiyon bazlı satırlar → ek çarpan
    switch (faction) {
      case Faction.voidF:
        multiplier += b.voidAtkPct / 100.0;
        break;
      case Faction.elemental:
        multiplier += b.elementalHpPct / 100.0;
        break;
      case Faction.mech:
        multiplier += b.mechCritPct / 200.0; // crit benzetmesi
        break;
      case Faction.nature:
        multiplier += b.natureDefPct / 100.0;
        break;
      case Faction.light:
        multiplier += b.lightSpeedPct / 100.0;
        break;
      case Faction.dark:
        multiplier += b.darkLifestealPct / 200.0; // lifesteal ~ yarım güç
        break;
    }

    final raw = hp + atk * 2 + def * 1.5 + spd * 3;
    return (raw * multiplier).round();
  }

  // Eski kodların çağırıp NULL beklediği yerler olabilir—bozmamak için bıraktım.
  get rarity => null;
  IconData? get emblem => null;
}

// -----------------------------
// Repository (singleton)
// -----------------------------
class HeroesRepo {
  HeroesRepo._();
  static final HeroesRepo I = HeroesRepo._().._seed();

  final List<HeroUnit> _heroes = [];

  List<HeroUnit> get all => List.unmodifiable(_heroes);

  // Top-6 seçimi ve başka yerler bununla çalışıyor
  List<HeroUnit> get allUnits => List.unmodifiable(_heroes);

  // Uyum için nullable imza korundu; bulamazsa ilk elemanı döndürür.
  HeroUnit? byId(int id) =>
      _heroes.firstWhere((h) => h.id == id, orElse: () => _heroes.first);

  // Küçük yuvarlak thumb (Home'daki defense grid için)
  Widget thumb(int id) {
    final h = byId(id);
    if (h == null) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: Colors.blueGrey.withValues(alpha: .25),
        child: const Text('?', style: TextStyle(fontWeight: FontWeight.w900)),
      );
    }
    return ClipOval(
      child: HeroPortrait(
        name: h.name,
        faction: h.faction,
        role: _roleFromFaction(h.faction),
        size: 28,
        borderRadius: 14,
      ),
    );
  }

  static Role _roleFromFaction(Faction f) => switch (f) {
    Faction.light => Role.healer,
    Faction.dark => Role.raider,
    Faction.voidF => Role.mage,
    Faction.nature => Role.ranger,
    Faction.mech => Role.warrior,
    Faction.elemental => Role.mage,
  };

  // Kullanışlı yardımcılar
  int effectivePowerOf(HeroUnit h) => h.effectivePower();
  int effectivePowerById(int id) => (byId(id))?.effectivePower() ?? 0;

  // -----------------------------
  // Seed (örnek ~100 kahraman)
  // -----------------------------
  void _seed() {
    final names = <String>[
      'Halo',
      'Celestia',
      'Radiant',
      'Vow',
      'Dawn',
      'Seraph',
      'Beacon',
      'Lumina',
      'Solaria',
      'Althea',
      'Divina',
      'Auriel',
      'Elyra',
      'Sanctis',
      'Oriana',
      'Gloria',
      'Lumen',
      'Null',
      'Rift',
      'Echo',
      'Singularity',
      'Worm',
      'Aether',
      'Phase',
      'Oblivion',
      'Nyx',
      'Eclipse',
      'Anomaly',
      'Fractis',
      'Eventide',
      'Umbra',
      'Parallax',
      'Xerath',
      'Abyssion',
      'Shade',
      'Hex',
      'Gloom',
      'Abyss',
      'Ruin',
      'Dread',
      'Noctis',
      'Morrow',
      'Malice',
      'Cinderveil',
      'Morgrim',
      'Tenebris',
      'Veyra',
      'Draven',
      'Ebonfang',
      'Wraith',
      'Necros',
      'Thorn',
      'Grove',
      'Bloom',
      'Fang',
      'Bark',
      'Vine',
      'Wild',
      'Antler',
      'Sylva',
      'Oakheart',
      'Bramblescar',
      'Leafshade',
      'Mossfang',
      'Elderthorn',
      'Lupiris',
      'Verdantis',
      'Rootclaw',
      'Bolt',
      'Gear',
      'Core',
      'Pulse',
      'Circuit',
      'Alloy',
      'Drive',
      'Vector',
      'Mechron',
      'Synthra',
      'Axion',
      'Voltforge',
      'Cryon',
      'Titanex',
      'Dynatron',
      'Nexus',
      'Kryonix',
      'Storm',
      'Flare',
      'Glacier',
      'Quake',
      'Spark',
      'Tempest',
      'Cinder',
      'Torrent',
      'Pyra',
      'Ignis',
      'Frostveil',
      'Seirra',
      'Aqualis',
      'Magnar',
      'Voltra',
      'Shadra',
      'Terranis',
    ];

    final factions = Faction.values;

    for (var i = 0; i < names.length; i++) {
      // Taban statlar (örnek dağılım)
      final baseHp = 950 + (i % 25) * 25; // ~950..1575
      final baseAtk = 95 + (i % 20) * 5; // ~95..190
      final baseDef = 70 + (i % 18) * 4; // ~70..142
      final baseSpeed = 48 + (i % 12) * 2; // ~48..70

      _heroes.add(
        HeroUnit(
          id: i, // id=index → DefenseSetup ile birebir
          name: names[i],
          a: Colors.primaries[i % Colors.primaries.length],
          b: Colors.primaries[(i + 5) % Colors.primaries.length],
          faction: factions[i % factions.length],
          baseHp: baseHp,
          baseAtk: baseAtk,
          baseDef: baseDef,
          baseSpeed: baseSpeed,
        ),
      );
    }
  }

  load() {}
}
