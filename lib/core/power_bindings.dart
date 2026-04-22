// lib/core/power_bindings.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart' show Colors;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:overthrone/core/power_service.dart';

// Heroes (yeni UI modelleri)
import 'package:overthrone/features/heroes/heroes_page.dart'
    as ui; // allHeroes, HeroStore
import 'package:overthrone/features/heroes/hero_types.dart' as types; // Faction

// Eski core model (PowerService heroPower bunu istiyor)
import 'package:overthrone/features/heroes/hero_data.dart' as old; // HeroUnit
import 'package:overthrone/features/heroes/hero_types.dart' show Faction;
import 'package:overthrone/core/power_service.dart'
    show ExtraBonuses, PowerProviders;
// Gems tipleri
import 'package:overthrone/features/heroes/gems_page.dart'
    show GemItem, GemFamily;

// ---------- helpers ----------
Faction _mapFaction(types.Faction f) => f;

// Heronun id -> base power eşlemesi (UI modelinden okuyacağız)
final Map<int, int> _idToBasePower = {};

T _clamp<T extends num>(T v, T a, T b) => v < a ? a : (v > b ? b : v);

// ---------- GEM: slotları oku + ExtraBonuses üret ----------
Future<ExtraBonuses> _gemsProvider(String heroName) async {
  final p = await SharedPreferences.getInstance();
  final slots = <GemItem>[];

  for (int i = 0; i < 6; i++) {
    final raw = p.getString('gem_eq3_${heroName}_$i');
    if (raw == null || raw.isEmpty) continue;
    try {
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      slots.add(GemItem.fromJson(j));
    } catch (_) {}
  }

  final b = ExtraBonuses();

  // ---- tek taş katkıları (hero_detail_full.dart ile aynı mantık) ----
  double _hpPctByLv(int lv) {
    const t = [0.0, .01, .02, .02, .03, .03, .03, .04, .04, .04, .04];
    return t[_clamp(lv, 1, 10)];
  }

  double _atkPctByLv(int lv) {
    const t = [0.0, .01, .01, .02, .02, .02, .03, .03, .04, .04, .04];
    return t[_clamp(lv, 1, 10)];
  }

  for (final g in slots) {
    final lv = _clamp(g.level, 1, 10);
    b.hpPct += _hpPctByLv(lv) * 100;
    b.atkPct += _atkPctByLv(lv) * 100;

    if (lv >= 5) {
      switch (g.family) {
        case GemFamily.amethyst:
          b.trueDmgPct += (lv >= 9 ? 2 : 1); // armorPen ignore
          if (lv == 10) b.trueDmgPct += 1;
          break;
        case GemFamily.sunstone:
          b.holyDmgPct += (lv >= 9 ? 2 : 1);
          if (lv == 10) b.trueDmgPct += 1;
          break;
        case GemFamily.obsidian:
          b.trueDmgPct += (lv >= 9 ? 2 : 1);
          if (lv == 10) b.trueDmgPct += 1;
          break;
        case GemFamily.emerald:
          b.evasionPct += (lv >= 9 ? 2.0 : 1.0);
          if (lv == 10) b.blockPct += 1.0;
          break;
        case GemFamily.sapphire:
          b.accuracyPct += (lv >= 9 ? 2.0 : 1.0);
          // effectRes görünmez güçte yok; atlıyoruz
          break;
        case GemFamily.ruby:
          b.critDmgPct += (lv >= 9 ? 6.0 : 3.0);
          if (lv == 10) b.critRatePct += 1.0;
          break;
        case GemFamily.topaz:
          b.critRatePct += (lv >= 9 ? 3.0 : 1.5);
          if (lv == 10) b.critDmgPct += 3.0;
          break;
        case GemFamily.quartz:
          b.speedFlat += (lv >= 9 ? 4 : 2);
          // lv10: +1% accuracy vardı; ufak → es geçilebilir
          break;
      }
    }
  }

  // ---- Resonance (3+3 aile) ----
  int _thirdBestLevel(GemFamily f) {
    final lvls = slots.where((s) => s.family == f).map((s) => s.level).toList()
      ..sort((a, b) => b.compareTo(a));
    return lvls.length >= 3 ? lvls[2] : 0;
  }

  int _pair(GemFamily a, GemFamily c) =>
      math.min(_thirdBestLevel(a), _thirdBestLevel(c));
  int _tier(int lv) => lv >= 10 ? 3 : (lv >= 7 ? 2 : (lv >= 5 ? 1 : 0));

  // Brutality: Ruby + Amethyst
  final tBrut = _tier(_pair(GemFamily.ruby, GemFamily.amethyst));
  if (tBrut == 1) {
    b.critRatePct += 5;
    b.critDmgPct += 8;
  }
  if (tBrut == 2) {
    b.critRatePct += 7;
    b.critDmgPct += 12;
  }
  if (tBrut == 3) {
    b.critRatePct += 10;
    b.critDmgPct += 18;
    b.trueDmgPct += 1;
  }

  // Precision: Sapphire + Emerald
  final tPrec = _tier(_pair(GemFamily.sapphire, GemFamily.emerald));
  if (tPrec == 1) {
    b.accuracyPct += 5;
    b.speedFlat += 5;
  }
  if (tPrec == 2) {
    b.accuracyPct += 8;
    b.speedFlat += 10;
  }
  if (tPrec == 3) {
    b.accuracyPct += 10;
    b.speedFlat += 15;
  }

  // Fortitude: Topaz + Obsidian
  final tFort = _tier(_pair(GemFamily.topaz, GemFamily.obsidian));
  if (tFort == 1) {
    b.hpPct += 8;
    b.defPct += 5;
  }
  if (tFort == 2) {
    b.hpPct += 12;
    b.defPct += 8;
  }
  if (tFort == 3) {
    b.hpPct += 15;
    b.defPct += 12;
  }

  // Clarity: Obsidian + Sunstone
  final tClar = _tier(_pair(GemFamily.obsidian, GemFamily.sunstone));
  if (tClar == 1) {
    b.energyRegenPct += 5;
    b.speedFlat += 5;
  }
  if (tClar == 2) {
    b.energyRegenPct += 8;
    b.speedFlat += 10;
  }
  if (tClar == 3) {
    b.energyRegenPct += 12;
    b.speedFlat += 15;
  }

  return b;
}

