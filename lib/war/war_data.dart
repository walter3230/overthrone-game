// lib/war/war_data.dart
import 'dart:math';
import 'dart:convert'; // ⬅️ eklendi
import 'package:shared_preferences/shared_preferences.dart'; // ⬅️ eklendi
import 'package:flutter/material.dart';
import 'package:overthrone/throne/throne_state.dart' show ThroneState;
// Guild Tech (dikkat: klasör adı küçük)
import '../guild/guild_tech.dart';

// Heroes modülünden içe aktarım (GameHero + global allHeroes listesi)
import 'package:overthrone/features/heroes/heroes_page.dart'
    show GameHero, allHeroes;
import 'package:overthrone/features/heroes/hero_types.dart' show Role;

// -------------------- ARENA / LADDER --------------------
class Player {
  int id;
  String name;
  int rank; // 1 = en iyi
  int power;
  Player({
    required this.id,
    required this.name,
    required this.rank,
    required this.power,
  });
}

// -------------------- KAHRAMAN / SAVAŞ KATMANI -----------------------------
class BattleUnit {
  final GameHero hero;

  // Basit statlar
  double atk;
  double def;
  double hp;
  double speed;
  double critRate; // 0..1
  double critDmg; // 1.5 = +50%
  double dmgTakenMul; // gelen hasar çarpanı (0.9 = %10 azaltma)

  BattleUnit._(
    this.hero, {
    required this.atk,
    required this.def,
    required this.hp,
    required this.speed,
    required this.critRate,
    required this.critDmg,
    required this.dmgTakenMul,
  });

  /// GameHero.powerBase ve role’a göre kaba bir dağılım.
  factory BattleUnit.fromGameHero(GameHero h) {
    final roleAtk = switch (h.role) {
      Role.warrior => 0.55,
      Role.ranger => 0.60,
      Role.raider => 0.65,
      Role.mage => 0.62,
      Role.healer => 0.40,
    };
    final roleDef = switch (h.role) {
      Role.warrior => 0.35,
      Role.ranger => 0.28,
      Role.raider => 0.25,
      Role.mage => 0.22,
      Role.healer => 0.32,
    };

    final base = h.powerBase.toDouble();
    final atk = base * roleAtk;
    final def = base * roleDef;
    final hp = base * 5.0; // kaba HP ölçeği
    const baseSpeed = 100.0;

    final unit = BattleUnit._(
      h,
      atk: atk,
      def: def,
      hp: hp,
      speed: baseSpeed,
      critRate: 0.05,
      critDmg: 1.50,
      dmgTakenMul: 1.00,
    );

    // Pasifleri başlangıçta uygula
    unit._applyPassives();
    return unit;
  }

  /// Pasiflerden anahtar kelime yakalayıp stat uygula (çok basit parser).
  void _applyPassives() {
    for (final ab in hero.abilities) {
      if (ab.active) continue; // sadece pasifleri uygula
      final text = '${ab.name} ${ab.desc}'.toLowerCase();

      // Speed
      _applyPercent(text, ['speed', 'haste'], (v) => speed *= (1 + v));

      // ATK
      _applyPercent(text, [
        'attack',
        'atk',
        '+% attack',
      ], (v) => atk *= (1 + v));

      // DEF
      _applyPercent(text, ['defense', 'def'], (v) => def *= (1 + v));

      // Gelen hasar azaltımı
      _applyMinusPercent(text, [
        'damage taken',
        'dmg taken',
        'reduction',
      ], (v) => dmgTakenMul *= (1 - v));

      // Dodge
      _applyPercent(text, ['dodge'], (v) => dmgTakenMul *= (1 - v * 0.5));

      // Crit chance
      _applyPercent(text, ['crit chance', 'crit'], (v) {
        critRate += v;
        if (critRate > 0.8) critRate = 0.8;
      });

      // Crit damage
      _applyPercent(text, ['crit damage', 'crit dmg'], (v) {
        critDmg += v; // +%100 -> +1.0
      });

      // Resist
      _applyPercent(text, ['resist', 'effect res'], (v) {
        dmgTakenMul *= (1 - v * 0.5);
      });

      // Shield → efektif HP
      if (text.contains('shield') || text.contains('ward')) {
        hp *= 1.05;
      }

      // Set cümleleri
      if (text.contains('holy dmg')) {
        atk *= 1.02;
      }
      if (text.contains('true dmg') || text.contains('immunity')) {
        dmgTakenMul *= 0.98;
      }
    }

    // Güvenli sınırlar
    if (dmgTakenMul < 0.6) dmgTakenMul = 0.6; // %40’tan fazla azaltma yok
    if (critDmg < 1.2) critDmg = 1.2;
  }

