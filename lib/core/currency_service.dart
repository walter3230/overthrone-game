import 'dart:async';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // ValueNotifier

class CurrencyKeys {
  // -------- Shared --------
  static const crystals = 'curr_crystals_v1';

  // -------- Gems --------
  static const gemPity = 'gem_pity_v3';
  static const gemShards = 'gem_shards_v3';
  static const arkaik = 'gem_arkaik_v1';
  static const gemBoxes = 'gem_gembox_v1';

  // -------- Stigmata (v2) --------
  static const stigPity = 'stig2_pity';
  static const stigShards = 'stig2_shards';
  static const mythicBoxes = 'stig2_mythicBoxes';
  static const tickets = 'stig2_tickets';

  // -------- Equipment (NEW) --------
  static const voidStones = 'eq_voidstone_v1';
  static const lightStones = 'eq_lightstone_v1';
  static const equipStoneBoxes = 'eq_stonebox_v1';

  // -------- Research Accel (NEW) --------
  static const acc24h = 'lab_acc_24h_v1';
  static const acc12h = 'lab_acc_12h_v1';
  static const acc6h = 'lab_acc_6h_v1';
  static const acc1h = 'lab_acc_1h_v1';

  // -------- Profile / Rename (NEW) --------
  static const renameCount = 'profile_rename_count_v1';

  // -------- Throne materials (NEW) --------
  static const gold = 'curr_gold_v1';
  static const ingot = 'curr_ingot_v1';
  static const sigil = 'curr_sigil_v1';
  static const core = 'curr_core_v1';
  static const crown = 'curr_crown_v1';
}

class CurrencyService {
  CurrencyService._();

  /// Backward-compat facade for old `.instance` usages (public type).
  static final Compat instance = Compat._();

  static Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  static const int _maxCap = 2000000000;

  // ======= UI canlı göstergeler =======
  static final ValueNotifier<int> crystalsVN = ValueNotifier<int>(0);
  static final ValueNotifier<int> goldVN = ValueNotifier<int>(0);

  /// Açılışta bir kez çağır: mevcut değerleri VN'lere basar.
  static Future<void> load() async {
    final p = await _p;
    crystalsVN.value = p.getInt(CurrencyKeys.crystals) ?? 0;
    goldVN.value = p.getInt(CurrencyKeys.gold) ?? 0;
  }

  static void _maybeNotify(String key, int value) {
    if (key == CurrencyKeys.crystals) {
      crystalsVN.value = value;
    } else if (key == CurrencyKeys.gold) {
      goldVN.value = value;
    }
  }

  // ============== Low level (core) ==============
  static Future<int> getRaw(String key) async {
    final p = await _p;
    final v = p.getInt(key) ?? 0;
    // Okumada da VN senkron (özellikle ilk çağrılar için iyi olur)
    _maybeNotify(key, v);
    return v;
  }

  static Future<int> setRaw(
    String key,
    int value, {
    int min = 0,
    int max = _maxCap,
  }) async {
    final p = await _p;
    final v = value.clamp(min, max);
    await p.setInt(key, v);
    _maybeNotify(key, v);
    return v;
  }

  static Future<int> addRaw(
    String key,
    int delta, {
    int min = 0,
    int max = _maxCap,
  }) async {
    final p = await _p;
    final cur = p.getInt(key) ?? 0;
    final next = (cur + delta).clamp(min, max);
    await p.setInt(key, next);
    _maybeNotify(key, next);
    return next;
  }

  static Future<Map<String, int>> addManyRaw(
    Map<String, int> deltas, {
    int min = 0,
    int max = _maxCap,
  }) async {
    final p = await _p;
    final result = <String, int>{};
    for (final e in deltas.entries) {
      final cur = p.getInt(e.key) ?? 0;
      final next = (cur + e.value).clamp(min, max);
      await p.setInt(e.key, next);
      _maybeNotify(e.key, next);
      result[e.key] = next;
    }
    return result;
  }

