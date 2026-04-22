import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:overthrone/ui/game_theme.dart';
import 'battle_models.dart';
import 'battle_engine.dart';
import 'battle_effects.dart';

/// Full battle screen with turn-based animated combat
class BattleScreen extends StatefulWidget {
  const BattleScreen({
    super.key,
    required this.allies,
    required this.enemies,
    required this.stageName,
  });

  final List<CombatUnit> allies;
  final List<CombatUnit> enemies;
  final String stageName;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with TickerProviderStateMixin {
  late BattleEngine _engine;
  BattleResult? _result;
  bool _running = false;
  bool _finished = false;

  int _currentTurn = 0;
  AttackResult? _lastAction;
  final List<DamagePopup> _popups = [];
  int _popupId = 0;

  // Shake animation
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  int? _shakenUnitId;

  // Victory/defeat animation
  late AnimationController _resultCtrl;
  late Animation<double> _resultScaleAnim;
  late Animation<double> _resultGlowAnim;

  // Background pulse
  late AnimationController _bgPulseCtrl;

  @override
  void initState() {
    super.initState();
    _engine = BattleEngine(
      allies: widget.allies,
      enemies: widget.enemies,
    );

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnim = Tween(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );

    // Result animation
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _resultScaleAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _resultCtrl,
        curve: const Cubic(0.175, 0.885, 0.32, 1.275),
      ),
    );
    _resultGlowAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _resultCtrl, curve: Curves.easeInOut),
    );

    // Background pulse
    _bgPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 500), _runBattle);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _resultCtrl.dispose();
    _bgPulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _runBattle() async {
    setState(() => _running = true);

    await for (final turn in _engine.runStream()) {
      if (!mounted) return;
      setState(() => _currentTurn = turn.turnNumber);

      for (final action in turn.actions) {
        if (!mounted) return;
        setState(() => _lastAction = action);

        _shakenUnitId = action.target.id;
        _shakeCtrl.forward(from: 0);

        if (action.damage > 0) {
          _addPopup(
            action.target.id,
            '-${action.damage}',
            action.isCrit ? GameTheme.royalGold : GameTheme.plasmaRed,
            isCrit: action.isCrit,
          );
        }
        if (action.healAmount > 0) {
          _addPopup(action.target.id, '+${action.healAmount}',
              GameTheme.emeraldGlow);
        }

        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        setState(() {});
      }
    }

    if (!mounted) return;

    final won = _engine.aliveEnemies.isEmpty && _engine.aliveAllies.isNotEmpty;
    final allAlive = widget.allies.every((u) => u.isAlive);
    final allAbove50 = widget.allies.every((u) => u.hpRatio > 0.5);
    int stars = 0;
    if (won) {
      stars = 1;
      if (allAlive) stars = 2;
      if (allAlive && allAbove50) stars = 3;
    }

    _result = BattleResult(
      playerWon: won,
      stars: stars,
      turns: [],
      alliesEnd: widget.allies,
      enemiesEnd: widget.enemies,
    );

    setState(() {
      _running = false;
      _finished = true;
    });
    _resultCtrl.forward();
  }

  void _addPopup(int unitId, String text, Color color, {bool isCrit = false}) {
    _popups.add(DamagePopup(
      id: _popupId++,
      unitId: unitId,
      text: text,
      color: color,
    ));
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _popups.removeWhere((p) => p.id == _popupId - 1));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.abyss,
      body: SafeArea(
        child: Stack(
          children: [
            // ─── Battle Arena Background ───
            Positioned.fill(
              child: _BattleArenaBackground(
                bgPulseCtrl: _bgPulseCtrl,
              ),
            ),

            // ─── Battle Content ───
            Column(
              children: [
                _TopBar(
                  stageName: widget.stageName,
                  turn: _currentTurn,
                  onSkip: _finished
                      ? null
                      : () {
                          final result = _engine.run();
                          setState(() {
                            _result = result;
                            _running = false;
                            _finished = true;
                          });
                          _resultCtrl.forward();
                        },
                ),

                const SizedBox(height: 8),

                // Enemy team
                Expanded(
                  flex: 4,
                  child: _TeamDisplay(
                    units: widget.enemies,
                    isEnemy: true,
                    shakenId: _shakenUnitId,
                    shakeAnimation: _shakeAnim,
                    popups: _popups,
                  ),
                ),

                // VS divider
                _BattleDivider(lastAction: _lastAction),

                // Ally team
                Expanded(
                  flex: 4,
                  child: _TeamDisplay(
                    units: widget.allies,
                    isEnemy: false,
                    shakenId: _shakenUnitId,
                    shakeAnimation: _shakeAnim,
                    popups: _popups,
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),

            // Result overlay
            if (_finished && _result != null)
              _ResultPanel(
                result: _result!,
                scaleAnim: _resultScaleAnim,
                glowAnim: _resultGlowAnim,
                onContinue: () => Navigator.pop(context, _result),
              ),
          ],
        ),
      ),
    );
  }
}

