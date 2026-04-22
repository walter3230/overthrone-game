// lib/throne/throne_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:overthrone/ui/game_theme.dart';

import 'package:overthrone/war/defense_setup_page.dart';
import 'package:overthrone/throne/throne_state.dart' as thr;
import 'package:overthrone/core/currency_service.dart' as cur;

class ThroneScreen extends StatefulWidget {
  const ThroneScreen({super.key});
  @override
  State<ThroneScreen> createState() => _ThroneScreenState();
}

class _ThroneScreenState extends State<ThroneScreen> {
  int _gold = 0, _ing = 0, _sig = 0, _core = 0, _crown = 0;
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _loadAll();

    _listener = () {
      if (!mounted) return;
      setState(() {});
    };
    thr.ThroneState.I.version.addListener(_listener);
  }

  Future<void> _loadAll() async {
    await thr.ThroneState.I.load();
    final s = await cur.CurrencyService.throneStocks();
    if (!mounted) return;
    setState(() {
      _gold = s.gold;
      _ing = s.ingot;
      _sig = s.sigil;
      _core = s.core;
      _crown = s.crown;
    });
  }

  @override
  void dispose() {
    thr.ThroneState.I.version.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final T = thr.ThroneState.I;
    final lvl = T.level;
    final next = T.nextReq;
    final dur = T.nextDuration();

    return Scaffold(
      appBar: AppBar(title: const Text('Throne')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [GameTheme.abyss, GameTheme.deepNavy, GameTheme.abyss],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Throne Level Card ───
            _ThroneLevelCard(
              lvl: lvl,
              next: next,
              dur: dur,
              gold: _gold,
              ing: _ing,
              sig: _sig,
              core: _core,
              crown: _crown,
              onUpgrade: () async {
                final ok = await thr.ThroneState.I.levelUp();
                if (!mounted) return;
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Upgrade complete.')),
                  );
                  await _loadAll();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Not enough materials.')),
                  );
                }
              },
            ),

            const SizedBox(height: 14),

            // ─── Shield Card ───
            _ThronePanel(
              title: 'Shield',
              icon: Icons.shield_outlined,
              accentColor: GameTheme.neonBlue,
              child: _ShieldCard(),
              footer: 'Shield prevents throne attacks & loot loss.',
            ),

            const SizedBox(height: 14),

            // ─── Defense Setup Card ───
            _ThronePanel(
              title: 'Defense Setup',
              icon: Icons.groups_outlined,
              accentColor: GameTheme.emeraldGlow,
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Assign 6 heroes to guard your throne.'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DefenseSetupPage()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameTheme.emeraldGlow,
                      foregroundColor: GameTheme.abyss,
                    ),
                    child: const Text('Manage', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ─── Attack & Occupy Card ───
            _ThronePanel(
              title: 'Attack & Occupy',
              icon: Icons.gavel,
              accentColor: GameTheme.plasmaRed,
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Raid enemy thrones to steal loot & crowns.'),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [GameTheme.plasmaRed, Color(0xFFB71C1C)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: GameTheme.plasmaRed.withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Matchmaking... (demo)')),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Find Opponent',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Throne level card with dramatic visual
class _ThroneLevelCard extends StatelessWidget {
  const _ThroneLevelCard({
    required this.lvl,
    required this.next,
    required this.dur,
    required this.gold,
    required this.ing,
    required this.sig,
    required this.core,
    required this.crown,
    required this.onUpgrade,
  });

  final int lvl;
  final thr.ThroneReq next;
  final Duration dur;
  final int gold, ing, sig, core, crown;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final T = thr.ThroneState.I;
    final d = T.nextDelta();
    final atk = d.atk.toStringAsFixed(d.atk >= 1 ? 0 : 1);
    final hp = d.hp.toStringAsFixed(d.hp >= 1 ? 0 : 1);

    return GlowContainer(
      glowColor: GameTheme.royalGold,
      glowRadius: 10,
      borderRadius: 20,
      backgroundColor: GameTheme.darkSurface,
      borderGradient: const [
        GameTheme.royalGold,
        Color(0xFFFF8F00),
        GameTheme.royalGold,
      ],
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [GameTheme.royalGold, Color(0xFFFF8F00)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: GameTheme.royalGold.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chair_alt,
                    color: GameTheme.abyss,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'THRONE LEVEL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: GameTheme.royalGold,
                        ),
                      ),
                      Text(
                        'Lv.$lvl',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (lvl < 30)
                  ElevatedButton(
                    onPressed: onUpgrade,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameTheme.royalGold,
                      foregroundColor: GameTheme.abyss,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Upgrade',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Requirements
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MaterialNeed(Icons.attach_money, gold, next.gold, 'Gold', GameTheme.royalGold),
                _MaterialNeed(Icons.hexagon_outlined, ing, next.ironIngot, 'Ingots', GameTheme.neonBlue),
                if (next.royalSigil > 0)
                  _MaterialNeed(Icons.workspace_premium_outlined, sig, next.royalSigil, 'Sigils', GameTheme.voidViolet),
                if (next.ancientCore > 0)
                  _MaterialNeed(Icons.memory_outlined, core, next.ancientCore, 'Cores', GameTheme.cosmicPurple),
                if (next.celestialCrown > 0)
                  _MaterialNeed(Icons.emoji_events_outlined, crown, next.celestialCrown, 'Crowns', GameTheme.royalGold),
                _DurationChip(dur: dur),
              ],
            ),

