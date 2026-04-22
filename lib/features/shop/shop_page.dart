import 'package:flutter/material.dart';

/// Shop page with real package offerings
class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Shop'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Packages'),
              Tab(text: 'VIP'),
              Tab(text: 'Resources'),
              Tab(text: 'Special'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PackagesTab(),
            _VIPTab(),
            _ResourcesTab(),
            _SpecialTab(),
          ],
        ),
      ),
    );
  }
}

class _PackagesTab extends StatelessWidget {
  const _PackagesTab();

  @override
  Widget build(BuildContext context) {
    final packages = [
      _ShopItem('Starter Pack', 'x500 Crystals + x50 Keys + x10K Gold', '₺39.99', Icons.diamond_outlined, Colors.cyan),
      _ShopItem('Resource Crate', 'Gold x2M + Energy x10 + Ingots x20', '₺29.99', Icons.auto_awesome, Colors.amber),
      _ShopItem('Hero Bundle', 'Epic Shard x10 + Summon Tickets x5', '₺89.99', Icons.shield, Colors.purple),
      _ShopItem('Speed Pack', 'x5 Speed-Up (1hr) + x2 Speed-Up (8hr)', '₺19.99', Icons.speed, Colors.green),
      _ShopItem('Growth Fund', 'Unlock bonus rewards at every 10 levels', '₺149.99', Icons.trending_up, Colors.orange),
      _ShopItem('Monthly Card', '300 Crystals + 100K Gold daily for 30 days', '₺49.99', Icons.calendar_month, Colors.blue),
    ];

    return _buildGrid(context, packages);
  }
}

class _VIPTab extends StatelessWidget {
  const _VIPTab();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vipLevels = [
      _VipTier('Bronze VIP', '₺29.99/mo', ['+1 Boss Raid', '+5% XP', 'Daily 50 Crystals'], Colors.brown),
      _VipTier('Silver VIP', '₺59.99/mo', ['+2 Boss Raid', '+10% XP', 'Daily 150 Crystals', 'Exclusive Skin'], Colors.grey.shade400),
      _VipTier('Gold VIP', '₺99.99/mo', ['+3 Boss Raid', '+15% XP', 'Daily 300 Crystals', 'Exclusive Hero', 'Priority Support'], Colors.amber),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: vipLevels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final v = vipLevels[i];
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [v.color.withValues(alpha: .12), cs.surfaceContainerHighest],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: v.color.withValues(alpha: .5), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.workspace_premium, color: v.color, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(v.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: v.color)),
                  ),
                  Text(v.price, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              ...v.perks.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check, size: 16, color: v.color),
                    const SizedBox(width: 8),
                    Text(p, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${v.name} subscription - Google Play Billing')),
                    );
                  },
                  child: const Text('Subscribe'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VipTier {
  final String name, price;
  final List<String> perks;
  final Color color;
  const _VipTier(this.name, this.price, this.perks, this.color);
}

class _ResourcesTab extends StatelessWidget {
  const _ResourcesTab();

  @override
  Widget build(BuildContext context) {
    final items = [
      _ShopItem('100 Crystals', 'Small crystal pack', '₺9.99', Icons.diamond, Colors.cyan),
      _ShopItem('500 Crystals', 'Medium crystal pack', '₺39.99', Icons.diamond, Colors.cyan),
      _ShopItem('2000 Crystals', 'Large crystal pack', '₺129.99', Icons.diamond, Colors.cyan),
      _ShopItem('5M Gold', 'Gold bundle', '₺19.99', Icons.attach_money, Colors.amber),
      _ShopItem('20M Gold', 'Gold mega pack', '₺59.99', Icons.attach_money, Colors.amber),
      _ShopItem('Energy x20', 'Energy refill', '₺14.99', Icons.bolt, Colors.green),
    ];
    return _buildGrid(context, items);
  }
}

class _SpecialTab extends StatelessWidget {
  const _SpecialTab();

  @override
  Widget build(BuildContext context) {
    final items = [
      _ShopItem('Shadow Set', 'Exclusive dark equipment set (6pc)', '₺199.99', Icons.shield, Colors.purple),
      _ShopItem('Phoenix Skin', 'Limited edition hero skin', '₺79.99', Icons.style, Colors.orange),
      _ShopItem('Void Gems x6', 'Full set of void gems Lv.5', '₺149.99', Icons.diamond_outlined, Colors.indigo),
      _ShopItem('Stigmata Set', 'Warborn Aegis 6-piece set', '₺249.99', Icons.auto_awesome, Colors.red),
    ];
    return _buildGrid(context, items);
  }
}

Widget _buildGrid(BuildContext context, List<_ShopItem> items) {
  final cs = Theme.of(context).colorScheme;
  return GridView.builder(
    padding: const EdgeInsets.all(12),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.85,
    ),
    itemCount: items.length,
    itemBuilder: (_, i) {
      final item = items[i];
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
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 24),
            ),
            const Spacer(),
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 4),
            Text(item.subtitle, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant), maxLines: 2),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Purchase: ${item.title} - Google Play Billing')),
                  );
                },
                child: Text(item.price, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ShopItem {
  final String title, subtitle, price;
  final IconData icon;
  final Color color;
  const _ShopItem(this.title, this.subtitle, this.price, this.icon, this.color);
}
