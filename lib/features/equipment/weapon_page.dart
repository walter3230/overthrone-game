import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:overthrone/core/currency_service.dart';
import 'equipment_models.dart';

class WeaponPage extends StatefulWidget {
  const WeaponPage({super.key, required this.heroName});
  final String heroName;

  @override
  State<WeaponPage> createState() => _WeaponPageState();
}

class _WeaponPageState extends State<WeaponPage> {
  // Persist keys
  static const _eqKeyPrefix = 'eq_weapon_'; // hero slot key (JSON of equipped)
  static const _invKey = 'inv_weapon'; // global inventory list

  // Seed inventory examples
  List<EqItem> _items = [
    EqItem(rarity: EqRarity.mythic, level: 5),
    EqItem(rarity: EqRarity.mythic, level: 5, setKind: 'light'),
    EqItem(rarity: EqRarity.legendary, level: 4),
    EqItem(rarity: EqRarity.epic, level: 3),
    EqItem(rarity: EqRarity.elite, level: 2),
  ];

  EqItem? _equipped; // equipped on this hero (not in inventory)
  final Set<EqRarity> _filters = {...EqRarity.values};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  bool _same(EqItem a, EqItem b) =>
      a.rarity == b.rarity && a.level == b.level && a.setKind == b.setKind;

  bool _removeOneFromInventory(EqItem it) {
    final idx = _items.indexWhere((e) => _same(e, it));
    if (idx >= 0) {
      _items.removeAt(idx);
      return true;
    }
    return false;
  }

  Future<void> _loadAll() async {
    final p = await SharedPreferences.getInstance();

    // Inventory
    final invRaw = p.getString(_invKey);
    if (invRaw != null) {
      _items = (jsonDecode(invRaw) as List)
          .map((e) => EqItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    }

    // Slot
    final rawEq = p.getString('$_eqKeyPrefix${widget.heroName}');
    if (rawEq != null && rawEq.trim().isNotEmpty) {
      try {
        _equipped = EqItem.fromJson(
          (jsonDecode(rawEq) as Map).cast<String, dynamic>(),
        );
        _removeOneFromInventory(_equipped!);
      } catch (_) {
        _equipped = null;
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();

    await p.setString(
      _invKey,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );

    final slotKey = '$_eqKeyPrefix${widget.heroName}';
    if (_equipped == null) {
      await p.remove(slotKey);
    } else {
      await p.setString(slotKey, jsonEncode(_equipped!.toJson()));
    }
  }

  Future<void> _equip(EqItem it) async {
    _removeOneFromInventory(it);

    if (_equipped != null) {
      _items.insert(0, _equipped!);
    }

    _equipped = EqItem(rarity: it.rarity, level: it.level)
      ..setKind = it.setKind;

    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Weapon equipped.')));
    setState(() {});
  }

  Future<void> _unequip() async {
    if (_equipped != null) {
      _items.insert(0, _equipped!);
      _equipped = null;
      await _save();
      setState(() {});
    }
  }

  Future<void> _forge(EqItem it, String kind) async {
    if (it.rarity != EqRarity.mythic) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Mythic can be forged.')),
      );
      return;
    }

    final ok = await CurrencyService.spendStones(
      kind: kind == 'void' ? 'Void' : 'Light',
      amount: 100,
    );
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough stones (need 100).')),
      );
      setState(() {});
      return;
    }