/// Animated battle arena background
class _BattleArenaBackground extends StatelessWidget {
  const _BattleArenaBackground({required this.bgPulseCtrl});
  final AnimationController bgPulseCtrl;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: bgPulseCtrl,
      builder: (_, __) {
        final pulse = bgPulseCtrl.value;
        return CustomPaint(
          painter: _ArenaPainter(pulse: pulse),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ArenaPainter extends CustomPainter {
  final double pulse;
  _ArenaPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    // Dark base
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = GameTheme.abyss,
    );

    // Central arena glow
    final centerGlow = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.8 + pulse * 0.1,
        colors: [
          GameTheme.cosmicPurple.withOpacity(0.06 + pulse * 0.02),
          GameTheme.voidViolet.withOpacity(0.03),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      centerGlow,
    );

    // Grid lines
    final gridPaint = Paint()
      ..color = GameTheme.cosmicPurple.withOpacity(0.04)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Enemy zone tint (top)
    final enemyZone = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          GameTheme.plasmaRed.withOpacity(0.04),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.5),
      enemyZone,
    );

    // Ally zone tint (bottom)
    final allyZone = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.center,
        colors: [
          GameTheme.cosmicPurple.withOpacity(0.04),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5),
      allyZone,
    );
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter old) => true;
}