  /// “+10% speed” vb değerleri uygula
  void _applyPercent(
    String text,
    List<String> keys,
    void Function(double asFraction) apply,
  ) {
    final regex = RegExp(r'(\+)?\s*(\d+(\.\d+)?)\s*%');
    for (final k in keys) {
      if (!text.contains(k)) continue;
      for (final m in regex.allMatches(text)) {
        final v = double.tryParse(m.group(2) ?? '');
        if (v != null) apply(v / 100.0);
      }
    }
  }

  /// “takes 12% less damage” gibi azalma kalıpları.
  void _applyMinusPercent(
    String text,
    List<String> keys,
    void Function(double asFraction) apply,
  ) {
    final regex = RegExp(r'(\d+(\.\d+)?)\s*%');
    for (final k in keys) {
      if (!text.contains(k)) continue;
      for (final m in regex.allMatches(text)) {
        final v = double.tryParse(m.group(1) ?? '');
        if (v != null) apply(v / 100.0);
      }
    }
  }

  /// Basit etkin güç metriği
  double get effectivePower {
    final dpsMul = (1 + critRate * (critDmg - 1));
    final offense = atk * dpsMul;
    final defense = def / dmgTakenMul;
    final ehp = hp / dmgTakenMul;
    return offense * 0.6 + defense * 0.25 + ehp * 0.15 + speed * 2.0;
  }
}

// -------------------- REPO: Arena + Heroes + Defense ------------------------
class ArenaRepo {
  ArenaRepo._();
  static final ArenaRepo I = ArenaRepo._().._seed();

  static const _kDefense = 'arena_defense_v1'; // ⬅️ persist anahtarı

  final Random _rng = Random(42);

  final List<Player> _players = [];
  int tickets = 5;
  int myId = 50;

  // Heroes & Defense
  final List<GameHero> heroes = <GameHero>[];
  List<int> defense = [];
  final ValueNotifier<List<int>> defenseNotifier = ValueNotifier<List<int>>([]);

  // -------------------- Seed / Demo veri --------------------
  void _seed() {
    _seedPlayers();
    _seedHeroesFromDB();
  }

  void _seedPlayers() {
    _players.clear();
    for (int i = 0; i < 100; i++) {
      _players.add(
        Player(
          id: i,
          name: i == myId ? 'You' : 'Commander #${i + 1}',
          rank: i + 1,
          power: 900 + i * 15 + _rng.nextInt(40),
        ),
      );
    }
  }

  void _seedHeroesFromDB() {
    heroes
      ..clear()
      ..addAll(allHeroes);

    // Varsayılan: savunma boşsa ilk 6 (persist yüklendiyse dokunma)
    if (defense.isEmpty) {
      defense = heroes.take(6).map((h) => h.id).toList(growable: false);
    }
    defenseNotifier.value = List<int>.from(defense);
  }

