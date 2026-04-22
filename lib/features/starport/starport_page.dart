import 'package:flutter/material.dart';
import 'package:overthrone/features/profile/profile_repo.dart' as profile;

// CORE
import 'package:overthrone/core/energy_service.dart';
import 'package:overthrone/core/currency_service.dart' as currency;
import 'package:overthrone/core/bag_service.dart' as bag;
import 'package:overthrone/core/power_service.dart' as power;

// HERO SOURCES
import 'package:overthrone/features/heroes/heroes_page.dart'
    as heroes
    show allHeroes, GameHero;

// (Bu importları kaldırdık; undefined_prefixed_name veriyordu)
// import 'package:overthrone/features/heroes/hero_data.dart' as hdata;
// import 'package:overthrone/features/heroes/hero_detail_full.dart' as hfull;
// import 'package:overthrone/features/heroes/hero_types.dart' as htypes;
// import 'package:overthrone/features/heroes/heroes_abilities_db.dart' as hab;

// PVE
import 'pve_sim_page.dart';
import 'pve_progress_service.dart'
    show PveArea, PveDifficulty, PveProgressService;

/// Starport – lean, error-free, 5 areas, hero selection.
class StarportPage extends StatefulWidget {
  const StarportPage({super.key});
  @override
  State<StarportPage> createState() => _StarportPageState();
}

enum Activity { campaign, bosses, arena, expedition, trials }