    setState(() {
      it.setKind = kind;
      if (_equipped != null && _same(_equipped!, it)) {
        _equipped!.setKind = kind;
      }
    });
    await _save();
  }

  Future<void> _openShop() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            ListTile(
              leading: const Icon(Icons.workspace_premium),
              title: const Text('Mythic Armament Pack'),
              subtitle: const Text(
                r'$100 • 10K Crystal • Mythic Weapon Lv5 • Stone Box (100)',
              ),
              onTap: () async {
                if (!mounted) return;
                Navigator.pop(context);
                final kind = await _pickStone(100);
                if (kind == null) return;
                await CurrencyService.instance.add(
                  crys: 10000,
                  voids: kind == 'void' ? 100 : 0,
                  lights: kind == 'light' ? 100 : 0,
                );
                setState(() {
                  _items.insert(0, EqItem(rarity: EqRarity.mythic, level: 5));
                });
                await _save();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.star_half),
              title: const Text('Champion Starter Pack'),
              subtitle: const Text(
                r'$50 • 5K Crystal • 50 Weapon Shards • Stone Box (50)',
              ),
              onTap: () async {
                if (!mounted) return;
                Navigator.pop(context);
                final kind = await _pickStone(50);
                if (kind == null) return;
                await CurrencyService.instance.add(
                  crys: 5000,
                  voids: kind == 'void' ? 50 : 0,
                  lights: kind == 'light' ? 50 : 0,
                );
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickStone(int amount) => showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Open Stone Box'),
      content: Text('Choose the stone type to receive (x$amount).'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'void'),
          child: const Text('Void'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, 'light'),
          child: const Text('Light'),
        ),
      ],
    ),
  );

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _equipped != null);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Weapon'),
          actions: [
            IconButton(onPressed: _openShop, icon: const Icon(Icons.add)),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatPill(
                    icon: Icons.dark_mode,
                    label: 'VoidStone',
                    load: () => CurrencyService.voidStones(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatPill(
                    icon: Icons.light_mode,
                    label: 'LightStone',
                    load: () => CurrencyService.lightStones(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatPill(
                    icon: Icons.diamond,
                    label: 'Crystals',
                    load: () => CurrencyService.crystals(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _equippedCard(cs),
            const SizedBox(height: 12),
            _filtersRow(),
            const SizedBox(height: 12),
            Text('Inventory', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _grid(),
          ],
        ),
      ),
    );
  }

  Widget _equippedCard(ColorScheme cs) {
    if (_equipped == null) return _empty(cs);
    final it = _equipped!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _rarityIcon(it.rarity),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weapon · ${it.rarity.label}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lv ${it.level}${it.setKind == null ? '' : '  •  ${it.setKind == 'void' ? 'Void Set' : 'Light Set'}'}',
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: _unequip, child: const Text('Unequip')),
            ],
          ),
          const SizedBox(height: 12),
          _bonusSection(it),
        ],
      ),
    );
  }

  Widget _empty(ColorScheme cs) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: cs.outlineVariant),
    ),
    child: const Row(
      children: [
        Icon(Icons.gavel),
        SizedBox(width: 12),
        Expanded(child: Text('No weapon equipped.')),
      ],
    ),
  );

  Widget _rarityIcon(EqRarity r) => CircleAvatar(
    radius: 22,
    backgroundColor: r.color(context).withValues(alpha: .15),
    child: Icon(Icons.gavel, color: r.color(context)),
  );

  Widget _filtersRow() {
    Widget chip(EqRarity r) => FilterChip(
      label: Text(r.label),
      selected: _filters.contains(r),
      onSelected: (v) =>
          setState(() => v ? _filters.add(r) : _filters.remove(r)),
      avatar: Icon(Icons.gavel, size: 18, color: r.color(context)),
    );
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        chip(EqRarity.elite),
        chip(EqRarity.epic),
        chip(EqRarity.legendary),
        chip(EqRarity.mythic),
        TextButton(
          onPressed: () => setState(
            () => _filters
              ..clear()
              ..addAll(EqRarity.values),
          ),
          child: const Text('Clear'),
        ),
      ],
    );
  }

  Widget _grid() {
    final items = _items.where((e) => _filters.contains(e.rarity)).toList();
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final count = (w ~/ 160.0).clamp(1, 4);
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: .78,
          ),
          itemBuilder: (_, i) => _card(items[i]),
        );
      },
    );
  }

  Widget _card(EqItem it) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _sheet(it),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: it.rarity.color(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gavel, color: it.rarity.color(context)),
                const SizedBox(width: 6),
                Text(
                  it.rarity.label,
                  style: TextStyle(color: it.rarity.color(context)),
                ),
              ],
            ),
            const Spacer(),
            Text(
              'Level ${it.level}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                it.setKind == null
                    ? '— —'
                    : (it.setKind == 'void' ? 'Void Set' : 'Light Set'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sheet(EqItem it) async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, controller) => SafeArea(
          child: SingleChildScrollView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: _rarityIcon(it.rarity),
                  title: Text('Weapon · ${it.rarity.label}'),
                  subtitle: Text('Level ${it.level}'),
                ),
                const SizedBox(height: 6),
                _bonusSection(it),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.check),
                  title: const Text('Equip'),
                  onTap: () async {
                    await _equip(it);
                    if (mounted) Navigator.pop(context);
                  },
                ),
                ListTile(
                  enabled: it.rarity == EqRarity.mythic,
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('Forge into Void Set'),
                  subtitle: const Text(
                    'Costs: 100× VoidStone • Unlocks: basic attacks may deal True DMG.',
                  ),
                  onTap: it.rarity == EqRarity.mythic
                      ? () => _forge(it, 'void')
                      : null,
                ),
                ListTile(
                  enabled: it.rarity == EqRarity.mythic,
                  leading: const Icon(Icons.wb_sunny),
                  title: const Text('Forge into Light Set'),
                  subtitle: const Text(
                    'Costs: 100× LightStone • On crit restore Energy & gain Holy DMG (1 turn).',
                  ),
                  onTap: it.rarity == EqRarity.mythic
                      ? () => _forge(it, 'light')
                      : null,
                ),
                if (_equipped != null && _same(_equipped!, it))
                  ListTile(
                    leading: const Icon(Icons.remove_circle_outline),
                    title: const Text('Unequip'),
                    onTap: () async {
                      await _unequip();
                      if (mounted) Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bonusSection(EqItem it) {
    final lines = _bonusLines(it);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bonuses', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        ...lines.map(
          (t) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.add_task, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(t)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<String> _bonusLines(EqItem it) {
    final t = switch (it.rarity) {
      EqRarity.elite => .45,
      EqRarity.epic => .65,
      EqRarity.legendary => .85,
      EqRarity.mythic => 1.00,
    };
    String pct(double v) => '${(v * 100).toStringAsFixed(v >= .1 ? 0 : 1)}%';

    final critRate = (0.02 * t) + (0.002 * it.level);
    final critDmg = (0.18 * t) + (0.02 * it.level);

    final lines = <String>[
      'ATK: scales with hero ATK (≈ (8% + 2%×Lv) × rarity factor)',
      'Crit Rate: +${pct(critRate)}',
      'Crit DMG: +${pct(critDmg)}',
    ];
    if (it.setKind == 'void') lines.add('Set: Void — +2% True DMG.');
    if (it.setKind == 'light') {
      lines.add('Set: Light — +5% Holy DMG & +5% Energy Regen.');
    }
    return lines;
  }
}

// Reuse pill
class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.load,
  });

  final IconData icon;
  final String label;
  final Future<int> Function() load;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: FutureBuilder<int>(
              future: load(),
              builder: (context, snap) {
                final text = snap.hasData
                    ? '$label x${snap.data}'
                    : (snap.hasError ? '$label —' : '$label …');
                return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
              },
            ),
          ),
        ],
      ),
    );
  }
}
