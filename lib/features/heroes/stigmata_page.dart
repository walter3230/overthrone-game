// lib/features/heroes/stigmata_page.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:overthrone/core/currency_service.dart';

/// ===== Public API (Hero page consumes only the main stat list) =====
enum StigmaBonus { critRate, critDmg, accuracy, dodge, breakArmor, block }

class StigmataPage extends StatefulWidget {
  const StigmataPage({
    super.key,
    required this.heroName,
    this.initial = const <StigmaBonus?>[],
  });

  final String heroName;
  final List<StigmaBonus?> initial;

  @override
  State<StigmataPage> createState() => _StigmataPageState();
}

/// ===== Model & helpers =====
enum _SortMode { recommended, levelDesc, rarity, newest }

enum ClassTag { warrior, ranger, raider, healer, mage }

enum StigmaRarity { normal, mythic }

extension ClassTagX on ClassTag {
  String get label => switch (this) {
    ClassTag.warrior => 'Warrior',
    ClassTag.ranger => 'Ranger',
    ClassTag.raider => 'Raider',
    ClassTag.healer => 'Healer',
    ClassTag.mage => 'Mage',
  };
  IconData get icon => switch (this) {
    ClassTag.warrior => Icons.shield,
    ClassTag.ranger => Icons.travel_explore,
    ClassTag.raider => Icons.rocket_launch,
    ClassTag.healer => Icons.medical_services,
    ClassTag.mage => Icons.auto_awesome,
  };
}

extension RarityX on StigmaRarity {
  Color frame(ColorScheme cs) =>
      this == StigmaRarity.mythic ? cs.primary : cs.outlineVariant;
  String get label => this == StigmaRarity.mythic ? 'Mythic' : 'Normal';
}

extension BonusX on StigmaBonus {
  String get label => switch (this) {
    StigmaBonus.critRate => 'CRate',
    StigmaBonus.critDmg => 'CDmg',
    StigmaBonus.accuracy => 'ACC',
    StigmaBonus.dodge => 'Dodge',
    StigmaBonus.breakArmor => 'Break',
    StigmaBonus.block => 'Block',
  };
  IconData get icon => switch (this) {
    StigmaBonus.critRate => Icons.center_focus_strong,
    StigmaBonus.critDmg => Icons.local_fire_department,
    StigmaBonus.accuracy => Icons.gps_fixed,
    StigmaBonus.dodge => Icons.swipe,
    StigmaBonus.breakArmor => Icons.rocket,
    StigmaBonus.block => Icons.security,
  };

  /// numeric contribution (percent) — Lv1..5
  double scaledVal(int lv) {
    switch (this) {
      case StigmaBonus.critRate:
        return 1.0 + 0.6 * (lv - 1); // 1.0 → 3.4
      case StigmaBonus.critDmg:
        return 3.0 + 1.5 * (lv - 1); // 3.0 → 9.0
      case StigmaBonus.accuracy:
        return 1.5 + 0.7 * (lv - 1); // 1.5 → 4.3
      case StigmaBonus.dodge:
        return 1.5 + 0.7 * (lv - 1);
      case StigmaBonus.breakArmor:
        return 2.0 + 0.8 * (lv - 1); // 2.0 → 5.2
      case StigmaBonus.block:
        return 2.0 + 0.8 * (lv - 1);
    }
  }

  String scaledText(int lv) => '+${scaledVal(lv).toStringAsFixed(1)}% $label';
}

class StigmaItem {
  final String id;
  final String setName; // mythic set name or '—'
  final StigmaRarity rarity;
  final ClassTag classTag; // type for normal items
  final StigmaBonus main;
  final List<String> subs; // display only
  final int level; // 1..5 (no upgrade system)
  final bool locked;

  const StigmaItem({
    required this.id,
    required this.setName,
    required this.rarity,
    required this.classTag,
    required this.main,
    required this.subs,
    required this.level,
    required this.locked,
  });

