// lib/war/defense_setup_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:overthrone/features/heroes/hero_data.dart'
    show HeroUnit;
import 'package:overthrone/features/heroes/heroes_page.dart'
    as ui; // ui.allHeroes, HeroStore
import 'package:overthrone/features/heroes/hero_types.dart'
    as types; // Faction/Rarity + badge()
import 'package:overthrone/features/heroes/hero_types.dart'
    show Faction;
import 'package:overthrone/core/power_service.dart' show PowerService, fmt;
import 'war_data.dart';

// ---------------- helpers ----------------

Faction _map(types.Faction f) => f;

final Map<int, int> _powerCache = {};

HeroUnit _calibratedUnitFromUi(int id, String name, types.Faction tf) {
  final uiH = ui.allHeroes.firstWhere(
    (e) => e.id == id,
    orElse: () => ui.allHeroes.first,
  );
  final base = uiH.powerBase;
  return HeroUnit(
    id: id,
    name: name,
    a: Colors.blue,
    b: Colors.purple,
    faction: _map(tf),
    baseHp: base * 15,
    baseAtk: base * 7,
    baseDef: base * 5,
    baseSpeed: 100,
  );
}

Future<int> _powerOf(int id, String name, types.Faction tf) async {
  final hit = _powerCache[id];
  if (hit != null) return hit;
  final unit = _calibratedUnitFromUi(id, name, tf);
  final v = await PowerService.I.heroPower(unit, name);
  _powerCache[id] = v;
  return v;
}

class _HeroRow {
  final int id;
  final String name;
  final types.Faction tf;
  final types.Rarity rarity;
  final int power;
  const _HeroRow(this.id, this.name, this.tf, this.rarity, this.power);
}

// ---------------- page ----------------

class DefenseSetupPage extends StatefulWidget {
  const DefenseSetupPage({super.key});
  @override
  State<DefenseSetupPage> createState() => _DefenseSetupPageState();
}

class _DefenseSetupPageState extends State<DefenseSetupPage> {
  final selected = <int>{};
  Set<int> _owned = {};
  List<_HeroRow> _rows = [];
  bool _loading = true;
  late final VoidCallback _powerListener;

  @override
  void initState() {
    super.initState();
    selected.addAll(ArenaRepo.I.defense);
    _loadOwnedAndBuild();

    // Güç değişince listeyi yeniden kur (research/throne/guild vb.)
    _powerListener = () {
      _powerCache.clear();
      _rebuildSorted();
    };
    PowerService.I.totalPower.addListener(_powerListener);
  }

  Future<void> _loadOwnedAndBuild() async {
    final ids = await ui.HeroStore.loadOwned();
    if (!mounted) return;
    _owned = ids;
    selected.removeWhere((id) => !_owned.contains(id));
    await _rebuildSorted();
  }

  Future<void> _rebuildSorted() async {
    if (!mounted) return;
    setState(() => _loading = true);

    // Kaynak: ui.allHeroes (tam havuz)
    final candidates = ui.allHeroes
        .where((h) => _owned.contains(h.id))
        .toList();

    final rows = await Future.wait(
      candidates.map((h) async {
        final p = await _powerOf(h.id, h.name, h.faction);
        return _HeroRow(h.id, h.name, h.faction, h.rarity, p);
      }),
    );

    rows.sort((a, b) => b.power.compareTo(a.power)); // DESC
    final top30 = rows.take(30).toList();

    if (!mounted) return;
    setState(() {
      _rows = top30;
      _loading = false;
    });
  }

  @override
  void dispose() {
    PowerService.I.totalPower.removeListener(_powerListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Set Defense (${selected.length}/6)'),
        actions: [
          TextButton(
            onPressed: selected.length == 6
                ? () async {
                    ArenaRepo.I.setDefense(
                      selected.toList(),
                    ); // ⬅️ kaydet + notify
                    await PowerService.I.recomputeTop6FromRepo();
                    if (mounted) Navigator.pop(context);
                  }
                : null,

            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.74,
                ),
                itemCount: _rows.length,
                itemBuilder: (_, i) {
                  final r = _rows[i];
                  final isOn = selected.contains(r.id);
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        if (isOn) {
                          selected.remove(r.id);
                        } else if (selected.length < 6) {
                          selected.add(r.id);
                        }
                      });
                    },
                    child: _HeroGridCard(
                      id: r.id,
                      name: r.name,
                      tf: r.tf,
                      rarity: r.rarity,
                      selected: isOn,
                      presetPower: r.power,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

String _shortName(String name, types.Faction f) {
  final prefix = '${f.label} ';
  return name.startsWith(prefix) ? name.substring(prefix.length) : name;
}

// ---------------- card (Heroes sayfası stili) ----------------

class _HeroGridCard extends StatelessWidget {
  const _HeroGridCard({
    required this.id,
    required this.name,
    required this.tf,
    required this.rarity,
    required this.selected,
    required this.presetPower,
  });

  final int id;
  final String name;
  final types.Faction tf;
  final types.Rarity rarity;
  final bool selected;
  final int presetPower;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grad = _gradFor(tf);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? cs.primary : cs.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Arkaplan gradyan
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: grad,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Sol üst fraksiyon rozeti
            Positioned(left: 8, top: 8, child: _RoundEmblem(tf)),
            // Sağ üst nadirlik etiketi
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: rarity.badge(cs).withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: rarity.badge(cs)),
                ),
                child: Text(
                  rarity.label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
            // İçerik
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    const Spacer(),
                    // İsim
                    Text(
                      _shortName(name, tf),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),
                    // Güç
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.bolt,
                          size: 16,
                          color: Colors.white,
                        ), // güç simgesi
                        const SizedBox(width: 6),
                        Text(
                          fmt(presetPower),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),
                    Icon(
                      selected ? Icons.check_circle : Icons.add_circle_outline,
                      size: 20,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Küçük fraksiyon rozeti (Heroes sayfasındakine benzer)
class _RoundEmblem extends StatelessWidget {
  const _RoundEmblem(this.f, {this.size = 24});
  final types.Faction f;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: cs.surface.withValues(alpha: .35),
      child: Icon(f.icon, size: size * .6, color: cs.onPrimaryContainer),
    );
  }
}

// Heroes’daki palete yakın gradyanlar
List<Color> _gradFor(types.Faction f) => switch (f) {
  types.Faction.elemental => const [Colors.blue, Colors.purple],
  types.Faction.dark => const [Color(0xFF2C2C54), Color(0xFF6D214F)],
  types.Faction.nature => const [Colors.green, Colors.teal],
  types.Faction.mech => const [Colors.grey, Color(0xFF00BCD4)],
  types.Faction.voidF => const [Color(0xFF1B1B2F), Color(0xFF4E31AA)],
  types.Faction.light => const [Color(0xFFFFD54F), Color(0xFFFFF59D)],
};
