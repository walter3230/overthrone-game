// lib/ui/app_shell.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:overthrone/features/profile/profile_repo.dart';
import 'package:overthrone/core/power_service.dart';
import 'package:overthrone/core/currency_service.dart'
    as cur
    show CurrencyService;

/// Short number for UI
String fmtUi(num n) {
  if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(0)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
  return n.toString();
}

/// Public page scaffold used across pages
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.title,
    required this.child,
    this.showTitle = true,
  });

  final String title;
  final Widget child;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.surface, cs.surfaceContainerHighest],
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
            const SizedBox(height: 8),
            if (showTitle)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          // avatar
          InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: ValueListenableBuilder<int>(
              valueListenable: ProfileRepo.I.avatarFrame,
              builder: (_, frameIdx, __) {
                final ring = _frameDecoration(frameIdx, cs);
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
                          final color = _avatarColor(colorIdx, cs);
                          final hasImage =
                              (path != null) && File(path).existsSync();
                          return CircleAvatar(
                            radius: 22,
                            backgroundColor: hasImage
                                ? null
                                : color.withValues(alpha: .15),
                            backgroundImage: hasImage
                                ? FileImage(File(path))
                                : null,
                            child: hasImage
                                ? null
                                : Icon(Icons.person, size: 26, color: color),
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

          // name + VIP + power
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                _VipPill(level: vip),
                const SizedBox(height: 2),
                ValueListenableBuilder<int>(
                  valueListenable: PowerService.I.totalPower,
                  builder: (_, total, __) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up, size: 16, color: cs.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          fmtUi(total),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // resources
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<int>(
                valueListenable: cur.CurrencyService.crystalsVN,
                builder: (_, v, __) => Transform.scale(
                  scale: .90,
                  child: ResourcePill(
                    icon: Icons.diamond_outlined,
                    label: fmtUi(v),
                    onTap: () {},
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<int>(
                valueListenable: cur.CurrencyService.goldVN,
                builder: (_, v, __) => Transform.scale(
                  scale: .90,
                  child: ResourcePill(
                    icon: Icons.attach_money,
                    label: fmtUi(v),
                    onTap: () {},
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VipPill extends StatelessWidget {
  const _VipPill({required this.level});
  final int level;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cs.primary, cs.secondary]),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'VIP $level',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
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
    final cs = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.add_circle_outline, size: 18, color: cs.primary),
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
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: content,
        ),
      ),
    );
  }
}

BoxDecoration? _frameDecoration(int idx, ColorScheme cs) {
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
        border: Border.all(color: cs.primary, width: 3),
      );
  }
}

Color _avatarColor(int idx, ColorScheme cs) {
  final palette = <Color>[
    cs.primary,
    cs.secondary,
    cs.tertiary,
    Colors.teal,
    Colors.amber,
    Colors.pinkAccent,
    Colors.indigo,
    Colors.deepOrange,
  ];
  return palette[idx % palette.length];
}