  StigmaItem copyWith({
    String? id,
    String? setName,
    StigmaRarity? rarity,
    ClassTag? classTag,
    StigmaBonus? main,
    List<String>? subs,
    int? level,
    bool? locked,
  }) => StigmaItem(
    id: id ?? this.id,
    setName: setName ?? this.setName,
    rarity: rarity ?? this.rarity,
    classTag: classTag ?? this.classTag,
    main: main ?? this.main,
    subs: subs ?? this.subs,
    level: level ?? this.level,
    locked: locked ?? this.locked,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'setName': setName,
    'rarity': rarity.index,
    'classTag': classTag.index,
    'main': main.index,
    'subs': subs,
    'level': level,
    'locked': locked,
  };
  factory StigmaItem.fromJson(Map<String, dynamic> j) => StigmaItem(
    id: j['id'] as String,
    setName: j['setName'] as String,
    rarity: StigmaRarity.values[j['rarity'] as int],
    classTag: ClassTag.values[j['classTag'] as int],
    main: StigmaBonus.values[j['main'] as int],
    subs: (j['subs'] as List).cast<String>(),
    level: j['level'] as int,
    locked: (j['locked'] as bool?) ?? false,
  );
}

/// ===== Storage =====
class _Store {
  static Future<SharedPreferences> get _p async =>
      SharedPreferences.getInstance();

  static String _slotsKey(String hero) => 'stig2_slots_$hero';
  static String get bagKey => 'stig2_bag';
  static String effectsKey(String hero) => 'stig2_effects_$hero';

  // hero detail sayfasının beklediği anahtarlar
  static String setNameKey(String hero) => 'stig_set_name_$hero';
  static String setPiecesKey(String hero) => 'stig_set_pieces_$hero';

  static Future<void> saveActiveSet({
    required String hero,
    String? name,
    required int pieces,
  }) async {
    final p = await _p;
    await p.setInt(setPiecesKey(hero), pieces);
    if (name == null || name.isEmpty) {
      await p.remove(setNameKey(hero));
    } else {
      await p.setString(setNameKey(hero), name);
    }
  }

  // --- UI: equipped main icons for hero card ---
  static String uiMainsKey(String hero) => 'stig2_uimains_$hero';

  static Future<void> saveUIMains(String hero, List<int> mains) async {
    final p = await _p;
    await p.setStringList(
      uiMainsKey(hero),
      mains.map((e) => e.toString()).toList(),
    );
  }

  // ignore: unused_element
  static Future<List<int>> loadUIMains(String hero) async {
    final p = await _p;
    final raw = p.getStringList(uiMainsKey(hero));
    if (raw == null) return List<int>.filled(6, -1);
    return List<int>.generate(
      6,
      (i) => i < raw.length ? int.tryParse(raw[i]) ?? -1 : -1,
    );
  }

  static Future<void> saveSlots(String hero, List<StigmaItem?> slots) async {
    final p = await _p;
    await p.setStringList(
      _slotsKey(hero),
      slots.map((e) => e == null ? '' : jsonEncode(e.toJson())).toList(),
    );
  }

  static Future<List<StigmaItem?>> loadSlots(String hero) async {
    final p = await _p;
    final raw = p.getStringList(_slotsKey(hero));
    if (raw == null) return List<StigmaItem?>.filled(6, null);
    return raw
        .map(
          (s) => s.isEmpty
              ? null
              : StigmaItem.fromJson(
                  (jsonDecode(s) as Map).cast<String, dynamic>(),
                ),
        )
        .toList();
  }

  static Future<void> saveBag(List<StigmaItem> bag) async {
    final p = await _p;
    await p.setString(bagKey, jsonEncode(bag.map((e) => e.toJson()).toList()));
  }

  static Future<List<StigmaItem>> loadBag() async {
    final p = await _p;
    final raw = p.getString(bagKey);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(StigmaItem.fromJson).toList();
  }

  static Future<void> saveEffects(String hero, Map<String, dynamic> eff) async {
    final p = await _p;
    await p.setString(effectsKey(hero), jsonEncode(eff));
  }
}

/// ===== Page state =====
class _StigmataPageState extends State<StigmataPage> {
  // 6 slots
  List<StigmaItem?> _slots = List<StigmaItem?>.filled(6, null);

  // bag
  List<StigmaItem> _bag = [];

  // currencies
  int pity = 30, shards = 8, mythicBoxes = 0, crystals = 0, tickets = 0;

  // ui
  ClassTag _targetClass = ClassTag.warrior;
  _SortMode _sort = _SortMode.recommended;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _refreshBalances() async {
    pity = await CurrencyService.stigPity();
    shards = await CurrencyService.stigShards();
    mythicBoxes = await CurrencyService.mythicBoxes();
    crystals = await CurrencyService.crystals();
    tickets = await CurrencyService.tickets();
    if (pity == 0) {
      // default pity 30
      pity = 30;
      await CurrencyService.setStigPity(30);
    }
    if (mounted) setState(() {});
  }

