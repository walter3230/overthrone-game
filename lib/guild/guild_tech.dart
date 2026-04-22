// lib/guild/guild_tech.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:overthrone/core/power_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TechBranch {
  int progress; // 0..100
  TechBranch({this.progress = 0});
  bool get completed => progress >= 100;
}

class FactionTechData {
  final String id; // "elemental", "dark", ...
  final String name; // UI adı
  final String letter; // rozet harfi
  final Color color;
  final List<TechBranch> branches;

  FactionTechData({
    required this.id,
    required this.name,
    required this.letter,
    required this.color,
    List<TechBranch>? branches,
  }) : branches = branches ?? List.generate(12, (_) => TechBranch());

  int get totalUnlocked =>
      branches.fold(0, (acc, b) => acc + b.progress); // 0..1200
  int get completedBranches => branches.where((b) => b.completed).length;

  double get atkBonusPct => completedBranches * 3.0; // %3 her dal
  double get hpBonusPct => completedBranches * 5.0; // %5 her dal
}

class GuildTech {
  GuildTech._();
  static final GuildTech I = GuildTech._();

  // --- Persist keys
  static const _xpKey = 'gt_xp';
  static const _branchesKey = 'gt_branches';

  /// Harcanabilir GUILD XP (quest’lerden gelir)
  int guildXp = 0;

  /// UI’ları tazelemek için
  final ValueNotifier<int> version = ValueNotifier<int>(0);

  final List<FactionTechData> factions = [
    FactionTechData(
      id: 'elemental',
      name: 'Elemental',
      letter: 'E',
      color: Colors.lightBlue,
    ),
    FactionTechData(
      id: 'dark',
      name: 'Dark',
      letter: 'D',
      color: Colors.deepPurple,
    ),
    FactionTechData(
      id: 'nature',
      name: 'Nature',
      letter: 'N',
      color: Colors.green,
    ),
    FactionTechData(
      id: 'mech',
      name: 'Mech',
      letter: 'M',
      color: Colors.orange,
    ),
    FactionTechData(
      id: 'void',
      name: 'Void',
      letter: 'V',
      color: Colors.indigo,
    ),
    FactionTechData(
      id: 'light',
      name: 'Light',
      letter: 'L',
      color: Colors.yellow.shade700,
    ),
  ];

  // ---------- TOPLAM BONUS / ÇARPAN ----------
  double get totalAtkBonusPct =>
      factions.fold(0.0, (s, f) => s + f.atkBonusPct);
  double get totalHpBonusPct => factions.fold(0.0, (s, f) => s + f.hpBonusPct);

  /// Savaş & kahraman gücü için tekleştirilmiş çarpan:
  /// etkin% = 0.6*ATK + 0.4*HP  →  Power x(1+etkin%/100)
  double get powerMultiplier {
    final eff = 0.6 * totalAtkBonusPct + 0.4 * totalHpBonusPct;
    return 1.0 + eff / 100.0;
  }

  // ---------- PERSIST ----------
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    guildXp = p.getInt(_xpKey) ?? 0;

    final raw = p.getString(_branchesKey);
    if (raw != null) {
      final list = (jsonDecode(raw) as List);
      for (int fi = 0; fi < factions.length && fi < list.length; fi++) {
        final arr = (list[fi] as List).cast<int>();
        final br = factions[fi].branches;
        for (int bi = 0; bi < br.length && bi < arr.length; bi++) {
          // clamp num döndürür → int’e çevir
          br[bi].progress = arr[bi].clamp(0, 100).toInt();
        }
      }
    }
    version.value++;
    await PowerService.I.recomputeTop6FromRepo();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_xpKey, guildXp);
    final arr = factions
        .map((f) => f.branches.map((b) => b.progress).toList())
        .toList(growable: false);
    await p.setString(_branchesKey, jsonEncode(arr));
  }

  // ---------- İŞLEMLER (1’er 1’er) ----------
  bool get hasXp => guildXp > 0;

  /// +1 ilerlet; 1 XP harcar. Dönen bool: gerçekleşti mi?
  bool increment(int factionIndex, int branchIndex) {
    final b = factions[factionIndex].branches[branchIndex];
    if (guildXp <= 0) return false;
    if (b.progress >= 100) return false;
    b.progress += 1;
    guildXp -= 1;
    version.value++;
    _save();
    PowerService.I.recomputeTop6FromRepo();
    return true;
  }

  /// -1 geri al; 1 XP iade eder (isteğe bağlı).
  bool decrement(int factionIndex, int branchIndex) {
    final b = factions[factionIndex].branches[branchIndex];
    if (b.progress <= 0) return false;
    b.progress -= 1;
    guildXp += 1;
    version.value++;
    _save();
    PowerService.I.recomputeTop6FromRepo();
    return true;
  }

  /// Quest/bundle gibi yerlerden XP eklemek/çıkarmak
  void addGuildXp(int delta) {
    guildXp = (guildXp + delta).clamp(0, 999999);
    version.value++;
    _save();
    PowerService.I.recomputeTop6FromRepo();
  }
}

