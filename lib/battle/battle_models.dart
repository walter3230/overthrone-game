import 'package:flutter/material.dart';
import 'package:overthrone/features/heroes/hero_types.dart';

export 'package:overthrone/features/heroes/hero_types.dart' show DamageType, DefenseType;

/// Type advantage multiplier
double dmgTypeMultiplier(DamageType atk, DefenseType def) {
  const table = <DamageType, Map<DefenseType, double>>{
    DamageType.physical: {
      DefenseType.armored: 0.7,
      DefenseType.warded: 1.3,
      DefenseType.balanced: 1.0,
      DefenseType.ethereal: 1.1,
      DefenseType.fortified: 0.8,
    },
    DamageType.magical: {
      DefenseType.armored: 1.3,
      DefenseType.warded: 0.7,
      DefenseType.balanced: 1.0,
      DefenseType.ethereal: 1.1,
      DefenseType.fortified: 0.9,
    },
    DamageType.pure: {
      DefenseType.armored: 1.0,
      DefenseType.warded: 1.0,
      DefenseType.balanced: 1.0,
      DefenseType.ethereal: 1.4,
      DefenseType.fortified: 1.0,
    },
    DamageType.holy: {
      DefenseType.armored: 1.0,
      DefenseType.warded: 1.0,
      DefenseType.balanced: 1.1,
      DefenseType.ethereal: 1.5,
      DefenseType.fortified: 0.9,
    },
    DamageType.dark: {
      DefenseType.armored: 1.1,
      DefenseType.warded: 1.0,
      DefenseType.balanced: 1.0,
      DefenseType.ethereal: 0.8,
      DefenseType.fortified: 1.2,
    },
    DamageType.nature: {
      DefenseType.armored: 1.0,
      DefenseType.warded: 1.2,
      DefenseType.balanced: 1.0,
      DefenseType.ethereal: 1.0,
      DefenseType.fortified: 1.1,
    },
  };
  return table[atk]?[def] ?? 1.0;
}

/// Status effect on a unit
class StatusEffect {
  final String name;
  final int duration; // turns remaining
  final double atkMod;   // multiplier (1.0 = no change)
  final double defMod;
  final double spdMod;
  final int dotDmg;      // damage per turn (poison, burn)
  final int hotHeal;     // heal per turn (regen)
  final bool stunned;
  final bool silenced;   // can't use abilities

  const StatusEffect({
    required this.name,
    this.duration = 2,
    this.atkMod = 1.0,
    this.defMod = 1.0,
    this.spdMod = 1.0,
    this.dotDmg = 0,
    this.hotHeal = 0,
    this.stunned = false,
    this.silenced = false,
  });

  StatusEffect tick() => StatusEffect(
    name: name,
    duration: duration - 1,
    atkMod: atkMod,
    defMod: defMod,
    spdMod: spdMod,
    dotDmg: dotDmg,
    hotHeal: hotHeal,
    stunned: stunned,
    silenced: silenced,
  );

  bool get expired => duration <= 0;
}

/// A unit in combat
class CombatUnit {
  final int id;
  final String name;
  final bool isAlly;
  final DamageType dmgType;
  final DefenseType defType;
  final IconData factionIcon;
  final Color color;

  // Base stats
  final int maxHp;
  int currentHp;
  final int baseAtk;
  final int baseDef;
  final int baseSpeed;

  // Combat modifiers
  double critRate;
  double critDmg;
  int energy; // 0-100, ultimate at 100

  // Abilities
  final List<CombatAbility> abilities;

  // Active status effects
  final List<StatusEffect> effects = [];

  CombatUnit({
    required this.id,
    required this.name,
    required this.isAlly,
    required this.dmgType,
    required this.defType,
    required this.factionIcon,
    required this.color,
    required this.maxHp,
    required this.baseAtk,
    required this.baseDef,
    required this.baseSpeed,
    required this.abilities,
    this.critRate = 0.1,
    this.critDmg = 1.5,
  }) : currentHp = maxHp, energy = 0;

  bool get isDead => currentHp <= 0;
  bool get isAlive => currentHp > 0;
  double get hpRatio => currentHp / maxHp;

  int get effectiveAtk {
    double m = 1.0;
    for (final e in effects) m *= e.atkMod;
    return (baseAtk * m).round();
  }

  int get effectiveDef {
    double m = 1.0;
    for (final e in effects) m *= e.defMod;
    return (baseDef * m).round();
  }

  int get effectiveSpeed {
    double m = 1.0;
    for (final e in effects) m *= e.spdMod;
    return (baseSpeed * m).round();
  }

  bool get isStunned => effects.any((e) => e.stunned);
  bool get isSilenced => effects.any((e) => e.silenced);

  bool get canUseUltimate => energy >= 100 && !isSilenced;

  void gainEnergy(int amount) {
    energy = (energy + amount).clamp(0, 100);
  }

  void applyDamage(int dmg) {
    currentHp = (currentHp - dmg).clamp(0, maxHp);
  }

  void applyHeal(int heal) {
    currentHp = (currentHp + heal).clamp(0, maxHp);
  }

  void tickEffects() {
    // Apply DoT/HoT
    for (final e in effects) {
      if (e.dotDmg > 0) applyDamage(e.dotDmg);
      if (e.hotHeal > 0) applyHeal(e.hotHeal);
    }
    // Tick durations
    for (int i = effects.length - 1; i >= 0; i--) {
      effects[i] = effects[i].tick();
      if (effects[i].expired) effects.removeAt(i);
    }
  }
}

/// Combat ability
class CombatAbility {
  final String name;
  final String description;
  final bool isActive;     // true = active, false = passive
  final bool isUltimate;   // costs 100 energy
  final double multiplier; // damage multiplier
  final bool isAoe;        // targets all enemies
  final bool isHeal;       // heals ally
  final double healRatio;  // % of caster's ATK
  final StatusEffect? appliedEffect;

  const CombatAbility({
    required this.name,
    required this.description,
    this.isActive = true,
    this.isUltimate = false,
    this.multiplier = 1.0,
    this.isAoe = false,
    this.isHeal = false,
    this.healRatio = 0.0,
    this.appliedEffect,
  });
}

/// Result of a single attack action
class AttackResult {
  final CombatUnit attacker;
  final CombatUnit target;
  final int damage;
  final bool isCrit;
  final bool isUltimate;
  final bool isAoe;
  final String abilityName;
  final int healAmount;
  final StatusEffect? appliedEffect;

  const AttackResult({
    required this.attacker,
    required this.target,
    required this.damage,
    this.isCrit = false,
    this.isUltimate = false,
    this.isAoe = false,
    this.abilityName = 'Attack',
    this.healAmount = 0,
    this.appliedEffect,
  });
}

/// Result of a complete battle
class BattleResult {
  final bool playerWon;
  final int stars;
  final List<BattleTurn> turns;
  final List<CombatUnit> alliesEnd;
  final List<CombatUnit> enemiesEnd;

  const BattleResult({
    required this.playerWon,
    required this.stars,
    required this.turns,
    required this.alliesEnd,
    required this.enemiesEnd,
  });
}

/// A single turn in battle
class BattleTurn {
  final int turnNumber;
  final List<AttackResult> actions;

  const BattleTurn({
    required this.turnNumber,
    required this.actions,
  });
}
