import 'dart:math' as math;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:overthrone/core/currency_service.dart' as cur;
import 'package:overthrone/features/profile/profile_repo.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const int _renameCost = 1000; // 💎

  @override
  void initState() {
    super.initState();
    // Güvenli: app boot’ta da çağrılıyor, burada tekrar çağırmak sorun olmaz.
    ProfileRepo.I.load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Avatar + İsim + (ALTINDA) Yeniden Adlandır ----
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AvatarPicker(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValueListenableBuilder<String>(
                        valueListenable: ProfileRepo.I.name,
                        builder: (_, name, __) => Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // İSMİN ALTINDA RENAME
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          height: 36,
                          child: FilledButton.tonal(
                            onPressed: _onRename,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Rename ($_renameCost)'),
                                const SizedBox(width: 6),
                                const Icon(Icons.diamond_outlined, size: 16),
                              ],
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
          const SizedBox(height: 12),

          // ---- Oyuncu ID + Kopyala ----
          _InfoTile(
            icon: Icons.badge_outlined,
            title: 'Player ID',
            trailing: TextButton.icon(
              onPressed: () {
                final id = ProfileRepo.I.playerId;
                Clipboard.setData(ClipboardData(text: id));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Copied $id')));
              },
              icon: const Icon(Icons.copy, size: 16),
              label: ValueListenableBuilder<String>(
                valueListenable: ProfileRepo.I.name, // sadece rebuild için
                builder: (_, __, ___) => Text(
                  ProfileRepo.I.playerId,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),

          // ---- VIP / Hesap / Bölge (placeholder kartlar) ----
          _InfoTile(
            icon: Icons.workspace_premium_outlined,
            title: 'VIP',
            subtitle: const Text('VIP 9 • Global +5% gold, +5% speed (demo)'),
            trailing: OutlinedButton(
              onPressed: () {},
              child: const Text('Details'),
            ),
          ),
          _InfoTile(
            icon: Icons.public,
            title: 'Region / Server',
            subtitle: const Text('EU-12 (demo)'),
            trailing: OutlinedButton(
              onPressed: () {},
              child: const Text('Change'),
            ),
          ),
          _InfoTile(
            icon: Icons.security_outlined,
            title: 'Account',
            subtitle: const Text('Not linked (demo)'),
            trailing: OutlinedButton(
              onPressed: () {},
              child: const Text('Link'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onRename() async {
    final newName = await _askName();
    if (newName == null) return;

    // Maliyet kontrolü
    final gems = await cur.CurrencyService.crystals();
    if (gems < _renameCost) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not enough gems.')));
      return;
    }

    // Harca → ismi kaydet → bildir
    await cur.CurrencyService.addCrystals(-_renameCost);
    await ProfileRepo.I.setName(newName);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Renamed to "$newName".')));
  }

  Future<String?> _askName() async {
    final c = TextEditingController(text: ProfileRepo.I.name.value);
    String? error;
    return showDialog<String>(
      context: context,
      builder: (_) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Change name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '3–16 chars, A–Z 0–9 _',
                  errorText: error,
                ),
                onChanged: (_) => (error = null),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.diamond_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Cost: $_renameCost',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => c.text = _randomName(),
                    child: const Text('Random'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final v = c.text.trim();
                final e = _validateName(v);
                if (e != null) {
                  error = e;
                  // rebuild:
                  (context as Element).markNeedsBuild();
                  return;
                }
                Navigator.pop(context, v);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  String? _validateName(String v) {
    if (v.length < 3 || v.length > 16) return 'Name must be 3–16 chars.';
    final re = RegExp(r'^[A-Za-z0-9_]+$');
    if (!re.hasMatch(v)) return 'Only letters, numbers and _.';
    return null;
  }

  String _randomName() {
    const adj = [
      'Brave',
      'Crimson',
      'Mystic',
      'Nova',
      'Shadow',
      'Lucky',
      'Royal',
    ];
    const noun = ['Knight', 'Ranger', 'Wolf', 'Mage', 'Drake', 'Rogue', 'Fox'];
    final r = math.Random();
    return '${adj[r.nextInt(adj.length)]}${noun[r.nextInt(noun.length)]}_${100 + r.nextInt(900)}';
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker();

  // Profil ekranındaki avatarı biraz büyüttük
  static const double _avatarRadius = 34; // iç daire yarıçapı
  static const double _ringWidth = 3; // çerçeve kalınlığı

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // foto yoksa fallback renk paleti
    final colors = <Color>[
      cs.primary,
      cs.secondary,
      cs.tertiary,
      Colors.teal,
      Colors.amber,
      Colors.pinkAccent,
      Colors.indigo,
      Colors.deepOrange,
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(_avatarRadius + 10),
      onTap: () => _openSheet(context, colors),
      child: ValueListenableBuilder<int>(
        valueListenable: ProfileRepo.I.avatarFrame,
        builder: (_, frameIdx, __) {
          final ring = _frameDecoration(frameIdx, cs);
          return Container(
            padding: EdgeInsets.all(frameIdx == 0 ? 0 : _ringWidth),
            decoration: ring,
            child: ValueListenableBuilder2<int, String?>(
              a: ProfileRepo.I.avatarColorIndex,
              b: ProfileRepo.I.avatarImagePath,
              builder: (_, colorIdx, imgPath, __) {
                final color = colors[colorIdx % colors.length];
                final hasImage = imgPath != null && File(imgPath).existsSync();
                return CircleAvatar(
                  radius: _avatarRadius,
                  backgroundColor: hasImage
                      ? null
                      : color.withValues(alpha: .25),
                  backgroundImage: hasImage ? FileImage(File(imgPath)) : null,
                  child: hasImage
                      ? null
                      : Icon(Icons.person, color: color, size: 30),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openSheet(BuildContext context, List<Color> colors) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 4,
                    width: 44,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Avatar',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),

                  // Galeriden fotoğraf
                  ListTile(
                    leading: Icon(
                      Icons.photo_library_outlined,
                      color: cs.primary,
                    ),
                    title: const Text('Choose from gallery'),
                    onTap: () async {
                      final picker = ImagePicker();
                      try {
                        final x = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 720,
                          maxHeight: 720,
                          imageQuality: 85,
                        );
                        if (x != null) {
                          await ProfileRepo.I.setAvatarFromGallery(x);
                        }
                        if (context.mounted) Navigator.pop(context);
                      } on PlatformException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gallery error: ${e.code}')),
                          );
                        }
                      }
                    },
                  ),

                  // Renkli avatar seçimi (grid)
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Or pick a color',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: colors.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    itemBuilder: (_, i) => InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await ProfileRepo.I
                            .clearAvatarImage(); // foto varsa kaldır
                        await ProfileRepo.I.setAvatarColor(i);
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          border: Border.all(color: cs.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: colors[i].withValues(alpha: .25),
                            child: Icon(Icons.person, color: colors[i]),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ---- Frame seçimi ----
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Avatar Frame',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<int>(
                    valueListenable: ProfileRepo.I.avatarFrame,
                    builder: (_, current, __) {
                      final frames = [0, 1, 2, 3, 4]; // 0=kapalı
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: frames.map((i) {
                          final selected = i == current;
                          return InkWell(
                            onTap: () => ProfileRepo.I.setAvatarFrame(i),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 58,
                              height: 58,
                              padding: EdgeInsets.all(i == 0 ? 0 : 3),
                              decoration: _frameTileDecoration(
                                i,
                                cs,
                                selected: selected,
                              ),
                              child: Center(
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: cs.surfaceContainerHighest,
                                  child: i == 0
                                      ? Text(
                                          'Off',
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 8),
                  // Fotoğrafı kaldır
                  ValueListenableBuilder<String?>(
                    valueListenable: ProfileRepo.I.avatarImagePath,
                    builder: (_, path, __) => (path == null)
                        ? const SizedBox.shrink()
                        : TextButton.icon(
                            onPressed: () async {
                              await ProfileRepo.I.clearAvatarImage();
                              if (context.mounted) Navigator.pop(context);
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remove photo'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ------ ÇERÇEVE (FRAME) yardımcıları ------
  static BoxDecoration? _frameDecoration(int idx, ColorScheme cs) {
    if (idx == 0) return null; // kapalı
    switch (idx) {
      case 1: // Altın
        return const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
          ),
        );
      case 2: // Mor-Pembe
        return const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF7C4DFF), Color(0xFFE91E63)],
          ),
        );
      case 3: // Mavi-Cyan
        return const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
          ),
        );
      case 4: // Gökkuşağı
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

  static BoxDecoration _frameTileDecoration(
    int idx,
    ColorScheme cs, {
    required bool selected,
  }) {
    final base = _frameDecoration(idx, cs);
    final highlight = BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: selected
          ? [
              BoxShadow(
                color: cs.primary.withValues(alpha: .35),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ]
          : const [],
    );

    if (base == null) {
      // "Off" kutusu
      return BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? cs.primary : cs.outlineVariant,
          width: selected ? 2 : 1,
        ),
      );
    }

    // Seçili ise gölge ekle
    return base.copyWith(boxShadow: highlight.boxShadow);
  }
}

/// İki ValueListenable’ı birlikte dinlemek için ufak yardımcı
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  const ValueListenableBuilder2({
    super.key,
    required this.a,
    required this.b,
    required this.builder,
  });

  final ValueListenable<A> a;
  final ValueListenable<B> b;
  final Widget Function(BuildContext, A, B, Widget?) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: a,
      builder: (_, va, __) => ValueListenableBuilder<B>(
        valueListenable: b,
        builder: (ctx, vb, child) => builder(ctx, va, vb, child),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(icon, color: cs.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }
}
