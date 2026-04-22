// lib/features/heroes/heroes_page.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:overthrone/core/power_service.dart';
import 'package:overthrone/ui/game_theme.dart';
import 'package:overthrone/core/synergy_system.dart';

import 'hero_types.dart';
import 'heroes_abilities_db.dart';
import 'hero_detail_full.dart';

/// ================== MODELLER ==================

class GameHero {
  final int id;
  final String name;
  final Faction faction;
  final Rarity rarity;
  final Role role;
  final int powerBase;
  final List<Ability> abilities;
  const GameHero({
    required this.id,
    required this.name,
    required this.faction,
    required this.rarity,
    required this.role,
    required this.powerBase,
    required this.abilities,
  });
}

/// ================== KAHRAMAN HAVUZU ==================
final List<GameHero> allHeroes = _generateHeroes();

List<GameHero> _generateHeroes() {
  final rng = Random(7);
  final heroes = <GameHero>[];
  int id = 1;

  const elemNames = [
    'Storm', 'Flare', 'Glacier', 'Quake', 'Spark',
    'Tempest', 'Cinder', 'Torrent', 'Pyra', 'Ignis',
    'Frostveil', 'Seirra', 'Aqualis', 'Magnar', 'Voltra',
    'Shadra', 'Terranis',
  ];
  const darkNames = [
    'Shade', 'Hex', 'Gloom', 'Abyss', 'Ruin',
    'Dread', 'Noctis', 'Morrow', 'Malice', 'Cinderveil',
    'Morgrim', 'Tenebris', 'Veyra', 'Draven', 'Ebonfang',
    'Wraith', 'Necros',
  ];
  const natNames = [
    'Thorn', 'Grove', 'Bloom', 'Fang', 'Bark',
    'Vine', 'Wild', 'Antler', 'Sylva', 'Oakheart',
    'Bramblescar', 'Leafshade', 'Mossfang', 'Elderthorn',
    'Lupiris', 'Verdantis', 'Rootclaw',
  ];
  const mechNames = [
    'Bolt', 'Gear', 'Core', 'Pulse', 'Circuit',
    'Alloy', 'Drive', 'Vector', 'Mechron', 'Synthra',
    'Axion', 'Voltforge', 'Cryon', 'Titanex', 'Dynatron',
    'Nexus', 'Kryonix',
  ];
  const voidNames = [
    'Null', 'Rift', 'Echo', 'Singularity', 'Worm',
    'Aether', 'Phase', 'Oblivion', 'Nyx', 'Eclipse',
    'Anomaly', 'Fractis', 'Eventide', 'Umbra', 'Parallax',
    'Xerath', 'Abyssion',
  ];
  const lightNames = [
    'Halo', 'Celestia', 'Radiant', 'Vow', 'Dawn',
    'Seraph', 'Beacon', 'Lumina', 'Solaria', 'Althea',
    'Divina', 'Auriel', 'Elyra', 'Sanctis', 'Oriana',
    'Gloria', 'Lumen',
  ];

  final bank = <Faction, List<String>>{
    Faction.elemental: elemNames,
    Faction.dark: darkNames,
    Faction.nature: natNames,
    Faction.mech: mechNames,
    Faction.voidF: voidNames,
    Faction.light: lightNames,
  };

  const roleCycle = [
    Role.warrior, Role.ranger, Role.raider, Role.healer, Role.mage,
  ];

  for (final f in Faction.values) {
    int rolePtr = 0;
    final used = <String>{};

    String full(String seed) => '${f.label} $seed';
    int nextPower(Rarity r) => switch (r) {
      Rarity.sPlus => 1500 + rng.nextInt(80),
      Rarity.s => 1320 + rng.nextInt(80),
      Rarity.a => 1120 + rng.nextInt(80),
      Rarity.b => 920 + rng.nextInt(80),
    };

    for (final r in [Rarity.sPlus, Rarity.s]) {
      final names = dbNamesForFaction(f, r);
      for (final fullName in names) {
        final role = roleCycle[rolePtr % roleCycle.length];
        rolePtr++;
        final abilities = abilitiesForHeroName(
          fullName: fullName, rarity: r, role: role, faction: f,
        );
        heroes.add(GameHero(
          id: id++, name: fullName, faction: f, rarity: r,
          role: role, powerBase: nextPower(r), abilities: abilities,
        ));
        final seed = fullName.substring('${f.label} '.length);
        used.add(seed);
      }
    }

    final seeds = bank[f]!;
    List<String> remaining = seeds
        .where((s) => !used.contains(s)).toList(growable: true);

    final plan = <Rarity, int>{Rarity.a: 3, Rarity.b: 2};

    for (final entry in plan.entries) {
      final r = entry.key;
      for (int i = 0; i < entry.value && i < remaining.length; i++) {
        final seed = remaining.removeAt(0);
        final name = full(seed);
        final role = roleCycle[rolePtr % roleCycle.length];
        rolePtr++;

        final abilities = abilitiesForHeroName(
          fullName: name, rarity: r, role: role, faction: f,
        );

        heroes.add(GameHero(
          id: id++, name: name, faction: f, rarity: r,
          role: role, powerBase: nextPower(r), abilities: abilities,
        ));
      }
    }
  }

  heroes.sort((a, b) {
    final r = a.rarity.sort.compareTo(b.rarity.sort);
    if (r != 0) return r;
    return a.id.compareTo(b.id);
  });
  return heroes;
}

