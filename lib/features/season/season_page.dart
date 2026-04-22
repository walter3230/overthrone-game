import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:overthrone/features/heroes/hero_types.dart';
import 'package:overthrone/features/heroes/heroes_page.dart' show GameHero, allHeroes;
import 'package:overthrone/core/firestore_sync.dart';
import 'package:overthrone/features/chat/chat_page.dart';

/// Season page with Rankings, Season Pass, Gacha, Chat tabs
class SeasonPageFull extends StatelessWidget {
  const SeasonPageFull({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Season'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Rankings'),
              Tab(text: 'Season Pass'),
              Tab(text: 'Summon'),
              Tab(text: 'Chat'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _RankingsTab(),
            _SeasonPassTab(),
            _GachaTab(),
            ChatPage(),
          ],
        ),
      ),
    );
  }
}

// ---- Rankings Tab ----
class _RankingsTab extends StatefulWidget {
  const _RankingsTab();
  @override
  State<_RankingsTab> createState() => _RankingsTabState();
}

class _RankingsTabState extends State<_RankingsTab> {
  List<LeaderboardEntry> _players = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // First sync our own data
    await FirestoreSync.I.syncProfile();
    // Then fetch leaderboard
    final players = await FirestoreSync.I.getTopPlayers(limit: 100);
    if (mounted) setState(() { _players = players; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _players.length,
        itemBuilder: (_, i) {
          final p = _players[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: p.isYou ? cs.primary.withValues(alpha: .12) : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: p.isYou ? Border.all(color: cs.primary, width: 2) : Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '#${p.rank}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: p.rank <= 3 ? Colors.amber : cs.onSurface,
                    ),
                  ),
                ),
                if (p.rank <= 3)
                  Icon(Icons.emoji_events, size: 18,
                    color: p.rank == 1 ? Colors.amber : p.rank == 2 ? Colors.grey.shade400 : Colors.brown),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: TextStyle(
                        fontWeight: p.isYou ? FontWeight.w900 : FontWeight.w600,
                        color: p.isYou ? cs.primary : null,
                      )),
                      if (p.isYou)
                        Text('YOU', style: TextStyle(fontSize: 10, color: cs.primary, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Text('${p.power}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---- Season Pass Tab ----
class _SeasonPassTab extends StatefulWidget {
  const _SeasonPassTab();
  @override
  State<_SeasonPassTab> createState() => _SeasonPassTabState();
}

class _SeasonPassTabState extends State<_SeasonPassTab> {
  int _currentTier = 0;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _currentTier = p.getInt('season_pass_tier') ?? 0;
    _isPremium = p.getBool('season_pass_premium') ?? false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 100,
      itemBuilder: (_, i) {
        final tier = i + 1;
        final claimed = tier <= _currentTier;
        final isMilestone = tier == 50 || tier == 100;

        String freeReward = 'Gold x${tier * 1000}';
        String premiumReward = 'Crystals x${tier * 5}';
        if (tier == 50) {
          freeReward = 'Hero Shards x10';
          premiumReward = 'Exclusive Skin';
        } else if (tier == 100) {
          freeReward = 'Gold x100K';
          premiumReward = 'FREE HERO';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMilestone
                ? Colors.amber.withValues(alpha: .08)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: claimed ? cs.primary : isMilestone ? Colors.amber : cs.outlineVariant,
              width: isMilestone ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '$tier',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isMilestone ? Colors.amber : null,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(freeReward, style: const TextStyle(fontSize: 12)),
                    if (_isPremium || isMilestone)
                      Text(
                        premiumReward,
                        style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
              if (claimed)
                Icon(Icons.check_circle, color: cs.primary, size: 20)
              else if (tier == _currentTier + 1)
                FilledButton(
                  onPressed: () async {
                    final p = await SharedPreferences.getInstance();
                    await p.setInt('season_pass_tier', tier);
                    setState(() => _currentTier = tier);
                  },
                  child: const Text('Claim'),
                )
              else
                Icon(Icons.lock_outline, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        );
      },
    );
  }
}

// ---- Gacha Tab ----
class _GachaTab extends StatefulWidget {
  const _GachaTab();
  @override
  State<_GachaTab> createState() => _GachaTabState();
}

class _GachaTabState extends State<_GachaTab> {
  int _pityCounter = 0;
  final List<GameHero> _pullHistory = [];

  GameHero _pull() {
    _pityCounter++;
    final rng = Random();

    Rarity rarity;
    if (_pityCounter >= 80) {
      rarity = Rarity.sPlus;
      _pityCounter = 0;
    } else {
      final roll = rng.nextDouble();
      if (roll < 0.015) {
        rarity = Rarity.sPlus;
        _pityCounter = 0;
      } else if (roll < 0.095) {
        rarity = Rarity.s;
      } else if (roll < 0.395) {
        rarity = Rarity.a;
      } else {
        rarity = Rarity.b;
      }
    }

    final pool = allHeroes.where((h) => h.rarity == rarity).toList();
    if (pool.isEmpty) return allHeroes.first;
    return pool[rng.nextInt(pool.length)];
  }

  void _singlePull() {
    final hero = _pull();
    setState(() => _pullHistory.insert(0, hero));
    _showPullResult([hero]);
  }

  void _tenPull() {
    final heroes = <GameHero>[];
    for (int i = 0; i < 10; i++) {
      heroes.add(_pull());
    }
    // Guarantee at least one A+
    if (!heroes.any((h) => h.rarity == Rarity.a || h.rarity == Rarity.s || h.rarity == Rarity.sPlus)) {
      final pool = allHeroes.where((h) => h.rarity == Rarity.a).toList();
      if (pool.isNotEmpty) {
        heroes[9] = pool[Random().nextInt(pool.length)];
      }
    }
    setState(() => _pullHistory.insertAll(0, heroes));
    _showPullResult(heroes);
  }

  void _showPullResult(List<GameHero> heroes) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${heroes.length == 1 ? 'Single' : '10x'} Summon!'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: heroes.length,
            itemBuilder: (_, i) {
              final h = heroes[i];
              return Container(
                decoration: BoxDecoration(
                  color: h.rarity.badge(cs).withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: h.rarity.badge(cs)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(h.faction.icon, size: 18, color: h.rarity.badge(cs)),
                    const SizedBox(height: 2),
                    Text(h.rarity.label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Banner
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary.withValues(alpha: .15), cs.tertiary.withValues(alpha: .1)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.primary.withValues(alpha: .3)),
          ),
          child: Column(
            children: [
              const Text('Hero Summon', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Pity: $_pityCounter/80', style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('S+: 1.5%  S: 8%  A: 30%  B: 60.5%',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.tonal(
                    onPressed: _singlePull,
                    child: const Column(
                      children: [
                        Text('Single', style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('300 💎', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: _tenPull,
                    child: const Column(
                      children: [
                        Text('10x Pull', style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('2700 💎', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // History
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('Recent Pulls', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('${_pullHistory.length} total', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _pullHistory.isEmpty
              ? Center(child: Text('No pulls yet', style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _pullHistory.length,
                  itemBuilder: (_, i) {
                    final h = _pullHistory[i];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: h.rarity.badge(cs).withValues(alpha: .2),
                        child: Icon(h.faction.icon, size: 16, color: h.rarity.badge(cs)),
                      ),
                      title: Text(h.name, style: const TextStyle(fontSize: 13)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: h.rarity.badge(cs).withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(h.rarity.label, style: TextStyle(fontSize: 11, color: h.rarity.badge(cs), fontWeight: FontWeight.w800)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
