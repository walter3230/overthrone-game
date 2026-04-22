import 'dart:async';
import 'package:flutter/material.dart';
import 'package:overthrone/core/currency_service.dart';

class ResearchHubScreen extends StatefulWidget {
  const ResearchHubScreen({super.key});
  @override
  State<ResearchHubScreen> createState() => _ResearchHubScreenState();
}

class _ResearchHubScreenState extends State<ResearchHubScreen> {
  // Pass: 1 slot (default) / 2 slot (pass)
  bool isPassOwner = false;

  // Ekonomi: anlık envanter (UI cache) — gerçek değerler CurrencyService’te
  int crystals = 0;
  int acc24 = 0, acc12 = 0, acc6 = 0, acc1 = 0;

  // Kuyruk (demo): gerçek oyun veritabanıyla senk bağlayacağız
  final List<_QueueItem> queue = [];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      var changed = false;
      for (final q in queue) {
        if (!q.finished) {
          q.remaining -= const Duration(seconds: 1);
          if (q.remaining.isNegative) q.remaining = Duration.zero;
          changed = true;
        }
      }
      if (changed && mounted) setState(() {});
    });
  }

  Future<void> _bootstrap() async {
    // Varsayılan: tek slot, bir tane aktif iş olsun
    if (queue.isEmpty) {
      queue.add(_QueueItem.demo('HP +1% (1/10)', const Duration(hours: 3)));
    }
    await _refreshWallet();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _refreshWallet() async {
    crystals = await CurrencyService.crystals();
    final stock = await CurrencyService.accelStock();
    acc24 = stock.acc24;
    acc12 = stock.acc12;
    acc6 = stock.acc6;
    acc1 = stock.acc1;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int get maxSlots => isPassOwner ? 2 : 1;
  bool get canStartNew => queue.length < maxSlots;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Lab / Research')),
      body: RefreshIndicator(
        onRefresh: _refreshAndRebuild,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(cs),
            const SizedBox(height: 12),
            ...queue.map((q) => _queueCard(context, q)).toList(),
            if (canStartNew) ...[
              const SizedBox(height: 12),
              _startNewCard(context),
            ],
            const SizedBox(height: 20),
            Text(
              'Inventory',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _inv(cs, '24h Scroll', acc24, Icons.schedule),
                _inv(cs, '12h Scroll', acc12, Icons.schedule),
                _inv(cs, '6h Scroll', acc6, Icons.schedule),
                _inv(cs, '1h Scroll', acc1, Icons.schedule),
                _inv(cs, 'Crystals', crystals, Icons.diamond_outlined),
              ],
            ),
            const SizedBox(height: 24),
            _treeSection(cs),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshAndRebuild() async {
    await _refreshWallet();
    if (mounted) setState(() {});
  }

  Widget _header(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Research Queue • Slots: $maxSlots',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          Switch(
            value: isPassOwner,
            onChanged: (v) => setState(() => isPassOwner = v),
          ),
          const SizedBox(width: 6),
          const Text('Pass'),
        ],
      ),
    );
  }

  Widget _queueCard(BuildContext context, _QueueItem q) {
    final cs = Theme.of(context).colorScheme;
    final pct = q.total.inSeconds == 0
        ? 0.0
        : (1 - (q.remaining.inSeconds / q.total.inSeconds))
              .clamp(0.0, 1.0)
              .toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.biotech),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  q.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                q.finished ? 'Finished' : _fmtDur(q.remaining),
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: pct),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: q.finished
                      ? null
                      : () async {
                          final r = await showDialog<_SpeedUpResult>(
                            context: context,
                            builder: (_) => _SpeedUpDialog(
                              remaining: q.remaining,
                              acc24: acc24,
                              acc12: acc12,
                              acc6: acc6,
                              acc1: acc1,
                              crystals: crystals,
                            ),
                          );
                          if (r != null) {
                            // CurrencyService üzerinden atomik harcama:
                            final outcome =
                                await CurrencyService.applyResearchSpeedUp(
                                  remaining: q.remaining,
                                  use24: r.use24,
                                  use12: r.use12,
                                  use6: r.use6,
                                  use1: r.use1,
                                  crystals: r.crystalsSpent,
                                );
                            if (outcome == null) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Speed up failed (stock/limit).',
                                  ),
                                ),
                              );
                              return;
                            }
                            // UI’ı sonuçla güncelle
                            setState(() {
                              q.remaining = outcome.newRemaining;
                            });
                            // Stokları/Crystals’ı tazele
                            await _refreshWallet();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Reduced ${_fmtDur(outcome.reduced)}',
                                ),
                              ),
                            );
                          }
                        },
                  child: const Text('Speed Up'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: q.finished
                      ? () {
                          setState(() => queue.remove(q));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${q.title} completed.')),
                          );
                        }
                      : null,
                  child: const Text('Claim'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _startNewCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Start New Research',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.local_fire_department),
            title: const Text('%1 True Damage (step 1/10)'),
            subtitle: const Text('Duration: 1d'),
            trailing: FilledButton(
              onPressed: () => setState(() {
                queue.add(
                  _QueueItem.demo(
                    'True Damage +1% (1/10)',
                    const Duration(days: 1),
                  ),
                );
              }),
              child: const Text('Start'),
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.health_and_safety_outlined),
            title: const Text('%1 HP (step 1/10)'),
            subtitle: const Text('Duration: 4h'),
            trailing: FilledButton(
              onPressed: () => setState(() {
                queue.add(
                  _QueueItem.demo('HP +1% (1/10)', const Duration(hours: 4)),
                );
              }),
              child: const Text('Start'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inv(ColorScheme cs, String label, int value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          Text('$value'),
        ],
      ),
    );
  }

  // Faction özel placeholder ağaç
  Widget _treeSection(ColorScheme cs) {
    final nodes = [
      _TreeNode(
        'Void Mastery',
        'Void heroes: +%1 ATK (10 steps)',
        Icons.blur_circular_outlined,
      ),
      _TreeNode(
        'Elemental Ward',
        'Elemental heroes: +%1 HP (10 steps)',
        Icons.bubble_chart,
      ),
      _TreeNode(
        'Mech Crit Ops',
        'Mech heroes: +%1 Crit (10 steps)',
        Icons.memory_outlined,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Faction Research',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...nodes.map(
          (n) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(n.icon, color: cs.primary),
            title: Text(n.title),
            subtitle: Text(n.desc),
            trailing: FilledButton.tonal(
              onPressed: canStartNew
                  ? () => setState(
                      () => queue.add(
                        _QueueItem.demo(
                          '${n.title} +1% (1/10)',
                          const Duration(hours: 6),
                        ),
                      ),
                    )
                  : null,
              child: const Text('Queue'),
            ),
          ),
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

class _QueueItem {
  final String title;
  final Duration total;
  Duration remaining;
  _QueueItem(this.title, this.total) : remaining = total;
  bool get finished => remaining <= Duration.zero;
  factory _QueueItem.demo(String t, Duration dur) => _QueueItem(t, dur);
}

class _TreeNode {
  final String title, desc;
  final IconData icon;
  _TreeNode(this.title, this.desc, this.icon);
}

// ---------------- Speed Up Dialog ----------------

class _SpeedUpResult {
  final Duration
  reduced; // sadece UI gösterimi için (CurrencyService hesaplayacak)
  final int use24, use12, use6, use1;
  final int crystalsSpent;
  _SpeedUpResult({
    required this.reduced,
    required this.use24,
    required this.use12,
    required this.use6,
    required this.use1,
    required this.crystalsSpent,
  });
}

class _SpeedUpDialog extends StatefulWidget {
  const _SpeedUpDialog({
    required this.remaining,
    required this.acc24,
    required this.acc12,
    required this.acc6,
    required this.acc1,
    required this.crystals,
  });

  final Duration remaining;
  final int acc24, acc12, acc6, acc1;
  final int crystals;

  @override
  State<_SpeedUpDialog> createState() => _SpeedUpDialogState();
}

class _SpeedUpDialogState extends State<_SpeedUpDialog> {
  int use24 = 0, use12 = 0, use6 = 0, use1 = 0;
  int crystalToSpend = 0;

  Duration get _reducedPreview {
    var s = 0;
    s += use24 * 24 * 3600;
    s += use12 * 12 * 3600;
    s += use6 * 6 * 3600;
    s += use1 * 3600;
    if (crystalToSpend > 0) {
      s += CurrencyService.crystalToDuration(crystalToSpend).inSeconds;
    }
    if (s > widget.remaining.inSeconds) s = widget.remaining.inSeconds;
    return Duration(seconds: s);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final after = widget.remaining - _reducedPreview;
    return AlertDialog(
      title: const Text('Speed Up Research'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row('24h Scroll', widget.acc24, use24, (v) {
            setState(() => use24 = v.clamp(0, widget.acc24));
          }),
          _row('12h Scroll', widget.acc12, use12, (v) {
            setState(() => use12 = v.clamp(0, widget.acc12));
          }),
          _row('6h Scroll', widget.acc6, use6, (v) {
            setState(() => use6 = v.clamp(0, widget.acc6));
          }),
          _row('1h Scroll', widget.acc1, use1, (v) {
            setState(() => use1 = v.clamp(0, widget.acc1));
          }),
          const Divider(),
          Row(
            children: [
              const Expanded(child: Text('Crystals (1h = 250)')),
              SizedBox(
                width: 120,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '0'),
                  onChanged: (t) {
                    final v = int.tryParse(t) ?? 0;
                    setState(
                      () => crystalToSpend = v.clamp(0, widget.crystals),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Will reduce: ${_fmtDur(_reducedPreview)}'),
          Text(
            'Remaining: ${_fmtDur(after)}',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          const Text('Min crystal+scroll cut: 5 minutes.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_reducedPreview.inMinutes < 5) return; // min 5 dk
            Navigator.pop(
              context,
              _SpeedUpResult(
                reduced: _reducedPreview,
                use24: use24,
                use12: use12,
                use6: use6,
                use1: use1,
                crystalsSpent: crystalToSpend,
              ),
            );
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _row(String label, int has, int use, ValueChanged<int> onChanged) {
    return Row(
      children: [
        Expanded(child: Text('$label  (x$has)')),
        IconButton(
          onPressed: () => onChanged((use - 1).clamp(0, has)),
          icon: const Icon(Icons.remove),
        ),
        Text('$use'),
        IconButton(
          onPressed: () => onChanged((use + 1).clamp(0, has)),
          icon: const Icon(Icons.add),
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