  // 1.2k, 3.4m, 2b şeklinde kısaltma
  String _fmt(int n) {
    if (n >= 1000000000) {
      final v = n / 1000000000;
      return v % 1 == 0
          ? '${v.toStringAsFixed(0)}b'
          : '${v.toStringAsFixed(1)}b';
    }
    if (n >= 1000000) {
      final v = n / 1000000;
      return v % 1 == 0
          ? '${v.toStringAsFixed(0)}m'
          : '${v.toStringAsFixed(1)}m';
    }
    if (n >= 1000) {
      final v = n / 1000;
      return v % 1 == 0
          ? '${v.toStringAsFixed(0)}k'
          : '${v.toStringAsFixed(1)}k';
    }
    return n.toString();
  }

  Future<void> _init() async {
    // currency -> CurrencyService
    await _refreshBalances();

    // bag & slots
    _bag = await _Store.loadBag();
    if (_bag.isEmpty) _seedBag();

    final savedSlots = await _Store.loadSlots(widget.heroName);
    if (widget.initial.isNotEmpty) {
      _slots = List<StigmaItem?>.filled(6, null);
      for (int i = 0; i < math.min(6, widget.initial.length); i++) {
        final b = widget.initial[i];
        if (b != null) _slots[i] = _makeNormal(b, _targetClass, 3);
      }
    } else {
      _slots = savedSlots;
    }

    await _persistEffects(); // aktif set & efekt kaydı
    if (!mounted) return;
    setState(() {});
  }

  void _seedBag() {
    for (int i = 0; i < 24; i++) {
      final b = StigmaBonus.values[_rng.nextInt(StigmaBonus.values.length)];
      final ct = ClassTag.values[_rng.nextInt(ClassTag.values.length)];
      final lv = 1 + _rng.nextInt(5);
      _bag.add(_makeNormal(b, ct, lv));
    }
  }

  StigmaItem _makeNormal(StigmaBonus main, ClassTag ct, int lv) => StigmaItem(
    id: 'n_${DateTime.now().microsecondsSinceEpoch}_${_rng.nextInt(999)}',
    setName: '—',
    rarity: StigmaRarity.normal,
    classTag: ct,
    main: main,
    subs: [
      main.scaledText(lv),
      'HP% +${(1 + .5 * (lv - 1)).toStringAsFixed(1)}',
    ],
    level: lv.clamp(1, 5),
    locked: false,
  );

  Future<void> _persistAll() async {
    await _Store.saveBag(_bag);
    await _Store.saveSlots(widget.heroName, _slots);
    await _persistEffects();
  }

  /// ----- sort & score -----
  Map<StigmaBonus, double> _weightsFor(ClassTag tag) {
    switch (tag) {
      case ClassTag.warrior:
        return {
          StigmaBonus.block: 1.0,
          StigmaBonus.breakArmor: .9,
          StigmaBonus.dodge: .6,
          StigmaBonus.accuracy: .5,
          StigmaBonus.critRate: .4,
          StigmaBonus.critDmg: .4,
        };
      case ClassTag.ranger:
        return {
          StigmaBonus.critRate: 1.0,
          StigmaBonus.critDmg: .9,
          StigmaBonus.accuracy: .7,
          StigmaBonus.breakArmor: .6,
          StigmaBonus.dodge: .4,
          StigmaBonus.block: .3,
        };
      case ClassTag.raider:
        return {
          StigmaBonus.critDmg: 1.0,
          StigmaBonus.breakArmor: .9,
          StigmaBonus.critRate: .8,
          StigmaBonus.dodge: .5,
          StigmaBonus.accuracy: .4,
          StigmaBonus.block: .3,
        };
      case ClassTag.healer:
        return {
          StigmaBonus.accuracy: .9,
          StigmaBonus.block: .8,
          StigmaBonus.dodge: .6,
          StigmaBonus.critRate: .3,
          StigmaBonus.critDmg: .3,
          StigmaBonus.breakArmor: .2,
        };
      case ClassTag.mage:
        return {
          StigmaBonus.critDmg: 1.0,
          StigmaBonus.accuracy: .8,
          StigmaBonus.critRate: .75,
          StigmaBonus.breakArmor: .6,
          StigmaBonus.dodge: .3,
          StigmaBonus.block: .3,
        };
    }
  }