  static Future<bool> trySpend(Map<String, int> costs) async {
    final p = await _p;
    for (final e in costs.entries) {
      final cur = p.getInt(e.key) ?? 0;
      if (cur < e.value) return false;
    }
    for (final e in costs.entries) {
      final cur = p.getInt(e.key) ?? 0;
      final next = math.max(0, cur - e.value);
      await p.setInt(e.key, next);
      _maybeNotify(e.key, next);
    }
    return true;
  }

  static Future<Map<String, int>> grant(Map<String, int> rewards) async {
    return addManyRaw(rewards, min: 0, max: _maxCap);
  }

  static String fmtShort(int n) {
    String trim(String s) =>
        s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    if (n >= 1000000000) return '${trim((n / 1e9).toStringAsFixed(1))}b';
    if (n >= 1000000) return '${trim((n / 1e6).toStringAsFixed(1))}m';
    if (n >= 1000) return '${trim((n / 1e3).toStringAsFixed(1))}k';
    return '$n';
  }

  // ============== Typed wrappers ==============
  // Crystals
  static Future<int> crystals() => getRaw(CurrencyKeys.crystals);
  static Future<int> addCrystals(int delta) =>
      addRaw(CurrencyKeys.crystals, delta);

  // -------- Throne materials (NEW) --------
  static Future<int> gold() => getRaw(CurrencyKeys.gold);
  static Future<int> addGold(int d) => addRaw(CurrencyKeys.gold, d);

  static Future<int> ingots() => getRaw(CurrencyKeys.ingot);
  static Future<int> addIngots(int d) => addRaw(CurrencyKeys.ingot, d);

  static Future<int> sigils() => getRaw(CurrencyKeys.sigil);
  static Future<int> addSigils(int d) => addRaw(CurrencyKeys.sigil, d);

  static Future<int> cores() => getRaw(CurrencyKeys.core);
  static Future<int> addCores(int d) => addRaw(CurrencyKeys.core, d);

  static Future<int> crowns() => getRaw(CurrencyKeys.crown);
  static Future<int> addCrowns(int d) => addRaw(CurrencyKeys.crown, d);

  /// Throne materyal stoklarını tek seferde oku.
  static Future<({int gold, int ingot, int sigil, int core, int crown})>
  throneStocks() async {
    final p = await _p;
    final r = (
      gold: p.getInt(CurrencyKeys.gold) ?? 0,
      ingot: p.getInt(CurrencyKeys.ingot) ?? 0,
      sigil: p.getInt(CurrencyKeys.sigil) ?? 0,
      core: p.getInt(CurrencyKeys.core) ?? 0,
      crown: p.getInt(CurrencyKeys.crown) ?? 0,
    );
    // toplu okuma sonrası da notifier'ları güncelle
    goldVN.value = r.gold;
    return r;
  }

  /// Throne materyallerini tek çağrıda artır/azalt (pozitif = ekle, negatif = düş).
  static Future<void> grantMaterials({
    int gold = 0,
    int ingot = 0,
    int sigil = 0,
    int core = 0,
    int crown = 0,
  }) async {
    await addManyRaw({
      if (gold != 0) CurrencyKeys.gold: gold,
      if (ingot != 0) CurrencyKeys.ingot: ingot,
      if (sigil != 0) CurrencyKeys.sigil: sigil,
      if (core != 0) CurrencyKeys.core: core,
      if (crown != 0) CurrencyKeys.crown: crown,
    });
  }

  /// Throne materyallerini harca (her biri opsiyonel). Yetersizse false.
  static Future<bool> spendThroneMats({
    int gold = 0,
    int ingot = 0,
    int sigil = 0,
    int core = 0,
    int crown = 0,
  }) {
    final map = <String, int>{
      if (gold > 0) CurrencyKeys.gold: gold,
      if (ingot > 0) CurrencyKeys.ingot: ingot,
      if (sigil > 0) CurrencyKeys.sigil: sigil,
      if (core > 0) CurrencyKeys.core: core,
      if (crown > 0) CurrencyKeys.crown: crown,
    };
    if (map.isEmpty) return Future.value(true);
    return trySpend(map);
  }