// ---------------- UI: Guild Tech ----------------

class GuildTechPage extends StatelessWidget {
  const GuildTechPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gt = GuildTech.I;

    return Scaffold(
      appBar: AppBar(title: const Text('Guild Tech')),
      body: ValueListenableBuilder<int>(
        valueListenable: gt.version,
        builder: (_, __, ___) {
          return Column(
            children: [
              // XP + Global bonus + Power multiplier
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: cs.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Guild XP: ${gt.guildXp}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+${gt.totalAtkBonusPct.toStringAsFixed(0)}% ATK • +${gt.totalHpBonusPct.toStringAsFixed(0)}% HP',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Power x${gt.powerMultiplier.toStringAsFixed(3)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Fraksiyon grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: gt.factions.length,
                  itemBuilder: (_, i) {
                    final f = gt.factions[i];
                    final double progress = (f.totalUnlocked / 1200)
                        .clamp(0.0, 1.0)
                        .toDouble();
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      color: cs.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _FactionPage(index: i),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: f.color.withValues(
                                      alpha: .2,
                                    ),
                                    foregroundColor: f.color,
                                    child: Text(f.letter),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      f.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              LinearProgressIndicator(value: progress),
                              const SizedBox(height: 6),
                              Text(
                                '${f.totalUnlocked} / 1200 unlocked',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonal(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => _FactionPage(index: i),
                                      ),
                                    );
                                  },
                                  child: const Text('Open'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FactionPage extends StatelessWidget {
  const _FactionPage({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final gt = GuildTech.I;
    final f = gt.factions[index];
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('${f.name} Tech')),
      body: ValueListenableBuilder<int>(
        valueListenable: gt.version,
        builder: (_, __, ___) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: f.color.withValues(alpha: .2),
                      foregroundColor: f.color,
                      child: Text(f.letter),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${f.totalUnlocked} / 1200 unlocked',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bonus: +${f.atkBonusPct.toStringAsFixed(0)}% ATK • +${f.hpBonusPct.toStringAsFixed(0)}% HP',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: (f.totalUnlocked / 1200)
                                .clamp(0.0, 1.0)
                                .toDouble(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 12 dal – 1+1 artar, 1 XP harcar
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(12, (i) {
                  final b = f.branches[i];
                  return GestureDetector(
                    onTap: () {
                      final ok = gt.increment(index, i);
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Yetersiz XP veya dal 100/100'),
                          ),
                        );
                      }
                    },
                    onLongPress: () {
                      // uzun basışla 1 geri al (opsiyonel)
                      gt.decrement(index, i);
                    },
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 10,
                            top: 8,
                            child: Text(
                              'B${i + 1}',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (b.completed)
                            const Positioned(
                              right: 8,
                              top: 8,
                              child: Icon(Icons.check_circle, size: 18),
                            ),
                          Center(
                            child: Text(
                              '${b.progress}/100',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: 10,
                            child: LinearProgressIndicator(
                              value: (b.progress / 100)
                                  .clamp(0.0, 1.0)
                                  .toDouble(),
                              backgroundColor: cs.surfaceContainerHighest
                                  .withValues(alpha: .6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Text(
                'Her tamamlanan dal (+100) için: +%3 ATK • +%5 HP',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                'GLOBAL: +${gt.totalAtkBonusPct.toStringAsFixed(0)}% ATK • +${gt.totalHpBonusPct.toStringAsFixed(0)}% HP  →  Power x${gt.powerMultiplier.toStringAsFixed(3)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          );
        },
      ),
    );
  }
}