  double _score(StigmaItem it, ClassTag target) {
    final w = _weightsFor(target)[it.main] ?? .5;
    final rarityBonus = it.rarity == StigmaRarity.mythic ? 2.0 : 0.0;
    final classMatch = (it.classTag == target) ? 0.5 : 0.0;
    final setSynergy =
        (it.rarity == StigmaRarity.mythic &&
            _mythicSetNameFor(target) == it.setName)
        ? 1.0
        : 0.0;
    return it.level * 1.0 + w * 2.0 + rarityBonus + classMatch + setSynergy;
  }

  void _sortBag() {
    switch (_sort) {
      case _SortMode.recommended:
        _bag.sort(
          (a, b) => _score(b, _targetClass).compareTo(_score(a, _targetClass)),
        );
        break;
      case _SortMode.levelDesc:
        _bag.sort((a, b) => b.level.compareTo(a.level));
        break;
      case _SortMode.rarity:
        _bag.sort((a, b) {
          final r = b.rarity.index.compareTo(a.rarity.index);
          return r != 0 ? r : b.level.compareTo(a.level);
        });
        break;
      case _SortMode.newest:
        _bag.sort((a, b) => b.id.compareTo(a.id));
        break;
    }
  }

  /// ----- equip / unequip / auto -----
  void _equipToSlot(int slotIndex, StigmaItem it) {
    setState(() {
      final back = _slots[slotIndex];
      if (back != null) _bag.add(back);
      _slots[slotIndex] = it;
      _bag.removeWhere((x) => x.id == it.id);
    });
    _persistAll();
  }

  void _unequipSlot(int slotIndex) {
    final cur = _slots[slotIndex];
    if (cur == null) return;
    setState(() {
      _bag.add(cur);
      _slots[slotIndex] = null;
    });
    _persistAll();
  }

  void _autoEquip() {
    final pool = _bag.where((e) => !e.locked).toList();
    pool.sort(
      (a, b) => _score(b, _targetClass).compareTo(_score(a, _targetClass)),
    );
    final pick = pool.take(6).toList();
    setState(() {
      for (int i = 0; i < _slots.length; i++) {
        final s = _slots[i];
        if (s != null) _bag.add(s);
        _slots[i] = null;
      }
      for (int i = 0; i < pick.length; i++) {
        _slots[i] = pick[i];
        _bag.removeWhere((x) => x.id == pick[i].id);
      }
    });
    _persistAll();
    _toast('Auto-equip applied for ${_targetClass.label}');
  }

