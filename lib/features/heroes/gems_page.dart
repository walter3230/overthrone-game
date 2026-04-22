// lib/features/heroes/gems_page.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Currency service
import 'package:overthrone/core/currency_service.dart';

/// =======================================================
/// GEM MODELİ — İsimli aileler + ilerleyiş
/// =======================================================

enum GemFamily {
  amethyst, // Armor Pen (+ Real DMG at Lv10)
  sunstone, // Holy DMG
  obsidian, // Real DMG
  emerald, // Dodge
  sapphire, // Accuracy / Effect Hit
  ruby, // Crit DMG
  topaz, // Crit Rate
  quartz, // Speed
}

extension GemFamilyX on GemFamily {
  String get name => switch (this) {
    GemFamily.amethyst => 'Amethyst',
    GemFamily.sunstone => 'Sunstone',
    GemFamily.obsidian => 'Obsidian',
    GemFamily.emerald => 'Emerald',
    GemFamily.sapphire => 'Sapphire',
    GemFamily.ruby => 'Ruby',
    GemFamily.topaz => 'Topaz',
    GemFamily.quartz => 'Quartz',
  };

  IconData get icon => switch (this) {
    GemFamily.amethyst => Icons.auto_awesome,
    GemFamily.sunstone => Icons.wb_sunny,
    GemFamily.obsidian => Icons.whatshot,
    GemFamily.emerald => Icons.eco,
    GemFamily.sapphire => Icons.water_drop,
    GemFamily.ruby => Icons.local_fire_department,
    GemFamily.topaz => Icons.center_focus_strong,
    GemFamily.quartz => Icons.speed,
  };
}

/// Envanter öğesi
class GemItem {
  final String id;
  final GemFamily family;
  final int level; // 1..10
  const GemItem({required this.id, required this.family, required this.level});

  GemItem copyWith({GemFamily? family, int? level}) => GemItem(
    id: id,
    family: family ?? this.family,
    level: level ?? this.level,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'family': family.index,
    'level': level,
  };

  factory GemItem.fromJson(Map<String, dynamic> j) => GemItem(
    id: j['id'] as String,
    family: GemFamily.values[j['family'] as int],
    level: j['level'] as int,
  );
}

/// Slotlarda takılı olan gem — null boş demek
typedef GemSlotList = List<GemItem?>;

/// =======================================================
/// STORAGE
/// =======================================================
class _Store {
  static Future<SharedPreferences> get _p async =>
      SharedPreferences.getInstance();

  // v3: isimli aileler + slot bazlı saklama
  static String slotKey(String hero, int i) => 'gem_eq3_${hero}_$i';
  static String get bagKey => 'gem_bag_v3';

  static Future<GemSlotList> loadSlots(String hero) async {
    final p = await _p;
    final out = List<GemItem?>.filled(6, null);
    for (int i = 0; i < 6; i++) {
      final raw = p.getString(slotKey(hero, i));
      if (raw != null) out[i] = GemItem.fromJson(jsonDecode(raw));
    }
    return out;
  }

  static Future<void> saveSlots(String hero, GemSlotList slots) async {
    final p = await _p;
    for (int i = 0; i < 6; i++) {
      final it = slots[i];
      if (it == null) {
        await p.remove(slotKey(hero, i));
      } else {
        await p.setString(slotKey(hero, i), jsonEncode(it.toJson()));
      }
    }
  }

