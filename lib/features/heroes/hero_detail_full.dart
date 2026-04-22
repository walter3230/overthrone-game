// ignore_for_file: prefer_const_constructors

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:overthrone/core/power_service.dart';
import 'package:overthrone/guild/guild_tech.dart';
import 'package:overthrone/throne/throne_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:overthrone/features/research/research_data.dart';
import 'dart:convert';
import 'hero_types.dart';
// Modeller
import 'heroes_page.dart' show GameHero;
// Ekipman sayfaları
import '../equipment/weapon_page.dart' show WeaponPage;
import '../equipment/armor_page.dart' show ArmorPage;
import '../equipment/helmet_page.dart' show HelmetPage;
import '../equipment/ring_page.dart' show RingPage;

// Gems & Stigmata
import 'gems_page.dart' show GemsPage, GemFamily, GemItem;
import 'stigmata_page.dart' show StigmataPage, StigmaBonus;

/// ------------------ Yardımcı formatlar ------------------
String _fmt(int v) {
  String t(String s) => s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  if (v >= 1000000000) return '${t((v / 1e9).toStringAsFixed(1))}B';
  if (v >= 1000000) return '${t((v / 1e6).toStringAsFixed(1))}M';
  if (v >= 1000) return '${t((v / 1e3).toStringAsFixed(1))}K';
  return '$v';
}

String _pct(num x) {
  final d = x.toDouble();
  if (d.isNaN || !d.isFinite) return '0%';
  final y = d * 100.0;
  final digits = y.abs() >= 10 ? 0 : 1;
  return '${y.toStringAsFixed(digits)}%';
}

/// ------------------ Stat modeli ------------------
class StatBlock {
  int hp = 0, atk = 0, def = 0, speed = 0;
  double hpPct = 0, atkPct = 0, defPct = 0;

  double critRate = 0, critDmg = 0, accuracy = 0, dodge = 0;
  double block = 0, armorPen = 0, lifesteal = 0, energyRegen = 0;

  // ilave statlar
  double effectHit = 0, effectRes = 0, dmgImmunity = 0;
  double realDmg = 0, holyDmg = 0;

  StatBlock();
  StatBlock operator +(StatBlock o) {
    final r = StatBlock()
      ..hp = hp + o.hp
      ..atk = atk + o.atk
      ..def = def + o.def
      ..speed = speed + o.speed
      ..hpPct = hpPct + o.hpPct
      ..atkPct = atkPct + o.atkPct
      ..defPct = defPct + o.defPct
      ..critRate = critRate + o.critRate
      ..critDmg = critDmg + o.critDmg
      ..accuracy = accuracy + o.accuracy
      ..dodge = dodge + o.dodge
      ..block = block + o.block
      ..armorPen = armorPen + o.armorPen
      ..lifesteal = lifesteal + o.lifesteal
      ..energyRegen = energyRegen + o.energyRegen
      ..effectHit = effectHit + o.effectHit
      ..effectRes = effectRes + o.effectRes
      ..dmgImmunity = dmgImmunity + o.dmgImmunity
      ..realDmg = realDmg + o.realDmg
      ..holyDmg = holyDmg + o.holyDmg;
    return r;
  }
}

/// ------------------ Gem → Stat katkısı ------------------
StatBlock gemToStats(GemItem g) {
  final b = StatBlock();

  // Temel HP% / ATK% (1..10)
  const hpPctTbl = [0.0, .01, .02, .02, .03, .03, .03, .04, .04, .04, .04];
  const atkPctTbl = [0.0, .01, .01, .02, .02, .02, .03, .03, .04, .04, .04];
  final lv = g.level.clamp(1, 10);
  b.hpPct += hpPctTbl[lv];
  b.atkPct += atkPctTbl[lv];

  // Lv5'te 3. stat, Lv9 güçlenir; Lv10'da 4. stat
  if (lv >= 5) {
    switch (g.family) {
      case GemFamily.amethyst:
        b.armorPen += (lv >= 9) ? 0.02 : 0.01;
        if (lv == 10) b.realDmg += 0.01;
        break;
      case GemFamily.sunstone:
        b.holyDmg += (lv >= 9) ? 0.02 : 0.01;
        if (lv == 10) b.realDmg += 0.01;
        break;
      case GemFamily.obsidian:
        b.realDmg += (lv >= 9) ? 0.02 : 0.01;
        if (lv == 10) b.armorPen += 0.01;
        break;
      case GemFamily.emerald:
        b.dodge += (lv >= 9) ? 0.02 : 0.01;
        if (lv == 10) b.block += 0.01;
        break;
      case GemFamily.sapphire:
        b.accuracy += (lv >= 9) ? 0.02 : 0.01;
        if (lv == 10) b.effectRes += 0.02;
        break;
      case GemFamily.ruby:
        b.critDmg += (lv >= 9) ? 0.06 : 0.03;
        if (lv == 10) b.critRate += 0.01;
        break;
      case GemFamily.topaz:
        b.critRate += (lv >= 9) ? 0.03 : 0.015;
        if (lv == 10) b.critDmg += 0.03;
        break;
      case GemFamily.quartz:
        b.speed += (lv >= 9) ? 4 : 2;
        if (lv == 10) b.accuracy += 0.01;
        break;
    }
  }
  return b;
}

