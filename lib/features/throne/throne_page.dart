// lib/throne/throne_state.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart'; // << ValueNotifier için şart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:overthrone/core/currency_service.dart' as cur;
// Opsiyonel: level artınca total power’ı yeniden hesaplatmak istersen kullanılır.
// Kütüğünüzde varsa bırakın, yoksa bu importu ve ilgili satırı silebilirsiniz.
import 'package:overthrone/core/power_service.dart' show PowerService;

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

  Map<String, dynamic> toJson() => {
    'g': gold,
    'i': ironIngot,
    's': royalSigil,
    'c': ancientCore,
    'cc': celestialCrown,
  };
}

class ThroneBonus {
  final double atkPct; // team-wide
  final double hpPct; // team-wide
  final int flatPower; // direct “throne power”
  const ThroneBonus({
    required this.atkPct,
    required this.hpPct,
    required this.flatPower,
  });
}

class ThroneState {
  ThroneState._();
  static final ThroneState I = ThroneState._();

  static const _kKey = 'throne_state_v3';

  // Public
  int level = 1; // 1..30

  // Upgrade runtime
  DateTime? _upgradeEndAt;
  Duration? upgradingPlanned; // persist for progress bar

  // Optional change notifications for other pages
  final ValueNotifier<int> version = ValueNotifier<int>(0);

  // ---------- Static tables ----------
  static const List<ThroneReq> _reqs = [
    // gold, ingot, sigil, core, crown   // index = level-1 (next step uses [level])
    ThroneReq(
      gold: 50_000,
      ironIngot: 5,
      royalSigil: 0,
      ancientCore: 0,
      celestialCrown: 0,
    ), // 1
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
    ), // 10
    // 11..20 add Sigil
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
    ), // 20
    // 21..30 add Core; 30 needs Crown
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
    ), // 30
  ];

  static const List<ThroneBonus> _bonuses = [
    // 1..30
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

  // ---------- Derived ----------
  bool get isUpgrading => _upgradeEndAt != null;

  ThroneReq get nextReq {
    if (level >= 30) return _reqs[29];
    return _reqs[level]; // “next” cost (index = current level)
  }

  ThroneBonus get bonus => _bonuses[(level - 1).clamp(0, 29)];

  // Difference (shown in UI): next level – current level
  ({double atk, double hp, int power}) nextDelta() {
    if (level >= 30) return (atk: 0.0, hp: 0.0, power: 0);
    final curB = bonus;
    final nextB = _bonuses[level];
    return (
      atk: (nextB.atkPct - curB.atkPct),
      hp: (nextB.hpPct - curB.hpPct),
      power: (nextB.flatPower - curB.flatPower),
    );
  }

  /// Duration to reach the next level (current -> current+1)
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

  Duration remainingUpgrade() {
    final end = _upgradeEndAt;
    if (end == null) return Duration.zero;
    final now = DateTime.now();
    return end.isAfter(now) ? end.difference(now) : Duration.zero;
  }

  // ---------- Actions ----------
  /// Spend materials from global CurrencyService and start the timer.
  Future<bool> beginUpgrade() async {
    if (isUpgrading || level >= 30) return false;

    final r = nextReq;
    final ok = await cur.CurrencyService.spendThroneMats(
      gold: r.gold,
      ingot: r.ironIngot,
      sigil: r.royalSigil,
      core: r.ancientCore,
      crown: r.celestialCrown,
    );
    if (!ok) return false;

    final d = nextDuration();
    upgradingPlanned = d;
    _upgradeEndAt = DateTime.now().add(d);
    await _save();
    version.value++;
    return true;
  }

  /// Completes upgrade when timer ends. Call this periodically (e.g. 1s).
  Future<void> pump() async {
    if (!isUpgrading) return;
    if (remainingUpgrade() != Duration.zero) return;

    // Finish
    _upgradeEndAt = null;
    upgradingPlanned = null;
    if (level < 30) level += 1;
    await _save();
    version.value++;

    // Optional: update power system
    try {
      PowerService.I.recomputeTop6FromRepo();
    } catch (_) {
      // ignore if not available
    }
  }

  // ---------- Persistence ----------
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kKey);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        level = (m['lvl'] as int?) ?? 1;
        final end = m['end'] as int?;
        _upgradeEndAt = (end == null || end <= 0)
            ? null
            : DateTime.fromMillisecondsSinceEpoch(end);
        final plannedMs = m['plan'] as int?;
        upgradingPlanned = (plannedMs == null || plannedMs <= 0)
            ? null
            : Duration(milliseconds: plannedMs);
      } catch (_) {
        // ignore decode errors, keep defaults
      }
    }
    version.value++;
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kKey,
      jsonEncode({
        'lvl': level,
        'end': _upgradeEndAt?.millisecondsSinceEpoch ?? 0,
        'plan': upgradingPlanned?.inMilliseconds ?? 0,
      }),
    );
  }
}
