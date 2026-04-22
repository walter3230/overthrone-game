import 'dart:math';
import 'package:flutter/material.dart';
import 'package:overthrone/battle/battle_models.dart';
import 'package:overthrone/battle/battle_screen.dart';
import 'package:overthrone/features/heroes/hero_types.dart';
import 'package:overthrone/features/heroes/heroes_page.dart' show allHeroes;

/// Guild War state
enum GuildWarPhase { idle, registration, matchmaking, warDay1, warDay2, warDay3, results }

/// Guild War page
class GuildWarPageFull extends StatefulWidget {
  const GuildWarPageFull({super.key});
  @override
  State<GuildWarPageFull> createState() => _GuildWarPageFullState();
}

class _GuildWarPageFullState extends State<GuildWarPageFull> {
  GuildWarPhase _phase = GuildWarPhase.idle;
  int _attacksLeft = 3;
  int _ourScore = 0;
  int _theirScore = 0;
  final List<_WarTarget> _targets = [];

  @override
  void initState() {
    super.initState();
    _generateTargets();
  }

  void _generateTargets() {
    final rng = Random(42);
    _targets.clear();
    for (int i = 0; i < 10; i++) {
      _targets.add(_WarTarget(
        name: 'Enemy_${rng.nextInt(9000) + 1000}',
        power: 5000 + rng.nextInt(30000),
        defeated: false,
      ));
    }
  }

  void _startRegistration() {
    setState(() => _phase = GuildWarPhase.registration);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _phase = GuildWarPhase.warDay1);
    });
  }

  Future<void> _attack(_WarTarget target) async {
    if (_attacksLeft <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attacks left today!')),
      );
      return;
    }

    final roster = allHeroes.take(6).toList();
    final allies = <CombatUnit>[];
    for (int i = 0; i < roster.length; i++) {
      final h = roster[i];
      allies.add(CombatUnit(
        id: i,
        name: h.name,
        isAlly: true,
        dmgType: h.faction.defaultDmgType,
        defType: h.role.defaultDefType,
        factionIcon: h.faction.icon,
        color: Colors.primaries[i % Colors.primaries.length],
        maxHp: h.powerBase * 15,
        baseAtk: (h.powerBase * 0.7).round(),
        baseDef: (h.powerBase * 0.5).round(),
        baseSpeed: 55,
        abilities: const [
          CombatAbility(name: 'Strike', description: 'Attack', multiplier: 1.2),
          CombatAbility(name: 'Ultimate', description: 'Strong', multiplier: 2.0, isUltimate: true),
        ],
      ));
    }

    // Enemy team
    final rng = Random();
    final enemies = List.generate(6, (i) {
      final f = Faction.values[rng.nextInt(Faction.values.length)];
      return CombatUnit(
        id: 1000 + i,
        name: '${target.name}_$i',
        isAlly: false,
        dmgType: f.defaultDmgType,
        defType: DefenseType.balanced,
        factionIcon: f.icon,
        color: Colors.redAccent,
        maxHp: (target.power * 2).round(),
        baseAtk: (target.power * 0.1).round(),
        baseDef: (target.power * 0.07).round(),
        baseSpeed: 50 + rng.nextInt(20),
        abilities: const [
          CombatAbility(name: 'Defense', description: 'Defend', multiplier: 1.0),
        ],
      );
    });

    if (!mounted) return;

    final result = await Navigator.of(context).push<BattleResult>(
      MaterialPageRoute(
        builder: (_) => BattleScreen(
          allies: allies,
          enemies: enemies,
          stageName: 'Guild War: vs ${target.name}',
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _attacksLeft--;
      if (result != null && result.playerWon) {
        target.defeated = true;
        _ourScore += 3;
      } else {
        _theirScore += 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Guild War')),
      body: _phase == GuildWarPhase.idle
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.military_tech, size: 64, color: cs.primary),
                  const SizedBox(height: 16),
                  const Text('Guild War', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('Register your guild for war!', style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _startRegistration,
                    icon: const Icon(Icons.flag),
                    label: const Text('Register'),
                  ),
                ],
              ),
            )
          : _phase == GuildWarPhase.registration
              ? const Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Finding opponent guild...'),
                  ],
                ))
              : Column(
                  children: [
                    // Score bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: cs.surfaceContainerHighest,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('Our Guild', style: TextStyle(fontWeight: FontWeight.w700)),
                              Text('$_ourScore', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: cs.primary)),
                            ],
                          ),
                          Text('VS', style: TextStyle(fontSize: 20, color: cs.onSurfaceVariant)),
                          Column(
                            children: [
                              const Text('Enemy Guild', style: TextStyle(fontWeight: FontWeight.w700)),
                              Text('$_theirScore', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.redAccent)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Attacks left: $_attacksLeft/3', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _targets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final t = _targets[i];
                          return ListTile(
                            tileColor: t.defeated
                                ? cs.primary.withValues(alpha: .08)
                                : cs.surfaceContainerHighest,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: CircleAvatar(
                              backgroundColor: t.defeated ? cs.primary : Colors.redAccent,
                              child: Icon(
                                t.defeated ? Icons.check : Icons.person,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(t.name),
                            subtitle: Text('Power: ${t.power}'),
                            trailing: t.defeated
                                ? const Text('Defeated', style: TextStyle(fontWeight: FontWeight.w700))
                                : FilledButton(
                                    onPressed: _attacksLeft > 0 ? () => _attack(t) : null,
                                    child: const Text('Attack'),
                                  ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _WarTarget {
  final String name;
  final int power;
  bool defeated;
  _WarTarget({required this.name, required this.power, this.defeated = false});
}