/// Top bar with stage name and turn counter
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.stageName,
    required this.turn,
    this.onSkip,
  });
  final String stageName;
  final int turn;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [GameTheme.deepNavy, GameTheme.abyss],
        ),
        border: Border(
          bottom: BorderSide(
            color: GameTheme.cosmicPurple.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.pop(context, null),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stageName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Turn $turn',
                  style: const TextStyle(
                    fontSize: 11,
                    color: GameTheme.neonBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onSkip != null)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    GameTheme.cosmicPurple.withOpacity(0.2),
                    GameTheme.voidViolet.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: GameTheme.cosmicPurple.withOpacity(0.3),
                ),
              ),
              child: TextButton.icon(
                onPressed: onSkip,
                icon: const Icon(Icons.fast_forward,
                    size: 14, color: GameTheme.neonBlue),
                label: const Text('Skip',
                    style: TextStyle(color: GameTheme.neonBlue, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

/// VS divider with action info
class _BattleDivider extends StatelessWidget {
  const _BattleDivider({required this.lastAction});
  final AttackResult? lastAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    GameTheme.cosmicPurple.withOpacity(0.5),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: GameTheme.cosmicPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: GameTheme.cosmicPurple.withOpacity(0.2),
                ),
              ),
              child: Text(
                lastAction != null
                    ? '${lastAction!.attacker.name} → ${lastAction!.abilityName}'
                    : 'Battle Start',
                style: const TextStyle(
                  fontSize: 11,
                  color: GameTheme.neonBlue,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    GameTheme.cosmicPurple.withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays a team of units
class _TeamDisplay extends StatelessWidget {
  const _TeamDisplay({
    required this.units,
    required this.isEnemy,
    this.shakenId,
    this.shakeAnimation,
    required this.popups,
  });

  final List<CombatUnit> units;
  final bool isEnemy;
  final int? shakenId;
  final Animation<double>? shakeAnimation;
  final List<DamagePopup> popups;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: units.map((u) {
          final isShaken = shakenId == u.id;
          Widget card = _BattleUnitCard(unit: u, isEnemy: isEnemy);

          if (isShaken && shakeAnimation != null) {
            card = AnimatedBuilder(
              animation: shakeAnimation!,
              builder: (_, child) => Transform.translate(
                offset: Offset(
                  shakeAnimation!.value *
                      math.sin(shakeAnimation!.value * 3.14),
                  0,
                ),
                child: child,
              ),
              child: card,
            );
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              card,
              ...popups
                  .where((p) => p.unitId == u.id)
                  .map((p) => Positioned(
                        top: -24,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: p.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: p.color.withOpacity(0.3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Text(
                              p.text,
                              style: TextStyle(
                                color: p.color,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                shadows: const [
                                  Shadow(
                                    blurRadius: 6,
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )),
            ],
          );
        }).toList(),
      ),
    );
  }
}

/// Single unit card in battle - premium design
class _BattleUnitCard extends StatelessWidget {
  const _BattleUnitCard({required this.unit, required this.isEnemy});
  final CombatUnit unit;
  final bool isEnemy;

  @override
  Widget build(BuildContext context) {
    final dead = unit.isDead;
    final hpPct = unit.hpRatio.clamp(0.0, 1.0);

    final accentColor = isEnemy ? GameTheme.plasmaRed : GameTheme.neonBlue;
    final factionColor = unit.color;

    return Opacity(
      opacity: dead ? 0.35 : 1.0,
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withOpacity(0.06),
              factionColor.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: dead
                ? const Color(0xFF2A3352)
                : accentColor.withOpacity(0.4),
            width: dead ? 1 : 1.5,
          ),
          boxShadow: dead
              ? null
              : [
                  BoxShadow(
                    color: accentColor.withOpacity(0.08),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with glow
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: dead
                    ? null
                    : [
                        BoxShadow(
                          color: factionColor.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: factionColor.withOpacity(0.15),
                child: dead
                    ? Icon(Icons.close,
                        color: GameTheme.plasmaRed.withOpacity(0.6))
                    : Icon(unit.factionIcon, color: factionColor, size: 22),
              ),
            ),
            const SizedBox(height: 4),

            // Name
            Text(
              unit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),

            const SizedBox(height: 4),

            // HP bar - premium
            _PremiumBar(
              value: hpPct,
              color: hpPct > 0.5
                  ? GameTheme.emeraldGlow
                  : hpPct > 0.25
                      ? GameTheme.amberEnergy
                      : GameTheme.plasmaRed,
              height: 6,
            ),
            const SizedBox(height: 2),

            // Energy bar
            _PremiumBar(
              value: unit.energy / 100.0,
              color: unit.energy >= 100
                  ? GameTheme.royalGold
                  : GameTheme.cosmicPurple,
              height: 3,
            ),
          ],
        ),
      ),
    );
  }
}

/// Premium progress bar with glow
class _PremiumBar extends StatelessWidget {
  const _PremiumBar({
    required this.value,
    required this.color,
    required this.height,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: GameTheme.midSurface,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: LayoutBuilder(
          builder: (_, c) {
            final width = c.maxWidth * value.clamp(0.0, 1.0);
            return Stack(
              children: [
                Container(
                  width: width,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(height / 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Battle result panel overlay - dramatic victory/defeat
class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.result,
    required this.scaleAnim,
    required this.glowAnim,
    required this.onContinue,
  });

  final BattleResult result;
  final Animation<double> scaleAnim;
  final Animation<double> glowAnim;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final won = result.playerWon;
    final accentColor = won ? GameTheme.royalGold : GameTheme.plasmaRed;

    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([scaleAnim, glowAnim]),
        builder: (_, __) {
          return Transform.scale(
            scale: scaleAnim.value,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    GameTheme.deepNavy,
                    GameTheme.abyss,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: accentColor.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(glowAnim.value * 0.25),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: accentColor.withOpacity(glowAnim.value * 0.1),
                    blurRadius: 60,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Victory/Defeat title
                  Text(
                    won ? 'VICTORY' : 'DEFEAT',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(
                          color: accentColor.withOpacity(0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),

                  if (won) ...[
                    const SizedBox(height: 16),
                    // Stars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _AnimatedStar(
                            filled: i < result.stars,
                            delay: Duration(milliseconds: i * 200),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Continue button
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor,
                          accentColor.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Animated star for victory screen
class _AnimatedStar extends StatefulWidget {
  const _AnimatedStar({required this.filled, required this.delay});
  final bool filled;
  final Duration delay;

  @override
  State<_AnimatedStar> createState() => _AnimatedStarState();
}

class _AnimatedStarState extends State<_AnimatedStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.filled) {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Transform.scale(
          scale: widget.filled ? 0.5 + _ctrl.value * 0.5 : 1.0,
          child: Icon(
            widget.filled && _ctrl.value > 0.5 ? Icons.star : Icons.star_border,
            color: GameTheme.royalGold,
            size: 40,
          ),
        );
      },
    );
  }
}