/// ------------------ Resonance (Gems → set bonus) ------------------
StatBlock resonanceFromGems(List<GemItem?> slots, {List<String>? outLabels}) {
  int thirdBestLevel(GemFamily f) {
    final lvls = <int>[];
    for (final g in slots) {
      if (g != null && g.family == f) lvls.add(g.level);
    }
    lvls.sort((a, b) => b.compareTo(a)); // desc
    return lvls.length >= 3 ? lvls[2] : 0;
  }

  int pairLevel(GemFamily a, GemFamily b) =>
      math.min(thirdBestLevel(a), thirdBestLevel(b));
  int tier(int lv) => lv >= 10
      ? 3
      : lv >= 7
      ? 2
      : lv >= 5
      ? 1
      : 0;

  final s = StatBlock();

  // Brutality
  final tBrut = tier(pairLevel(GemFamily.ruby, GemFamily.amethyst));
  if (tBrut > 0) {
    outLabels?.add('Brutality T$tBrut');
    if (tBrut == 1) {
      s.critRate += .05;
      s.critDmg += .08;
    } else if (tBrut == 2) {
      s.critRate += .07;
      s.critDmg += .12;
    } else {
      s.critRate += .10;
      s.critDmg += .18;
      s.realDmg += .01;
    }
  }

  // Precision
  final tPrec = tier(pairLevel(GemFamily.sapphire, GemFamily.emerald));
  if (tPrec > 0) {
    outLabels?.add('Precision T$tPrec');
    if (tPrec == 1) {
      s.effectHit += .08;
      s.accuracy += .05;
      s.speed += 5;
    } else if (tPrec == 2) {
      s.effectHit += .10;
      s.accuracy += .08;
      s.speed += 10;
    } else {
      s.effectHit += .12;
      s.accuracy += .10;
      s.speed += 15;
    }
  }

  // Fortitude
  final tFort = tier(pairLevel(GemFamily.topaz, GemFamily.obsidian));
  if (tFort > 0) {
    outLabels?.add('Fortitude T$tFort');
    if (tFort == 1) {
      s.hpPct += .08;
      s.defPct += .05;
    } else if (tFort == 2) {
      s.hpPct += .12;
      s.defPct += .08;
    } else {
      s.hpPct += .15;
      s.defPct += .12;
    }
  }

  // Clarity
  final tClar = tier(pairLevel(GemFamily.obsidian, GemFamily.sunstone));
  if (tClar > 0) {
    outLabels?.add('Clarity T$tClar');
    if (tClar == 1) {
      s.energyRegen += .05;
      s.effectRes += .05;
      s.speed += 5;
    } else if (tClar == 2) {
      s.energyRegen += .08;
      s.effectRes += .08;
      s.speed += 10;
    } else {
      s.energyRegen += .12;
      s.effectRes += .12;
      s.speed += 15;
    }
  }

  return s;
}

/// Stigmata seçimini StatBlock’a çevir
StatBlock stigmaToStats(StigmaBonus? b) {
  final s = StatBlock();
  switch (b) {
    case StigmaBonus.critRate:
      s.critRate = 0.02;
      break;
    case StigmaBonus.critDmg:
      s.critDmg = 0.06;
      break;
    case StigmaBonus.accuracy:
      s.accuracy = 0.03;
      break;
    case StigmaBonus.dodge:
      s.dodge = 0.03;
      break;
    case StigmaBonus.breakArmor:
      s.armorPen = 0.03;
      break;
    case StigmaBonus.block:
      s.block = 0.03;
      break;
    case null:
      break;
  }
  return s;
}

/// =================== SAYFA ===================
class HeroFullPage extends StatefulWidget {
  const HeroFullPage({
    super.key,
    required this.hero,
    required this.portraitLevel,
  });

  final GameHero hero;
  final int portraitLevel;

  @override
  State<HeroFullPage> createState() => _HeroFullPageState();
}

class _HeroFullPageState extends State<HeroFullPage> {
  // ekipman takılı mı?
  bool hasWeapon = false, hasArmor = false, hasHelmet = false, hasRing = false;
  bool hasTalisman = false, hasExclusiveHero = false;

  // stigmata & gem slotları
  List<StigmaBonus?> stigmaSlots = List<StigmaBonus?>.filled(6, null);
  List<GemItem?> gemSlots = List<GemItem?>.filled(6, null);

  // UI: Stigmata ana stat ikon indeksleri
  List<int> _stigMains = List<int>.filled(6, -1);

  // aktif mythic set (stigmata)
  String? _stigSetName;
  int _stigSetPieces = 0;

