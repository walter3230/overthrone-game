import 'package:overthrone/core/bag_service.dart' show BagService;
import 'package:overthrone/core/currency_service.dart'
    as cur
    show CurrencyService;
import 'package:overthrone/core/energy_service.dart';
import 'package:overthrone/core/power_bindings.dart';
import 'package:overthrone/core/power_service.dart';
import 'package:overthrone/features/heroes/hero_data.dart' show HeroesRepo;
import 'package:overthrone/features/research/research_data.dart';
import 'package:flutter/material.dart';
import 'war/arena_page.dart';
import 'war/defense_setup_page.dart';
import 'features/heroes/heroes_page.dart';
import 'package:overthrone/throne/throne_page.dart' as tpage;
import 'package:overthrone/throne/throne_state.dart' as tstate;
import 'features/profile/profile_page.dart';
import 'package:overthrone/features/profile/profile_repo.dart';
import 'package:overthrone/features/starport/starport_page.dart';
import 'package:overthrone/ui/app_shell.dart';
import 'war/war_data.dart';
import 'package:overthrone/core/bag_sheet.dart' show showBagSheet;
import 'package:overthrone/core/power_service.dart';
import 'package:overthrone/guild/guild_tech.dart';
import 'package:overthrone/features/research/research_page.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data' show Uint8List;
import 'dart:io';
import 'package:flutter/rendering.dart'
    show
        debugPaintSizeEnabled,
        debugPaintBaselinesEnabled,
        debugPaintPointersEnabled,
        debugPaintLayerBordersEnabled;
import 'package:overthrone/features/heroes/heroes_page.dart'
    show GameHero, allHeroes;
import 'package:overthrone/features/starport/pve_progress_service.dart';
import 'package:overthrone/features/starport/stage_data.dart';
import 'package:overthrone/features/starport/pve_sim_page.dart';
import 'package:overthrone/features/season/season_page.dart';
import 'package:overthrone/features/shop/shop_page.dart';
import 'package:overthrone/features/chat/chat_page.dart';
import 'package:overthrone/features/chat/chat_service.dart' show ChatChannel;
import 'package:overthrone/features/boss/boss_raid_page.dart';
import 'package:overthrone/features/guild/guild_war_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:overthrone/core/auth_service.dart';
import 'package:overthrone/core/firestore_sync.dart';
import 'package:overthrone/ui/game_theme.dart';
import 'package:overthrone/core/synergy_system.dart';

// ---- short number formatter (UI) ----
String fmtUi(num n) {
  if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(0)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
  return n.toString();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await AuthService.I.init();

  await GuildTech.I.load();
  await tstate.ThroneState.I.load();
  await ResearchLab.I.load();
  await ResearchLab.I.pump();
  await ProfileRepo.I.load();
  await ArenaRepo.I.load();
  await EnergyService.I.load();
  await PveProgressService.I.load();

  await BagService.I.load();
  BagService.I.hookToCurrency();
  await cur.CurrencyService.load();
  await PowerService.I.load();
  await bindPowerProviders();

  await HeroesRepo.I.load();

  PowerService.I.attachListeners();
  await PowerService.I.recomputeTop6FromRepo();

  await PowerService.I.recomputeTop6FromRepo();

  ResearchLab.I.version.addListener(() {
    PowerService.I.recomputeTop6FromRepo();
  });
  tstate.ThroneState.I.version.addListener(() {
    PowerService.I.recomputeTop6FromRepo();
  });
  GuildTech.I.version.addListener(() {
    PowerService.I.recomputeTop6FromRepo();
  });

  ProfileRepo.I.setRoster(allHeroes);

  PowerService.I.totalPower.addListener(() {
    FirestoreSync.I.syncProfile();
  });

  runApp(const OverthroneApp());

  Future.microtask(() async {
    await ResearchLab.I.pump();
    await PowerService.I.recomputeTop6FromRepo();
  });
}