class _StarportPageState extends State<StarportPage>
    with TickerProviderStateMixin {
  static const PveDifficulty _diff = PveDifficulty.normal;
  static const int _stageCount = 20;
  static const int _energyPerStage = 10;

  Activity _activity = Activity.campaign;
  int _unlocked = 0;
  List _selectedHeroes = const [];

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _autofillHeroes();
  }

  Future<void> _loadProgress() async {
    final idx = PveProgressService.I.unlockedIndex;
    if (!mounted) return;
    setState(() => _unlocked = idx);
  }

  // --------- Roster (safe sources only) ---------
  List _getRoster() {
    // 1) Primary: heroes_page.dart → allHeroes
    try {
      return List<heroes.GameHero>.from(heroes.allHeroes);
    } catch (_) {}

    // 2) PowerService.I.heroes
    try {
      final ps = (power.PowerService.I as dynamic);
      final r = ps.heroes;
      if (r != null) return List.from(r as Iterable);
    } catch (_) {}

    // 3) ProfileRepo.I.heroes
    try {
      final r = (profile.ProfileRepo.I as dynamic).heroes;
      if (r != null) return List.from(r as Iterable);
    } catch (_) {}

    return const [];
  }

  // --------- Name / Power adapters ---------
  String _heroName(dynamic h) {
    try {
      return (h?.name ??
              h?['name'] ??
              h?.displayName ??
              h?['displayName'] ??
              'Hero')
          .toString();
    } catch (_) {
      return 'Hero';
    }
  }

  int _heroPower(dynamic h) {
    try {
      final v =
          (h?.powerBase ??
          h?.power ??
          h?['power'] ??
          h?.combatPower ??
          h?['combatPower'] ??
          h?.totalPower ??
          h?['totalPower'] ??
          h?.stats?.power ??
          (h is Map ? (h['p'] ?? h['cp'] ?? h['tp']) : 0));
      if (v is num) return v.toInt();
    } catch (_) {}
    try {
      final ps = (power.PowerService.I as dynamic);
      final pv = ps.computeHeroPower(h);
      if (pv is num) return pv.toInt();
    } catch (_) {}
    return 0;
  }

  int _computeRosterPower(List heroesList) {
    var sum = 0;
    for (final h in heroesList) {
      sum += _heroPower(h);
    }
    return sum;
  }

  List _sortedRoster() {
    final r = _getRoster();
    r.sort((a, b) => _heroPower(b).compareTo(_heroPower(a)));
    return r;
  }

  // --------- Selection ---------
  void _autofillHeroes() {
    final sorted = _sortedRoster();
    if (sorted.isEmpty) return;
    setState(() => _selectedHeroes = sorted.take(6).toList());
  }

  Future<void> _openHeroPicker() async {
    final roster = _sortedRoster();
    final current = Set.of(_selectedHeroes);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        builder: (_, controller) {
          final sel = Set.of(current);
          final maxP = roster.isEmpty ? 1 : _heroPower(roster.first);

          return StatefulBuilder(
            builder: (ctx, setSheet) => Scaffold(
              appBar: AppBar(title: const Text('Select Heroes')),
              body: roster.isEmpty
                  ? const Center(
                      child: Text(
                        'Roster is empty. Add heroes from the Heroes screen.',
                      ),
                    )
                  : GridView.builder(
                      controller: controller,
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.35,
                          ),
                      itemCount: roster.length,
                      itemBuilder: (_, i) {
                        final h = roster[i];
                        final on = sel.contains(h);
                        final name = _heroName(h);
                        final pwr = _heroPower(h);
                        final ratio = (pwr / (maxP <= 0 ? 1 : maxP)).clamp(
                          0.0,
                          1.0,
                        );

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            if (on)
                              sel.remove(h);
                            else if (sel.length < 6)
                              sel.add(h);
                            setSheet(() {});
                          },
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Checkbox(
                                        value: on,
                                        onChanged: (_) {
                                          if (on)
                                            sel.remove(h);
                                          else if (sel.length < 6)
                                            sel.add(h);
                                          setSheet(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'P: $pwr',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    on ? 'Selected' : 'Tap to select',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: on
                                          ? Colors.green
                                          : Theme.of(context).hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          sel.clear();
                          setSheet(() {});
                        },
                        child: const Text('Clear'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () {
                          final top6 = roster.take(6).toList();
                          sel
                            ..clear()
                            ..addAll(top6);
                          setSheet(() {});
                        },
                        child: const Text('Auto-Fill'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          setState(() => _selectedHeroes = sel.toList());
                        },
                        child: Text('Use ${sel.length} Heroes'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --------- Rewards ---------
  Future<void> _grantRewards(Activity a, {required int stageIndex}) async {
    // NOT: CurrencyService'te .I yok → doğrudan sınıfı dinamik kullanıyoruz.
    final cs = currency.CurrencyService as dynamic;
    final b = bag.BagService.I as dynamic;

    switch (a) {
      case Activity.campaign:
        try {
          cs.gainGold(5000 + stageIndex * 100);
        } catch (_) {}
        try {
          b.addItem({'id': 'gear_common', 'qty': 1});
        } catch (_) {
          try {
            b.add('gear_common', 1);
          } catch (_) {}
        }
        break;

      case Activity.bosses:
        try {
          cs.gainGold(2000 + stageIndex * 50);
        } catch (_) {}
        try {
          b.addItem({'id': 'rare_mat', 'qty': 2});
        } catch (_) {
          try {
            b.add('rare_mat', 2);
          } catch (_) {}
        }
        try {
          b.addItem({'id': 'gear_shard', 'qty': 4});
        } catch (_) {}
        break;

      case Activity.arena:
        try {
          cs.gainCrystals(2);
        } catch (_) {}
        try {
          b.addItem({'id': 'arena_coin', 'qty': 10});
        } catch (_) {
          try {
            b.add('arena_coin', 10);
          } catch (_) {}
        }
        break;

      case Activity.expedition:
        try {
          cs.gainGold(1500);
        } catch (_) {}
        try {
          b.addItem({'id': 'token', 'qty': 5});
        } catch (_) {
          try {
            b.add('token', 5);
          } catch (_) {}
        }
        try {
          b.addItem({'id': 'mat_basic', 'qty': 5});
        } catch (_) {}
        break;

      case Activity.trials:
        try {
          b.addItem({'id': 'rune', 'qty': 1});
        } catch (_) {
          try {
            b.add('rune', 1);
          } catch (_) {}
        }
        break;
    }
  }

  // --------- Energy & Sim flow ---------
  int _energyCost(Activity a) {
    switch (a) {
      case Activity.campaign:
        return _energyPerStage;
      case Activity.bosses:
        return 12;
      case Activity.arena:
        return 8;
      case Activity.expedition:
        return 8;
      case Activity.trials:
        return 10;
    }
  }

  Future<void> _start(Activity a, {required int stageIndex}) async {
    if (_selectedHeroes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No heroes selected.')));
      return;
    }

    final ok = await EnergyService.I.spend(_energyCost(a));
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not enough energy.')));
      return;
    }

    final res = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PVESimScreen(
          heroes: _selectedHeroes, // PVESimScreen imzası böyle
          area: PveArea.dungeon,
          levelIndex: stageIndex,
          difficulty: _diff,
        ),
      ),
    );

    final win = res is bool
        ? res
        : (res != null && (res as dynamic).win == true);
    if (!win) return;

    if (a == Activity.campaign) {
      await PveProgressService.I.markCleared(stageIndex, 1);
      await _loadProgress();
    }

    await _grantRewards(a, stageIndex: stageIndex);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Victory!'),
        content: Text('Rewards delivered for ${a.name}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // --------- UI ---------
  int _requiredPowerFor(int i) => 300 + i * 50;

  @override
  Widget build(BuildContext context) {
    final rosterPower = _computeRosterPower(
      _selectedHeroes.isEmpty ? _getRoster() : _selectedHeroes,
    );
    final next = _unlocked + 1;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Starport'),
          actions: [
            ValueListenableBuilder<int>(
              valueListenable: EnergyService.I.energyVN,
              builder: (_, v, __) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '⚡ $v',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            onTap: (i) => setState(() => _activity = Activity.values[i]),
            tabs: const [
              Tab(text: 'Campaign'),
              Tab(text: 'Bosses'),
              Tab(text: 'PvE Arena'),
              Tab(text: 'Expedition'),
              Tab(text: 'Trials'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CampaignTab(
              next: next > _stageCount ? null : next,
              rosterPower: rosterPower,
              reqPower: _requiredPowerFor(_unlocked),
              stageCount: _stageCount,
              unlocked: _unlocked,
              energyPerStage: _energyPerStage,
              onContinue: next <= _stageCount
                  ? () => _start(Activity.campaign, stageIndex: _unlocked)
                  : null,
              onStartStage: (i) => _start(Activity.campaign, stageIndex: i),
              onOpenPicker: _openHeroPicker,
              onAutoFill: _autofillHeroes,
              selectedCount: _selectedHeroes.length,
            ),
            _QuickTab(
              title: 'Boss Hunt',
              subtitle: 'High HP • Rare mats',
              energy: _energyCost(Activity.bosses),
              onStart: () => _start(Activity.bosses, stageIndex: 0),
              onOpenPicker: _openHeroPicker,
              onAutoFill: _autofillHeroes,
              selectedCount: _selectedHeroes.length,
            ),
            _QuickTab(
              title: 'PvE Arena',
              subtitle: 'Waves • Fast battles',
              energy: _energyCost(Activity.arena),
              onStart: () => _start(Activity.arena, stageIndex: 0),
              onOpenPicker: _openHeroPicker,
              onAutoFill: _autofillHeroes,
              selectedCount: _selectedHeroes.length,
            ),
            _QuickTab(
              title: 'Expedition',
              subtitle: 'Short missions for resources',
              energy: _energyCost(Activity.expedition),
              onStart: () => _start(Activity.expedition, stageIndex: 0),
              onOpenPicker: _openHeroPicker,
              onAutoFill: _autofillHeroes,
              selectedCount: _selectedHeroes.length,
            ),
            _QuickTab(
              title: 'Trials',
              subtitle: 'Special challenges',
              energy: _energyCost(Activity.trials),
              onStart: () => _start(Activity.trials, stageIndex: 0),
              onOpenPicker: _openHeroPicker,
              onAutoFill: _autofillHeroes,
              selectedCount: _selectedHeroes.length,
            ),
          ],
        ),
      ),
    );
  }
}

// ======= Widgets =======

class _CampaignTab extends StatelessWidget {
  const _CampaignTab({
    required this.next,
    required this.rosterPower,
    required this.reqPower,
    required this.stageCount,
    required this.unlocked,
    required this.energyPerStage,
    required this.onContinue,
    required this.onStartStage,
    required this.onOpenPicker,
    required this.onAutoFill,
    required this.selectedCount,
  });

  final int? next;
  final int rosterPower;
  final int reqPower;
  final int stageCount;
  final int unlocked;
  final int energyPerStage;
  final VoidCallback? onContinue;
  final void Function(int i) onStartStage;
  final VoidCallback onOpenPicker;
  final VoidCallback onAutoFill;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Campaign',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Next Stage: ${next ?? '—'}'),
                    const Spacer(),
                    FilledButton(
                      onPressed: onContinue,
                      child: const Text('Continue'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Your Power: $rosterPower'),
                    const SizedBox(width: 12),
                    Text(
                      'Req: $reqPower',
                      style: TextStyle(
                        color: rosterPower >= reqPower
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.tonal(
              onPressed: onAutoFill,
              child: const Text('Auto-Fill'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onOpenPicker,
              child: Text('Select ($selectedCount)'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stageCount,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final locked = i > unlocked;
            final req = 300 + i * 50;
            final ok = rosterPower >= req;
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: cs.surfaceVariant.withValues(alpha: .2),
              title: Text('Stage ${i + 1}'),
              subtitle: Text('Energy $energyPerStage • Req Power $req'),
              trailing: locked
                  ? const Text(
                      'Locked',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    )
                  : FilledButton(
                      onPressed: ok ? () => onStartStage(i) : null,
                      child: const Text('Start'),
                    ),
            );
          },
        ),
      ],
    );
  }
}

class _QuickTab extends StatelessWidget {
  const _QuickTab({
    required this.title,
    required this.subtitle,
    required this.energy,
    required this.onStart,
    required this.onOpenPicker,
    required this.onAutoFill,
    required this.selectedCount,
  });

  final String title;
  final String subtitle;
  final int energy;
  final VoidCallback onStart;
  final VoidCallback onOpenPicker;
  final VoidCallback onAutoFill;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(subtitle),
            trailing: FilledButton(
              onPressed: onStart,
              child: Text('Start (⚡$energy)'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.tonal(
              onPressed: onAutoFill,
              child: const Text('Auto-Fill'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onOpenPicker,
              child: Text('Select ($selectedCount)'),
            ),
          ],
        ),
      ],
    );
  }
}