// ---------- STIGMATA: ana statlar + set bonusları ----------
Future<ExtraBonuses> _stigmataProvider(String heroName) async {
  final p = await SharedPreferences.getInstance();
  final b = ExtraBonuses();

  // 6 kutudaki ana stat ikon indexleri (-1: boş)
  final raw = p.getStringList('stig2_uimains_$heroName') ?? const [];
  final idxs = List<int>.generate(
    6,
    (i) => i < raw.length ? int.tryParse(raw[i]) ?? -1 : -1,
  );

  for (final idx in idxs) {
    switch (idx) {
      case 0:
        b.critRatePct += 2;
        break; // CRate
      case 1:
        b.critDmgPct += 6;
        break; // CDmg
      case 2:
        b.accuracyPct += 3;
        break; // Accuracy
      case 3:
        b.evasionPct += 3;
        break; // Dodge
      case 4: /* break armor */
        break; // şu an güç denkleminde yok
      case 5:
        b.blockPct += 3;
        break; // Block
      default:
        break;
    }
  }

  // Mythic set (opsiyonel)
  final name = p.getString('stig_set_name_$heroName');
  final pieces = p.getInt('stig_set_pieces_$heroName') ?? 0;
  final has4 = pieces >= 4, has6 = pieces >= 6;

  switch (name) {
    case 'Warborn Aegis':
      if (has4) {
        b.defPct += 15;
        b.blockPct += 10;
      }
      if (has6) {
        b.dmgImmunityPct += 10;
      }
      break;
    case 'Windstalker Veil':
      if (has4) {
        b.critRatePct += 10;
        b.critDmgPct += 20;
      }
      break;
    case 'Night Predator':
      if (has4) {
        b.critDmgPct += 25; /* armorPen */
      }
      if (has6) {
        b.trueDmgPct += 5;
      }
      break;
    case 'Lifebinder Grace':
      if (has4) {
        b.accuracyPct += 10;
      }
      if (has6) {
        b.dmgImmunityPct += 3;
      }
      break;
    case 'Archmage Sigil':
      if (has4) {
        b.critDmgPct += 25;
        b.accuracyPct += 10;
      }
      break;
  }

  return b;
}

// ---------- bind ----------

Future<void> bindPowerProviders() async {
  PowerProviders.topHeroes = () async {
    final owned = await ui.HeroStore.loadOwned();
    final useFallback = owned.isEmpty;

    final out = <(old.HeroUnit, String)>[];
    for (final g in ui.allHeroes) {
      if (!useFallback && !owned.contains(g.id)) continue;

      final u = old.HeroUnit(
        id: g.id,
        name: g.name,
        a: Colors.blue,
        b: Colors.purple,
        faction: _mapFaction(g.faction),
        baseHp: g.powerBase * 15,
        baseAtk: g.powerBase * 7,
        baseDef: g.powerBase * 5,
        baseSpeed: 100,
      );
      out.add((u, g.name));
    }
    return out;
  };

  // Kahraman baz gücü sağlayıcısı (PowerService buradan okuyacak)
  PowerProviders.heroBasePower = (old.HeroUnit u) => _idToBasePower[u.id] ?? 0;

  PowerProviders.gems = _gemsProvider;
  PowerProviders.stigmata = _stigmataProvider;
}
