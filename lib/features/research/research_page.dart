// lib/features/research/research_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:overthrone/core/power_service.dart';

import 'package:overthrone/features/research/research_data.dart';
import 'package:overthrone/core/currency_service.dart' as cur;

class ResearchPage extends StatefulWidget {
  const ResearchPage({super.key});
  @override
  State<ResearchPage> createState() => _ResearchPageState();
}

class _ResearchPageState extends State<ResearchPage> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await Future.wait([
        PowerService.I.load(),
        ResearchLab.I.load(),
        ResearchLab.I.pump(),
        PowerService.I.recomputeTop6FromRepo(),
      ]);
      if (mounted) setState(() {});
    });

    _tick = Timer.periodic(const Duration(seconds: 5), (_) async {
      await ResearchLab.I.pump();
      await PowerService.I.recomputeTop6FromRepo();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Lab / Research')),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: ResearchLab.I.version,
          builder: (_, __, ___) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // bonuses quick glance
                    Builder(
                      builder: (_) {
                        final b = ResearchLab.I.computeBonuses();
                        return Text(
                          'HP:${b.hpPct.toStringAsFixed(0)}%  '
                          'ATK:${b.atkPct.toStringAsFixed(0)}%  '
                          'DEF:${b.defPct.toStringAsFixed(0)}%  '
                          'SPD:${b.speedPct.toStringAsFixed(0)}%  '
                          'CRIT:${b.critPct.toStringAsFixed(0)}%  '
                          'ALL:${b.allStatsPct.toStringAsFixed(1)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // total power
                    ValueListenableBuilder<int>(
                      valueListenable: PowerService.I.totalPower,
                      builder: (_, v, __) => Text(
                        'Total Power: $v',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

                const _InventoryRow(),
                const SizedBox(height: 12),
                const _QueueCard(),
                const SizedBox(height: 16),
                Text(
                  'Tech Tree',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ...ResearchLab.I.nodes.map((n) => _NodeTile(node: n, cs: cs)),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InventoryRow extends StatefulWidget {
  const _InventoryRow();

  @override
  State<_InventoryRow> createState() => _InventoryRowState();
}

class _InventoryRowState extends State<_InventoryRow> {
  ({int crystals, int gold, int ingot, int sigil, int core, int crown}) _s = (
    crystals: 0,
    gold: 0,
    ingot: 0,
    sigil: 0,
    core: 0,
    crown: 0,
  );

  Future<void> _load() async {
    final cry = await cur.CurrencyService.crystals();
    final th = await cur.CurrencyService.throneStocks();
    if (!mounted) return;
    setState(
      () => _s = (
        crystals: cry,
        gold: th.gold,
        ingot: th.ingot,
        sigil: th.sigil,
        core: th.core,
        crown: th.crown,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Widget _chip(ColorScheme cs, IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    margin: const EdgeInsets.only(right: 8),
    decoration: BoxDecoration(
      color: cs.surfaceContainerHighest,
      border: Border.all(color: cs.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(cs, Icons.diamond_outlined, 'Crystals: ${_s.crystals}'),
          _chip(cs, Icons.attach_money, 'Gold: ${_s.gold}'),
          _chip(cs, Icons.hexagon_outlined, 'Ingots: ${_s.ingot}'),
          _chip(cs, Icons.workspace_premium_outlined, 'Sigils: ${_s.sigil}'),
          _chip(cs, Icons.memory_outlined, 'Cores: ${_s.core}'),
          _chip(cs, Icons.emoji_events_outlined, 'Crowns: ${_s.crown}'),
        ],
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard();

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = ResearchLab.I.active;
    if (q == null) return const SizedBox.shrink();

    final node = ResearchLab.I.byId(q.id);
    final now = DateTime.now();
    final remaining = q.endAt.isAfter(now)
        ? q.endAt.difference(now)
        : Duration.zero;

    // progress = 1 - remaining/planned
    final plannedMs = q.planned.inMilliseconds;
    final progress = plannedMs <= 0
        ? 0.0
        : (1.0 - remaining.inMilliseconds / plannedMs).clamp(0.0, 1.0);

    final done = remaining == Duration.zero;

    // crystal quotes
    final oneHour = const Duration(hours: 1);
    final suQuote = done ? null : ResearchLab.I.speedUpQuote(oneHour);
    final fnQuote = done ? null : ResearchLab.I.finishNowQuote();

    final canSpeedUp = suQuote != null;
    final canFinishNow = fnQuote != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${node.title} → Lv ${q.targetLevel}'),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: (!done && canSpeedUp)
                      ? () async {
                          await ResearchLab.I.speedUpPay(oneHour);
                          await PowerService.I.recomputeTop6FromRepo();
                        }
                      : null,
                  icon: const Icon(Icons.speed),
                  label: Text(
                    suQuote == null
                        ? 'Speed Up'
                        : 'Speed Up -1h • ${suQuote.costCrystal} Crystals',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: (!done && canFinishNow)
                      ? () async {
                          await ResearchLab.I.finishNowPay();
                          await PowerService.I.recomputeTop6FromRepo();
                        }
                      : null,
                  child: Text(
                    fnQuote == null
                        ? 'Finish Now'
                        : 'Finish Now • ${fnQuote.costCrystal} Crystals',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: done
                    ? () async {
                        await ResearchLab.I.pump();
                        await PowerService.I.recomputeTop6FromRepo();
                      }
                    : null,
                child: const Text('Claim'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            done ? 'Completed' : 'Remaining: ${_fmt(remaining)}',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({required this.node, required this.cs});
  final ResearchNode node;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final unlocked = ResearchLab.I.isUnlocked(node);
    final canStart = ResearchLab.I.canStart(node);
    final busy = ResearchLab.I.isBusy();
    final nextCost = node.isMax ? null : node.nextCost();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          // tier dot
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: switch (node.tier) {
                1 => cs.primary.withValues(alpha: .85),
                2 => cs.tertiary.withValues(alpha: .85),
                3 => cs.secondary.withValues(alpha: .85),
                _ => cs.error.withValues(alpha: .85),
              },
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          // title + info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${node.title}  (Lv ${node.level}/${node.maxLv})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  node.subtitle,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 8),
                if (!unlocked)
                  Text(
                    'Requires previous research at least Lv.5',
                    style: TextStyle(
                      color: cs.error.withValues(alpha: .85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else if (node.isMax)
                  Text(
                    'Completed',
                    style: TextStyle(
                      color: cs.primary.withValues(alpha: .85),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  _CostRow(cost: nextCost!, cs: cs),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: (!unlocked || node.isMax || busy || !canStart)
                ? null
                : () async {
                    final ok = await ResearchLab.I.start(node);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Not enough materials.')),
                      );
                    }
                    await PowerService.I.recomputeTop6FromRepo();
                  },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({required this.cost, required this.cs});
  final ResearchCost cost;
  final ColorScheme cs;

  Widget _tag(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    margin: const EdgeInsets.only(right: 6),
    decoration: BoxDecoration(
      color: cs.surface.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: cs.outlineVariant),
    ),
    child: Row(
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
      ],
    ),
  );

  String _dur() {
    final d = cost.time;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runSpacing: 6,
      children: [
        _tag(Icons.attach_money, '${cost.gold}'),
        _tag(Icons.hexagon_outlined, '${cost.ingot}'),
        if (cost.sigil > 0)
          _tag(Icons.workspace_premium_outlined, '${cost.sigil}'),
        if (cost.core > 0) _tag(Icons.memory_outlined, '${cost.core}'),
        if (cost.crown > 0) _tag(Icons.emoji_events_outlined, '${cost.crown}'),
        _tag(Icons.timer_outlined, _dur()),
      ],
    );
  }
}