  // -------------------- Persist --------------------
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kDefense);
    if (s == null || s.isEmpty) {
      // hiçbir kayıt yoksa mevcut (seed) kalsın
      defenseNotifier.value = List<int>.from(defense);
      return;
    }

    try {
      final raw = (jsonDecode(s) as List);
      final ids = <int>[];
      for (final e in raw) {
        final v = (e is int) ? e : int.tryParse(e.toString());
        if (v != null && heroes.any((h) => h.id == v)) ids.add(v);
        if (ids.length == 6) break;
      }
      if (ids.isNotEmpty) {
        defense = List<int>.from(ids);
        defenseNotifier.value = List<int>.from(defense);
      }
    } catch (_) {
      // bozuk veri varsa görmezden gel
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDefense, jsonEncode(defense));
  }

  // -------------------- Ladder yardımcıları --------------------
  List<Player> get ladder {
    _players.sort((a, b) => a.rank.compareTo(b.rank));
    return List.unmodifiable(_players);
  }

  Player get me => _players.firstWhere((p) => p.id == myId);
  int get myRank => me.rank;
  bool get canAttack => tickets > 0;

  /// 5 üst, 3 alt rakip
  List<Player> pickOpponents() {
    final list = ladder;
    final idx = list.indexWhere((p) => p.id == myId);
    final out = <Player>[];

    for (var i = 1; i <= 5; i++) {
      final j = (idx - i).clamp(0, list.length - 1);
      if (j != idx) out.add(list[j]);
    }
    for (var i = 1; i <= 3; i++) {
      final j = (idx + i).clamp(0, list.length - 1);
      if (j != idx) out.add(list[j]);
    }

    final seen = <int>{};
    return out.where((p) => seen.add(p.id)).toList();
  }

  /// Basit dövüş: 6’şar kahraman → etkin güç toplanır,
  /// Guild Tech etkisi **bizim güç** üzerine çarpılır,
  /// Ability metinlerinden küçük bir **bias** eklenir.
  BattleResult fight(Player opponent) {
    if (!canAttack) return BattleResult(false, 0);
    tickets--;

    // 1) Takımları kur
    final myUnits = _buildDefenseUnits();
    final enemyUnits = _buildRandomEnemy(opponent.power);

    // 2) Güç hesapları
    double myPow = myUnits.fold<double>(0, (s, u) => s + u.effectivePower);
    final enPow = enemyUnits.fold<double>(0, (s, u) => s + u.effectivePower);

    // 3) Guild Tech → bizim güce çarp
    myPow *= GuildTech.I.powerMultiplier;

    // 4) Taban şans (logit benzeri): my / (my + en)
    double chance = myPow / (myPow + enPow).clamp(1.0, double.infinity);

    // 5) Ability bias (küçük kaydırma)
    final myScore = _teamAbilityScore(myUnits.map((e) => e.hero).toList());
    final enScore = _teamAbilityScore(enemyUnits.map((e) => e.hero).toList());
    final diff = myScore - enScore;
    // Aralığı ~[-0.02, +0.02] olacak şekilde yumuşat
    final bias = 0.02 * _tanh(diff / 4.0);
    chance = (chance + bias).clamp(0.05, 0.95);

    // 6) Zar at
    final win = _rng.nextDouble() < chance;
    var climbed = 0;

    if (win && opponent.rank < me.rank) {
      final old = me.rank;
      me.rank = opponent.rank;
      opponent.rank = old;
      climbed = old - me.rank;
    }
    return BattleResult(win, climbed);
  }

  // -------------------- Heroes / Defense yardımcıları ------------------------
  GameHero _heroById(int id) => heroes.firstWhere((h) => h.id == id);

  /// Toggle + kaydet (maks 6)
  void toggle(int heroId) {
    final cur = List<int>.from(defense);
    if (cur.contains(heroId)) {
      cur.remove(heroId);
    } else {
      if (cur.length >= 6) return;
      if (!heroes.any((h) => h.id == heroId)) return;
      cur.add(heroId);
    }
    defense = cur;
    defenseNotifier.value = List<int>.unmodifiable(defense);
    _save();
  }

  void setDefense(List<int> ids) {
    final uniq = <int>{};
    final valid = <int>[];
    for (final id in ids) {
      final exists = heroes.any((h) => h.id == id);
      if (exists && uniq.add(id)) {
        valid.add(id);
        if (valid.length == 6) break;
      }
    }
    if (valid.isEmpty) return;
    defense = valid;
    defenseNotifier.value = List<int>.unmodifiable(defense);
    _save(); // ⬅️ kaydet
  }

  void clearDefense() {
    defense = <int>[];
    defenseNotifier.value = const <int>[];
    _save();
  }

  bool contains(int id) => defense.contains(id);
  int get count => defense.length;
  bool get isFull => count >= 6;

  List<GameHero> get defenseHeroes => defense.map(_heroById).toList();

  List<BattleUnit> _buildDefenseUnits() =>
      defenseHeroes.map(BattleUnit.fromGameHero).toList();

  List<BattleUnit> _buildRandomEnemy(int approxPower) {
    final pool = List<GameHero>.from(heroes)..shuffle(_rng);
    final pick = pool.take(6).map(BattleUnit.fromGameHero).toList();

    // Rakip toplam gücünü opponent.power civarına normalize et
    final total = pick.fold<double>(0, (s, u) => s + u.effectivePower);
    if (total > 0) {
      final target = approxPower.toDouble() * 12; // 6 ünite ~ power*12
      final scale = target / total;
      for (final u in pick) {
        u
          ..atk *= scale
          ..def *= scale
          ..hp *= scale;
      }
    }
    return pick;
    // Not: speed/crit oranlarını değiştirmiyoruz; sadece ham güç ölçeği.
  }

  // ---- Ability skorlayıcı (küçük bias için) ----
  double _teamAbilityScore(List<GameHero> team) {
    double score = 0;
    for (final h in team) {
      for (final ab in h.abilities) {
        final t = ('${ab.name} ${ab.desc}').toLowerCase();

        // Şifa/temizleme/koruma (sürdürülebilirlik)
        if (_hasAny(t, ['heal', 'regeneration', 'regen'])) score += 2.0;
        if (_hasAny(t, ['cleanse', 'purify', 'dispel'])) score += 1.2;
        if (_hasAny(t, ['shield', 'ward', 'barrier'])) score += 1.5;

        // Kontrol / hız / enerji (tempo)
        if (_hasAny(t, ['stun', 'freeze', 'silence', 'taunt'])) score += 1.6;
        if (_hasAny(t, ['speed', 'haste'])) score += 1.2;
        if (_hasAny(t, ['energy', 'mana'])) score += 1.0;

        // Savunma kırma → burst potansiyeli
        if (_hasAny(t, [
          'defense break',
          'def break',
          'armor break',
          'vulnerab',
          'expose',
          'def down',
        ])) {
          score += 1.6;
        }

        // Zamanla hasar
        if (_hasAny(t, ['bleed', 'poison', 'burn'])) score += 1.0;

        // Canlandırma, görünmezlik, summon (küçük etkiler)
        if (_hasAny(t, ['revive', 'resurrect'])) score += 2.5;
        if (_hasAny(t, ['stealth', 'invis'])) score += 0.8;
        if (_hasAny(t, ['summon', 'minion'])) score += 0.8;
      }
    }
    return score;
  }

  bool _hasAny(String text, List<String> keys) {
    for (final k in keys) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  double _tanh(double x) {
    // hızlı ve stabil tanh
    final e1 = exp(x);
    final e2 = exp(-x);
    return (e1 - e2) / (e1 + e2);
  }
}

// -------------------- BattleResult --------------------
class BattleResult {
  final bool win;
  final int climbed; // kaç sıra yükseldi
  BattleResult(this.win, this.climbed);
}

double globalAtkPct() =>
    GuildTech.I.totalAtkBonusPct + ThroneState.I.atkBonusPct;
double globalHpPct() => GuildTech.I.totalHpBonusPct + ThroneState.I.hpBonusPct;

/// Example “effective power” multiplier used inside combat calculators
double effectivePowerMultiplier() {
  final atk = globalAtkPct();
  final hp = globalHpPct();
  final eff = 0.6 * atk + 0.4 * hp;
  return 1.0 + eff / 100.0;
}
