import 'dart:math';
import 'package:flutter/material.dart';
import 'package:overthrone/features/heroes/hero_types.dart';
import 'package:overthrone/battle/battle_models.dart';

/// Boss definitions
class BossData {
  final int id;
  final String name;
  final String title;
  final Faction faction;
  final int hp;
  final int atk;
  final int def;
  final int speed;
  final int recommendedPower;
  final List<CombatAbility> abilities;
  final BossLootTable loot;

  const BossData({
    required this.id,
    required this.name,
    required this.title,
    required this.faction,
    required this.hp,
    required this.atk,
    required this.def,
    required this.speed,
    required this.recommendedPower,
    required this.abilities,
    required this.loot,
  });

  CombatUnit toCombatUnit() => CombatUnit(
    id: 9000 + id,
    name: name,
    isAlly: false,
    dmgType: faction.defaultDmgType,
    defType: DefenseType.fortified,
    factionIcon: faction.icon,
    color: _bossColor(faction),
    maxHp: hp,
    baseAtk: atk,
    baseDef: def,
    baseSpeed: speed,
    abilities: abilities,
    critRate: 0.15,
    critDmg: 2.0,
  );
}

Color _bossColor(Faction f) => switch (f) {
  Faction.elemental => Colors.deepPurple,
  Faction.dark => const Color(0xFF8B0000),
  Faction.nature => Colors.teal,
  Faction.mech => Colors.blueGrey,
  Faction.voidF => const Color(0xFF2D0050),
  Faction.light => Colors.orange,
};

class BossLootTable {
  final Map<String, int> guaranteed; // always drops
  final Map<String, double> chance;  // item -> probability

  const BossLootTable({this.guaranteed = const {}, this.chance = const {}});

  Map<String, int> roll(Random rng) {
    final drops = Map<String, int>.from(guaranteed);
    for (final entry in chance.entries) {
      if (rng.nextDouble() < entry.value) {
        drops[entry.key] = (drops[entry.key] ?? 0) + 1;
      }
    }
    return drops;
  }
}

/// All bosses
final List<BossData> allBosses = [
  BossData(
    id: 1,
    name: 'Drakonis',
    title: 'The Flame Emperor',
    faction: Faction.elemental,
    hp: 500000,
    atk: 2500,
    def: 800,
    speed: 60,
    recommendedPower: 10000,
    abilities: const [
      CombatAbility(name: 'Dragon Breath', description: 'AoE fire', multiplier: 1.5, isAoe: true),
      CombatAbility(name: 'Tail Swipe', description: 'Heavy strike', multiplier: 2.0),
      CombatAbility(name: 'Inferno', description: 'Ultimate AoE burn', multiplier: 1.8, isAoe: true, isUltimate: true,
        appliedEffect: StatusEffect(name: 'Burn', duration: 3, dotDmg: 200)),
    ],
    loot: BossLootTable(
      guaranteed: {'Ingots': 5, 'Gold': 50000},
      chance: {'Stigmata Cores': 0.4, 'Gem Fragments': 0.5, 'Equipment Blueprints': 0.2},
    ),
  ),
  BossData(
    id: 2,
    name: 'Umbralord',
    title: 'Shadow King',
    faction: Faction.dark,
    hp: 600000,
    atk: 2800,
    def: 700,
    speed: 70,
    recommendedPower: 15000,
    abilities: const [
      CombatAbility(name: 'Shadow Strike', description: 'Dark slash', multiplier: 1.8),
      CombatAbility(name: 'Curse', description: 'Weaken target', multiplier: 0.5,
        appliedEffect: StatusEffect(name: 'Cursed', duration: 3, atkMod: 0.7, defMod: 0.7)),
      CombatAbility(name: 'Eclipse', description: 'AoE darkness', multiplier: 1.6, isAoe: true, isUltimate: true),
    ],
    loot: BossLootTable(
      guaranteed: {'Sigils': 3, 'Hero Shards': 2, 'Gold': 80000},
      chance: {'Stigmata Cores': 0.5, 'Gem Fragments': 0.6, 'Crowns': 0.1},
    ),
  ),
  BossData(
    id: 3,
    name: 'Mechagod',
    title: 'The Iron Titan',
    faction: Faction.mech,
    hp: 800000,
    atk: 3200,
    def: 1200,
    speed: 45,
    recommendedPower: 25000,
    abilities: const [
      CombatAbility(name: 'Laser Beam', description: 'Pure damage', multiplier: 2.2),
      CombatAbility(name: 'EMP Blast', description: 'AoE stun', multiplier: 0.8, isAoe: true,
        appliedEffect: StatusEffect(name: 'Stunned', duration: 1, stunned: true)),
      CombatAbility(name: 'Annihilate', description: 'Devastating AoE', multiplier: 2.0, isAoe: true, isUltimate: true),
    ],
    loot: BossLootTable(
      guaranteed: {'Equipment Blueprints': 3, 'Cores': 2, 'Gold': 120000},
      chance: {'Stigmata Cores': 0.6, 'Gem Fragments': 0.7, 'Crowns': 0.15},
    ),
  ),
  BossData(
    id: 4,
    name: 'Yggdrasil',
    title: 'World Tree Guardian',
    faction: Faction.nature,
    hp: 700000,
    atk: 2200,
    def: 1500,
    speed: 40,
    recommendedPower: 20000,
    abilities: const [
      CombatAbility(name: 'Root Crush', description: 'Entangle and crush', multiplier: 1.6,
        appliedEffect: StatusEffect(name: 'Rooted', duration: 2, spdMod: 0.3)),
      CombatAbility(name: 'Nature Heal', description: 'Self heal', isHeal: true, healRatio: 2.0),
      CombatAbility(name: 'Wrath of Nature', description: 'AoE nature', multiplier: 1.5, isAoe: true, isUltimate: true),
    ],
    loot: BossLootTable(
      guaranteed: {'Ingots': 8, 'Sigils': 4, 'Gold': 100000},
      chance: {'Hero Shards': 0.4, 'Gem Fragments': 0.5, 'Stigmata Cores': 0.3},
    ),
  ),
  BossData(
    id: 5,
    name: 'Voidlord',
    title: 'The Endless Abyss',
    faction: Faction.voidF,
    hp: 1000000,
    atk: 3500,
    def: 900,
    speed: 80,
    recommendedPower: 40000,
    abilities: const [
      CombatAbility(name: 'Void Rend', description: 'Pure void damage', multiplier: 2.5),
      CombatAbility(name: 'Silence', description: 'Silence all', multiplier: 0.3, isAoe: true,
        appliedEffect: StatusEffect(name: 'Silenced', duration: 2, silenced: true)),
      CombatAbility(name: 'Oblivion', description: 'Erase existence', multiplier: 3.0, isUltimate: true),
    ],
    loot: BossLootTable(
      guaranteed: {'Crowns': 2, 'Cores': 5, 'Hero Shards': 5, 'Gold': 200000},
      chance: {'Stigmata Cores': 0.7, 'Gem Fragments': 0.8, 'Equipment Blueprints': 0.4},
    ),
  ),
];
