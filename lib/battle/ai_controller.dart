import 'dart:math';
import 'battle_models.dart';

/// AI controller for enemy units in battle
class AIController {
  final Random _rng;
  final int difficulty; // 1-10, affects targeting intelligence

  AIController({int? seed, this.difficulty = 5})
      : _rng = Random(seed);

  /// Select an ability for the given enemy unit
  CombatAbility selectAbility(
    CombatUnit unit,
    List<CombatUnit> allies, // enemy's allies
    List<CombatUnit> foes,   // player's team
  ) {
    final actives = unit.abilities
        .where((a) => a.isActive && !a.isUltimate)
        .toList();

    if (actives.isEmpty) {
      return const CombatAbility(
        name: 'Attack',
        description: 'Basic attack',
        multiplier: 1.0,
      );
    }

    // High difficulty: smart choices
    if (difficulty >= 7) {
      // Heal if ally low
      final healAb = actives.where((a) => a.isHeal).firstOrNull;
      if (healAb != null && allies.any((u) => u.hpRatio < 0.3)) {
        return healAb;
      }

      // AoE if 3+ foes alive
      if (foes.length >= 3) {
        final aoe = actives.where((a) => a.isAoe).firstOrNull;
        if (aoe != null) return aoe;
      }

      // Highest multiplier ability
      actives.sort((a, b) => b.multiplier.compareTo(a.multiplier));
      return actives.first;
    }

    // Low difficulty: mostly random
    if (difficulty <= 3) {
      return actives[_rng.nextInt(actives.length)];
    }

    // Medium difficulty: 60% smart, 40% random
    if (_rng.nextDouble() < 0.6) {
      actives.sort((a, b) => b.multiplier.compareTo(a.multiplier));
      return actives.first;
    }
    return actives[_rng.nextInt(actives.length)];
  }

  /// Select target from the player's alive units
  CombatUnit selectTarget(
    CombatUnit attacker,
    List<CombatUnit> targets,
  ) {
    if (targets.isEmpty) return targets.first;

    if (difficulty >= 7) {
      // Target lowest HP
      return targets.reduce((a, b) => a.currentHp < b.currentHp ? a : b);
    }

    if (difficulty <= 3) {
      // Random target
      return targets[_rng.nextInt(targets.length)];
    }

    // Medium: 50% lowest HP, 50% random
    if (_rng.nextDouble() < 0.5) {
      return targets.reduce((a, b) => a.currentHp < b.currentHp ? a : b);
    }
    return targets[_rng.nextInt(targets.length)];
  }
}
