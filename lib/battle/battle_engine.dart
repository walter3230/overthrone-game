import 'dart:math';
import 'battle_models.dart';

/// Turn-based battle engine
class BattleEngine {
  final List<CombatUnit> allies;
  final List<CombatUnit> enemies;
  final Random _rng;
  final int maxTurns;

  BattleEngine({
    required this.allies,
    required this.enemies,
    int? seed,
    this.maxTurns = 30,
  }) : _rng = Random(seed);

  List<CombatUnit> get allUnits => [...allies, ...enemies];
  List<CombatUnit> get aliveAllies => allies.where((u) => u.isAlive).toList();
  List<CombatUnit> get aliveEnemies => enemies.where((u) => u.isAlive).toList();
  bool get battleOver => aliveAllies.isEmpty || aliveEnemies.isEmpty;

  /// Run the full battle and return result
  BattleResult run() {
    final turns = <BattleTurn>[];
    int turnNum = 0;

    while (!battleOver && turnNum < maxTurns) {
      turnNum++;
      final actions = _executeTurn(turnNum);
      turns.add(BattleTurn(turnNumber: turnNum, actions: actions));
    }

    final won = aliveEnemies.isEmpty && aliveAllies.isNotEmpty;
    final stars = _calculateStars(won);

    return BattleResult(
      playerWon: won,
      stars: stars,
      turns: turns,
      alliesEnd: allies,
      enemiesEnd: enemies,
    );
  }

  /// Run battle as a stream for animated playback
  Stream<BattleTurn> runStream() async* {
    int turnNum = 0;
    while (!battleOver && turnNum < maxTurns) {
      turnNum++;
      final actions = _executeTurn(turnNum);
      final turn = BattleTurn(turnNumber: turnNum, actions: actions);
      yield turn;
      await Future.delayed(const Duration(milliseconds: 800));
    }
  }

  List<AttackResult> _executeTurn(int turnNum) {
    final actions = <AttackResult>[];

    // Sort all alive units by speed (descending)
    final turnOrder = allUnits.where((u) => u.isAlive).toList()
      ..sort((a, b) => b.effectiveSpeed.compareTo(a.effectiveSpeed));

    for (final unit in turnOrder) {
      if (unit.isDead || battleOver) continue;

      // Tick status effects
      unit.tickEffects();
      if (unit.isDead) continue;

      // Skip if stunned
      if (unit.isStunned) continue;

      final result = _unitAction(unit);
      if (result != null) actions.add(result);
    }

    return actions;
  }

  AttackResult? _unitAction(CombatUnit unit) {
    final isPlayerUnit = unit.isAlly;
    final friendlies = isPlayerUnit ? aliveAllies : aliveEnemies;
    final foes = isPlayerUnit ? aliveEnemies : aliveAllies;

    if (foes.isEmpty) return null;

    // Check for ultimate
    if (unit.canUseUltimate) {
      final ult = unit.abilities.where((a) => a.isUltimate).firstOrNull;
      if (ult != null) {
        unit.energy = 0;
        return _executeAbility(unit, ult, foes, friendlies);
      }
    }

    // AI selects ability
    final ability = _selectAbility(unit, foes, friendlies);
    return _executeAbility(unit, ability, foes, friendlies);
  }

  CombatAbility _selectAbility(
    CombatUnit unit,
    List<CombatUnit> foes,
    List<CombatUnit> friendlies,
  ) {
    final activeAbilities = unit.abilities
        .where((a) => a.isActive && !a.isUltimate)
        .toList();

    if (activeAbilities.isEmpty) {
      return const CombatAbility(
        name: 'Attack',
        description: 'Basic attack',
        multiplier: 1.0,
      );
    }

    // Healer logic: heal if ally < 30% HP
    final healAbility = activeAbilities.where((a) => a.isHeal).firstOrNull;
    if (healAbility != null) {
      final needsHeal = friendlies.any((u) => u.hpRatio < 0.3);
      if (needsHeal) return healAbility;
    }

    // AoE if 3+ foes
    if (foes.length >= 3) {
      final aoe = activeAbilities.where((a) => a.isAoe).firstOrNull;
      if (aoe != null) return aoe;
    }

    // Random active ability
    return activeAbilities[_rng.nextInt(activeAbilities.length)];
  }

  AttackResult _executeAbility(
    CombatUnit caster,
    CombatAbility ability,
    List<CombatUnit> foes,
    List<CombatUnit> friendlies,
  ) {
    // Heal
    if (ability.isHeal) {
      final target = friendlies.reduce(
        (a, b) => a.hpRatio < b.hpRatio ? a : b,
      );
      final heal = (caster.effectiveAtk * ability.healRatio).round();
      target.applyHeal(heal);
      caster.gainEnergy(20);
      return AttackResult(
        attacker: caster,
        target: target,
        damage: 0,
        healAmount: heal,
        abilityName: ability.name,
      );
    }

    // AoE damage
    if (ability.isAoe) {
      int totalDmg = 0;
      CombatUnit firstTarget = foes.first;
      bool anyCrit = false;
      for (final target in List.of(foes)) {
        final (dmg, crit) = _calculateDamage(caster, target, ability.multiplier);
        target.applyDamage(dmg);
        target.gainEnergy(10);
        totalDmg += dmg;
        if (crit) anyCrit = true;
        if (ability.appliedEffect != null && _rng.nextDouble() < 0.6) {
          target.effects.add(ability.appliedEffect!);
        }
      }
      caster.gainEnergy(20);
      return AttackResult(
        attacker: caster,
        target: firstTarget,
        damage: totalDmg,
        isCrit: anyCrit,
        isAoe: true,
        isUltimate: ability.isUltimate,
        abilityName: ability.name,
        appliedEffect: ability.appliedEffect,
      );
    }

    // Single target
    final target = _selectTarget(foes);
    final (dmg, crit) = _calculateDamage(caster, target, ability.multiplier);
    target.applyDamage(dmg);
    target.gainEnergy(10);
    caster.gainEnergy(20);

    if (ability.appliedEffect != null && _rng.nextDouble() < 0.6) {
      target.effects.add(ability.appliedEffect!);
    }

    return AttackResult(
      attacker: caster,
      target: target,
      damage: dmg,
      isCrit: crit,
      isUltimate: ability.isUltimate,
      abilityName: ability.name,
      appliedEffect: ability.appliedEffect,
    );
  }

  CombatUnit _selectTarget(List<CombatUnit> foes) {
    // Target lowest HP
    return foes.reduce((a, b) => a.currentHp < b.currentHp ? a : b);
  }

  (int, bool) _calculateDamage(
    CombatUnit attacker,
    CombatUnit defender,
    double multiplier,
  ) {
    final rawDmg = attacker.effectiveAtk * multiplier;
    final def = defender.effectiveDef;
    final mitigated = rawDmg * (1 - def / (def + 500));
    final typeMultiplier = dmgTypeMultiplier(attacker.dmgType, defender.defType);

    final isCrit = _rng.nextDouble() < attacker.critRate;
    final critMul = isCrit ? attacker.critDmg : 1.0;

    // Small variance +-10%
    final variance = 0.9 + _rng.nextDouble() * 0.2;

    final finalDmg = (mitigated * typeMultiplier * critMul * variance).round();
    return (finalDmg.clamp(1, 999999), isCrit);
  }

  int _calculateStars(bool won) {
    if (!won) return 0;

    final allAlive = allies.every((u) => u.isAlive);
    final allAbove50 = allies.every((u) => u.hpRatio > 0.5);

    if (allAlive && allAbove50) return 3;
    if (allAlive) return 2;
    return 1;
  }
}