extension GameHeroX on GameHero {
  String get shortName {
    final prefix = '${faction.label} ';
    return name.startsWith(prefix) ? name.substring(prefix.length) : name;
  }
}

/// ================== PERSISTENCE ==================
class HeroStore {
  static const _kOwned = 'owned_heroes';
  static const _kPortraitPrefix = 'portrait_';
  static const _kPlans = 'hero_plans';

  static Future<SharedPreferences> get _p async =>
      SharedPreferences.getInstance();

  static Future<Set<int>> loadOwned() async {
    final p = await _p;
    final ls = p.getStringList(_kOwned) ?? const [];
    return ls.map(int.parse).toSet();
  }

  static Future<void> saveOwned(Set<int> ids) async {
    final p = await _p;
    await p.setStringList(_kOwned, ids.map((e) => '$e').toList());
  }

  static Future<int> portraitLevel(int id) async {
    final p = await _p;
    return p.getInt('$_kPortraitPrefix$id') ?? 0;
  }

  static Future<void> setPortraitLevel(int id, int lv) async {
    final p = await _p;
    await p.setInt('$_kPortraitPrefix$id', lv.clamp(0, 10));
  }

  static Future<List<HeroPlan>> loadPlans() async {
    final p = await _p;
    final raw = p.getString(_kPlans);
    if (raw == null) {
      final def = List.generate(
        9, (i) => HeroPlan(name: 'Plan ${i + 1}', heroIds: const []),
      );
      await savePlans(def);
      return def;
    }
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(HeroPlan.fromJson).toList();
  }

  static Future<void> savePlans(List<HeroPlan> plans) async {
    final p = await _p;
    await p.setString(
      _kPlans, jsonEncode(plans.map((e) => e.toJson()).toList()),
    );
  }
}

class HeroPlan {
  String name;
  List<int> heroIds;
  HeroPlan({required this.name, required this.heroIds});
  Map<String, dynamic> toJson() => {'name': name, 'heroIds': heroIds};
  factory HeroPlan.fromJson(Map<String, dynamic> j) => HeroPlan(
    name: j['name'] as String,
    heroIds: (j['heroIds'] as List).cast<int>(),
  );
}

/// ================== SAYFA ==================
class HeroesPage extends StatefulWidget {
  const HeroesPage({super.key});
  @override
  State<HeroesPage> createState() => _HeroesPageState();
}

class _HeroesPageState extends State<HeroesPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Heroes'),
          bottom: TabBar(
            indicatorColor: GameTheme.cosmicPurple,
            indicatorWeight: 2,
            labelColor: GameTheme.neonBlue,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
            tabs: const [
              Tab(text: 'Hero'),
              Tab(text: 'Portraits'),
              Tab(text: 'Group Plan'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_OwnedTab(), _PortraitsTab(), _GroupPlanTab()],
        ),
      ),
    );
  }
}