  // -------- Gems / Stigmata / Equipment / Tickets --------
  static Future<int> gemPity() => getRaw(CurrencyKeys.gemPity);
  static Future<int> setGemPity(int v) =>
      setRaw(CurrencyKeys.gemPity, v, min: 0, max: 999999);

  static Future<int> gemShards() => getRaw(CurrencyKeys.gemShards);
  static Future<int> addGemShards(int d) => addRaw(CurrencyKeys.gemShards, d);

  static Future<int> arkaik() => getRaw(CurrencyKeys.arkaik);
  static Future<int> addArkaik(int d) => addRaw(CurrencyKeys.arkaik, d);

  static Future<int> gemBoxes() => getRaw(CurrencyKeys.gemBoxes);
  static Future<int> addGemBoxes(int d) => addRaw(CurrencyKeys.gemBoxes, d);

  static Future<int> stigPity() => getRaw(CurrencyKeys.stigPity);
  static Future<int> setStigPity(int v) =>
      setRaw(CurrencyKeys.stigPity, v, min: 0, max: 999999);

  static Future<int> stigShards() => getRaw(CurrencyKeys.stigShards);
  static Future<int> addStigShards(int d) => addRaw(CurrencyKeys.stigShards, d);

  static Future<int> mythicBoxes() => getRaw(CurrencyKeys.mythicBoxes);
  static Future<int> addMythicBoxes(int d) =>
      addRaw(CurrencyKeys.mythicBoxes, d);

  static Future<int> tickets() => getRaw(CurrencyKeys.tickets);
  static Future<int> addTickets(int d) => addRaw(CurrencyKeys.tickets, d);

  static Future<int> voidStones() => getRaw(CurrencyKeys.voidStones);
  static Future<int> addVoidStones(int d) => addRaw(CurrencyKeys.voidStones, d);

  static Future<int> lightStones() => getRaw(CurrencyKeys.lightStones);
  static Future<int> addLightStones(int d) =>
      addRaw(CurrencyKeys.lightStones, d);

  static Future<int> stoneBoxes() => getRaw(CurrencyKeys.equipStoneBoxes);
  static Future<int> addStoneBoxes(int d) =>
      addRaw(CurrencyKeys.equipStoneBoxes, d);

  /// Spend equipment stones (use: spendStones(kind: 'void', amount: 100)).
  static Future<bool> spendStones({
    required String kind, // 'void' | 'light'
    required int amount,
  }) {
    assert(kind == 'void' || kind == 'light');
    return trySpend({
      kind == 'void' ? CurrencyKeys.voidStones : CurrencyKeys.lightStones:
          amount,
    });
  }

  static Future<bool> openStoneBoxes({
    required int boxes,
    required String kind, // 'void' | 'light'
    required int unitsPerBox,
  }) async {
    assert(kind == 'void' || kind == 'light');
    if (boxes <= 0 || unitsPerBox <= 0) return false;

    final ok = await trySpend({CurrencyKeys.equipStoneBoxes: boxes});
    if (!ok) return false;

    final total = boxes * unitsPerBox;
    if (kind == 'void') {
      await addVoidStones(total);
    } else {
      await addLightStones(total);
    }
    return true;
  }

  // ============== NEW: Research accelerators & crystal speedups ==============
  static Future<({int acc24, int acc12, int acc6, int acc1})>
  accelStock() async {
    final p = await _p;
    return (
      acc24: p.getInt(CurrencyKeys.acc24h) ?? 0,
      acc12: p.getInt(CurrencyKeys.acc12h) ?? 0,
      acc6: p.getInt(CurrencyKeys.acc6h) ?? 0,
      acc1: p.getInt(CurrencyKeys.acc1h) ?? 0,
    );
  }

