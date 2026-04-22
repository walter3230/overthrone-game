import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:overthrone/battle/battle_models.dart';
import 'package:overthrone/battle/battle_screen.dart';
import 'package:overthrone/features/heroes/hero_types.dart';
import 'package:overthrone/features/heroes/heroes_page.dart' show GameHero, allHeroes;
import 'package:overthrone/core/bag_service.dart';
import 'boss_data.dart';

class BossRaidPage extends StatefulWidget {
  const BossRaidPage({super.key});
  @override
  State<BossRaidPage> createState() => _BossRaidPageState();
}

class _BossRaidPageState extends State<BossRaidPage> {
  int _raidsToday = 0;
  int _maxRaids = 3;
  bool _isVip = false;

  @override
  void initState() {
    super.initState();
    _loadRaidState();
  }

  Future<void> _loadRaidState() async {
    final p = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = p.getString('boss_raid_date') ?? '';
    if (savedDate != today) {
      await p.setString('boss_raid_date', today);
      await p.setInt('boss_raids_used', 0);
    }
    _raidsToday = p.getInt('boss_raids_used') ?? 0;
    _isVip = p.getBool('is_vip') ?? false;
    _maxRaids = _isVip ? 6 : 3;
    if (mounted) setState(() {});
  }

  Future<void> _useRaid() async {
    final p = await SharedPreferences.getInstance();
    _raidsToday++;
    await p.setInt('boss_raids_used', _raidsToday);
    if (mounted) setState(() {});
  }

  Future<void> _fightBoss(BossData boss) async {
    if (_raidsToday >= _maxRaids) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No raids left today! VIP for more.')),
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
        baseSpeed: 50 + (h.powerBase ~/ 100).clamp(0, 50),
        abilities: const [
          CombatAbility(name: 'Strike', description: 'Basic attack', multiplier: 1.2),
          CombatAbility(name: 'Power Move', description: 'Strong hit', multiplier: 1.8, isUltimate: true),
        ],
      ));
    }

    if (!mounted) return;

    final result = await Navigator.of(context).push<BattleResult>(
      MaterialPageRoute(
        builder: (_) => BattleScreen(
          allies: allies,
          enemies: [boss.toCombatUnit()],
          stageName: '${boss.name} - ${boss.title}',
        ),
      ),
    );

    if (!mounted) return;

    await _useRaid();

    if (result != null && result.playerWon) {
      final rng = Random();
      final drops = boss.loot.roll(rng);
      for (final entry in drops.entries) {
        BagService.I.add(entry.key, entry.value);
      }
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Boss Defeated!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: drops.entries
                  .map((e) => Text('${e.key}: x${e.value}'))
                  .toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boss Raids'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Raids: $_raidsToday/$_maxRaids',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: allBosses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final boss = allBosses[i];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _bossColor(boss.faction).withValues(alpha: .15),
                  cs.surfaceContainerHighest,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _bossColor(boss.faction).withValues(alpha: .2),
                  child: Icon(boss.faction.icon, size: 30, color: _bossColor(boss.faction)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(boss.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      Text(boss.title, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text('Power: ${boss.recommendedPower}+',
                        style: TextStyle(fontSize: 11, color: cs.primary)),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _raidsToday < _maxRaids ? () => _fightBoss(boss) : null,
                  child: const Text('Fight'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Color _bossColor(Faction f) => switch (f) {
  Faction.elemental => Colors.deepPurple,
  Faction.dark => const Color(0xFF8B0000),
  Faction.nature => Colors.teal,
  Faction.mech => Colors.blueGrey,
  Faction.voidF => const Color(0xFF2D0050),
  Faction.light => Colors.orange,
};