  int _heroPowerForDisplay() {
    final t = _totals();

    // ESKİ: final s = t.pieces;
    final s = t.buffs; // <<<<<<

    double base = t.hp * 5.2 + t.atk * 14.0 + t.def * 8.0 + t.speed * 10.0;

    double mult = 1.0;
    mult *= 1 + s.critRate * 0.60 + s.critDmg * 0.30;
    mult *= 1 + s.accuracy * 0.20 + s.dodge * 0.20 + s.block * 0.25;
    mult *= 1 + s.armorPen * 0.35 + s.realDmg * 1.00 + s.holyDmg * 0.45;
    mult *= 1 + s.dmgImmunity * 0.45 + s.lifesteal * 0.30;
    mult *= 1 + s.effectHit * 0.15 + s.effectRes * 0.15;

    final gtMult = GuildTech.I.powerMultiplier;
    final th = ThroneState.I;
    final thMult = 1.0 + (0.6 * th.atkBonusPct + 0.4 * th.hpBonusPct) / 100.0;

    final total = base * mult * gtMult * thMult + th.powerContribution;
    return total.round();
  }

  // parça katkıları
  StatBlock sWeapon = StatBlock(),
      sArmor = StatBlock(),
      sHelmet = StatBlock(),
      sRing = StatBlock(),
      sTalisman = StatBlock(),
      sExclusiveHero = StatBlock();

  @override
  void initState() {
    super.initState();
    _reloadStigSet();
    _loadStigmataMiniIcons();
    _loadWeaponStatsFromDisk();
    _loadArmorStatsFromDisk();
    _loadHelmetStatsFromDisk();
    _loadRingStatsFromDisk();
    _loadGemSlotsFromDisk();
  }