  static Future<List<GemItem>> loadBag() async {
    final p = await _p;
    final raw = p.getString(bagKey);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<dynamic>();
    return list
        .map((e) => GemItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  static Future<void> saveBag(List<GemItem> bag) async {
    final p = await _p;
    await p.setString(bagKey, jsonEncode(bag.map((e) => e.toJson()).toList()));
  }
}

// ===================== RESONANCE HELPERS (TOP-LEVEL) =====================
class _ResoView {
  final String title;
  final String sub;
  final IconData icon;
  const _ResoView(this.title, this.sub, this.icon);
}

/// Bir aile için takılı taşların seviyelerinden, ilk 3’ün en düşük seviyesini döndür.
/// (3 adet yoksa 0 döner → rezonans yok)
int _top3Threshold(GemFamily f, GemSlotList slots) {
  final levels = <int>[];
  for (final g in slots) {
    if (g != null && g.family == f) levels.add(g.level);
  }
  if (levels.length < 3) return 0;
  levels.sort(); // asc
  return levels[levels.length - 3]; // top3 içindeki en düşük seviye
}

int _bestPairLevel(GemFamily a, GemFamily b, GemSlotList slots) =>
    math.min(_top3Threshold(a, slots), _top3Threshold(b, slots));

int _tierFromLevel(int lv) => lv >= 10
    ? 3
    : lv >= 7
    ? 2
    : lv >= 5
    ? 1
    : 0;

List<_ResoView> _detectResonances(GemSlotList slots) {
  final out = <_ResoView>[];

  // Brutality = Ruby + Amethyst (3+3)
  final tBrut = _tierFromLevel(
    _bestPairLevel(GemFamily.ruby, GemFamily.amethyst, slots),
  );
  if (tBrut > 0) {
    out.add(
      _ResoView(
        'Brutality T$tBrut',
        tBrut == 1
            ? '+5% CR • +8% CD'
            : tBrut == 2
            ? '+7% CR • +12% CD'
            : '+10% CR • +18% CD • +1% Real',
        Icons.local_fire_department,
      ),
    );
  }

  // Precision = Sapphire + Emerald (3+3)
  final tPrec = _tierFromLevel(
    _bestPairLevel(GemFamily.sapphire, GemFamily.emerald, slots),
  );
  if (tPrec > 0) {
    out.add(
      _ResoView(
        'Precision T$tPrec',
        tPrec == 1
            ? '+8% EH • +5% Acc • +5 SPD'
            : tPrec == 2
            ? '+10% EH • +8% Acc • +10 SPD'
            : '+12% EH • +10% Acc • +15 SPD',
        Icons.center_focus_strong,
      ),
    );
  }

  // Fortitude = Topaz + Obsidian (3+3)
  final tFort = _tierFromLevel(
    _bestPairLevel(GemFamily.topaz, GemFamily.obsidian, slots),
  );
  if (tFort > 0) {
    out.add(
      _ResoView(
        'Fortitude T$tFort',
        tFort == 1
            ? '+8% HP • +5% DEF • +5% Heal'
            : tFort == 2
            ? '+12% HP • +8% DEF • +8% Heal'
            : '+15% HP • +12% DEF • +12% Heal',
        Icons.shield,
      ),
    );
  }

  // Clarity = Obsidian + Sunstone (3+3)
  final tClar = _tierFromLevel(
    _bestPairLevel(GemFamily.obsidian, GemFamily.sunstone, slots),
  );
  if (tClar > 0) {
    out.add(
      _ResoView(
        'Clarity T$tClar',
        tClar == 1
            ? '+5% Mana Regen • +5% Resist • +5 SPD'
            : tClar == 2
            ? '+8% Mana Regen • +8% Resist • +10 SPD'
            : '+12% Mana Regen • +12% Resist • +15 SPD • +1 Skill Trigger',
        Icons.bolt,
      ),
    );
  }

  return out;
}
// =================== /RESONANCE HELPERS ======================

/// Basit paket modeli (top-level)
class _ShopPack {
  final String title, price, desc;
  final IconData icon;
  final VoidCallback onBuy;
  const _ShopPack({
    required this.title,
    required this.price,
    required this.desc,
    required this.icon,
    required this.onBuy,
  });
}

String _shortInt(int v) {
  String t(double x) =>
      (x % 1 == 0) ? x.toStringAsFixed(0) : x.toStringAsFixed(1);
  if (v >= 1000000) return '${t(v / 1000000)}M';
  if (v >= 10000) return '${t(v / 1000)}K';
  return '$v';
}

/// =======================================================
/// SAYFA
/// =======================================================
class GemsPage extends StatefulWidget {
  const GemsPage({super.key, required this.heroName});
  final String heroName;

  @override
  State<GemsPage> createState() => GemsPageState();
}

class GemsPageState extends State<GemsPage> {
  final _rng = math.Random();

  GemSlotList _slots = List<GemItem?>.filled(6, null);
  List<GemItem> _bag = [];

  int _pity = 30;
  int _shards = 6;
  int _arkaik = 0;
  int _crystals = 0;
  int _gemBoxes = 0;

  // Pull ücretleri (Crystal)
  static const int _costPull1 = 300;
  static const int _costPull10 = 2700; // %10 indirim

  // filtreler
  final Set<GemFamily> _typeFilter = {};
  int _minLv = 1;

  // upgrade: kaç feeder gerekir (seçilen taş harcanmaz)
  static const int _feedersPerUpgrade = 4;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _slots = await _Store.loadSlots(widget.heroName);
    _bag = await _Store.loadBag();

    // Currencies via CurrencyService
    _pity = await CurrencyService.gemPity();
    _shards = await CurrencyService.gemShards();
    _arkaik = await CurrencyService.arkaik();
    _crystals = await CurrencyService.crystals();
    _gemBoxes = await CurrencyService.gemBoxes();

    if (_bag.isEmpty) _seedBag();
    if (mounted) setState(() {});
  }

  void _seedBag() {
    for (int i = 0; i < 12; i++) {
      final fam = GemFamily.values[_rng.nextInt(GemFamily.values.length)];
      final lv = 1 + _rng.nextInt(2);
      _bag.add(_newGem(fam, lv));
    }
  }

  GemItem _newGem(GemFamily f, int lv) => GemItem(
    id: 'g_${DateTime.now().microsecondsSinceEpoch}_${_rng.nextInt(999)}',
    family: f,
    level: lv.clamp(1, 10),
  );

  Future<void> _persistAll() async {
    await _Store.saveSlots(widget.heroName, _slots);
    await _Store.saveBag(_bag);

    await CurrencyService.setGemPity(_pity);
    await CurrencyService.setRaw(CurrencyKeys.gemShards, _shards);
    await CurrencyService.setRaw(CurrencyKeys.arkaik, _arkaik);
    await CurrencyService.setRaw(CurrencyKeys.crystals, _crystals);
    await CurrencyService.setRaw(CurrencyKeys.gemBoxes, _gemBoxes);
  }

  // En üstte, diğer helper’ların yanına:
  int _cmpGem(GemItem a, GemItem b) {
    // 1) Level DESC
    final byLv = b.level.compareTo(a.level);
    if (byLv != 0) return byLv;

    // 2) Aile (stabil bir ikincil sıralama)
    final byFam = a.family.index.compareTo(b.family.index);
    if (byFam != 0) return byFam;

    // 3) Son olarak id (stabilite)
    return a.id.compareTo(b.id);
  }

  // =====================================================
  // SHOP + PURCHASES
  // =====================================================

  void _openShop() {
    final cs = Theme.of(context).colorScheme;

    final packs = <_ShopPack>[
      _ShopPack(
        title: 'Starter Pouch',
        price: '\$4.99',
        desc: '500 Crystals • +12 Shards • +20 Arkaik',
        icon: Icons.blur_on,
        onBuy: () {
          _applyPurchase(crystals: 500, shards: 12, arkaik: 20);
        },
      ),
      _ShopPack(
        title: 'Early Builder',
        price: '\$9.99',
        desc: '1,000 Crystals • +25 Shards • +40 Arkaik • +1× Lv4 Selector',
        icon: Icons.inventory_2,
        onBuy: () {
          _applyPurchase(crystals: 1000, shards: 25, arkaik: 40, selLv4: 1);
        },
      ),
      _ShopPack(
        title: 'Progress Pack',
        price: '\$19.99',
        desc: '2,000 Crystals • +50 Shards • +80 Arkaik • +1× Lv5 Selector',
        icon: Icons.auto_graph,
        onBuy: () {
          _applyPurchase(crystals: 2000, shards: 50, arkaik: 80, selLv5: 1);
        },
      ),
      _ShopPack(
        title: 'Advanced Builder',
        price: '\$49.99',
        desc:
            '5,000 Crystals • +120 Shards • +160 Arkaik • +2× Lv5 Selector • +1 GemBox',
        icon: Icons.workspace_premium,
        onBuy: () {
          _applyPurchase(
            crystals: 5000,
            shards: 120,
            arkaik: 160,
            selLv5: 2,
            gembox: 1,
          );
        },
      ),
      _ShopPack(
        title: 'Whale Vault',
        price: '\$99.99',
        desc:
            '10,000 Crystals • +250 Shards • +320 Arkaik • +3× Lv5 Selector • +4 GemBox',
        icon: Icons.stars,
        onBuy: () {
          _applyPurchase(
            crystals: 10000,
            shards: 250,
            arkaik: 320,
            selLv5: 3,
            gembox: 4,
          );
        },
      ),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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
                title: const Text('Shop'),
                subtitle: Text('Crystals: $_crystals • GemBox: x$_gemBoxes'),
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
                  child: Text(p.price),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _applyPurchase({
    int crystals = 0,
    int shards = 0,
    int arkaik = 0,
    int gembox = 0,
    int selLv4 = 0,
    int selLv5 = 0,
  }) async {
    final res = await CurrencyService.purchase({
      if (crystals > 0) CurrencyKeys.crystals: crystals,
      if (shards > 0) CurrencyKeys.gemShards: shards,
      if (arkaik > 0) CurrencyKeys.arkaik: arkaik,
      if (gembox > 0) CurrencyKeys.gemBoxes: gembox,
    });

    setState(() {
      _crystals = res[CurrencyKeys.crystals] ?? _crystals;
      _shards = res[CurrencyKeys.gemShards] ?? _shards;
      _arkaik = res[CurrencyKeys.arkaik] ?? _arkaik;
      _gemBoxes = res[CurrencyKeys.gemBoxes] ?? _gemBoxes;
    });
    await _persistAll();
    if (!mounted) return;

    final msg = [
      if (crystals > 0) '+$crystals Crystals',
      if (shards > 0) '+$shards Shards',
      if (arkaik > 0) '+$arkaik Arkaik',
      if (gembox > 0) '+$gembox GemBox',
      if (selLv4 > 0) '+$selLv4× Lv4 Selector',
      if (selLv5 > 0) '+$selLv5× Lv5 Selector',
    ].join(' • ');
    _toast('Purchased: $msg');

    // Seçiciler varsa hemen seçtir
    if (selLv4 > 0 || selLv5 > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Select your bonus gems'),
          action: SnackBarAction(
            label: 'Pick now',
            onPressed: () => _grantGemSelectors(lv4: selLv4, lv5: selLv5),
          ),
        ),
      );
    }
  }

  Future<void> _grantGemSelectors({int lv4 = 0, int lv5 = 0}) async {
    for (int i = 0; i < lv4; i++) {
      await _pickOneGem(level: 4);
    }
    for (int i = 0; i < lv5; i++) {
      await _pickOneGem(level: 5);
    }
  }

  Future<void> _pickOneGem({required int level}) async {
    final fam = await showModalBottomSheet<GemFamily>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: GemFamily.values.map((f) {
              return OutlinedButton.icon(
                icon: Icon(f.icon, size: 16),
                label: Text(f.name),
                onPressed: () => Navigator.pop(context, f),
              );
            }).toList(),
          ),
        ),
      ),
    );
    if (fam == null) return;
    setState(() => _bag.add(_newGem(fam, level)));
    await _persistAll();
    _toast('Received 1× Lv$level ${fam.name}');
  }

  // GemBox açma — toplam 6 adet Lv5, tür dağıtımı serbest
  void _openGemBox() {
    if (_gemBoxes <= 0) return;
    final cs = Theme.of(context).colorScheme;
    const maxPick = 6;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, controller) {
          final picks = <GemFamily, int>{
            for (final f in GemFamily.values) f: 0,
          };
          int total() => picks.values.fold(0, (a, b) => a + b);

          return StatefulBuilder(
            builder: (ctx, setSB) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ListTile(
                  leading: const Icon(Icons.card_giftcard),
                  title: const Text('GemBox — Choose any 6 (Lv 5)'),
                  subtitle: Text(
                    'Remaining: ${maxPick - total()}',
                    style: Theme.of(ctx).textTheme.labelMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final f in GemFamily.values)
                      _gemPickTile(
                        ctx,
                        family: f,
                        count: picks[f]!,
                        onDec: () => setSB(() {
                          if (picks[f]! > 0) picks[f] = picks[f]! - 1;
                        }),
                        onInc: () => setSB(() {
                          if (total() < maxPick) picks[f] = picks[f]! + 1;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: total() == maxPick
                      ? () {
                          setState(() {
                            picks.forEach((fam, c) {
                              for (int i = 0; i < c; i++) {
                                _bag.add(_newGem(fam, 5));
                              }
                            });
                            _gemBoxes = (_gemBoxes - 1).clamp(0, 999);
                          });
                          _persistAll();
                          Navigator.pop(ctx);
                          _toast('GemBox opened: 6× Lv5 added to bag!');
                        }
                      : null,
                  icon: const Icon(Icons.check),
                  label: Text('Confirm (${total()}/$maxPick)'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _gemPickTile(
    BuildContext ctx, {
    required GemFamily family,
    required int count,
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) {
    final cs = Theme.of(ctx).colorScheme;
    return Container(
      width: (MediaQuery.of(ctx).size.width - 16 * 2 - 10 * 2) / 2, // 2 sütun
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(family.icon, size: 22, color: cs.primary),
          const SizedBox(height: 6),
          Text(family.name, style: Theme.of(ctx).textTheme.labelMedium),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDec,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$count', style: Theme.of(ctx).textTheme.titleMedium),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onInc,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Lv 5', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // =====================================================
  // GEM STATS — metin olarak (popup ve kart için)
  // =====================================================
  List<String> statsFor(GemItem g) {
    // Temel ilerleyiş (hp%, atk%)
    int hp = switch (g.level) {
      1 => 1,
      2 => 2,
      3 => 2,
      4 => 3,
      5 => 3,
      6 => 3,
      7 => 4,
      8 => 4,
      9 => 4,
      _ => 4,
    };
    int atk = switch (g.level) {
      1 => 1,
      2 => 1,
      3 => 2,
      4 => 2,
      5 => 2,
      6 => 3,
      7 => 3,
      8 => 4,
      9 => 4,
      _ => 4,
    };

    // s1 değeri (Lv5'te açılır, Lv9'da artar)
    String? s1;
    switch (g.family) {
      case GemFamily.amethyst: // Armor PEN
        s1 = g.level >= 9
            ? 'Armor PEN +2%'
            : g.level >= 5
            ? 'Armor PEN +1%'
            : null;
        break;
      case GemFamily.sunstone: // Holy
        s1 = g.level >= 9
            ? 'Holy DMG +2%'
            : g.level >= 5
            ? 'Holy DMG +1%'
            : null;
        break;
      case GemFamily.obsidian: // Real
        s1 = g.level >= 9
            ? 'Real DMG +2%'
            : g.level >= 5
            ? 'Real DMG +1%'
            : null;
        break;
      case GemFamily.emerald:
        s1 = g.level >= 9
            ? 'Dodge +2%'
            : g.level >= 5
            ? 'Dodge +1%'
            : null;
        break;
      case GemFamily.sapphire:
        s1 = g.level >= 9
            ? 'Accuracy +2%'
            : g.level >= 5
            ? 'Accuracy +1%'
            : null;
        break;
      case GemFamily.ruby:
        s1 = g.level >= 9
            ? 'CRIT DMG +6%'
            : g.level >= 5
            ? 'CRIT DMG +3%'
            : null;
        break;
      case GemFamily.topaz:
        s1 = g.level >= 9
            ? 'CRIT +3%'
            : g.level >= 5
            ? 'CRIT +1.5%'
            : null;
        break;
      case GemFamily.quartz:
        final spd = g.level >= 9
            ? 4
            : g.level >= 5
            ? 2
            : 0;
        s1 = spd > 0 ? 'SPD +$spd' : null;
        break;
    }

    // s2 (Lv10’da ek ufak bonus)
    String? s2;
    if (g.level >= 10) {
      s2 = switch (g.family) {
        GemFamily.amethyst => 'Real DMG +1%',
        GemFamily.sunstone => 'Real DMG +1%',
        GemFamily.obsidian => 'Armor PEN +1%',
        GemFamily.emerald => 'Block +1%',
        GemFamily.sapphire => 'Effect RES +2%',
        GemFamily.ruby => 'CRIT +1%',
        GemFamily.topaz => 'CRIT DMG +3%',
        GemFamily.quartz => 'Accuracy +1%',
      };
    }

    final out = <String>['HP +$hp%', 'ATK +$atk%'];
    if (s1 != null) out.add(s1);
    if (s2 != null) out.add(s2);
    return out;
  }

  // =====================================================
  // EQUIP / UNEQUIP
  // =====================================================
  void _equipToSlot(GemItem it, int slotIndex) async {
    setState(() {
      _bag.removeWhere((x) => x.id == it.id); // çantadan çıkar
      final back = _slots[slotIndex]; // varsa geri ekle
      if (back != null) _bag.add(back);
      _slots[slotIndex] = it;
    });
    await _persistAll();
  }

  void _unequip(int slotIndex) async {
    final cur = _slots[slotIndex];
    if (cur == null) return;
    setState(() {
      _bag.add(cur);
      _slots[slotIndex] = null;
    });
    await _persistAll();
  }

  // =====================================================
  // UPGRADE (4× aynı + Arkaik) — seçilen taş harcanmaz
  // =====================================================
  int _arkaikCost(int level) {
    // Lv1->2:1, 2->3:2, 3->4:3, 4->5:5, 5->6:8, 6->7:13, 7->8:21, 8->9:34, 9->10:55
    const fib = [1, 2, 3, 5, 8, 13, 21, 34, 55];
    final idx = level - 1;
    if (idx < 0 || idx >= fib.length) return 99;
    return fib[idx];
  }

  bool _canUpgrade(GemItem it) {
    if (it.level >= 10) return false;
    final neededArkaik = _arkaikCost(it.level);
    final sameCount = _bag
        .where((g) => g.family == it.family && g.level == it.level)
        .length;
    // seçilen taş + 3 feeder = 4 adet aynı seviye/family
    return sameCount >= (_feedersPerUpgrade - 1) && _arkaik >= neededArkaik;
  }

  Future<void> _doUpgrade(GemItem it) async {
    if (!_canUpgrade(it)) {
      _toast('Not enough materials');
      return;
    }
    final neededArkaik = _arkaikCost(it.level);
    setState(() {
      // çantadan 3 feeder kaldır
      int toRemove = _feedersPerUpgrade - 1; // 3
      _bag.removeWhere((g) {
        final ok =
            toRemove > 0 &&
            g.family == it.family &&
            g.level == it.level &&
            g.id != it.id;
        if (ok) toRemove--;
        return ok;
      });
      _arkaik -= neededArkaik;

      // seçilen gem +1 (çantada veya slotta olabilir)
      final idx = _bag.indexWhere((g) => g.id == it.id);
      if (idx != -1) {
        _bag[idx] = _bag[idx].copyWith(level: it.level + 1);
      } else {
        for (int i = 0; i < _slots.length; i++) {
          final s = _slots[i];
          if (s != null && s.id == it.id) {
            _slots[i] = s.copyWith(level: s.level + 1);
            break;
          }
        }
      }
    });
    await _persistAll();
    _toast('Upgraded to Lv ${it.level + 1}');
  }

  // =====================================================
  // BANNER / CRAFT / AD
  // =====================================================
  Future<void> _pull({int count = 1}) async {
    final cost = (count == 10) ? _costPull10 : _costPull1;
    final newCr = await CurrencyService.spendCrystals(cost);
    if (newCr == null) {
      _toast('Not enough Crystals ($cost needed)');
      _promptOpenShop();
      return;
    }
    _crystals = newCr;

    for (int i = 0; i < count; i++) {
      _pity = math.max(0, _pity - 1);
      final guaranteed = _pity == 0;
      if (guaranteed) _pity = 30;

      final fam = GemFamily.values[_rng.nextInt(GemFamily.values.length)];
      final lv = guaranteed ? (3 + _rng.nextInt(2)) : (1 + _rng.nextInt(2));
      _bag.add(_newGem(fam, lv));
    }

    await _persistAll();
    _toast(count == 10 ? 'Limited x10 pulled!' : 'Limited x1 pulled!');
    if (mounted) setState(() {});
  }

  void _promptOpenShop() {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Not enough Crystals'),
        action: SnackBarAction(
          label: 'Open Shop',
          textColor: cs.primary,
          onPressed: _openShop,
        ),
      ),
    );
  }

  Future<void> _craft() async {
    final left = await CurrencyService.spendShards(
      key: CurrencyKeys.gemShards,
      amount: 2,
    );
    if (left == null) {
      _toast('Not enough shards');
      return;
    }
    _shards = left;
    final fam = GemFamily.values[_rng.nextInt(GemFamily.values.length)];
    final lv = 1 + _rng.nextInt(2);
    _bag.add(_newGem(fam, lv));
    await _persistAll();
    _toast('Crafted 1 Gem');
    if (mounted) setState(() {});
  }

  Future<void> _adArkaik() async {
    _arkaik = await CurrencyService.addArkaik(1);
    await _persistAll();
    _toast('Ad watched: +1 Arkaik');
    if (mounted) setState(() {});
  }

  void _toast(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final filtered = _bag.where((g) {
      final passType = _typeFilter.isEmpty || _typeFilter.contains(g.family);
      final passLv = g.level >= _minLv;
      return passType && passLv;
    }).toList()..sort(_cmpGem); // <-- eklendi

    // === Dinamik karo oranları (her cihaz) ===
    final screenW = MediaQuery.of(context).size.width;
    const hpad = 16.0;

    // Slots grid
    const slotCols = 3;
    const slotCross = 12.0;
    final slotTileW =
        (screenW - hpad * 2 - slotCross * (slotCols - 1)) / slotCols;
    const slotDesiredH = 168.0;
    final slotAspect = slotTileW / slotDesiredH;

    // Inventory grid
    const invCols = 3;
    const invCross = 10.0;
    final invTileW = (screenW - hpad * 2 - invCross * (invCols - 1)) / invCols;
    const invDesiredH = 164.0;
    final invAspect = invTileW / invDesiredH;

    final reso = _detectResonances(_slots);

    return PopScope(
      // sistem geri'yi biz yöneteceğiz ki sonucu iletelim
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_slots); // her çıkışta slotları geri döndür
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _slots),
          ),
          title: const Text('Gems'),
          actions: [
            IconButton(
              tooltip: 'Shop',
              icon: const Icon(Icons.storefront),
              onPressed: _openShop,
            ),
            const SizedBox(width: 6),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: SizedBox(
              height: 44,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                child: Row(
                  children: [
                    _topBadge(
                      Theme.of(context).colorScheme,
                      Icons.auto_fix_high,
                      'x$_pity',
                    ),
                    _topBadge(
                      Theme.of(context).colorScheme,
                      Icons.all_inclusive,
                      'x$_shards',
                    ),
                    _topBadge(
                      Theme.of(context).colorScheme,
                      Icons.auto_awesome,
                      'x$_arkaik',
                    ),
                    _topBadge(
                      Theme.of(context).colorScheme,
                      Icons.card_giftcard,
                      'x$_gemBoxes',
                    ),
                    _topBadge(
                      Theme.of(context).colorScheme,
                      Icons.blur_on,
                      _shortInt(_crystals),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              height: 52,
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _slots),
                  icon: const Icon(Icons.check),
                  label: const Text('Save & Back'),
                ),
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // slots
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: 6,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: slotCols,
                  mainAxisSpacing: slotCross,
                  crossAxisSpacing: slotCross,
                  childAspectRatio: slotAspect,
                ),
                itemBuilder: (_, i) => _slotCard(i),
              ),
              const SizedBox(height: 12),

              // Header + info button
              Row(
                children: [
                  Text(
                    'Active Resonance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Resonance info',
                    onPressed: _showResoInfo,
                    icon: const Icon(Icons.info_outline),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Active resonance list / none
              reso.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: const Text('No resonance'),
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: reso
                          .map(
                            (r) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cs.outlineVariant),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(r.icon, size: 16),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelLarge,
                                      ),
                                      Text(
                                        r.sub,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
              const SizedBox(height: 16),

              // Actions
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _action(
                    context,
                    icon: Icons.brightness_auto,
                    label: 'Limited x1',
                    onTap: () {
                      _pull(count: 1);
                    },
                  ),
                  _action(
                    context,
                    icon: Icons.brightness_high,
                    label: 'Limited x10',
                    onTap: () {
                      _pull(count: 10);
                    },
                  ),
                  _action(
                    context,
                    icon: Icons.precision_manufacturing,
                    label: 'Craft (2 Shards)',
                    onTap: () {
                      _craft();
                    },
                  ),
                  _action(
                    context,
                    icon: Icons.ondemand_video,
                    label: 'Ad: +1 Arkaik',
                    onTap: () {
                      _adArkaik();
                    },
                  ),
                  if (_gemBoxes > 0)
                    _action(
                      context,
                      icon: Icons.redeem,
                      label: 'Open GemBox (x$_gemBoxes)',
                      onTap: _openGemBox,
                    ),
                  _action(
                    context,
                    icon: Icons.storefront,
                    label: 'Shop',
                    onTap: _openShop,
                  ),
                  _action(
                    context,
                    icon: Icons.card_giftcard,
                    label: _gemBoxes > 0
                        ? 'Open GemBox (x$_gemBoxes)'
                        : 'Open GemBox',
                    enabled: _gemBoxes > 0,
                    onTap: _gemBoxes > 0 ? _openGemBox : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filters
              _filters(cs),
              const SizedBox(height: 10),

              Text('Inventory', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),

              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: filtered.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: invCols,
                  mainAxisSpacing: invCross,
                  crossAxisSpacing: invCross,
                  childAspectRatio: invAspect,
                ),
                itemBuilder: (_, i) => _invCard(filtered[i]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------- widgets

  Widget _filters(ColorScheme cs) {
    Widget chipFor(GemFamily f) {
      final on = _typeFilter.contains(f);
      return FilterChip(
        label: Text(f.name),
        avatar: Icon(f.icon, size: 16),
        selected: on,
        onSelected: (v) => setState(() {
          if (v) {
            _typeFilter.add(f);
          } else {
            _typeFilter.remove(f);
          }
        }),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final f in GemFamily.values) chipFor(f)],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Min Lv'),
              const SizedBox(width: 10),
              DropdownButton<int>(
                value: _minLv,
                onChanged: (v) => setState(() => _minLv = v ?? 1),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Lv 1+')),
                  DropdownMenuItem(value: 3, child: Text('Lv 3+')),
                  DropdownMenuItem(value: 5, child: Text('Lv 5+')),
                  DropdownMenuItem(value: 7, child: Text('Lv 7+')),
                  DropdownMenuItem(value: 10, child: Text('Lv 10')),
                ],
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _typeFilter.clear()),
                child: const Text('Clear Type'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topBadge(ColorScheme cs, IconData icon, String text) {
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

  Widget _pill(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return FittedBox(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: cs.outlineVariant),
        ),
        // ignore: unnecessary_null_comparison
        child: const TextStyle(fontSize: 12) != null
            ? Text(text, style: const TextStyle(fontSize: 12))
            // ignore: dead_code
            : Text(text),
      ),
    );
  }

  Widget _slotCard(int index) {
    final cs = Theme.of(context).colorScheme;
    final it = _slots[index];
    final isEmpty = it == null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _pill(context, 'Slot ${index + 1}'),
          const SizedBox(height: 6),
          if (!isEmpty) Icon(it.family.icon, size: 26, color: cs.primary),
          const Spacer(),
          _pill(context, isEmpty ? 'Empty' : 'Lv ${it.level}'),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isEmpty
                  ? () => _openPickForSlot(index)
                  : () => _unequip(index),
              child: FittedBox(
                child: Text(
                  isEmpty ? 'Equip' : 'Unequip',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPickForSlot(int slotIndex) async {
    final cs = Theme.of(context).colorScheme;
    final pool = List<GemItem>.from(_bag)..sort(_cmpGem);
    if (pool.isEmpty) {
      _toast('No gem in bag');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, controller) => ListView.separated(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: pool.length + 1,
          separatorBuilder: (_, __) => const Divider(height: 1),
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
                  g.family.icon,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
              ),
              title: Text('${g.family.name} • Lv ${g.level}'),
              subtitle: Text(
                statsFor(g).join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(ctx);
                _equipToSlot(g, slotIndex);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _invCard(GemItem it) {
    final cs = Theme.of(context).colorScheme;
    final needArk = _arkaikCost(it.level);
    final canUp = _canUpgrade(it);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openGemSheet(it),
      onLongPress: () => _showGemStats(it),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(it.family.icon, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${it.family.name} • Lv ${it.level}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            ...statsFor(it)
                .take(2)
                .map(
                  (s) => Text(
                    s,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            const SizedBox(height: 2),
            Container(
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: .6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: FittedBox(
                  child: Text(
                    canUp
                        ? 'Tap to Equip / Upgrade (Cost $needArk)'
                        : 'Tap for actions',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGemStats(GemItem it) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.surfaceContainerHighest,
                child: Icon(it.family.icon, color: cs.primary),
              ),
              title: Text('${it.family.name} • Lv ${it.level}'),
              subtitle: Text(statsFor(it).join(' • ')),
            ),
          ],
        ),
      ),
    );
  }

  void _openGemSheet(GemItem it) {
    final cs = Theme.of(context).colorScheme;
    final needArk = _arkaikCost(it.level);
    final canUp = _canUpgrade(it);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
                child: Icon(it.family.icon, color: cs.primary),
              ),
              title: Text('${it.family.name} • Lv ${it.level}'),
              subtitle: Text(statsFor(it).join(' • ')),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('Equip'),
              subtitle: const Text('Choose a slot'),
              onTap: () async {
                Navigator.pop(ctx);
                final idx = await showModalBottomSheet<int>(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Wrap(
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
                    ),
                  ),
                );
                if (idx != null) _equipToSlot(it, idx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: Text('Upgrade (Cost: $needArk Arkaik)'),
              subtitle: const Text('Need 4× same Lv & family (incl. this)'),
              enabled: canUp,
              onTap: canUp
                  ? () {
                      Navigator.pop(ctx);
                      _doUpgrade(it);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // Info sheet: resonance rules
  void _showResoInfo() {
    final cs = Theme.of(context).colorScheme;
    final active = _detectResonances(_slots);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text('Resonance Info', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            _resoRule(
              ctx,
              title: 'Brutality',
              pair:
                  'Ruby + Amethyst — need 3+3 stones (any slots). Tier = min(level of top 3 in each family)',
              icon: Icons.local_fire_department,
              tiers: const [
                'T1 (Lv 5+ each): +5% CR • +8% CD',
                'T2 (Lv 7+ each): +7% CR • +12% CD',
                'T3 (Lv 10 each): +10% CR • +18% CD • +1% Real DMG',
              ],
            ),
            _resoRule(
              ctx,
              title: 'Precision',
              pair:
                  'Sapphire + Emerald — need 3+3 stones (any slots). Tier = min(level of top 3 in each family)',
              icon: Icons.center_focus_strong,
              tiers: const [
                'T1 (Lv 5+ each): +8% Effect Hit • +5% Accuracy • +5 SPD',
                'T2 (Lv 7+ each): +10% Effect Hit • +8% Accuracy • +10 SPD',
                'T3 (Lv 10 each): +12% Effect Hit • +10% Accuracy • +15 SPD',
              ],
            ),
            _resoRule(
              ctx,
              title: 'Fortitude',
              pair:
                  'Topaz + Obsidian — need 3+3 stones. Tier = min(level of top 3 in each family)',
              icon: Icons.shield,
              tiers: const [
                'T1 (Lv 5+ each): +8% HP • +5% DEF • +5% Heal',
                'T2 (Lv 7+ each): +12% HP • +8% DEF • +8% Heal',
                'T3 (Lv 10 each): +15% HP • +12% DEF • +12% Heal',
              ],
            ),
            _resoRule(
              ctx,
              title: 'Clarity',
              pair:
                  'Obsidian + Sunstone — need 3+3 stones. Tier = min(level of top 3 in each family)',
              icon: Icons.bolt,
              tiers: const [
                'T1 (Lv 5+ each): +5% Mana Regen • +5% Resist • +5 SPD',
                'T2 (Lv 7+ each): +8% Mana Regen • +8% Resist • +10 SPD',
                'T3 (Lv 10 each): +12% Mana Regen • +12% Resist • +15 SPD • +1 Extra Skill Trigger',
              ],
            ),
            const SizedBox(height: 16),
            if (active.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: active
                    .map(
                      (r) => Chip(
                        avatar: Icon(r.icon, size: 16),
                        label: Text('${r.title}: ${r.sub}'),
                      ),
                    )
                    .toList(),
              )
            else
              const Text('No active resonance right now.'),
          ],
        ),
      ),
    );
  }

  Widget _resoRule(
    BuildContext ctx, {
    required String title,
    required String pair,
    required IconData icon,
    required List<String> tiers,
  }) {
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
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(pair, style: Theme.of(ctx).textTheme.bodySmall),
          const SizedBox(height: 8),
          ...tiers.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $t'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    final cs = Theme.of(ctx).colorScheme;
    final content = Container(
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
              style: Theme.of(ctx).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: (MediaQuery.of(ctx).size.width - 16 * 2 - 10 * 3) / 3,
      ),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: content,
        ),
      ),
    );
  }
}