            if (lvl < 30) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: GameTheme.cosmicPurple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: GameTheme.cosmicPurple.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up,
                        size: 14, color: GameTheme.emeraldGlow),
                    const SizedBox(width: 6),
                    Text(
                      'Next Lv.${lvl + 1}: +$atk% ATK, +$hp% HP, +${d.power} Power',
                      style: const TextStyle(
                        fontSize: 11,
                        color: GameTheme.emeraldGlow,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              const Text(
                'Max level reached',
                style: TextStyle(color: GameTheme.royalGold, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Material requirement chip
class _MaterialNeed extends StatelessWidget {
  const _MaterialNeed(
    this.icon,
    this.have,
    this.need,
    this.label,
    this.color,
  );

  final IconData icon;
  final int have;
  final int need;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ok = have >= need;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: ok ? color.withOpacity(0.12) : GameTheme.midSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ok ? color.withOpacity(0.4) : const Color(0xFF2A3352),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ok ? color : Colors.white38),
          const SizedBox(width: 6),
          Text(
            cur.CurrencyService.fmtShort(need),
            style: TextStyle(
              fontSize: 12,
              color: ok ? color : Colors.white54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '(${cur.CurrencyService.fmtShort(have)})',
            style: TextStyle(
              fontSize: 10,
              color: ok ? color.withOpacity(0.7) : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

/// Duration chip
class _DurationChip extends StatelessWidget {
  const _DurationChip({required this.dur});
  final Duration dur;

  @override
  Widget build(BuildContext context) {
    final h = dur.inHours;
    final m = dur.inMinutes % 60;
    final s = dur.inSeconds % 60;
    String text;
    if (h > 0) text = '${h}h ${m}m';
    else if (m > 0) text = '${m}m ${s}s';
    else text = '${s}s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: GameTheme.amberEnergy.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: GameTheme.amberEnergy.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: GameTheme.amberEnergy),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: GameTheme.amberEnergy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic throne panel card
class _ThronePanel extends StatelessWidget {
  const _ThronePanel({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
    this.footer,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget child;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return GlowContainer(
      glowColor: accentColor,
      glowRadius: 6,
      borderRadius: 16,
      backgroundColor: GameTheme.darkSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: accentColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
            if (footer != null) ...[
              const SizedBox(height: 8),
              Text(
                footer!,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shield card with timer
class _ShieldCard extends StatefulWidget {
  @override
  State<_ShieldCard> createState() => _ShieldCardState();
}

class _ShieldCardState extends State<_ShieldCard> {
  Duration shieldLeft = const Duration(hours: 5, minutes: 12);
  bool shieldActive = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!shieldActive || !mounted) return;
      setState(() {
        if (shieldLeft.inSeconds > 0) {
          shieldLeft -= const Duration(seconds: 1);
        } else {
          shieldActive = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              shieldActive ? Icons.shield : Icons.shield_outlined,
              color: shieldActive ? GameTheme.neonBlue : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              shieldActive ? 'Active • ${_fmtDur(shieldLeft)} left' : 'Inactive',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: shieldActive ? GameTheme.neonBlue : Colors.white38,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: shieldActive
                ? (shieldLeft.inMinutes / (12 * 60)).clamp(0, 1)
                : 0,
            minHeight: 8,
            backgroundColor: GameTheme.midSurface,
            valueColor: AlwaysStoppedAnimation(
              shieldActive ? GameTheme.neonBlue : Colors.white12,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() {
                  shieldActive = true;
                  shieldLeft = const Duration(hours: 12);
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameTheme.neonBlue.withOpacity(0.2),
                  foregroundColor: GameTheme.neonBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Renew (12h)'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() {
                  shieldActive = false;
                  shieldLeft = Duration.zero;
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameTheme.plasmaRed.withOpacity(0.2),
                  foregroundColor: GameTheme.plasmaRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Drop'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }
}
