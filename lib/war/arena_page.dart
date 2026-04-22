import 'package:flutter/material.dart';
import 'war_data.dart';
import 'defense_setup_page.dart';

class ArenaPage extends StatefulWidget {
  const ArenaPage({super.key});
  @override
  State<ArenaPage> createState() => _ArenaPageState();
}

class _ArenaPageState extends State<ArenaPage> {
  final repo = ArenaRepo.I;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ladder = repo.ladder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arena (PvP)'),
        actions: [
          IconButton(
            tooltip: 'Set Defense',
            icon: const Icon(Icons.shield),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DefenseSetupPage()),
            ).then((_) => setState(() {})),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tickets bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.confirmation_num, color: cs.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Tickets: ${repo.tickets}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      'Rank: ${repo.myRank}',
                      style: TextStyle(color: cs.outline),
                    ),
                  ],
                ),
              ),
            ),

            // Ladder
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                itemCount: ladder.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final p = ladder[i];
                  final isMe = p.id == repo.myId;
                  return Container(
                    decoration: BoxDecoration(
                      color: isMe
                          ? cs.primary.withValues(alpha: 0.10)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isMe ? cs.primary : cs.outlineVariant,
                        width: isMe ? 2 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: cs.primary.withValues(alpha: 0.18),
                          child: Text('${p.rank}'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'PWR ${p.power}',
                                style: TextStyle(color: cs.outline),
                              ),
                            ],
                          ),
                        ),
                        if (isMe)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // Bottom Attack button
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton(
            onPressed: repo.canAttack ? _onAttack : null,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Attack'),
            ),
          ),
        ),
      ),
    );
  }

  void _onAttack() async {
    final opponents = repo.pickOpponents();

    if (!mounted) return;
    final target = await showModalBottomSheet<Player>(
      context: context,
      showDragHandle: true,
      isScrollControlled: false,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: opponents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = opponents[i];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                tileColor: cs.surfaceContainerHighest,
                leading: CircleAvatar(
                  backgroundColor: cs.primary.withValues(alpha: 0.18),
                  child: Text('${p.rank}'),
                ),
                title: Text(p.name),
                subtitle: Text('PWR ${p.power}'),
                trailing: const Icon(
                  Icons.flash_on,
                ), // Flutter 3.22+ var; yoksa Icons.flash_on
                onTap: () => Navigator.pop(ctx, p),
              );
            },
          ),
        );
      },
    );

    if (target == null) return;

    final result = repo.fight(target);
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(result.win ? 'Victory!' : 'Defeat'),
        content: Text(
          result.win
              ? 'You defeated ${target.name}.\n\nClimbed ${result.climbed} rank(s). New rank: ${repo.myRank}.'
              : 'You lost to ${target.name}. Tickets left: ${repo.tickets}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (mounted) setState(() {});
  }
}