  Future<void> _reloadStigSet() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _stigSetName = p.getString('stig_set_name_${widget.hero.name}');
      _stigSetPieces = p.getInt('stig_set_pieces_${widget.hero.name}') ?? 0;
    });
  }

  Future<void> _loadStigmataMiniIcons() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('stig2_uimains_${widget.hero.name}');
    final list = raw == null
        ? List<int>.filled(6, -1)
        : List<int>.generate(
            6,
            (i) => i < raw.length ? int.tryParse(raw[i]) ?? -1 : -1,
          );
    if (!mounted) return;
    setState(() => _stigMains = list);
  }

  void _quickEquip() {
    final h = widget.hero;
    final p = h.powerBase.toDouble();
    final baseHp = (p * 15).round();
    final baseAtk = (p * 7).round();
    final baseDef = (p * 5).round();

    final tier = {
      Rarity.sPlus: 1.00,
      Rarity.s: 0.85,
      Rarity.a: 0.70,
      Rarity.b: 0.55,
    }[h.rarity]!;

    sWeapon = StatBlock()
      ..atk = (baseAtk * (0.22 * tier)).round()
      ..critRate = 0.08 + 0.04 * tier
      ..critDmg = 0.30 + 0.10 * tier;

    sArmor = StatBlock()
      ..hp = (baseHp * (0.26 * tier)).round()
      ..def = (baseDef * (0.18 * tier)).round()
      ..block = 0.06;

    sHelmet = StatBlock()
      ..speed = (10 + 6 * tier).round()
      ..accuracy = 0.08
      ..effectRes = 0.06;

    sRing = StatBlock()
      ..atkPct = 0.12 + 0.06 * tier
      ..critDmg = 0.25 + 0.10 * tier
      ..armorPen = 0.06;

    sTalisman = StatBlock()
      ..hpPct = 0.06
      ..atkPct = 0.06
      ..defPct = 0.06;

    sExclusiveHero = StatBlock()
      ..lifesteal = 0.08
      ..dodge = 0.05;

    stigmaSlots = [
      StigmaBonus.critRate,
      StigmaBonus.critDmg,
      StigmaBonus.accuracy,
      StigmaBonus.dodge,
      StigmaBonus.breakArmor,
      StigmaBonus.block,
    ];
    setState(() {
      hasWeapon = hasArmor = hasHelmet = hasRing = true;
      hasTalisman = hasExclusiveHero = true;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Best gear equipped!')));
    PowerService.I.recomputeTop6FromRepo();
  }

  // Mythic sınıf set bonusları
  StatBlock _stigmaClassSetStats(String? name, int pieces) {
    final s = StatBlock();
    if (name == null || pieces < 4) return s;
    final has4 = pieces >= 4;
    final has6 = pieces >= 6;
    switch (name) {
      case 'Warborn Aegis':
        if (has4) {
          s.defPct += .15;
          s.block += .10;
        }
        if (has6) s.dmgImmunity += .10;
        break;
      case 'Windstalker Veil':
        if (has4) {
          s.critRate += .10;
          s.critDmg += .20;
        }
        break;
      case 'Night Predator':
        if (has4) {
          s.critDmg += .25;
          s.armorPen += .10;
        }
        if (has6) s.realDmg += .05;
        break;
      case 'Lifebinder Grace':
        if (has4) s.accuracy += .10;
        if (has6) s.dmgImmunity += .03;
        break;
      case 'Archmage Sigil':
        if (has4) {
          s.critDmg += .25;
          s.accuracy += .10;
        }
        break;
    }
    return s;
  }

  ({
    int hp,
    int atk,
    int def,
    int speed,
    Map<String, String> extras,
    StatBlock buffs,
  })
  _totals() {
    final h = widget.hero;
    final baseHp = h.powerBase * 15;
    final baseAtk = h.powerBase * 7;
    final baseDef = h.powerBase * 5;

    final base = (StatBlock()
      ..hp = baseHp
      ..atk = baseAtk
      ..def = baseDef
      ..speed = 100);

    // gem katkıları
    StatBlock sGems = StatBlock();
    for (final g in gemSlots) {
      if (g != null) sGems = sGems + gemToStats(g);
    }

    // stigmata katkıları
    StatBlock sStig = StatBlock();
    for (final b in stigmaSlots) {
      sStig = sStig + stigmaToStats(b);
    }

    // Resonance katkısı
    final sReso = resonanceFromGems(gemSlots);

    // Mythic set katkısı
    final sSet = _stigmaClassSetStats(_stigSetName, _stigSetPieces);

    StatBlock pieces =
        sWeapon + sArmor + sHelmet + sRing + sTalisman + sExclusiveHero;
    pieces = pieces + sGems + sStig + sReso + sSet;

    // Research + Throne + Guild çarpanları
    final rb = ResearchLab.I.computeBonuses();
    final throne = ThroneState.I;
    final gt = GuildTech.I;

    final allStatsPct = rb.allStatsPct;

    final hpMul =
        1 +
        (rb.hpPct + throne.hpBonusPct + gt.totalHpBonusPct + allStatsPct) /
            100.0;
    final atkMul =
        1 +
        (rb.atkPct + throne.atkBonusPct + gt.totalAtkBonusPct + allStatsPct) /
            100.0;
    final defMul = 1 + (rb.defPct + allStatsPct) / 100.0;
    final spdMul = 1 + (rb.speedPct + allStatsPct) / 100.0;

    final hp0 = ((base.hp + pieces.hp) * (1 + pieces.hpPct)).toDouble();
    final atk0 = ((base.atk + pieces.atk) * (1 + pieces.atkPct)).toDouble();
    final def0 = ((base.def + pieces.def) * (1 + pieces.defPct)).toDouble();
    final spd0 = (base.speed + pieces.speed).toDouble();

    final hp = (hp0 * hpMul).round();
    final atk = (atk0 * atkMul).round();
    final def = (def0 * defMul).round();
    final speed = (spd0 * spdMul).round();

    // ---- TOPLAM yüzdeler (research + throne + guild + parçalar) ----
    final totalCritRate = (rb.critPct / 100.0) + pieces.critRate;
    final totalAccuracy = (rb.accuracyPct / 100.0) + pieces.accuracy;
    final totalDodge = (rb.evasionPct / 100.0) + pieces.dodge;
    final totalTrueDmg = (rb.trueDmgPct / 100.0) + pieces.realDmg;
    final totalEnRegen = (rb.energyRegenPct / 100.0) + pieces.energyRegen;

    final totalHpPct = (rb.hpPct + allStatsPct) / 100.0 + pieces.hpPct;
    final totalAtkPct = (rb.atkPct + allStatsPct) / 100.0 + pieces.atkPct;
    final totalDefPct = (rb.defPct + allStatsPct) / 100.0 + pieces.defPct;
    final totalSpdPct =
        (rb.speedPct + allStatsPct) / 100.0; // flat speed parçalardan geliyor

    final extras = <String, String>{
      // Offense
      'Crit Rate': _pct(totalCritRate.clamp(0, 1)),
      'Crit DMG': _pct(pieces.critDmg),
      'Accuracy': _pct(totalAccuracy),
      'Armor PEN': _pct(pieces.armorPen),
      'Holy DMG': _pct(pieces.holyDmg),
      'Real DMG': _pct(totalTrueDmg),
      // Defense / Utility
      'Dodge': _pct(totalDodge),
      'Block': _pct(pieces.block),
      'Effect Hit': _pct(pieces.effectHit),
      'Effect Res': _pct(pieces.effectRes),
      'DMG Immunity': _pct(pieces.dmgImmunity),
      'Lifesteal': _pct(pieces.lifesteal),
      'Energy Regen': _pct(totalEnRegen),
      // % Bonuses
      'HP%': _pct(totalHpPct),
      'ATK%': _pct(totalAtkPct),
      'DEF%': _pct(totalDefPct),
      'Speed%': _pct(totalSpdPct),
    };

    return (
      hp: hp,
      atk: atk,
      def: def,
      speed: speed,
      extras: extras,
      buffs: pieces,
    );
  }

  // ==== Equip sayfaları aç/kapa ====
  GameHero get hero => widget.hero;

  Future<void> _openGems() async {
    final res = await Navigator.of(context).push<List<GemItem?>>(
      MaterialPageRoute(builder: (_) => GemsPage(heroName: widget.hero.name)),
    );
    if (!mounted) return;
    if (res != null) {
      setState(() => gemSlots = res);
    } else {
      await _loadGemSlotsFromDisk();
      await PowerService.I.recomputeTop6FromRepo();
    }
  }

  Future<void> _openStigmata() async {
    final res = await Navigator.of(context).push<List<StigmaBonus?>>(
      MaterialPageRoute(builder: (_) => StigmataPage(heroName: hero.name)),
    );
    if (!mounted) return;
    if (res != null) setState(() => stigmaSlots = res);
    await _reloadStigSet();
    await _loadStigmataMiniIcons();
    await PowerService.I.recomputeTop6FromRepo();
  }

  Future<void> _openWeaponPage() async {
    final equippedNow = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WeaponPage(heroName: widget.hero.name)),
    );
    if (!mounted) return;
    setState(() => hasWeapon = equippedNow ?? hasWeapon);
    await _loadWeaponStatsFromDisk();
    await PowerService.I.recomputeTop6FromRepo();
  }

  Future<void> _openArmorPage() async {
    final equippedNow = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ArmorPage(heroName: widget.hero.name)),
    );
    if (!mounted) return;
    setState(() => hasArmor = equippedNow ?? hasArmor);
    await _loadArmorStatsFromDisk();
    await PowerService.I.recomputeTop6FromRepo();
  }

  Future<void> _openHelmetPage() async {
    final equippedNow = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => HelmetPage(heroName: widget.hero.name)),
    );
    if (!mounted) return;
    setState(() => hasHelmet = equippedNow ?? hasHelmet);
    await _loadHelmetStatsFromDisk();
    await PowerService.I.recomputeTop6FromRepo();
  }

  Future<void> _openRingPage() async {
    final equippedNow = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RingPage(heroName: widget.hero.name)),
    );
    if (!mounted) return;
    setState(() => hasRing = equippedNow ?? hasRing);
    await _loadRingStatsFromDisk();
    await PowerService.I.recomputeTop6FromRepo();
  }

  /// ---- Diskten takılı parçaların statlarını oku ----

  Future<void> _loadGemSlotsFromDisk() async {
    final p = await SharedPreferences.getInstance();
    final out = List<GemItem?>.filled(6, null);
    for (int i = 0; i < 6; i++) {
      final raw = p.getString('gem_eq3_${hero.name}_$i');
      if (raw != null) {
        final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
        out[i] = GemItem.fromJson(map);
      }
    }
    if (!mounted) return;
    setState(() => gemSlots = out);
  }

  Future<void> _loadWeaponStatsFromDisk() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('eq_weapon_${widget.hero.name}');
    if (raw == null) {
      if (!mounted) return;
      setState(() {
        hasWeapon = false;
        sWeapon = StatBlock();
      });
      return;
    }
    final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final rarity = (j['rarity'] as String?)?.toLowerCase() ?? 'elite';
    final level = (j['level'] as int?) ?? 1;
    final setKind = (j['set'] as String?)?.toLowerCase();

    final baseAtk = widget.hero.powerBase * 7;

    final t = switch (rarity) {
      'elite' => .45,
      'epic' => .65,
      'legendary' => .85,
      _ => 1.00,
    };

    final atkAdd = (baseAtk * (0.08 + 0.02 * level) * t).round();
    final critRate = (0.02 * t) + (0.002 * level);
    final critDmg = (0.18 * t) + (0.02 * level);

    final s = StatBlock()
      ..atk = atkAdd
      ..critRate = critRate
      ..critDmg = critDmg;

    if (setKind == 'void') s.realDmg += 0.02;
    if (setKind == 'light') {
      s.holyDmg += 0.05;
      s.energyRegen += 0.05;
    }

    if (!mounted) return;
    setState(() {
      hasWeapon = true;
      sWeapon = s;
    });
  }

  Future<void> _loadArmorStatsFromDisk() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('eq_armor_${widget.hero.name}');
    if (raw == null) {
      if (!mounted) return;
      setState(() {
        hasArmor = false;
        sArmor = StatBlock();
      });
      return;
    }
    final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final rarity = (j['rarity'] as String?)?.toLowerCase() ?? 'elite';
    final level = (j['level'] as int?) ?? 1;
    final setKind = (j['set'] as String?)?.toLowerCase();

    final baseHp = widget.hero.powerBase * 15;
    final baseDef = widget.hero.powerBase * 5;

    final t = switch (rarity) {
      'elite' => .45,
      'epic' => .65,
      'legendary' => .85,
      _ => 1.00,
    };

    final hpAdd = (baseHp * (0.06 + 0.02 * level) * t).round();
    final defAdd = (baseDef * (0.06 + 0.02 * level) * t).round();

    final s = StatBlock()
      ..hp = hpAdd
      ..def = defAdd
      ..block = 0.02 * (1 + level / 10) * t;

    if (setKind == 'void') s.dmgImmunity += 0.02;
    if (setKind == 'light') s.holyDmg += 0.03;

    if (!mounted) return;
    setState(() {
      hasArmor = true;
      sArmor = s;
    });
  }

  Future<void> _loadHelmetStatsFromDisk() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('eq_helmet_${widget.hero.name}');
    if (raw == null) {
      if (!mounted) return;
      setState(() {
        hasHelmet = false;
        sHelmet = StatBlock();
      });
      return;
    }
    final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final rarity = (j['rarity'] as String?)?.toLowerCase() ?? 'elite';
    final level = (j['level'] as int?) ?? 1;
    final setKind = (j['set'] as String?)?.toLowerCase();

    final t = switch (rarity) {
      'elite' => .45,
      'epic' => .65,
      'legendary' => .85,
      _ => 1.00,
    };

    final s = StatBlock()
      ..speed = (4 + level) * t.round()
      ..accuracy = (0.01 * t) + (0.002 * level)
      ..effectRes = (0.01 * t) + (0.002 * level);

    if (setKind == 'void') s.realDmg += 0.01;
    if (setKind == 'light') s.holyDmg += 0.02;

    if (!mounted) return;
    setState(() {
      hasHelmet = true;
      sHelmet = s;
    });
  }

  Future<void> _loadRingStatsFromDisk() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('eq_ring_${widget.hero.name}');
    if (raw == null) {
      if (!mounted) return;
      setState(() {
        hasRing = false;
        sRing = StatBlock();
      });
      return;
    }
    final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final rarity = (j['rarity'] as String?)?.toLowerCase() ?? 'elite';
    final level = (j['level'] as int?) ?? 1;
    final setKind = (j['set'] as String?)?.toLowerCase();

    final t = switch (rarity) {
      'elite' => .45,
      'epic' => .65,
      'legendary' => .85,
      _ => 1.00,
    };

    final s = StatBlock()
      ..atkPct = (0.04 * t) + (0.01 * level)
      ..critRate = (0.01 * t) + (0.001 * level)
      ..critDmg = (0.12 * t) + (0.02 * level);

    if (setKind == 'void') s.realDmg += 0.02;
    if (setKind == 'light') s.holyDmg += 0.03;

    if (!mounted) return;
    setState(() {
      hasRing = true;
      sRing = s;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hero = widget.hero;
    final cs = Theme.of(context).colorScheme;

    final grad = switch (hero.faction) {
      Faction.elemental => [Colors.blue, Colors.purple],
      Faction.dark => [const Color(0xFF2C2C54), const Color(0xFF6D214F)],
      Faction.nature => [Colors.green, Colors.teal],
      Faction.mech => [Colors.grey, const Color(0xFF00BCD4)],
      Faction.voidF => [const Color(0xFF1B1B2F), const Color(0xFF4E31AA)],
      Faction.light => [const Color(0xFFFFD54F), const Color(0xFFFFF59D)],
    };

    final totals = _totals();
    final rb = ResearchLab.I.computeBonuses();
    final sb = totals.buffs;

    final snap = StatSnapshot(
      hp: totals.hp.toDouble(),
      atk: totals.atk.toDouble(),
      def: totals.def.toDouble(),
      spd: totals.speed.toDouble(),
      // yüzde tabanlılar:
      critRatePct: (rb.critPct + sb.critRate * 100).clamp(0, 100),
      critDmgPct: sb.critDmg * 100,
      accuracyPct: rb.accuracyPct + sb.accuracy * 100,
      dodgePct: rb.evasionPct + sb.dodge * 100,
      blockPct: sb.block * 100,
      dmgImmunityPct: sb.dmgImmunity * 100,
      holyDmgPct: sb.holyDmg * 100,
      trueDmgPct: (rb.trueDmgPct + sb.realDmg * 100),
      energyRegenPct: rb.energyRegenPct + sb.energyRegen * 100,
    );

    final heroPow = powerFromStats(snap).total;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(hero.name),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 12),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hero.rarity.badge(cs).withValues(alpha: .25),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: hero.rarity.badge(cs)),
            ),
            child: Text(
              hero.rarity.label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // === Kanvas ===
          Container(
            height: MediaQuery.of(context).size.height * 0.72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: grad,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .2),
                  blurRadius: 16,
                ),
              ],
            ),
            child: _HeroCanvas(
              hero: hero,
              portraitLevel: widget.portraitLevel,
              powerValue: heroPow,
              onOpenAbilities: () => _openAbilities(hero),
              onOpenWeapon: _openWeaponPage,
              onOpenArmor: _openArmorPage,
              onOpenHelmet: _openHelmetPage,
              onOpenRing: _openRingPage,
              onOpenStigmata: _openStigmata,
              eqWeapon: hasWeapon,
              eqArmor: hasArmor,
              eqHelmet: hasHelmet,
              eqRing: hasRing,
              stigMains: _stigMains,
              power: heroPow,
            ),
          ),
          SizedBox(height: 12),

          // === Toplam HP/ATK/DEF ===
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statPill(context, Icons.favorite, totals.hp),
              _statPill(context, Icons.flash_on, totals.atk),
              _statPill(context, Icons.shield, totals.def),
            ],
          ),
          SizedBox(height: 14),

          // === Alt aksiyonlar ===
          Row(
            children: [
              Expanded(
                child: _mainAction(
                  context,
                  icon: Icons.diamond_rounded,
                  label: 'Gems',
                  onTap: _openGems,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _mainAction(
                  context,
                  icon: Icons.insights,
                  label: 'Stats',
                  onTap: () => _openStats(context, (
                    hp: totals.hp,
                    atk: totals.atk,
                    def: totals.def,
                    speed: totals.speed,
                    extras: totals.extras,
                  )),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _mainAction(
                  context,
                  icon: Icons.bolt,
                  label: 'Quick Equip',
                  onTap: _quickEquip,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(BuildContext context, IconData icon, int value) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17),
          SizedBox(width: 8),
          Tooltip(message: '$value', child: Text(_fmt(value))),
        ],
      ),
    );
  }

  Widget _mainAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }

  IconData _resoIcon(String label) {
    if (label.startsWith('Brutality')) return Icons.local_fire_department;
    if (label.startsWith('Precision')) return Icons.center_focus_strong;
    if (label.startsWith('Fortitude')) return Icons.shield;
    if (label.startsWith('Clarity')) return Icons.bolt;
    return Icons.star;
  }

  void _openStats(
    BuildContext context,
    ({int hp, int atk, int def, int speed, Map<String, String> extras}) t,
  ) {
    final cs = Theme.of(context).colorScheme;

    // Aktif rezonans etiketleri
    final resoLabels = <String>[];
    resonanceFromGems(gemSlots, outLabels: resoLabels);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: EdgeInsets.all(16),
          children: [
            Text('Hero Stats', style: Theme.of(ctx).textTheme.titleLarge),
            SizedBox(height: 12),

            // Ana sayılar
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _chip(
                  Icons.trending_up,
                  'Hero Power',
                  _fmt(_heroPowerForDisplay()),
                ), // +++ PATCH
                _chip(Icons.favorite, 'HP', _fmt(t.hp)),
                _chip(Icons.flash_on, 'ATK', _fmt(t.atk)),
                _chip(Icons.shield, 'DEF', _fmt(t.def)),
                _chip(Icons.speed, 'Speed', '${t.speed}'),
                ...t.extras.entries.map(
                  (e) => _chip(Icons.data_usage, e.key, e.value),
                ),
              ],
            ),

            // Aktif Rezonanslar
            if (resoLabels.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Active Resonance',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: resoLabels
                    .map(
                      (lbl) => Chip(
                        avatar: Icon(_resoIcon(lbl), size: 16),
                        label: Text(lbl),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData i, String k, String v) => Chip(
    avatar: Icon(i, size: 16),
    label: Text('$k: $v'),
    visualDensity: VisualDensity.compact,
  );

  void _openAbilities(GameHero hero) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: EdgeInsets.all(16),
          children: [
            Text('Abilities', style: Theme.of(ctx).textTheme.titleLarge),
            SizedBox(height: 12),
            ...hero.abilities.map(
              (a) => ListTile(
                leading: Icon(
                  a.active ? Icons.flash_on : Icons.auto_awesome,
                  color: cs.primary,
                ),
                title: Text(a.name),
                subtitle: Text(a.desc),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =================== Kanvas ===================
class _HeroCanvas extends StatelessWidget {
  const _HeroCanvas({
    required this.hero,
    required this.portraitLevel,
    required this.onOpenAbilities,
    required this.onOpenWeapon,
    required this.onOpenArmor,
    required this.onOpenHelmet,
    required this.onOpenRing,
    required this.onOpenStigmata,
    required this.eqWeapon,
    required this.eqArmor,
    required this.eqHelmet,
    required this.eqRing,
    required this.stigMains,
    required this.power,
    required this.powerValue,
  });

  final GameHero hero;
  final int portraitLevel;
  final int powerValue;

  final VoidCallback onOpenAbilities;
  final VoidCallback onOpenWeapon, onOpenArmor, onOpenHelmet, onOpenRing;
  final VoidCallback onOpenStigmata;

  // ekipman takılı mı?
  final bool eqWeapon, eqArmor, eqHelmet, eqRing;

  // 6 kutucukta çizilecek ana stat ikon indeksleri (-1 = boş)
  final List<int> stigMains;
  final int power;

  // ana stat index -> ikon
  IconData _iconForStigmaMain(int idx) {
    switch (idx) {
      case 0:
        return Icons.center_focus_strong; // CRate
      case 1:
        return Icons.local_fire_department; // CDmg
      case 2:
        return Icons.gps_fixed; // Accuracy
      case 3:
        return Icons.swipe; // Dodge
      case 4:
        return Icons.rocket; // Break
      case 5:
        return Icons.security; // Block
      default:
        return Icons.auto_fix_high; // boş
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Portre
        Positioned.fill(
          left: 36,
          right: 36,
          top: 100,
          bottom: 150,
          child: LayoutBuilder(
            builder: (_, c) {
              final maxSide = math.min(c.maxWidth, c.maxHeight);
              final size = maxSide * 0.78;
              return Center(
                child: Icon(
                  Icons.account_circle_rounded,
                  size: size,
                  color: Colors.white.withValues(alpha: .65),
                ),
              );
            },
          ),
        ),
        // Sol üst: faction + role
        Positioned(
          left: 18,
          top: 18,
          child: Row(
            children: [
              _roundIcon(context, hero.faction.icon),
              SizedBox(width: 10),
              _roundIcon(context, hero.role.icon),
            ],
          ),
        ),
        // Sağ üst: skins + abilities
        Positioned(
          right: 18,
          top: 18,
          child: Row(
            children: [
              _roundIcon(context, Icons.style, onTap: () {}),
              SizedBox(width: 10),
              _roundIcon(context, Icons.menu_book, onTap: onOpenAbilities),
            ],
          ),
        ),
        // Üst merkez: portrait seviyesi + power
        Positioned.fill(
          top: 20,
          child: Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _topBadge(
                  context,
                  portraitLevel >= 10
                      ? 'Immortal'
                      : 'Portrait $portraitLevel/10',
                ),
                SizedBox(height: 10),
                _powerPill(context, power),
              ],
            ),
          ),
        ),
        // Sol gövde: weapon + armor
        Positioned(
          left: 22,
          top: 170,
          child: Column(
            children: [
              _equipSquare(
                context,
                Icons.gavel,
                active: eqWeapon,
                onTap: onOpenWeapon,
              ),
              SizedBox(height: 16),
              _equipSquare(
                context,
                Icons.shield,
                active: eqArmor,
                onTap: onOpenArmor,
              ),
            ],
          ),
        ),
        // Sağ gövde: helmet + ring
        Positioned(
          right: 22,
          top: 170,
          child: Column(
            children: [
              _equipSquare(
                context,
                Icons.military_tech,
                active: eqHelmet,
                onTap: onOpenHelmet,
              ),
              SizedBox(height: 16),
              _equipSquare(
                context,
                Icons.ring_volume,
                active: eqRing,
                onTap: onOpenRing,
              ),
            ],
          ),
        ),
        // Stigmata şeridi
        Positioned(
          left: 22,
          right: 22,
          bottom: 22,
          child: LayoutBuilder(
            builder: (context, c) {
              const gap = 12.0;
              final w = c.maxWidth;
              final side = ((w - gap * 5) / 6).clamp(38.0, 48.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (i) => _stigmaBox(
                    context,
                    size: side,
                    onTap: onOpenStigmata,
                    mainIdx: (i < stigMains.length) ? stigMains[i] : -1,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _roundIcon(
    BuildContext context,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    final child = CircleAvatar(
      radius: 19,
      backgroundColor: Colors.black.withValues(alpha: .18),
      child: Icon(
        icon,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        size: 19,
      ),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(19),
      onTap: onTap,
      child: child,
    );
  }

  Widget _equipSquare(
    BuildContext context,
    IconData icon, {
    bool active = false,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final box = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(16),
        border: active ? Border.all(color: cs.primary, width: 2) : null,
        boxShadow: active
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: .35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 22,
            ),
          ),
          if (active)
            Positioned(
              right: 6,
              top: 6,
              child: Icon(Icons.circle, size: 8, color: cs.primary),
            ),
        ],
      ),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: box,
    );
  }

  Widget _stigmaBox(
    BuildContext context, {
    required double size,
    int mainIdx = -1,
    VoidCallback? onTap,
  }) {
    final has = mainIdx >= 0;
    final icon = _iconForStigmaMain(mainIdx);
    final cs = Theme.of(context).colorScheme;

    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(14),
        border: has
            ? Border.all(color: cs.primary.withValues(alpha: .6))
            : null,
      ),
      child: Icon(
        icon,
        color: has ? cs.primary : cs.onPrimaryContainer,
        size: size * .52,
      ),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: box,
    );
  }

  Widget _topBadge(BuildContext context, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _powerPill(BuildContext context, int powerValue) {
    return Tooltip(
      message: 'Power: ${_fmt(powerValue)}',
      child: Container(
        constraints: BoxConstraints(minHeight: 28, minWidth: 64),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .22),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.trending_up, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              _fmt(powerValue),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
