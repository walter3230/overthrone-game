// lib/throne/throne_state.dart
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:overthrone/core/power_service.dart';
import 'package:overthrone/core/currency_service.dart'; // <<< EKLENDİ

class ThroneReq {
  final int gold; // basic currency
  final int ironIngot; // lv 1-30, always
  final int royalSigil; // adds from 11+
  final int ancientCore; // adds from 21+
  final int celestialCrown; // extra for 30
  const ThroneReq({
    required this.gold,
    required this.ironIngot,
    required this.royalSigil,
    required this.ancientCore,
    required this.celestialCrown,
  });
}

class ThroneBonus {
  final double atkPct; // permanent team-wide
  final double hpPct; // permanent team-wide
  final int flatPower; // direct “throne power” (shown as piece)
  const ThroneBonus({
    required this.atkPct,
    required this.hpPct,
    required this.flatPower,
  });
}

// UI'de "Next at Lv.X: +a% ATK, +h% HP, +p Power" için delta modeli
class NextDelta {
  final double atk;
  final double hp;
  final int power;
  const NextDelta(this.atk, this.hp, this.power);
}

class ThroneState {
  ThroneState._();
  static final ThroneState I = ThroneState._();

  // 🔔 SADECE seviye/pencere durumu burada saklanır (materyaller CurrencyService’te)
  static const _kKey =
      'throne_state_v3'; // ← key bump: envanter persist’i kaldırıldı

  final ValueNotifier<int> version = ValueNotifier<int>(0);

  int level = 1; // 1..30

  // ⚠️ Bunlar artık sadece GÖSTERİM için cache (tek kaynak CurrencyService)
  int invGold = 0;
  int invIngot = 0;
  int invSigil = 0;
  int invCore = 0;
  int invCrown = 0;
  int invCrystal = 0;