  /// ----- effects aggregation (persist for hero page) -----
  Future<void> _persistEffects() async {
    final stats = <String, double>{
      'crate': 0,
      'cdmg': 0,
      'acc': 0,
      'dodge': 0,
      'break': 0,
      'block': 0,
      'hp': 0,
      'def': 0,
      'spd': 0,
      'dmgRed': 0,
    };
    final tags = <String>[];

    for (final s in _slots) {
      if (s == null) continue;
      final v = s.main.scaledVal(s.level);
      switch (s.main) {
        case StigmaBonus.critRate:
          stats['crate'] = stats['crate']! + v;
          break;
        case StigmaBonus.critDmg:
          stats['cdmg'] = stats['cdmg']! + v;
          break;
        case StigmaBonus.accuracy:
          stats['acc'] = stats['acc']! + v;
          break;
        case StigmaBonus.dodge:
          stats['dodge'] = stats['dodge']! + v;
          break;
        case StigmaBonus.breakArmor:
          stats['break'] = stats['break']! + v;
          break;
        case StigmaBonus.block:
          stats['block'] = stats['block']! + v;
          break;
      }
      final hp = 1 + .5 * (s.level - 1);
      stats['hp'] = stats['hp']! + hp;
    }

    final cnt = <String, int>{};
    for (final s in _slots) {
      if (s == null || s.rarity != StigmaRarity.mythic || s.setName == '—') {
        continue;
      }
      cnt[s.setName] = (cnt[s.setName] ?? 0) + 1;
    }
    void add(String key, double val) {
      stats[key] = stats[key]! + val;
    }

    cnt.forEach((name, pieces) {
      final has4 = pieces >= 4;
      final has6 = pieces >= 6;
      switch (name) {
        case 'Warborn Aegis':
          if (has4) {
            add('def', 15);
            add('block', 10);
          }
          if (has6) {
            add('dmgRed', 10);
            tags.add('Taunt on open');
          }
          break;
        case 'Windstalker Veil':
          if (has4) {
            add('crate', 10);
            add('cdmg', 20);
          }
          if (has6) {
            tags.add('First turn double-shot');
          }
          break;
        case 'Night Predator':
          if (has4) {
            add('cdmg', 25);
            add('break', 10);
          }
          if (has6) {
            tags.add('True damage under Execute');
          }
          break;
        case 'Lifebinder Grace':
          if (has4) {
            add('acc', 10);
            tags.add('Heal Amp +15%');
          }
          if (has6) {
            tags.add('Self-revive 30%');
          }
          break;
        case 'Archmage Sigil':
          if (has4) {
            add('cdmg', 25);
            add('acc', 10);
          }
          if (has6) {
            tags.add('First skill double-cast');
          }
          break;
      }
    });

    // En iyi mythic seti seçip hero detail için kaydet (>=4 parça ise)
    String? bestName;
    int bestPieces = 0;
    cnt.forEach((name, pieces) {
      if (pieces > bestPieces ||
          (pieces == bestPieces &&
              (bestName == null || name.compareTo(bestName!) < 0))) {
        bestName = name;
        bestPieces = pieces;
      }
    });
    final savePieces = bestPieces >= 4 ? (bestPieces >= 6 ? 6 : bestPieces) : 0;
    await _Store.saveActiveSet(
      hero: widget.heroName,
      name: savePieces >= 4 ? bestName : null,
      pieces: savePieces,
    );

    await _Store.saveEffects(widget.heroName, {'stats': stats, 'tags': tags});
    // ---- also persist 6 mini icons for hero page ----
    final mainsForUi = List<int>.generate(
      6,
      (i) =>
          _slots.length > i && _slots[i] != null ? _slots[i]!.main.index : -1,
    );
    await _Store.saveUIMains(widget.heroName, mainsForUi);
  }

  /// ----- banner / craft / box / shop -----
  void _pullLimited({int count = 1}) async {
    final left = await CurrencyService.spendTickets(count);
    if (left == null) {
      _toast('Not enough Banner Tickets');
      _promptOpenShop();
      return;
    }
    tickets = left;

    // pity'yi servisten çek, güncelle, geri yaz
    pity = await CurrencyService.stigPity();
    for (int i = 0; i < count; i++) {
      pity = math.max(0, pity - 1);
      final guaranteedLv5 = pity == 0;
      if (guaranteedLv5) pity = 30;

      final lv = guaranteedLv5 ? 5 : (1 + _rng.nextInt(5));
      final b = StigmaBonus.values[_rng.nextInt(StigmaBonus.values.length)];
      final ct = ClassTag.values[_rng.nextInt(ClassTag.values.length)];
      _bag.add(_makeNormal(b, ct, lv));
    }
    await CurrencyService.setStigPity(pity);

    await _persistAll();
    setState(() {});
    _toast(count == 10 ? 'Pulled x10!' : 'Pulled x1!');
  }