/// ================== 1) OWNED ==================
class _OwnedTab extends StatefulWidget {
  const _OwnedTab();
  @override
  State<_OwnedTab> createState() => _OwnedTabState();
}

class _OwnedTabState extends State<_OwnedTab> {
  Set<int> owned = {};
  Faction? filterFaction;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    owned = await HeroStore.loadOwned();
    setState(() {});
  }

  Future<void> _openFull(GameHero h) async {
    final lvl = await HeroStore.portraitLevel(h.id);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HeroFullPage(hero: h, portraitLevel: lvl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list =
        allHeroes
            .where((h) => owned.contains(h.id))
            .where((h) => filterFaction == null || h.faction == filterFaction)
            .toList()
          ..sort((a, b) {
            final r = a.rarity.sort.compareTo(b.rarity.sort);
            if (r != 0) return r;
            return a.id.compareTo(b.id);
          });

    return Column(
      children: [
        _FactionChips(
          current: filterFaction,
          onChanged: (f) => setState(() => filterFaction = f),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    'No owned heroes.\nGet heroes from Portraits.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    12, 8, 12, 12 + MediaQuery.of(context).padding.bottom,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _PremiumHeroCard(
                    h: list[i],
                    portraitLevel: 0,
                    owned: true,
                    footerText: list[i].shortName,
                    onTap: () => _openFull(list[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// ================== 2) PORTRAITS ==================
class _PortraitsTab extends StatefulWidget {
  const _PortraitsTab();
  @override
  State<_PortraitsTab> createState() => _PortraitsTabState();
}

class _PortraitsTabState extends State<_PortraitsTab> {
  Set<int> owned = {};
  Map<int, int> portrait = {};
  Faction? filterFaction;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    owned = await HeroStore.loadOwned();
    final map = <int, int>{};
    for (final h in allHeroes) {
      map[h.id] = await HeroStore.portraitLevel(h.id);
    }
    setState(() => portrait = map);
  }

  Future<void> _obtainOrUpgrade(GameHero h) async {
    if (!owned.contains(h.id)) {
      owned.add(h.id);
      await HeroStore.saveOwned(owned);
      setState(() {});
      await PowerService.I.recomputeTop6FromRepo();
      return;
    }
    final cur = portrait[h.id] ?? 0;
    if (cur < 10) {
      final next = cur + 1;
      portrait[h.id] = next;
      await HeroStore.setPortraitLevel(h.id, next);
      setState(() {});
      await PowerService.I.recomputeTop6FromRepo();
    }
  }

  void _openDetails(GameHero h) async {
    final lvl = portrait[h.id] ?? 0;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GameTheme.deepNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HeroDetailsSheet(
        hero: h,
        owned: owned.contains(h.id),
        portraitLevel: lvl,
        onObtainOrUpgrade: () async {
          await _obtainOrUpgrade(h);
          if (!mounted) return;
          Navigator.pop(context, true);
        },
      ),
    );
    if (!mounted) return;
    if (changed == true) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final list =
        allHeroes
            .where((h) => filterFaction == null || h.faction == filterFaction)
            .toList()
          ..sort((a, b) {
            final r = a.rarity.sort.compareTo(b.rarity.sort);
            if (r != 0) return r;
            return a.id.compareTo(b.id);
          });

    return Column(
      children: [
        _FactionChips(
          current: filterFaction,
          onChanged: (f) => setState(() => filterFaction = f),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(
              12, 8, 12, 12 + MediaQuery.of(context).padding.bottom,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.68,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) => _PremiumHeroCard(
              h: list[i],
              portraitLevel: portrait[list[i].id] ?? 0,
              owned: owned.contains(list[i].id),
              onTap: () => _openDetails(list[i]),
            ),
          ),
        ),
      ],
    );
  }
}

/// ================== 3) GROUP PLAN ==================
class _GroupPlanTab extends StatefulWidget {
  const _GroupPlanTab();
  @override
  State<_GroupPlanTab> createState() => _GroupPlanTabState();
}

class _GroupPlanTabState extends State<_GroupPlanTab> {
  List<HeroPlan> plans = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    plans = await HeroStore.loadPlans();
    setState(() {});
  }

  Future<void> _rename(int idx) async {
    final controller = TextEditingController(text: plans[idx].name);
    final ok = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GameTheme.deepNavy,
        title: const Text('Rename plan'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != null && ok.isNotEmpty) {
      plans[idx].name = ok;
      await HeroStore.savePlans(plans);
      setState(() {});
    }
  }

  Future<void> _edit(int idx) async {
    final res = await Navigator.of(context).push<List<int>>(
      MaterialPageRoute(
        builder: (_) => _PlanEditor(initial: plans[idx].heroIds),
      ),
    );
    if (res != null) {
      plans[idx].heroIds = res;
      await HeroStore.savePlans(plans);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final p = plans[i];
        return GlowContainer(
          glowColor: GameTheme.cosmicPurple,
          glowRadius: 6,
          borderRadius: 16,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          )),
                      const SizedBox(height: 8),
                      _MiniHeroStrip(ids: p.heroIds),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SmallBtn(
                        label: 'Rename',
                        onPressed: () => _rename(i),
                      ),
                      _SmallBtn(
                        label: 'Edit',
                        filled: true,
                        onPressed: () => _edit(i),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlanEditor extends StatefulWidget {
  const _PlanEditor({required this.initial});
  final List<int> initial;
  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  Set<int> owned = {};
  final Set<int> selected = {};
  Faction? filterFaction;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    owned = await HeroStore.loadOwned();
    selected
      ..clear()
      ..addAll(widget.initial);
    setState(() {});
  }

  void _toggle(int id) {
    setState(() {
      if (selected.contains(id)) {
        selected.remove(id);
      } else if (selected.length < 6) {
        selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allowed =
        allHeroes
            .where((h) => owned.contains(h.id))
            .where((h) => filterFaction == null || h.faction == filterFaction)
            .toList()
          ..sort((a, b) {
            final r = a.rarity.sort.compareTo(b.rarity.sort);
            if (r != 0) return r;
            return a.id.compareTo(b.id);
          });

    return Scaffold(
      appBar: AppBar(
        title: Text('Select heroes (${selected.length}/6)'),
        actions: [
          TextButton(
            onPressed: selected.length == 6
                ? () => Navigator.pop(context, selected.toList())
                : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          _FactionChips(
            current: filterFaction,
            onChanged: (f) => setState(() => filterFaction = f),
          ),
          // Synergy preview
          if (selected.isNotEmpty) _SynergyPreview(ids: selected),
          Expanded(
            child: _MiniCardGrid(
              heroes: allowed,
              selected: selected,
              onTap: (h) => _toggle(h.id),
            ),
          ),
        ],
      ),
    );
  }
}

/// ================== SYNERGY PREVIEW ==================
class _SynergyPreview extends StatelessWidget {
  const _SynergyPreview({required this.ids});
  final Set<int> ids;

  @override
  Widget build(BuildContext context) {
    final factions = <Faction>[];
    for (final id in ids) {
      try {
        final hero = allHeroes.firstWhere((h) => h.id == id);
        factions.add(hero.faction);
      } catch (_) {}
    }

    final synergies = FactionSynergies.compute(factions);
    if (synergies.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            GameTheme.emeraldGlow.withOpacity(0.08),
            GameTheme.voidViolet.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GameTheme.emeraldGlow.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 14, color: GameTheme.emeraldGlow),
              SizedBox(width: 6),
              Text(
                'ACTIVE SYNERGIES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: GameTheme.emeraldGlow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: synergies.map((s) {
              final color = GameTheme.factionGlow[s.faction.index] ?? GameTheme.neonBlue;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.bonus.name,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      s.bonus.desc,
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// ================== ORTAK UI ==================
class _FactionChips extends StatelessWidget {
  const _FactionChips({required this.current, required this.onChanged});
  final Faction? current;
  final ValueChanged<Faction?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _GameFilterChip(
            label: 'ALL',
            selected: current == null,
            color: GameTheme.neonBlue,
            onSelected: () => onChanged(null),
          ),
          const SizedBox(width: 6),
          ...Faction.values.map(
            (f) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _GameFilterChip(
                label: f.label,
                icon: f.icon,
                selected: current == f,
                color: GameTheme.factionGlow[f.index] ?? GameTheme.neonBlue,
                onSelected: () => onChanged(f),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameFilterChip extends StatelessWidget {
  const _GameFilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : GameTheme.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : const Color(0xFF2A3352),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 8)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? color : Colors.white38),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? color : Colors.white54,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundEmblem extends StatelessWidget {
  const _RoundEmblem(this.faction, {this.size = 24});
  final Faction faction;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = GameTheme.factionGlow[faction.index] ?? GameTheme.neonBlue;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.2), blurRadius: 6),
        ],
      ),
      child: Icon(faction.icon, size: size * .55, color: color),
    );
  }
}

/// Premium hero card - glow efektli, rarity border gradient'li
class _PremiumHeroCard extends StatelessWidget {
  const _PremiumHeroCard({
    required this.h,
    required this.portraitLevel,
    required this.owned,
    required this.onTap,
    this.footerText,
  });

  final GameHero h;
  final int portraitLevel;
  final bool owned;
  final VoidCallback onTap;
  final String? footerText;

  @override
  Widget build(BuildContext context) {
    final factionGrad = GameTheme.factionGradients[h.faction.index] ??
        [GameTheme.cosmicPurple, GameTheme.voidViolet];
    final rarityGlowColor = GameTheme.rarityGlow[h.rarity.sort] ??
        GameTheme.neonBlue;
    final rarityBorderGrad = GameTheme.rarityBorderGradients[h.rarity.sort];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: rarityBorderGrad != null
            ? ShapeDecoration(
                shape: GradientBoxBorder(
                  gradient: LinearGradient(colors: rarityBorderGrad),
                  borderWidth: 1.5,
                ),
                color: GameTheme.darkSurface,
                shadows: [
                  BoxShadow(
                    color: rarityGlowColor.withOpacity(0.12),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: GameTheme.darkSurface,
                border: Border.all(color: const Color(0xFF2A3352)),
                boxShadow: [
                  BoxShadow(
                    color: rarityGlowColor.withOpacity(0.12),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // Faction gradient background
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: factionGrad,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

              // Dark overlay for readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        GameTheme.abyss.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Faction emblem - top left
              Positioned(left: 6, top: 6, child: _RoundEmblem(h.faction, size: 20)),

              // Rarity badge - top right
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: rarityGlowColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: rarityGlowColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    h.rarity.label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: rarityGlowColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // Center - large faction icon
              Positioned.fill(
                child: Center(
                  child: Icon(
                    h.faction.icon,
                    size: 40,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
              ),

              // Bottom info
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: _buildFooter(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    if (footerText != null) {
      return Center(
        child: Text(
          footerText!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    return Row(
      children: [
        Icon(h.faction.icon, size: 12, color: Colors.white54),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            owned ? 'Portrait $portraitLevel/10' : 'Not owned',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: owned ? GameTheme.emeraldGlow : Colors.white38,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// Mini card grid
class _MiniCardGrid extends StatelessWidget {
  const _MiniCardGrid({required this.heroes, this.selected, this.onTap});

  final List<GameHero> heroes;
  final Set<int>? selected;
  final void Function(GameHero h)? onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        12, 8, 12, 12 + MediaQuery.of(context).padding.bottom,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: heroes.length,
      itemBuilder: (_, i) {
        final h = heroes[i];
        final sel = selected?.contains(h.id) ?? false;
        final factionColor =
            GameTheme.factionGlow[h.faction.index] ?? GameTheme.neonBlue;
        final rarityColor =
            GameTheme.rarityGlow[h.rarity.sort] ?? GameTheme.neonBlue;

        return GestureDetector(
          onTap: onTap == null ? null : () => onTap!(h),
          child: Container(
            decoration: BoxDecoration(
              gradient: sel
                  ? LinearGradient(
                      colors: [
                        GameTheme.cosmicPurple.withOpacity(0.2),
                        factionColor.withOpacity(0.1),
                      ],
                    )
                  : null,
              color: sel ? null : GameTheme.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? factionColor : const Color(0xFF2A3352),
                width: sel ? 1.5 : 1,
              ),
              boxShadow: sel
                  ? [BoxShadow(color: factionColor.withOpacity(0.1), blurRadius: 8)]
                  : null,
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _RoundEmblem(h.faction, size: 18),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: rarityColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        h.rarity.label,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: rarityColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Icon(h.faction.icon, size: 18, color: factionColor),
                Text(
                  h.shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Mini hero strip for group plans
class _MiniHeroStrip extends StatelessWidget {
  const _MiniHeroStrip({required this.ids});
  final List<int> ids;

  static const int _max = 6;

  @override
  Widget build(BuildContext context) {
    final items = ids.take(_max).toList();

    if (items.isEmpty) {
      return const Text(
        'Empty',
        style: TextStyle(color: Colors.white38, fontSize: 12),
      );
    }

    final cols = items.length <= 3 ? items.length : 3;

    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final h = allHeroes.firstWhere((e) => e.id == items[i]);
        final color = GameTheme.factionGlow[h.faction.index] ?? GameTheme.neonBlue;
        return Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.12),
              border: Border.all(color: color.withOpacity(0.4)),
              boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 4)],
            ),
            child: Icon(h.faction.icon, size: 14, color: color),
          ),
        );
      },
    );
  }
}

/// Hero details bottom sheet - premium tasarım
class _HeroDetailsSheet extends StatelessWidget {
  const _HeroDetailsSheet({
    required this.hero,
    required this.owned,
    required this.portraitLevel,
    required this.onObtainOrUpgrade,
  });

  final GameHero hero;
  final bool owned;
  final int portraitLevel;
  final VoidCallback onObtainOrUpgrade;

  @override
  Widget build(BuildContext context) {
    final factionColor =
        GameTheme.factionGlow[hero.faction.index] ?? GameTheme.neonBlue;
    final rarityColor =
        GameTheme.rarityGlow[hero.rarity.sort] ?? GameTheme.neonBlue;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [GameTheme.deepNavy, GameTheme.abyss],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            // Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                _RoundEmblem(hero.faction, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hero.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Role chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: factionColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: factionColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(hero.role.icon, size: 12, color: factionColor),
                                const SizedBox(width: 4),
                                Text(
                                  hero.role.label,
                                  style: TextStyle(fontSize: 10, color: factionColor),
                                ),
                              ],
                            ),
                          ),
                          // Rarity chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: rarityColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: rarityColor.withOpacity(0.4)),
                            ),
                            child: Text(
                              hero.rarity.label,
                              style: TextStyle(fontSize: 10, color: rarityColor, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GameTheme.darkSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A3352)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: GameTheme.amberEnergy, size: 18),
                  const SizedBox(width: 6),
                  Text('Power ${hero.powerBase}'),
                  const Spacer(),
                  Text('Portrait $portraitLevel/10'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (portraitLevel / 10).clamp(0, 1),
                minHeight: 8,
                backgroundColor: GameTheme.midSurface,
                valueColor: AlwaysStoppedAnimation(factionColor),
              ),
            ),
            const SizedBox(height: 16),

            // Abilities
            const Text(
              'Abilities',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...hero.abilities.map(
              (ab) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: GameTheme.darkSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2A3352)),
                ),
                child: Row(
                  children: [
                    Icon(
                      ab.active ? Icons.flash_on : Icons.auto_awesome,
                      size: 16,
                      color: ab.active ? GameTheme.amberEnergy : GameTheme.neonBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ab.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            ab.desc,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: owned
                      ? [factionColor, factionColor.withOpacity(0.7)]
                      : [GameTheme.cosmicPurple, GameTheme.voidViolet],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: (owned ? factionColor : GameTheme.cosmicPurple)
                        .withOpacity(0.3),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: onObtainOrUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  owned
                      ? (portraitLevel >= 10
                          ? 'Maxed (Immortal)'
                          : 'Upgrade Portrait ($portraitLevel/10)')
                      : 'Obtain Hero',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small button helper
class _SmallBtn extends StatelessWidget {
  const _SmallBtn({
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(84, 36)),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 12),
      ),
      visualDensity: VisualDensity.compact,
    );

    final child = Text(label);
    return filled
        ? FilledButton(style: style, onPressed: onPressed, child: child)
        : FilledButton.tonal(style: style, onPressed: onPressed, child: child);
  }
}