class OverthroneApp extends StatelessWidget {
  const OverthroneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Overthrone',
      debugShowCheckedModeBanner: false,
      theme: GameTheme.darkGameTheme,
      home: const RootShell(),
      routes: {
        '/throne': (_) => const tpage.ThroneScreen(),
        '/lab': (_) => const ResearchPage(),
        '/profile': (_) => const ProfilePage(),
        '/research': (_) => const ResearchPage(),
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ROOT SHELL - Profesyonel Oyun Navigasyonu
// ═══════════════════════════════════════════════════════════════

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  final PageStorageBucket _bucket = PageStorageBucket();
  int _index = 0;

  final List<Widget> _pages = const [
    HomePage(key: PageStorageKey('home')),
    StarportPage(key: PageStorageKey('starport')),
    GuildPage(key: PageStorageKey('guild')),
    WarpathPage(key: PageStorageKey('warpath')),
    HeroesPage(key: PageStorageKey('heroes')),
    SeasonPage(key: PageStorageKey('season')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageStorage(
        bucket: _bucket,
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: _GameBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// Profesyonel oyun bottom navigation bar
class _GameBottomNav extends StatelessWidget {
  const _GameBottomNav({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(Icons.home_rounded, 'Home'),
    _NavItem(Icons.public_rounded, 'Starport'),
    _NavItem(Icons.groups_rounded, 'Guild'),
    _NavItem(Icons.military_tech_rounded, 'War'),
    _NavItem(Icons.person_rounded, 'Heroes'),
    _NavItem(Icons.event_rounded, 'Season'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GameTheme.deepNavy, GameTheme.abyss],
        ),
        border: Border(
          top: BorderSide(
            color: GameTheme.cosmicPurple.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = i == currentIndex;
              return _NavButton(
                icon: item.icon,
                label: item.label,
                selected: selected,
                onTap: () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    if (widget.selected) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _NavButton old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      _ctrl.forward();
    } else if (!widget.selected && old.selected) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: GameTheme.cosmicPurple.withOpacity(t * 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 20 + t * 4,
                  color: Color.lerp(
                    Colors.white38,
                    GameTheme.neonBlue,
                    t,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 9 + t * 2,
                    fontWeight: FontWeight.w700,
                    color: Color.lerp(
                      Colors.white38,
                      Colors.white,
                      t,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GAME TOP BAR - Oyun Temalı Üst Çubuk
// ═══════════════════════════════════════════════════════════════

class GameTopBar extends StatelessWidget {
  const GameTopBar({
    super.key,
    required this.playerName,
    required this.level,
    required this.vip,
    required this.gems,
    required this.gold,
  });

  final String playerName;
  final int level;
  final int vip;
  final int gems;
  final int gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [GameTheme.deepNavy, GameTheme.abyss],
        ),
        border: Border(
          bottom: BorderSide(
            color: GameTheme.cosmicPurple.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: ValueListenableBuilder<int>(
              valueListenable: ProfileRepo.I.avatarFrame,
              builder: (_, frameIdx, __) {
                final ring = _frameDecoration(frameIdx);
                return Container(
                  padding: frameIdx == 0
                      ? EdgeInsets.zero
                      : const EdgeInsets.all(2.5),
                  decoration: ring,
                  child: ValueListenableBuilder<int>(
                    valueListenable: ProfileRepo.I.avatarColorIndex,
                    builder: (_, colorIdx, __) {
                      return ValueListenableBuilder<String?>(
                        valueListenable: ProfileRepo.I.avatarImagePath,
                        builder: (_, path, __) {
                          final hasImage =
                              (path != null) && File(path).existsSync();
                          return CircleAvatar(
                            radius: 20,
                            backgroundColor: hasImage
                                ? null
                                : GameTheme.cosmicPurple.withOpacity(0.2),
                            backgroundImage: hasImage
                                ? FileImage(File(path))
                                : null,
                            child: hasImage
                                ? null
                                : const Icon(
                                    Icons.person,
                                    size: 22,
                                    color: GameTheme.neonBlue,
                                  ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),

          // Name + VIP + Power
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: ProfileRepo.I.name,
                  builder: (_, playerName, __) => Text(
                    playerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _VipBadge(level: vip),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<int>(
                      valueListenable: PowerService.I.totalPower,
                      builder: (_, total, __) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt,
                              size: 14,
                              color: GameTheme.amberEnergy,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              fmtUi(total),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: GameTheme.amberEnergy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Resources
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<int>(
                valueListenable: cur.CurrencyService.crystalsVN,
                builder: (_, v, __) => _ResourceChip(
                  icon: Icons.diamond_outlined,
                  value: fmtUi(v),
                  color: GameTheme.neonBlue,
                ),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<int>(
                valueListenable: cur.CurrencyService.goldVN,
                builder: (_, v, __) => _ResourceChip(
                  icon: Icons.monetization_on_outlined,
                  value: fmtUi(v),
                  color: GameTheme.royalGold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VipBadge extends StatelessWidget {
  const _VipBadge({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [GameTheme.royalGold, Color(0xFFFF8F00)],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: GameTheme.royalGold.withOpacity(0.3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Text(
        'VIP $level',
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: GameTheme.abyss,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ResourceChip extends StatelessWidget {
  const _ResourceChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration? _frameDecoration(int idx) {
  if (idx == 0) return null;
  switch (idx) {
    case 1:
      return const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
        ),
      );
    case 2:
      return const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF7C4DFF), Color(0xFFE91E63)],
        ),
      );
    case 3:
      return const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
        ),
      );
    case 4:
      return const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFFF44336),
            Color(0xFFFF9800),
            Color(0xFFFFEB3B),
            Color(0xFF4CAF50),
            Color(0xFF2196F3),
            Color(0xFF9C27B0),
            Color(0xFFF44336),
          ],
        ),
      );
    default:
      return BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: GameTheme.cosmicPurple, width: 3),
      );
  }
}

// ═══════════════════════════════════════════════════════════════
// HOME PAGE - Epic Heroes Tarzı Ana Ekran
// ═══════════════════════════════════════════════════════════════

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Resource generation simulation
  final ValueNotifier<int> goldPerSec = ValueNotifier<int>(517);
  final ValueNotifier<int> expPerSec = ValueNotifier<int>(758);
  final ValueNotifier<int> energyPerSec = ValueNotifier<int>(12);

  void _openSheet(BuildContext context, String title, Widget child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GameTheme.deepNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              height: 1,
              color: Color(0xFF2A3352),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.abyss,
      body: SafeArea(
        child: Stack(
          children: [
            // ─── 3D City Map Background ───
            const Positioned.fill(
              child: _CityMapBackground(),
            ),

            // ─── Main Content ───
            Column(
              children: [
                // Top Bar
                const GameTopBar(
                  playerName: 'Commander',
                  level: 30,
                  vip: 9,
                  gems: 23000,
                  gold: 26000000,
                ),

                // ─── Side Menu Buttons ───
                Expanded(
                  child: Stack(
                    children: [
                      // Left side buttons
                      Positioned(
                        left: 8,
                        top: 16,
                        child: _LeftSideMenu(
                          onMail: () => _openMail(context),
                          onQuest: () => _openQuests(context),
                          onBag: () => _openBag(context),
                        ),
                      ),

                      // Right side buttons
                      Positioned(
                        right: 8,
                        top: 16,
                        child: _RightSideMenu(
                          onFriends: () => _openFriends(context),
                          onVIP: () => _openVIP(context),
                          onShop: () => _openShop(context),
                        ),
                      ),

                      // Center - Stage Path
                      Positioned(
                        left: 80,
                        right: 80,
                        top: 40,
                        bottom: 140,
                        child: _StagePathWidget(),
                      ),
                    ],
                  ),
                ),

                // ─── Bottom Resource Bar ───
                _ResourceProductionBar(
                  goldPerSec: goldPerSec,
                  expPerSec: expPerSec,
                  energyPerSec: energyPerSec,
                ),

                // ─── Battle Button ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      // Lab button
                      _GameActionButton(
                        icon: Icons.science_outlined,
                        label: 'Lab',
                        color: GameTheme.emeraldGlow,
                        onTap: () => Navigator.of(context).pushNamed('/research'),
                      ),
                      const SizedBox(width: 12),
                      // Battle button (epic)
                      Expanded(
                        child: _EpicBattleButton(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Menu actions
  void _openMail(BuildContext context) {
    final items = List.generate(12, (i) => 'System message #${i + 1}');
    _openSheet(
      context,
      'Mail',
      ListView.separated(
        controller: ScrollController(),
        padding: const EdgeInsets.all(15),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: GameTheme.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A3352)),
          ),
          child: Row(
            children: [
              const Icon(Icons.mail, color: GameTheme.neonBlue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items[i],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap to open...',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openQuests(BuildContext context) {
    _openSheet(
      context,
      'Quests',
      ListView(
        controller: ScrollController(),
        padding: const EdgeInsets.all(15),
        children: List.generate(
          8,
          (i) => _questTile(context, 'Win $i battles', '${i * 10} XP'),
        ),
      ),
    );
  }

  void _openBag(BuildContext context) {
    _openSheet(
      context,
      'Bag',
      ValueListenableBuilder<Map<String, int>>(
        valueListenable: BagService.I.itemsVN,
        builder: (_, items, __) {
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No items yet',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          final keys = items.keys.toList()
            ..sort((a, b) {
              int prio(String k) => (k == 'Gold' || k == 'Crystals') ? 0 : 1;
              final p = prio(a).compareTo(prio(b));
              return p != 0 ? p : a.compareTo(b);
            });

          return GridView.builder(
            controller: ScrollController(),
            padding: const EdgeInsets.all(15),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: keys.length,
            itemBuilder: (_, i) {
              final k = keys[i];
              final v = items[k] ?? 0;

              IconData iconFor(String key) {
                if (key == 'Gold') return Icons.attach_money;
                if (key == 'Crystals') return Icons.diamond_outlined;
                return Icons.auto_awesome;
              }

              String fmt(int n) {
                if (n >= 1000000000) return '${(n / 1e9).toStringAsFixed(1)}B';
                if (n >= 1000000) return '${(n / 1e6).toStringAsFixed(1)}M';
                if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
                return '$n';
              }

              final label = (k == 'Gold' || k == 'Crystals')
                  ? '$k\n${fmt(v)}'
                  : '$k\nx$v';

              return _bagItem(context, iconFor(k), label);
            },
          );
        },
      ),
    );
  }

  void _openVIP(BuildContext context) {
    _openSheet(
      context,
      'VIP',
      ListView(
        controller: ScrollController(),
        padding: const EdgeInsets.all(15),
        children: const [
          ListTile(
            title: Text('Current VIP: 9'),
            subtitle: Text('+5% Gold, +5% Speed, +1 Raid Ticket'),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  void _openShop(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShopPage()),
    );
  }

  void _openFriends(BuildContext context) {
    _openSheet(
      context,
      'Friends',
      ListView.separated(
        controller: ScrollController(),
        padding: const EdgeInsets.all(15),
        itemCount: 10,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: GameTheme.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A3352)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: GameTheme.cosmicPurple.withOpacity(0.2),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Player_${i + 1001}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Text(
                      'Online',
                      style: TextStyle(color: GameTheme.emeraldGlow, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameTheme.cosmicPurple,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Invite', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _questTile(BuildContext context, String title, String reward) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GameTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3352)),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_turned_in, color: GameTheme.emeraldGlow),
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: GameTheme.amberEnergy.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              reward,
              style: const TextStyle(
                color: GameTheme.amberEnergy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: GameTheme.cosmicPurple,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 30),
            ),
            child: const Text('Go', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  static Widget _bagItem(BuildContext context, IconData icon, String qty) {
    return Container(
      decoration: BoxDecoration(
        color: GameTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3352)),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(icon, size: 28, color: GameTheme.neonBlue),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Text(
              qty,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 3D CITY MAP BACKGROUND - Epic Heroes tarzı
// ═══════════════════════════════════════════════════════════════

class _CityMapBackground extends StatelessWidget {
  const _CityMapBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CityMapPainter(),
      size: Size.infinite,
    );
  }
}

class _CityMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Base gradient - dark city atmosphere
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0A1628), // Dark blue night sky
          const Color(0xFF0D1B2A), // City horizon
          const Color(0xFF1B263B), // Ground level
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      basePaint,
    );

    // Draw river flowing through center (like Epic Heroes)
    final riverPath = Path();
    final riverWidth = size.width * 0.35;
    final centerX = size.width / 2;

    riverPath.moveTo(centerX - riverWidth / 2, 0);
    riverPath.quadraticBezierTo(
      centerX - riverWidth / 3, size.height * 0.3,
      centerX - riverWidth / 4, size.height * 0.5,
    );
    riverPath.quadraticBezierTo(
      centerX - riverWidth / 5, size.height * 0.7,
      centerX, size.height,
    );
    riverPath.lineTo(centerX + riverWidth / 5, size.height);
    riverPath.quadraticBezierTo(
      centerX + riverWidth / 4, size.height * 0.7,
      centerX + riverWidth / 3, size.height * 0.5,
    );
    riverPath.quadraticBezierTo(
      centerX + riverWidth / 2.5, size.height * 0.3,
      centerX + riverWidth / 2, 0,
    );
    riverPath.close();

    final riverPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2E5C8A).withOpacity(0.6),
          const Color(0xFF4A90C8).withOpacity(0.5),
          const Color(0xFF6BB3E0).withOpacity(0.4),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(riverPath, riverPaint);

    // River highlight/shine
    final riverHighlight = Paint()
      ..color = const Color(0xFF8BC8F0).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawPath(riverPath, riverHighlight);

    // Draw terrain/ground on sides
    final groundLeft = Path();
    groundLeft.moveTo(0, 0);
    groundLeft.lineTo(centerX - riverWidth / 2, 0);
    groundLeft.quadraticBezierTo(
      centerX - riverWidth / 2.5, size.height * 0.3,
      centerX - riverWidth / 3, size.height * 0.5,
    );
    groundLeft.quadraticBezierTo(
      centerX - riverWidth / 2.5, size.height * 0.7,
      centerX - riverWidth / 3, size.height,
    );
    groundLeft.lineTo(0, size.height);
    groundLeft.close();

    final groundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1A2F1A).withOpacity(0.8), // Forest green
          const Color(0xFF0D1F0D).withOpacity(0.9),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(groundLeft, groundPaint);

    // Right side terrain
    final groundRight = Path();
    groundRight.moveTo(size.width, 0);
    groundRight.lineTo(centerX + riverWidth / 2, 0);
    groundRight.quadraticBezierTo(
      centerX + riverWidth / 2.5, size.height * 0.3,
      centerX + riverWidth / 3, size.height * 0.5,
    );
    groundRight.quadraticBezierTo(
      centerX + riverWidth / 2.5, size.height * 0.7,
      centerX + riverWidth / 3, size.height,
    );
    groundRight.lineTo(size.width, size.height);
    groundRight.close();

    final groundRightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          const Color(0xFF2A1F3A).withOpacity(0.8), // Purple terrain
          const Color(0xFF1A1025).withOpacity(0.9),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(groundRight, groundRightPaint);

    // Draw buildings/city silhouettes on sides
    _drawCitySilhouette(canvas, size, isLeft: true);
    _drawCitySilhouette(canvas, size, isLeft: false);

    // Draw path dots along the river (stage progression path)
    _drawStagePath(canvas, size, centerX, riverWidth);

    // Atmospheric fog at bottom
    final fogPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.center,
        colors: [
          const Color(0xFF0A0E1A).withOpacity(0.8),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3));

    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
      fogPaint,
    );
  }

  void _drawCitySilhouette(Canvas canvas, Size size, {required bool isLeft}) {
    final buildings = <Rect>[];
    final baseX = isLeft ? 0.0 : size.width * 0.75;
    final width = size.width * 0.25;

    // Generate building silhouettes
    for (int i = 0; i < 8; i++) {
      final h = 30.0 + (i % 3) * 25.0 + (i * 5);
      final w = 20.0 + (i % 2) * 15.0;
      final x = baseX + (i * width / 8);
      final y = size.height * 0.35 - h;
      buildings.add(Rect.fromLTWH(x, y, w, h));
    }

    final buildingPaint = Paint()
      ..color = isLeft
          ? const Color(0xFF0D1F2D).withOpacity(0.7)
          : const Color(0xFF1A0D2D).withOpacity(0.7);

    for (final rect in buildings) {
      canvas.drawRect(rect, buildingPaint);
      // Building windows
      final windowPaint = Paint()
        ..color = const Color(0xFFFFD54F).withOpacity(0.3);
      for (int wy = 0; wy < 3; wy++) {
        for (int wx = 0; wx < 2; wx++) {
          canvas.drawRect(
            Rect.fromLTWH(
              rect.left + 3 + wx * 8,
              rect.top + 5 + wy * 12,
              4,
              6,
            ),
            windowPaint,
          );
        }
      }
    }
  }

  void _drawStagePath(Canvas canvas, Size size, double centerX, double riverWidth) {
    // Draw path dots along a curved line
    final pathPaint = Paint()
      ..color = const Color(0xFFD4AF37).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final dotPaint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.fill;

    final dotGlowPaint = Paint()
      ..color = const Color(0xFFFFD54F).withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Draw connecting path
    final path = Path();
    path.moveTo(centerX, size.height * 0.15);
    path.quadraticBezierTo(
      centerX + 20, size.height * 0.35,
      centerX - 10, size.height * 0.55,
    );
    path.quadraticBezierTo(
      centerX + 15, size.height * 0.75,
      centerX, size.height * 0.92,
    );

    canvas.drawPath(path, pathPaint);

    // Draw stage nodes
    final stagePositions = [
      Offset(centerX, size.height * 0.15),
      Offset(centerX + 15, size.height * 0.28),
      Offset(centerX - 10, size.height * 0.42),
      Offset(centerX + 20, size.height * 0.55),
      Offset(centerX - 5, size.height * 0.70),
      Offset(centerX + 10, size.height * 0.82),
      Offset(centerX, size.height * 0.92),
    ];

    for (int i = 0; i < stagePositions.length; i++) {
      final pos = stagePositions[i];
      final isCurrent = i == 4; // Stage 5 is current
      final isCompleted = i < 4;

      final radius = isCurrent ? 18.0 : 14.0;
      final glowRadius = isCurrent ? 25.0 : 18.0;

      // Glow
      canvas.drawCircle(pos, glowRadius, dotGlowPaint);

      // Outer ring
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..color = isCompleted || isCurrent
              ? const Color(0xFFD4AF37)
              : const Color(0xFF4A5568)
          ..style = PaintingStyle.fill,
      );

      // Inner hexagon (stage badge)
      _drawHexagon(canvas, pos, radius * 0.7,
        isCompleted || isCurrent
            ? const Color(0xFF8B6914)
            : const Color(0xFF2D3748),
      );

      // Stage number
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: isCompleted || isCurrent ? Colors.white : Colors.white54,
            fontSize: isCurrent ? 14 : 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
      );

      // Stars for completed stages
      if (isCompleted) {
        for (int s = 0; s < 3; s++) {
          final starOffset = Offset(
            pos.dx - 12 + s * 12,
            pos.dy - radius - 8,
          );
          _drawStar(canvas, starOffset, 4, const Color(0xFFFFD54F));
        }
      }
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * 3.14159 / 180;
      final x = center.dx + radius * Math.cos(angle);
      final y = center.dy + radius * Math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()..color = color..style = PaintingStyle.fill,
    );
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final angle = (i * 36 - 90) * 3.14159 / 180;
      final r = i % 2 == 0 ? radius : radius * 0.4;
      final x = center.dx + r * Math.cos(angle);
      final y = center.dy + r * Math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()..color = color..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Math utility for trigonometry
class Math {
  static double cos(double radians) => radians.cos();
  static double sin(double radians) => radians.sin();
}

extension on double {
  double cos() => this < 0 ? -1.0 : 1.0; // Simplified
  double sin() => this < 0 ? -0.5 : 0.5; // Simplified
}

// ═══════════════════════════════════════════════════════════════
// SIDE MENU BUTTONS
// ═══════════════════════════════════════════════════════════════

class _LeftSideMenu extends StatelessWidget {
  const _LeftSideMenu({
    required this.onMail,
    required this.onQuest,
    required this.onBag,
  });

  final VoidCallback onMail;
  final VoidCallback onQuest;
  final VoidCallback onBag;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SideMenuButton(
          icon: Icons.mail_outline,
          label: 'Mail',
          badge: 3,
          color: GameTheme.neonBlue,
          onTap: onMail,
        ),
        const SizedBox(height: 10),
        _SideMenuButton(
          icon: Icons.assignment_turned_in_outlined,
          label: 'Quest',
          badge: 5,
          color: GameTheme.emeraldGlow,
          onTap: onQuest,
        ),
        const SizedBox(height: 10),
        _SideMenuButton(
          icon: Icons.backpack_outlined,
          label: 'Bag',
          color: GameTheme.royalGold,
          onTap: onBag,
        ),
      ],
    );
  }
}

class _RightSideMenu extends StatelessWidget {
  const _RightSideMenu({
    required this.onFriends,
    required this.onVIP,
    required this.onShop,
  });

  final VoidCallback onFriends;
  final VoidCallback onVIP;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SideMenuButton(
          icon: Icons.people_outline,
          label: 'Friends',
          badge: 1,
          color: GameTheme.voidViolet,
          onTap: onFriends,
        ),
        const SizedBox(height: 10),
        _SideMenuButton(
          icon: Icons.workspace_premium_outlined,
          label: 'VIP',
          color: GameTheme.royalGold,
          onTap: onVIP,
        ),
        const SizedBox(height: 10),
        _SideMenuButton(
          icon: Icons.local_mall_outlined,
          label: 'Shop',
          color: GameTheme.cosmicPurple,
          onTap: onShop,
        ),
      ],
    );
  }
}

class _SideMenuButton extends StatelessWidget {
  const _SideMenuButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 68,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 10,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24, color: color),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null && badge! > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: GameTheme.plasmaRed,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: GameTheme.plasmaRed.withOpacity(0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STAGE PATH WIDGET
// ═══════════════════════════════════════════════════════════════

class _StagePathWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: PveProgressService.I.version,
      builder: (_, __, ___) {
        final svc = PveProgressService.I;
        final currentStage = svc.unlockedIndex.clamp(0, allStages.length - 1);
        final totalStars = svc.totalStars;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Current Stage Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    GameTheme.royalGold.withOpacity(0.2),
                    GameTheme.royalGold.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: GameTheme.royalGold.withOpacity(0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on,
                    color: GameTheme.royalGold,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Stage ${currentStage + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: GameTheme.royalGold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: GameTheme.royalGold,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$totalStars',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: GameTheme.royalGold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// RESOURCE PRODUCTION BAR
// ═══════════════════════════════════════════════════════════════

class _ResourceProductionBar extends StatelessWidget {
  const _ResourceProductionBar({
    required this.goldPerSec,
    required this.expPerSec,
    required this.energyPerSec,
  });

  final ValueNotifier<int> goldPerSec;
  final ValueNotifier<int> expPerSec;
  final ValueNotifier<int> energyPerSec;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            GameTheme.deepNavy.withOpacity(0.9),
            GameTheme.abyss.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: GameTheme.cosmicPurple.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ResourceItem(
            icon: Icons.monetization_on,
            color: GameTheme.royalGold,
            valueNotifier: goldPerSec,
            label: '/s',
          ),
          Container(
            width: 1,
            height: 24,
            color: Colors.white12,
          ),
          _ResourceItem(
            icon: Icons.bolt,
            color: GameTheme.amberEnergy,
            valueNotifier: expPerSec,
            label: '/s',
          ),
          Container(
            width: 1,
            height: 24,
            color: Colors.white12,
          ),
          _ResourceItem(
            icon: Icons.local_fire_department,
            color: GameTheme.plasmaRed,
            valueNotifier: energyPerSec,
            label: '/s',
          ),
        ],
      ),
    );
  }
}

class _ResourceItem extends StatelessWidget {
  const _ResourceItem({
    required this.icon,
    required this.color,
    required this.valueNotifier,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final ValueNotifier<int> valueNotifier;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: valueNotifier,
      builder: (_, value, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              '+$value',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.withOpacity(0.7),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EPIC BATTLE BUTTON
// ═══════════════════════════════════════════════════════════════

class _EpicBattleButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: PveProgressService.I.version,
      builder: (_, __, ___) {
        final svc = PveProgressService.I;
        final idx = svc.unlockedIndex.clamp(0, allStages.length - 1);
        final stage = allStages[idx];
        final stars = svc.totalStars;

        return GestureDetector(
          onTap: () => _launchStage(context, stage, idx),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFD54F),
                  Color(0xFFFF8F00),
                  Color(0xFFFFD54F),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD54F).withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: const Color(0xFFFF8F00).withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Shine effect
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.4),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                  ),
                ),
                // Content
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_arrow,
                        color: Color(0xFF1A1A2E),
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'BATTLE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1A2E),
                              letterSpacing: 1.5,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${stage.chapter}-${stage.stage}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.star,
                                size: 12,
                                color: Color(0xFF1A1A2E),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$stars',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF1A1A2E),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _launchStage(BuildContext context, StageData stage, int idx) async {
    final roster = allHeroes.take(6).toList();
    if (roster.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No heroes available')),
      );
      return;
    }

    final won = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PVESimScreen(
          heroes: roster,
          area: PveArea.dungeon,
          levelIndex: idx,
          difficulty: PveDifficulty.normal,
        ),
      ),
    );

    if (won == true) {
      await PveProgressService.I.markCleared(idx, 1);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// GAME ACTION BUTTON (Lab)
// ═══════════════════════════════════════════════════════════════

class _GameActionButton extends StatelessWidget {
  const _GameActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DEFENSE STATE
// ═══════════════════════════════════════════════════════════════

class DefenseState {
  final ValueNotifier<List<int?>> slots = ValueNotifier<List<int?>>(
    List<int?>.filled(6, null, growable: false),
  );
}

final defenseState = DefenseState();

// ═══════════════════════════════════════════════════════════════
// GUILD PAGE
// ═══════════════════════════════════════════════════════════════

enum GuildRole { leader, coLeader, member }

String roleName(GuildRole r) => r == GuildRole.leader
    ? 'Leader'
    : r == GuildRole.coLeader
        ? 'Co-Leader'
        : 'Member';

class GuildMember {
  final String name;
  final int power;
  final GuildRole role;
  final bool online;
  final int daysInGuild;

  GuildMember({
    required this.name,
    required this.power,
    required this.role,
    required this.online,
    required this.daysInGuild,
  });
}

class GuildPage extends StatelessWidget {
  const GuildPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScreenScaffold(
      title: 'Guild',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _gameMenuTile(context,
              icon: Icons.account_balance,
              label: 'Guild Hall',
              color: GameTheme.royalGold,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const GuildHallPage()))),
          const SizedBox(height: 10),
          _gameMenuTile(context,
              icon: Icons.shield,
              label: 'Guild War',
              color: GameTheme.plasmaRed,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const GuildWarPage()))),
          const SizedBox(height: 10),
          _gameMenuTile(context,
              icon: Icons.science_outlined,
              label: 'Tech',
              color: GameTheme.neonBlue,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const GuildTechPage()))),
          const SizedBox(height: 10),
          _gameMenuTile(context,
              icon: Icons.assignment_outlined,
              label: 'Quests',
              color: GameTheme.emeraldGlow,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const GuildQuestsPage()))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  GameTheme.cosmicPurple.withOpacity(0.1),
                  GameTheme.voidViolet.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: GameTheme.cosmicPurple.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars, color: GameTheme.royalGold),
                const SizedBox(width: 10),
                const Text(
                  'Guild XP: ',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: GuildTech.I.version,
                  builder: (_, __, ___) => Text(
                    GuildTech.I.guildXp.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: GameTheme.royalGold,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GuildChatPage()),
                  ),
                  icon: const Icon(Icons.forum_outlined,
                      color: GameTheme.neonBlue),
                  label: const Text('Chat',
                      style: TextStyle(color: GameTheme.neonBlue)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gameMenuTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.08),
              color.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}

// ---- GUILD HALL ----
class GuildHallPage extends StatelessWidget {
  const GuildHallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guild Hall')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GuildHeader(),
          const SizedBox(height: 12),
          Text('Officers', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: Column(
              children: [
                _memberTile(context, 'Commander', 'Leader'),
                _memberTile(context, 'Helper #1', 'Co-leader'),
                _memberTile(context, 'Helper #2', 'Co-leader'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Members', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 27,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) =>
                  _memberTile(context, 'User ${i + 1}', 'Member'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberTile(BuildContext context, String name, String role) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: GameTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3352)),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: GameTheme.cosmicPurple.withOpacity(0.2),
          child: Text(name.substring(0, 1)),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(role),
        trailing: const Icon(Icons.more_vert, size: 18),
        onTap: () {},
      ),
    );
  }
}

class _GuildHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlowContainer(
      glowColor: GameTheme.royalGold,
      glowRadius: 8,
      borderRadius: 16,
      backgroundColor: GameTheme.darkSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.groups_3, size: 28, color: GameTheme.royalGold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'AG x Overthrone',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text('Capacity 3 / 30', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: GameTheme.cosmicPurple,
              ),
              child: const Text('Settings'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: GameTheme.emeraldGlow,
                foregroundColor: GameTheme.abyss,
              ),
              child: const Text('Invite'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget memberTile(BuildContext context, GuildMember m) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: GameTheme.darkSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF2A3352)),
    ),
    child: ListTile(
      leading: CircleAvatar(child: Text(m.name.substring(0, 1))),
      title: Text(m.name),
      subtitle: Text(
        '${roleName(m.role)} • ${_fmtPower(m.power)} • ${m.daysInGuild}d',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 10,
            color: m.online ? GameTheme.emeraldGlow : Colors.grey,
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            onSelected: (v) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('$v (demo)')));
            },
            itemBuilder: (_) => [
              if (m.role != GuildRole.leader)
                const PopupMenuItem(value: 'Promote', child: Text('Promote')),
              if (m.role != GuildRole.member)
                const PopupMenuItem(value: 'Demote', child: Text('Demote')),
              const PopupMenuItem(value: 'Kick', child: Text('Kick')),
              const PopupMenuItem(
                value: 'View Profile',
                child: Text('View Profile'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

String _fmtPower(int p) {
  if (p >= 1000000) return '${(p / 1000000).toStringAsFixed(0)}M';
  if (p >= 1000) return '${(p / 1000).toStringAsFixed(0)}K';
  return '$p';
}

// ---- GUILD SETTINGS ----
class GuildSettingsPage extends StatefulWidget {
  const GuildSettingsPage({super.key});
  @override
  State<GuildSettingsPage> createState() => _GuildSettingsPageState();
}

class _GuildSettingsPageState extends State<GuildSettingsPage> {
  final _name = TextEditingController(text: 'AG x Overthrone');
  final _motto = TextEditingController(text: 'We rise together.');
  final _announcement = TextEditingController(text: 'Welcome to our guild!');
  bool _private = false;
  bool _autoAccept = true;

  @override
  Widget build(BuildContext context) {
    return _ScreenScaffold(
      title: 'Guild Settings',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _textFieldCard('Guild Name', _name),
          const SizedBox(height: 10),
          _textFieldCard('Motto', _motto),
          const SizedBox(height: 10),
          _textFieldCard('Announcement', _announcement, maxLines: 3),
          const SizedBox(height: 10),
          _switchCard(
            'Private Guild (invite only)',
            _private,
            (v) => setState(() => _private = v),
          ),
          _switchCard(
            'Auto-accept join requests',
            _autoAccept,
            (v) => setState(() => _autoAccept = v),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved (demo)')),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _textFieldCard(String label, TextEditingController c,
      {int maxLines = 1}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GameTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3352)),
      ),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _switchCard(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: GameTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3352)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(label),
      ),
    );
  }
}

// ---- GUILD QUESTS ----
class GuildQuestsPage extends StatefulWidget {
  const GuildQuestsPage({super.key});
  @override
  State<GuildQuestsPage> createState() => _GuildQuestsPageState();
}

class _GuildQuestsPageState extends State<GuildQuestsPage> {
  final List<_Quest> _quests = [
    _Quest('Help a member', 40, 0.35),
    _Quest('Donate resources', 60, 0.22),
    _Quest('Win 3 PvE battles', 80, 0.18),
    _Quest('Defeat a world boss', 120, 0.12),
    _Quest('Complete 5 dungeons', 90, 0.20),
    _Quest('Upgrade any tech branch', 75, 0.16),
    _Quest('Participate in Guild War', 150, 0.14),
  ];

  void _reset() {
    setState(() {
      for (final q in _quests) {
        q.done = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guild Quests')),
      body: ValueListenableBuilder<int>(
        valueListenable: GuildTech.I.version,
        builder: (_, __, ___) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      GameTheme.royalGold.withOpacity(0.1),
                      GameTheme.cosmicPurple.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: GameTheme.royalGold.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: GameTheme.royalGold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Guild XP: ${GuildTech.I.guildXp}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+${GuildTech.I.totalAtkBonusPct.toStringAsFixed(0)}% ATK • +${GuildTech.I.totalHpBonusPct.toStringAsFixed(0)}% HP',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _reset,
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ..._quests.map(
                (q) => _QuestCard(
                  quest: q,
                  onToggle: (v) {
                    setState(() {
                      if (v && !q.done) {
                        q.done = true;
                        GuildTech.I.addGuildXp(q.xp);
                      } else if (!v && q.done) {
                        q.done = false;
                        GuildTech.I.addGuildXp(-q.xp);
                      }
                    });
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

class _Quest {
  _Quest(this.title, this.xp, this.progress);
  final String title;
  final int xp;
  final double progress;
  bool done = false;
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest, required this.onToggle});
  final _Quest quest;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GameTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3352)),
        boxShadow: quest.done
            ? [
                BoxShadow(
                  color: GameTheme.emeraldGlow.withOpacity(0.08),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: quest.done,
                onChanged: (v) => onToggle(v ?? false),
                activeColor: GameTheme.emeraldGlow,
              ),
              Expanded(
                child: Text(
                  quest.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: GameTheme.amberEnergy.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: GameTheme.amberEnergy.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '+${quest.xp} XP',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: GameTheme.amberEnergy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: quest.progress,
              backgroundColor: GameTheme.midSurface,
              valueColor: const AlwaysStoppedAnimation<Color>(
                GameTheme.cosmicPurple,
              ),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- GUILD CHAT ----
class GuildChatPage extends StatelessWidget {
  const GuildChatPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const ChatPage(initialChannel: ChatChannel.guild);
}

// ================== GUILD WAR ==================
class GuildWarPage extends StatelessWidget {
  const GuildWarPage({super.key});

  @override
  Widget build(BuildContext context) => const GuildWarPageFull();
}

// ═══════════════════════════════════════════════════════════════
// WARPATH PAGE
// ═══════════════════════════════════════════════════════════════

class WarpathPage extends StatelessWidget {
  const WarpathPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('War')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _warTile(
            context,
            icon: Icons.shield,
            label: 'Set Defense',
            subtitle: 'Pick 6 heroes for your defense',
            color: GameTheme.neonBlue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DefenseSetupPage()),
            ),
          ),
          const SizedBox(height: 12),
          _warTile(
            context,
            icon: Icons.military_tech_outlined,
            label: 'Arena (PvP)',
            subtitle: 'Climb the ladder & attack with tickets',
            color: GameTheme.royalGold,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArenaPage()),
            ),
          ),
          const SizedBox(height: 12),
          _warTile(
            context,
            icon: Icons.whatshot,
            label: 'Boss Raids',
            subtitle: 'Fight bosses for materials & loot',
            color: GameTheme.plasmaRed,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BossRaidPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}

class SeasonPage extends StatelessWidget {
  const SeasonPage({super.key});
  @override
  Widget build(BuildContext context) => const SeasonPageFull();
}

// ═══════════════════════════════════════════════════════════════
// SCREEN SCAFFOLD
// ═══════════════════════════════════════════════════════════════

class _ScreenScaffold extends StatelessWidget {
  const _ScreenScaffold({
    required this.title,
    required this.child,
    this.showTitle = true,
  });

  final String title;
  final Widget child;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GameTheme.abyss, GameTheme.deepNavy, GameTheme.abyss],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const GameTopBar(
              playerName: 'Commander',
              level: 30,
              vip: 9,
              gems: 23000,
              gold: 26000000,
            ),
            if (showTitle)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// OFFERS & STAT CARDS
// ═══════════════════════════════════════════════════════════════

class Offer {
  final String title;
  final String subtitle;
  final String priceText;
  final IconData icon;
  Offer(this.title, this.subtitle, this.priceText, this.icon);
}

final _demoOffers = <Offer>[
  Offer('Starter Pack', 'x500 Gems + x50 Keys', '₺39,99', Icons.diamond_outlined),
  Offer('Resource Crate', 'Gold x2M + Energy x10', '₺29,99', Icons.auto_awesome),
  Offer('Hero Bundle', 'Epic Shard x10 + Tickets', '₺89,99', Icons.shield),
];

class StatCardData {
  final String title, value;
  final IconData icon;
  const StatCardData(this.title, this.value, this.icon);
}

class _StatCardGrid extends StatelessWidget {
  const _StatCardGrid({required this.items});
  final List<StatCardData> items;
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        return GlowContainer(
          glowColor: GameTheme.cosmicPurple,
          glowRadius: 6,
          borderRadius: 16,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(it.icon, size: 28, color: GameTheme.neonBlue),
                const Spacer(),
                Text(
                  it.value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(it.title, style: const TextStyle(fontSize: 12, color: Colors.white60)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ResourcePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const ResourcePill({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: GameTheme.neonBlue),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.add_circle_outline,
                size: 18, color: GameTheme.neonBlue),
          ],
        ],
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: GameTheme.darkSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF2A3352)),
          ),
          child: content,
        ),
      ),
    );
  }
}