  void _promptOpenShop() {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Get more Banner Tickets in the Shop'),
        action: SnackBarAction(
          label: 'Open Shop',
          textColor: cs.primary,
          onPressed: _openShop,
        ),
      ),
    );
  }

  void _craft() async {
    const cost = 5;
    final left = await CurrencyService.spendShards(
      key: CurrencyKeys.stigShards,
      amount: cost,
    );
    if (left == null) {
      _toast('Not enough Shards (need $cost)');
      return;
    }
    shards = left;

    final b = StigmaBonus.values[_rng.nextInt(StigmaBonus.values.length)];
    final ct = ClassTag.values[_rng.nextInt(ClassTag.values.length)];
    final lv = 1 + _rng.nextInt(5);
    _bag.add(_makeNormal(b, ct, lv));

    await _persistAll();
    setState(() {});
    _toast('Crafted 1 Stigmata');
  }

  void _openMythicBox() async {
    final boxesNow = await CurrencyService.mythicBoxes();
    if (boxesNow <= 0) {
      _toast('No Mythic Box');
      return;
    }

    final chosen = await showModalBottomSheet<ClassTag>(
      // ignore: use_build_context_synchronously
      context: context,
      // showDragHandle: true,  // Eski SDK'larda yok; kullanma
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ClassTag.values.map((t) {
              return OutlinedButton.icon(
                icon: Icon(t.icon, size: 16),
                label: Text(t.label),
                onPressed: () => Navigator.pop(context, t),
              );
            }).toList(),
          ),
        ),
      ),
    );
    if (chosen == null) return;

    await CurrencyService.addMythicBoxes(-1);

    final setName = _mythicSetNameFor(chosen);
    setState(() {
      for (int i = 0; i < 6; i++) {
        final m = StigmaBonus.values[_rng.nextInt(StigmaBonus.values.length)];
        _bag.add(
          StigmaItem(
            id: 'm_${DateTime.now().microsecondsSinceEpoch}_$i',
            setName: setName,
            rarity: StigmaRarity.mythic,
            classTag: chosen,
            main: m,
            subs: [m.scaledText(5), 'SPD +${1 + _rng.nextInt(2)}'],
            level: 5,
            locked: false,
          ),
        );
      }
    });
    await _persistAll();
    _toast('Mythic Box opened: $setName x6 (Lv5)');
  }

  String _mythicSetNameFor(ClassTag t) => switch (t) {
    ClassTag.warrior => 'Warborn Aegis',
    ClassTag.ranger => 'Windstalker Veil',
    ClassTag.raider => 'Night Predator',
    ClassTag.healer => 'Lifebinder Grace',
    ClassTag.mage => 'Archmage Sigil',
  };

  void _openInfo() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text('Stigmata Info', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 10),
            _infoBlock(ctx, 'Mythic Class Sets', const [
              'Warborn Aegis (Warrior) — 4pc: DEF% +15, Block +10 • 6pc: Taunt + DMG Reduction +10%',
              'Windstalker Veil (Ranger) — 4pc: CRate +10, CDmg +20 • 6pc: First turn double-shot',
              'Night Predator (Raider) — 4pc: CDmg +25, Break +10 • 6pc: True damage under Execute',
              'Lifebinder Grace (Healer) — 4pc: ACC +10, Heal Amp +15 • 6pc: 30% self-revive',
              'Archmage Sigil (Mage) — 4pc: CDmg +25, ACC +10 • 6pc: First skill can double-cast',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _infoBlock(BuildContext ctx, String title, List<String> lines) {
    final cs = Theme.of(ctx).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...lines.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $e'),
            ),
          ),
        ],
      ),
    );
  }

  void _openShop() {
    final cs = Theme.of(context).colorScheme;
    final packs = <_ShopPack>[
      _ShopPack(
        title: 'Starter',
        priceTag: '\$4.99',
        desc: '500 Crystals • +3 Shards • +5 Banners',
        icon: Icons.shopping_bag,
        onBuy: () => _applyPurchase(cr: 500, sh: 3, bn: 5),
      ),
      _ShopPack(
        title: 'Booster',
        priceTag: '\$9.99',
        desc: '1,000 Crystals • +8 Shards • +10 Banners',
        icon: Icons.backpack,
        onBuy: () => _applyPurchase(cr: 1000, sh: 8, bn: 10),
      ),
      _ShopPack(
        title: 'Enhanced',
        priceTag: '\$19.99',
        desc: '2,000 Crystals • +16 Shards • +25 Banners',
        icon: Icons.local_mall,
        onBuy: () => _applyPurchase(cr: 2000, sh: 16, bn: 25),
      ),
      _ShopPack(
        title: 'Elite (Set)',
        priceTag: '\$49.99',
        desc: '5,000 Crystals • +24 Shards • +1 Mythic Box • +50 Banners',
        icon: Icons.workspace_premium,
        onBuy: () => _applyPurchase(cr: 5000, sh: 24, bx: 1, bn: 50),
      ),
      _ShopPack(
        title: 'Mythic Vault',
        priceTag: '\$99.99',
        desc: '10,000 Crystals • +50 Shards • +4 Mythic Box • +100 Banners',
        icon: Icons.star,
        onBuy: () => _applyPurchase(cr: 10000, sh: 50, bx: 4, bn: 100),
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, controller) => ListView.builder(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: packs.length + 1,
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return ListTile(
                leading: const Icon(Icons.storefront),
                title: const Text('Stigmata Shop'),
                subtitle: Text(
                  'Crystals: ${_fmt(crystals)} • Shards: ${_fmt(shards)} • MythicBox: x${_fmt(mythicBoxes)} • Banners: x${_fmt(tickets)}',
                ),
              );
            }
            final p = packs[i - 1];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.surfaceContainerHighest,
                  child: Icon(p.icon, color: cs.primary),
                ),
                title: Text(p.title),
                subtitle: Text(p.desc),
                trailing: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    p.onBuy();
                  },
                  child: Text(p.priceTag),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _applyPurchase({int cr = 0, int sh = 0, int bx = 0, int bn = 0}) async {
    await CurrencyService.purchase({
      if (cr != 0) CurrencyKeys.crystals: cr,
      if (sh != 0) CurrencyKeys.stigShards: sh,
      if (bx != 0) CurrencyKeys.mythicBoxes: bx,
      if (bn != 0) CurrencyKeys.tickets: bn,
    });

    await _refreshBalances();

    final msg = [
      if (cr > 0) '+$cr Crystals',
      if (sh > 0) '+$sh Shards',
      if (bx > 0) '+$bx Mythic Box',
      if (bn > 0) '+$bn Banners',
    ].join(' • ');
    _toast('Purchased: $msg');
  }

  /// ===== Build =====
  @override
  Widget build(BuildContext context) {
    _sortBag();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stigmata'),
        actions: [
          IconButton(
            onPressed: _openInfo,
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(onPressed: _openShop, icon: const Icon(Icons.storefront)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _autoEquip,
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Auto-Equip'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    final ret = _slots
                        .map((e) => e?.main)
                        .toList(growable: false);
                    Navigator.pop(context, ret);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Save & Back'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // status chips — horizontal scroll
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _topBadge(Icons.auto_fix_high, 'x$pity'),
                  _topBadge(Icons.all_inclusive, 'x$shards'),
                  _topBadge(Icons.inventory_2, 'x$mythicBoxes'),
                  _topBadge(Icons.confirmation_number, 'x$tickets'),
                  _topBadge(Icons.blur_on, _fmt(crystals)),
                ],
              ),
            ),
            const SizedBox(height: 10),

            _topControls(),
            const SizedBox(height: 12),

            // 6 slots
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              itemBuilder: (_, i) => _slotTile(i),
            ),
            const SizedBox(height: 12),

            Text(
              'Active Class Set',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            _setChips(),
            const SizedBox(height: 16),

            // Actions
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _action(
                  context,
                  icon: Icons.brightness_auto,
                  label: 'Banner x1',
                  onTap: () => _pullLimited(count: 1),
                ),
                _action(
                  context,
                  icon: Icons.brightness_high,
                  label: 'Banner x10',
                  onTap: () => _pullLimited(count: 10),
                ),
                _action(
                  context,
                  icon: Icons.precision_manufacturing,
                  label: 'Craft (5 Shards)',
                  onTap: _craft,
                ),
                _action(
                  context,
                  icon: Icons.inventory_2,
                  label: 'Open Mythic Box',
                  onTap: _openMythicBox,
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text('Inventory', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _bag.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.90,
              ),
              itemBuilder: (_, i) => _invCard(_bag[i]),
            ),
          ],
        ),
      ),
    );
  }

  /// ===== UI bits =====
  Widget _topControls() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          const Text('Class'),
          const SizedBox(width: 10),
          DropdownButton<ClassTag>(
            value: _targetClass,
            onChanged: (v) => setState(() {
              if (v != null) _targetClass = v;
            }),
            items: ClassTag.values
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Row(
                      children: [
                        Icon(t.icon, size: 16),
                        const SizedBox(width: 6),
                        Text(t.label),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const Spacer(),
          const Text('Sort'),
          const SizedBox(width: 10),
          DropdownButton<_SortMode>(
            value: _sort,
            onChanged: (v) => setState(() {
              if (v != null) _sort = v;
            }),
            items: const [
              DropdownMenuItem(
                value: _SortMode.recommended,
                child: Text('Recommended'),
              ),
              DropdownMenuItem(
                value: _SortMode.levelDesc,
                child: Text('Level'),
              ),
              DropdownMenuItem(value: _SortMode.rarity, child: Text('Rarity')),
              DropdownMenuItem(value: _SortMode.newest, child: Text('Newest')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topBadge(IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(text)],
      ),
    );
  }

  Widget _slotTile(int i) {
    final cs = Theme.of(context).colorScheme;
    final s = _slots[i];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: (s?.rarity ?? StigmaRarity.normal).frame(cs)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: s == null
                  ? const SizedBox.shrink() // empty = no icon
                  : Icon(
                      s.main.icon,
                      size: 28,
                      color: cs.primary.withValues(alpha: .9),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () =>
                  s == null ? _openPickerForSlot(i) : _unequipSlot(i),
              child: FittedBox(child: Text(s == null ? 'Equip' : 'Unequip')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPickerForSlot(int slotIndex) async {
    final pool = _bag;
    if (pool.isEmpty) {
      _toast('No stigmata in bag');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, controller) => ListView.separated(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemCount: pool.length + 1,
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 6),
                child: Center(
                  child: Text(
                    'Choose for Slot ${slotIndex + 1}',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
              );
            }
            final g = pool[i - 1];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(
                  ctx,
                ).colorScheme.surfaceContainerHighest,
                child: Icon(
                  g.main.icon,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
              ),
              title: Text(
                g.rarity == StigmaRarity.mythic ? g.setName : g.classTag.label,
              ),
              subtitle: Text(
                '${g.rarity.label} • ${g.main.label} • Lv ${g.level}',
              ),
              onTap: () {
                Navigator.pop(ctx);
                _equipToSlot(slotIndex, g);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _setChips() {
    final list = _activeMythicSets();
    if (list.isEmpty) {
      return const Wrap(children: [Chip(label: Text('No active class set'))]);
    }
    return Wrap(
      spacing: 8,
      children: list
          .map(
            (s) => Chip(
              avatar: const Icon(Icons.workspace_premium, size: 16),
              label: Text('${s.name}: ${s.state}'),
            ),
          )
          .toList(),
    );
  }

  List<_SetView> _activeMythicSets() {
    final map = <String, int>{};
    for (final s in _slots) {
      if (s == null) continue;
      if (s.rarity != StigmaRarity.mythic || s.setName == '—') continue;
      map[s.setName] = (map[s.setName] ?? 0) + 1;
    }
    final out = <_SetView>[];
    map.forEach((name, cnt) {
      if (cnt >= 4 && cnt < 6) out.add(_SetView(name, '4-Piece Active'));
      if (cnt >= 6) out.add(_SetView(name, '6-Piece Active'));
    });
    return out;
  }

  Widget _invCard(StigmaItem it) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openItemSheet(it),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: it.rarity.frame(cs)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 2),
                  child: Icon(it.main.icon, size: 26, color: cs.primary),
                ),
                if (it.locked) const Icon(Icons.lock, size: 14),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              it.rarity == StigmaRarity.mythic ? it.setName : it.classTag.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openItemSheet(StigmaItem it) async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.surfaceContainerHighest,
                child: Icon(it.main.icon, color: cs.primary),
              ),
              title: Text(
                it.rarity == StigmaRarity.mythic
                    ? it.setName
                    : it.classTag.label,
              ),
              subtitle: Text(
                '${it.rarity.label} • ${it.main.label} • Lv ${it.level}',
              ),
            ),
            const Divider(),
            ...it.subs.map(
              (s) => ListTile(
                dense: true,
                leading: const Icon(Icons.add, size: 16),
                title: Text(s),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickSlotAndEquip(it),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Equip'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        final idx = _bag.indexWhere((x) => x.id == it.id);
                        if (idx != -1) {
                          _bag[idx] = _bag[idx].copyWith(locked: !it.locked);
                        }
                      });
                      _persistAll();
                      Navigator.pop(ctx);
                    },
                    icon: Icon(it.locked ? Icons.lock_open : Icons.lock),
                    label: Text(it.locked ? 'Unlock' : 'Lock'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSlotAndEquip(StigmaItem it) async {
    final idx = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose slot',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  6,
                  (i) => OutlinedButton(
                    onPressed: () => Navigator.pop(context, i),
                    child: Text('Slot ${i + 1}'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (idx == null) return;
    _equipToSlot(idx, it);
  }

  Widget _action(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(ctx).colorScheme;
    final w = MediaQuery.of(ctx).size.width;
    const spacing = 10.0;
    final minW = (w - 32 - 2 * spacing) / 3;
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minW),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
}

class _ShopPack {
  final String title, priceTag, desc;
  final IconData icon;
  final VoidCallback onBuy;
  _ShopPack({
    required this.title,
    required this.priceTag,
    required this.desc,
    required this.icon,
    required this.onBuy,
  });
}

class _SetView {
  final String name, state;
  _SetView(this.name, this.state);
}
