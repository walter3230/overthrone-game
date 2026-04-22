import 'package:flutter/material.dart';
import 'package:overthrone/features/profile/profile_repo.dart'; // ProfileRepo.I.heroes
import 'package:overthrone/core/energy_service.dart'; // EnergyService.I.spend(...)
import 'pve_progress_service.dart';
import 'pve_sim_page.dart';

class CampaignPage extends StatefulWidget {
  const CampaignPage({super.key});

  @override
  State<CampaignPage> createState() => _CampaignPageState();
}

class _CampaignPageState extends State<CampaignPage> {
  static const int _stageCount = 20;
  static const int _energyPerStage = 10;

  int _unlocked = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _unlocked = PveProgressService.I.unlockedIndex;
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _start(int index) async {
    final roster = ProfileRepo.I.heroes;
    if (roster == null || roster.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Roster boş.')));
      return;
    }

    final ok = await EnergyService.I.spend(_energyPerStage);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Yetersiz enerji.')));
      return;
    }

    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PVESimScreen(
          heroes: roster,
          area: PveArea.dungeon,
          levelIndex: index,
          difficulty: PveDifficulty.normal,
        ),
      ),
    );

    final win = res is bool ? res : false;
    if (win) {
      await PveProgressService.I.markCleared(index, 1);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campaign')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _stageCount,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final locked = i > _unlocked;
          return ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: Theme.of(
              context,
            ).colorScheme.surfaceVariant.withOpacity(.25),
            title: Text('Stage ${i + 1}'),
            subtitle: const Text('Energy 10 • Rewards: Gold, XP, Common Gear'),
            trailing: locked
                ? const Text(
                    'Locked',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  )
                : ElevatedButton(
                    onPressed: () => _start(i),
                    child: const Text('Start'),
                  ),
          );
        },
      ),
    );
  }
}