  static Future<void> addAccels({
    int acc24 = 0,
    int acc12 = 0,
    int acc6 = 0,
    int acc1 = 0,
  }) async {
    await addManyRaw({
      if (acc24 != 0) CurrencyKeys.acc24h: acc24,
      if (acc12 != 0) CurrencyKeys.acc12h: acc12,
      if (acc6 != 0) CurrencyKeys.acc6h: acc6,
      if (acc1 != 0) CurrencyKeys.acc1h: acc1,
    });
  }

  /// Crystal → süre dönüşümü. 1 saat = 250 crystal (dakika bazlı orantı).
  static Duration crystalToDuration(int crystals) {
    if (crystals <= 0) return Duration.zero;
    final seconds = (crystals / 250.0) * 3600.0;
    return Duration(seconds: seconds.floor());
  }

  /// **Min 5 dakika** kuralı
  static bool _respectsMinCut(Duration d) => d.inMinutes >= 5;

  static Future<
    ({
      Duration reduced,
      int spentCrystals,
      int used24,
      int used12,
      int used6,
      int used1,
      Duration newRemaining,
    })?
  >
  applyResearchSpeedUp({
    required Duration remaining,
    int use24 = 0,
    int use12 = 0,
    int use6 = 0,
    int use1 = 0,
    int crystals = 0,
  }) async {
    if (remaining <= Duration.zero) {
      return (
        reduced: Duration.zero,
        spentCrystals: 0,
        used24: 0,
        used12: 0,
        used6: 0,
        used1: 0,
        newRemaining: Duration.zero,
      );
    }

    // Stok kontrolü
    final stock = await accelStock();
    if (use24 > stock.acc24 ||
        use12 > stock.acc12 ||
        use6 > stock.acc6 ||
        use1 > stock.acc1) {
      return null; // yetersiz scroll
    }

    // Teorik toplam kesinti
    var totalSeconds = 0;
    totalSeconds += use24 * 24 * 3600;
    totalSeconds += use12 * 12 * 3600;
    totalSeconds += use6 * 6 * 3600;
    totalSeconds += use1 * 1 * 3600;

    if (crystals > 0) {
      totalSeconds += crystalToDuration(crystals).inSeconds;
    }

    // Min 5 dk kuralı
    if (totalSeconds < 5 * 60) {
      return null;
    }

    // Kalan süreyi aşma
    final cap = remaining.inSeconds;
    if (totalSeconds > cap) totalSeconds = cap;

    // Harcamalar (atomik): önce crystals, sonra scroll
    if (crystals > 0) {
      final ok = await trySpend({CurrencyKeys.crystals: crystals});
      if (!ok) return null; // crystal yetmedi
    }
    // Scroll düş
    await addManyRaw({
      if (use24 > 0) CurrencyKeys.acc24h: -use24,
      if (use12 > 0) CurrencyKeys.acc12h: -use12,
      if (use6 > 0) CurrencyKeys.acc6h: -use6,
      if (use1 > 0) CurrencyKeys.acc1h: -use1,
    });

    final reduced = Duration(seconds: totalSeconds);
    if (!_respectsMinCut(reduced)) return null;

    final newRem = remaining - reduced;
    return (
      reduced: reduced,
      spentCrystals: crystals,
      used24: use24,
      used12: use12,
      used6: use6,
      used1: use1,
      newRemaining: newRem.isNegative ? Duration.zero : newRem,
    );
  }

  // ============== NEW: Profile rename pricing ==============
  static const int _renameBase = 1000; // crystal
  static const int _renameStep = 500; // crystal

  static Future<int> renameCount() => getRaw(CurrencyKeys.renameCount);

  static Future<int> nextRenameCost() async {
    final n = await renameCount();
    if (n <= 0) return 0;
    return _renameBase + _renameStep * (n - 1);
  }