  // ---- tablolar (değişmedi) ----
  static const List<ThroneReq> _reqs = [
    ThroneReq(
      gold: 50_000,
      ironIngot: 5,
      royalSigil: 0,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 80_000,
      ironIngot: 8,
      royalSigil: 0,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 120_000,
      ironIngot: 12,
      royalSigil: 0,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 180_000,
      ironIngot: 18,
      royalSigil: 0,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 250_000,
      ironIngot: 25,
      royalSigil: 0,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 340_000,
      ironIngot: 34,
      royalSigil: 0,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 450_000,
      ironIngot: 45,
      royalSigil: 0,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 600_000,
      ironIngot: 60,
      royalSigil: 0,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 800_000,
      ironIngot: 80,
      royalSigil: 0,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 1_100_000,
      ironIngot: 110,
      royalSigil: 0,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    // 11..20
    ThroneReq(
      gold: 1_500_000,
      ironIngot: 150,
      royalSigil: 2,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 2_000_000,
      ironIngot: 200,
      royalSigil: 3,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 2_700_000,
      ironIngot: 270,
      royalSigil: 4,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 3_600_000,
      ironIngot: 360,
      royalSigil: 5,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 4_800_000,
      ironIngot: 480,
      royalSigil: 6,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 6_400_000,
      ironIngot: 640,
      royalSigil: 8,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 8_500_000,
      ironIngot: 850,
      royalSigil: 10,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 11_000_000,
      ironIngot: 1100,
      royalSigil: 12,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 14_500_000,
      ironIngot: 1450,
      royalSigil: 14,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 19_000_000,
      ironIngot: 1900,
      royalSigil: 16,
      ancientCore: 0,
      celestialCrown: 0,
    ),
    // 21..30
    ThroneReq(
      gold: 25_000_000,
      ironIngot: 2500,
      royalSigil: 20,
      ancientCore: 1,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 33_000_000,
      ironIngot: 3300,
      royalSigil: 24,
      ancientCore: 1,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 44_000_000,
      ironIngot: 4400,
      royalSigil: 28,
      ancientCore: 2,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 58_000_000,
      ironIngot: 5800,
      royalSigil: 32,
      ancientCore: 2,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 76_000_000,
      ironIngot: 7600,
      royalSigil: 36,
      ancientCore: 3,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 100_000_000,
      ironIngot: 10000,
      royalSigil: 40,
      ancientCore: 4,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 132_000_000,
      ironIngot: 13200,
      royalSigil: 45,
      ancientCore: 5,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 175_000_000,
      ironIngot: 17500,
      royalSigil: 50,
      ancientCore: 6,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 232_000_000,
      ironIngot: 23200,
      royalSigil: 55,
      ancientCore: 8,
      celestialCrown: 0,
    ),
    ThroneReq(
      gold: 310_000_000,
      ironIngot: 31000,
      royalSigil: 60,
      ancientCore: 10,
      celestialCrown: 1,
    ),
  ];

  static const List<ThroneBonus> _bonuses = [
    ThroneBonus(atkPct: .3, hpPct: .3, flatPower: 1500),
    ThroneBonus(atkPct: .4, hpPct: .4, flatPower: 2000),
    ThroneBonus(atkPct: .5, hpPct: .5, flatPower: 2600),
    ThroneBonus(atkPct: .6, hpPct: .6, flatPower: 3300),
    ThroneBonus(atkPct: .8, hpPct: .8, flatPower: 4200),
    ThroneBonus(atkPct: 1.0, hpPct: 1.0, flatPower: 5200),
    ThroneBonus(atkPct: 1.2, hpPct: 1.2, flatPower: 6400),
    ThroneBonus(atkPct: 1.5, hpPct: 1.5, flatPower: 7800),
    ThroneBonus(atkPct: 1.8, hpPct: 1.8, flatPower: 9400),
    ThroneBonus(atkPct: 2.2, hpPct: 2.2, flatPower: 11200),
    ThroneBonus(atkPct: 2.6, hpPct: 2.6, flatPower: 13200),
    ThroneBonus(atkPct: 3.0, hpPct: 3.0, flatPower: 15400),
    ThroneBonus(atkPct: 3.5, hpPct: 3.5, flatPower: 17800),
    ThroneBonus(atkPct: 4.0, hpPct: 4.0, flatPower: 20400),
    ThroneBonus(atkPct: 4.6, hpPct: 4.6, flatPower: 23200),
    ThroneBonus(atkPct: 5.2, hpPct: 5.2, flatPower: 26200),
    ThroneBonus(atkPct: 5.9, hpPct: 5.9, flatPower: 29400),
    ThroneBonus(atkPct: 6.6, hpPct: 6.6, flatPower: 32800),
    ThroneBonus(atkPct: 7.4, hpPct: 7.4, flatPower: 36400),
    ThroneBonus(atkPct: 8.3, hpPct: 8.3, flatPower: 40200),
    ThroneBonus(atkPct: 9.3, hpPct: 9.3, flatPower: 44400),
    ThroneBonus(atkPct: 10.4, hpPct: 10.4, flatPower: 49000),
    ThroneBonus(atkPct: 11.6, hpPct: 11.6, flatPower: 54000),
    ThroneBonus(atkPct: 12.9, hpPct: 12.9, flatPower: 59400),
    ThroneBonus(atkPct: 14.3, hpPct: 14.3, flatPower: 65200),
    ThroneBonus(atkPct: 15.8, hpPct: 15.8, flatPower: 71400),
    ThroneBonus(atkPct: 17.4, hpPct: 17.4, flatPower: 78000),
    ThroneBonus(atkPct: 19.1, hpPct: 19.1, flatPower: 85000),
    ThroneBonus(atkPct: 21.0, hpPct: 21.0, flatPower: 92400),
    ThroneBonus(atkPct: 23.0, hpPct: 23.0, flatPower: 100000),
  ];

  ThroneReq get nextReq => (level >= 30) ? _reqs[29] : _reqs[level];
  ThroneBonus get bonus => _bonuses[(level - 1).clamp(0, 29)];
  int get powerContribution => bonus.flatPower;
  double get atkBonusPct => bonus.atkPct;
  double get hpBonusPct => bonus.hpPct;

  // ----------------- AKIŞLAR -----------------

  /// CurrencyService’teki stokları iç cache’e yansıt (tek kaynak → CS).
  Future<void> refreshFromCurrency() async {
    final s = await CurrencyService.throneStocks();
    invGold = s.gold;
    invIngot = s.ingot;
    invSigil = s.sigil;
    invCore = s.core;
    invCrown = s.crown;
    invCrystal = await CurrencyService.crystals();
    version.value++;
  }

  bool canLevelUp() {
    if (level >= 30) return false;
    final r = _reqs[level];
    // Burada cache kullanıyoruz; UI tarafında sık sık refreshFromCurrency çağrılıyor.
    return invGold >= r.gold &&
        invIngot >= r.ironIngot &&
        invSigil >= r.royalSigil &&
        invCore >= r.ancientCore &&
        (level < 29 || invCrown >= r.celestialCrown);
  }

  /// Harcamayı CS üstünden yap, seviye artır, sonra cache’i yenile.
  Future<bool> levelUp() async {
    if (level >= 30) return false;
    final r = _reqs[level];
    final ok = await CurrencyService.spendThroneMats(
      gold: r.gold,
      ingot: r.ironIngot,
      sigil: r.royalSigil,
      core: r.ancientCore,
      crown: (level == 29) ? r.celestialCrown : 0,
    );
    if (!ok) return false;

    level += 1;
    await _save();
    await refreshFromCurrency(); // stoklar ekranla senkron
    version.value++;
    PowerService.I.recomputeTop6FromRepo();
    return true;
  }

  /// Eski çağrıları bozmayalım: bu artık CS’e delege eder.
  Future<void> grant({
    int gold = 0,
    int ingot = 0,
    int sigil = 0,
    int core = 0,
    int crown = 0,
    int crystal = 0,
  }) async {
    await CurrencyService.grantMaterials(
      gold: gold,
      ingot: ingot,
      sigil: sigil,
      core: core,
      crown: crown,
    );
    if (crystal != 0) {
      await CurrencyService.addCrystals(crystal);
    }
    await refreshFromCurrency();
  }

  /// Bir SONRAKİ seviye için süre (değişmedi)
  Duration nextDuration() {
    final to = level + 1;
    double minutes;
    if (to <= 10) {
      minutes = 5.0 * math.pow(1.35, (to - 1)).toDouble();
    } else if (to <= 20) {
      minutes = 120.0 * math.pow(1.35, (to - 11)).toDouble();
    } else {
      minutes = 480.0 * math.pow(1.35, (to - 21)).toDouble();
    }
    return Duration(minutes: minutes.round());
  }

  NextDelta nextDelta() {
    if (level >= 30) return const NextDelta(0, 0, 0);
    final cur = _bonuses[level - 1];
    final nxt = _bonuses[level];
    return NextDelta(
      nxt.atkPct - cur.atkPct,
      nxt.hpPct - cur.hpPct,
      nxt.flatPower - cur.flatPower,
    );
  }

  // ----------------- Persist (sadece seviye) -----------------

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kKey);
    if (raw != null) {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      level = (m['lvl'] as int?) ?? 1;
    }
    await refreshFromCurrency(); // stokları CS’ten çek
    version.value++;
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kKey, jsonEncode({'lvl': level}));
  }
}
