import 'dart:math';
import 'package:flutter/material.dart';
import 'package:overthrone/features/heroes/hero_types.dart';
import 'package:overthrone/battle/battle_models.dart';

/// Stage definition for PvE campaign
class StageData {
  final int chapter;    // 1-10
  final int stage;      // 1-10
  final String name;
  final int recommendedPower;
  final List<EnemyTemplate> enemies;
  final StageReward reward;

  const StageData({
    required this.chapter,
    required this.stage,
    required this.name,
    required this.recommendedPower,
    required this.enemies,
    required this.reward,
  });

  String get id => '$chapter-$stage';
  int get absoluteIndex => (chapter - 1) * 10 + (stage - 1);
}

/// Template for enemy unit in a stage
class EnemyTemplate {
  final String name;
  final Faction faction;
  final Role role;
  final int hp;
  final int atk;
  final int def;
  final int speed;

  const EnemyTemplate({
    required this.name,
    required this.faction,
    required this.role,
    required this.hp,
    required this.atk,
    required this.def,
    required this.speed,
  });

  CombatUnit toCombatUnit(int id) {
    return CombatUnit(
      id: 1000 + id,
      name: name,
      isAlly: false,
      dmgType: faction.defaultDmgType,
      defType: role.defaultDefType,
      factionIcon: faction.icon,
      color: _factionColor(faction),
      maxHp: hp,
      baseAtk: atk,
      baseDef: def,
      baseSpeed: speed,
      abilities: _defaultAbilities(role),
    );
  }
}

Color _factionColor(Faction f) => switch (f) {
  Faction.elemental => Colors.blue,
  Faction.dark => Colors.purple,
  Faction.nature => Colors.green,
  Faction.mech => Colors.cyan,
  Faction.voidF => Colors.indigo,
  Faction.light => Colors.amber,
};

List<CombatAbility> _defaultAbilities(Role role) {
  switch (role) {
    case Role.warrior:
      return const [
        CombatAbility(name: 'Slash', description: 'Heavy melee strike', multiplier: 1.2),
        CombatAbility(name: 'Shield Bash', description: 'Stun target', multiplier: 0.8,
          appliedEffect: StatusEffect(name: 'Stunned', duration: 1, stunned: true)),
        CombatAbility(name: 'Warcry', description: 'AoE attack', multiplier: 0.7, isAoe: true, isUltimate: true),
      ];
    case Role.ranger:
      return const [
        CombatAbility(name: 'Arrow Shot', description: 'Ranged attack', multiplier: 1.1),
        CombatAbility(name: 'Volley', description: 'AoE arrows', multiplier: 0.6, isAoe: true),
        CombatAbility(name: 'Snipe', description: 'Critical shot', multiplier: 2.0, isUltimate: true),
      ];
    case Role.raider:
      return const [
        CombatAbility(name: 'Backstab', description: 'Sneak attack', multiplier: 1.4),
        CombatAbility(name: 'Poison Blade', description: 'Apply poison', multiplier: 0.9,
          appliedEffect: StatusEffect(name: 'Poison', duration: 3, dotDmg: 50)),
        CombatAbility(name: 'Assassinate', description: 'Lethal strike', multiplier: 2.5, isUltimate: true),
      ];
    case Role.healer:
      return const [
        CombatAbility(name: 'Smite', description: 'Holy attack', multiplier: 0.7),
        CombatAbility(name: 'Heal', description: 'Restore ally HP', isHeal: true, healRatio: 1.5),
        CombatAbility(name: 'Divine Light', description: 'AoE heal', isHeal: true, healRatio: 0.8, isUltimate: true),
      ];
    case Role.mage:
      return const [
        CombatAbility(name: 'Fireball', description: 'Magic attack', multiplier: 1.3),
        CombatAbility(name: 'Blizzard', description: 'AoE magic', multiplier: 0.8, isAoe: true,
          appliedEffect: StatusEffect(name: 'Frozen', duration: 1, spdMod: 0.5)),
        CombatAbility(name: 'Meteor', description: 'Ultimate AoE', multiplier: 1.2, isAoe: true, isUltimate: true),
      ];
  }
}

/// Reward for completing a stage
class StageReward {
  final int gold;
  final int xp;
  final Map<String, int> materials; // item name -> count

  const StageReward({
    this.gold = 0,
    this.xp = 0,
    this.materials = const {},
  });
}

/// Generate all 100 stages (10 chapters × 10 stages)
final List<StageData> allStages = _generateStages();

List<StageData> _generateStages() {
  final rng = Random(42);
  final stages = <StageData>[];
  final factions = Faction.values;
  final roles = Role.values;

  for (int ch = 1; ch <= 10; ch++) {
    for (int st = 1; st <= 10; st++) {
      final idx = (ch - 1) * 10 + (st - 1);
      final power = 300 + (idx * 500); // 300 -> 50,000
      final scale = 1.0 + idx * 0.12;

      // Enemy count: 3-6 based on stage
      final enemyCount = 3 + (idx ~/ 25).clamp(0, 3);

      final enemies = List.generate(enemyCount, (i) {
        final f = factions[(idx + i) % factions.length];
        final r = roles[(idx + i) % roles.length];
        final nameParts = ['Scout', 'Guard', 'Enforcer', 'Champion', 'Warlord', 'Overlord'];
        final nameIdx = (idx ~/ 17 + i) % nameParts.length;

        return EnemyTemplate(
          name: '${f.label} ${nameParts[nameIdx]}',
          faction: f,
          role: r,
          hp: (800 * scale + rng.nextInt(200)).round(),
          atk: (60 * scale + rng.nextInt(20)).round(),
          def: (40 * scale + rng.nextInt(15)).round(),
          speed: 45 + rng.nextInt(25),
        );
      });

      final chapterNames = [
        'Frontier', 'Darkwood', 'Iron Peaks', 'Void Rift',
        'Sunken Temple', 'Storm Citadel', 'Shadow Realm',
        'Mechforge', 'Celestial Gate', 'Throne of Ruin',
      ];

      stages.add(StageData(
        chapter: ch,
        stage: st,
        name: '${chapterNames[ch - 1]} $ch-$st',
        recommendedPower: power,
        enemies: enemies,
        reward: StageReward(
          gold: 1000 + idx * 500,
          xp: 50 + idx * 10,
          materials: {
            if (idx % 3 == 0) 'Ingots': 1 + idx ~/ 10,
            if (idx % 5 == 0) 'Sigils': 1 + idx ~/ 15,
            if (idx % 7 == 0) 'Hero Shards': 1 + idx ~/ 20,
            if (idx % 4 == 0) 'Gem Fragments': 2 + idx ~/ 8,
          },
        ),
      ));
    }
  }
  return stages;
}