  static Future<int?> performRenameSpend(String trim) async {
    final n = await renameCount();
    final cost = n == 0 ? 0 : (_renameBase + _renameStep * (n - 1));
    if (cost > 0) {
      final ok = await trySpend({CurrencyKeys.crystals: cost});
      if (!ok) return null;
    }
    await addRaw(CurrencyKeys.renameCount, 1);
    return crystals();
  }

  // ============== High level flows (mevcut) ==============
  static Future<int?> spendCrystals(int amount) async {
    final ok = await trySpend({CurrencyKeys.crystals: amount});
    if (!ok) return null;
    return crystals(); // VN zaten güncellenmiş olacak
  }

  static Future<int?> spendTickets(int amount) async {
    final ok = await trySpend({CurrencyKeys.tickets: amount});
    if (!ok) return null;
    return tickets();
  }

  static Future<int?> spendShards({
    required String key,
    required int amount,
  }) async {
    final ok = await trySpend({key: amount});
    if (!ok) return null;
    final p = await _p;
    return p.getInt(key) ?? 0;
  }

  static Future<Map<String, int>> purchase(Map<String, int> rewards) async {
    return grant(rewards);
  }

  /// Compatibility adder used across the app.
  static Future<Map<String, int>> add({
    int crys = 0,
    int lights = 0,
    int voids = 0,
    int boxes = 0,
    int tickets = 0,
    int gemShards = 0,
    int stigShards = 0,
    int mythicBoxes = 0,
  }) {
    final map = <String, int>{};
    if (crys != 0) map[CurrencyKeys.crystals] = crys;
    if (lights != 0) map[CurrencyKeys.lightStones] = lights;
    if (voids != 0) map[CurrencyKeys.voidStones] = voids;
    if (boxes != 0) map[CurrencyKeys.equipStoneBoxes] = boxes;
    if (tickets != 0) map[CurrencyKeys.tickets] = tickets;
    if (gemShards != 0) map[CurrencyKeys.gemShards] = gemShards;
    if (stigShards != 0) map[CurrencyKeys.stigShards] = stigShards;
    if (mythicBoxes != 0) map[CurrencyKeys.mythicBoxes] = mythicBoxes;
    if (map.isEmpty) return Future.value(<String, int>{});
    return addManyRaw(map);
  }
}

/// Public facade so old code can keep using `CurrencyService.instance`.
class Compat {
  Compat._();

  // read helpers
  Future<int> crystals() => CurrencyService.crystals();
  Future<int> voidStones() => CurrencyService.voidStones();
  Future<int> lightStones() => CurrencyService.lightStones();
  Future<int> stoneBoxes() => CurrencyService.stoneBoxes();

  // old .add(...) / .grant(...) style
  Future<Map<String, int>> add({
    int crys = 0,
    int lights = 0,
    int voids = 0,
    int boxes = 0,
    int tickets = 0,
    int gemShards = 0,
    int stigShards = 0,
    int mythicBoxes = 0,
  }) => CurrencyService.add(
    crys: crys,
    lights: lights,
    voids: voids,
    boxes: boxes,
    tickets: tickets,
    gemShards: gemShards,
    stigShards: stigShards,
    mythicBoxes: mythicBoxes,
  );

  Future<Map<String, int>> grant({
    int crys = 0,
    int lights = 0,
    int voids = 0,
    int boxes = 0,
    int tickets = 0,
  }) => CurrencyService.add(
    crys: crys,
    lights: lights,
    voids: voids,
    boxes: boxes,
    tickets: tickets,
  );

  // positional → named adapter
  Future<bool> spendStones(String kind, int amount) =>
      CurrencyService.spendStones(kind: kind, amount: amount);

  Future<bool> openStoneBoxes({
    required int boxes,
    required String kind,
    required int unitsPerBox,
  }) => CurrencyService.openStoneBoxes(
    boxes: boxes,
    kind: kind,
    unitsPerBox: unitsPerBox,
  );

  Future<Map<String, int>> purchase(Map<String, int> rewards) =>
      CurrencyService.purchase(rewards);
}
