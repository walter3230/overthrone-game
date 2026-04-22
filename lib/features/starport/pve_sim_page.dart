import 'package:flutter/material.dart';
import 'package:overthrone/battle/battle_models.dart';
import 'package:overthrone/battle/battle_screen.dart';
import 'package:overthrone/features/heroes/hero_types.dart';
import 'package:overthrone/features/heroes/heroes_page.dart' show GameHero;
import 'pve_progress_service.dart';
import 'stage_data.dart';

/// PvE battle entry point - converts heroes to CombatUnits and launches BattleScreen
class PVESimScreen extends StatefulWidget {
  final List heroes;
  final PveArea area;
  final int levelIndex;
  final PveDifficulty difficulty;

  const PVESimScreen({
    super.key,
    required this.heroes,
    required this.area,
    required this.levelIndex,
    required this.difficulty,
  });

  @override
  State<PVESimScreen> createState() => _PVESimScreenState();
}

class _PVESimScreenState extends State<PVESimScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _launchBattle());
  }

  Future<void> _launchBattle() async {
    // Convert player heroes to CombatUnits
    final allies = <CombatUnit>[];
    for (int i = 0; i < widget.heroes.length; i++) {
      final h = widget.heroes[i];
      allies.add(_heroToCombatUnit(h, i, isAlly: true));
    }

    // Get stage enemies
    final stageIdx = widget.levelIndex.clamp(0, allStages.length - 1);
    final stage = allStages[stageIdx];
    final enemies = <CombatUnit>[];
    for (int i = 0; i < stage.enemies.length; i++) {
      enemies.add(stage.enemies[i].toCombatUnit(i));
    }

    if (!mounted) return;

    // Launch battle screen
    final result = await Navigator.of(context).push<BattleResult>(
      MaterialPageRoute(
        builder: (_) => BattleScreen(
          allies: allies,
          enemies: enemies,
          stageName: stage.name,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null && result.playerWon) {
      Navigator.pop(context, true);
    } else {
      Navigator.pop(context, false);
    }
  }

  CombatUnit _heroToCombatUnit(dynamic h, int index, {required bool isAlly}) {
    // Handle both GameHero and other hero types
    String name = 'Hero';
    int power = 1000;
    Faction faction = Faction.elemental;
    Role role = Role.warrior;

    if (h is GameHero) {
      name = h.name;
      power = h.powerBase;
      faction = h.faction;
      role = h.role;
    } else {
      // Try dynamic access for compatibility
      try { name = h.name as String; } catch (_) {}
      try { power = (h.powerBase ?? h.power ?? 1000) as int; } catch (_) {}
      try { faction = h.faction as Faction; } catch (_) {}
      try { role = h.role as Role; } catch (_) {}
    }

    final baseHp = power * 15;
    final baseAtk = power * 7 ~/ 10;
    final baseDef = power * 5 ~/ 10;
    final baseSpeed = 50 + (power ~/ 100).clamp(0, 50);

    return CombatUnit(
      id: index,
      name: name,
      isAlly: isAlly,
      dmgType: faction.defaultDmgType,
      defType: role.defaultDefType,
      factionIcon: faction.icon,
      color: _factionColor(faction),
      maxHp: baseHp,
      baseAtk: baseAtk,
      baseDef: baseDef,
      baseSpeed: baseSpeed,
      abilities: _roleAbilities(role),
    );
  }

  List<CombatAbility> _roleAbilities(Role role) {
    switch (role) {
      case Role.warrior:
        return const [
          CombatAbility(name: 'Slash', description: 'Heavy strike', multiplier: 1.2),
          CombatAbility(name: 'Shield Bash', description: 'Stun attack', multiplier: 0.8,
            appliedEffect: StatusEffect(name: 'Stunned', duration: 1, stunned: true)),
          CombatAbility(name: 'Warcry', description: 'AoE attack', multiplier: 0.9, isAoe: true, isUltimate: true),
        ];
      case Role.ranger:
        return const [
          CombatAbility(name: 'Arrow Shot', description: 'Ranged attack', multiplier: 1.1),
          CombatAbility(name: 'Rain of Arrows', description: 'AoE', multiplier: 0.6, isAoe: true),
          CombatAbility(name: 'Snipe', description: 'Critical shot', multiplier: 2.0, isUltimate: true),
        ];
      case Role.raider:
        return const [
          CombatAbility(name: 'Backstab', description: 'Sneak attack', multiplier: 1.4),
          CombatAbility(name: 'Poison Blade', description: 'Poison', multiplier: 0.9,
            appliedEffect: StatusEffect(name: 'Poison', duration: 3, dotDmg: 50)),
          CombatAbility(name: 'Assassinate', description: 'Lethal', multiplier: 2.5, isUltimate: true),
        ];
      case Role.healer:
        return const [
          CombatAbility(name: 'Smite', description: 'Holy attack', multiplier: 0.7),
          CombatAbility(name: 'Heal', description: 'Restore HP', isHeal: true, healRatio: 1.5),
          CombatAbility(name: 'Divine Light', description: 'Mass heal', isHeal: true, healRatio: 0.8, isUltimate: true),
        ];
      case Role.mage:
        return const [
          CombatAbility(name: 'Fireball', description: 'Magic attack', multiplier: 1.3),
          CombatAbility(name: 'Blizzard', description: 'AoE freeze', multiplier: 0.8, isAoe: true,
            appliedEffect: StatusEffect(name: 'Frozen', duration: 1, spdMod: 0.5)),
          CombatAbility(name: 'Meteor', description: 'Ultimate AoE', multiplier: 1.2, isAoe: true, isUltimate: true),
        ];
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

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1117),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
