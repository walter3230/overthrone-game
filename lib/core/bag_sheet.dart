import 'package:flutter/material.dart';
import 'package:overthrone/core/bag_service.dart';

Future<void> showBagSheet(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Bag',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ValueListenableBuilder<Map<String, int>>(
                valueListenable: BagService.I.itemsVN,
                builder: (_, items, __) {
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'No items yet',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    );
                  }

                  // Currencies önce, sonra alfabetik
                  final keys = items.keys.toList()
                    ..sort((a, b) {
                      int prio(String k) =>
                          (k == 'Gold' || k == 'Crystals') ? 0 : 1;
                      final p = prio(a).compareTo(prio(b));
                      return p != 0 ? p : a.compareTo(b);
                    });

                  return GridView.builder(
                    controller: controller,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: .9,
                        ),
                    itemCount: keys.length,
                    itemBuilder: (_, i) {
                      final k = keys[i];
                      final v = items[k] ?? 0;
                      final icon = k == 'Gold'
                          ? Icons.attach_money
                          : k == 'Crystals'
                          ? Icons.diamond_outlined
                          : Icons.auto_awesome;

                      String fmt(int n) {
                        if (n >= 1000000000)
                          return '${(n / 1e9).toStringAsFixed(1)}B';
                        if (n >= 1000000)
                          return '${(n / 1e6).toStringAsFixed(1)}M';
                        if (n >= 1000)
                          return '${(n / 1000).toStringAsFixed(1)}K';
                        return '$n';
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          border: Border.all(color: cs.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 22, color: cs.primary),
                            const SizedBox(height: 8),
                            Text(
                              k,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              k == 'Gold' || k == 'Crystals' ? fmt(v) : 'x$v',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
