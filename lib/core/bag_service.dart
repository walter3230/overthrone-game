// lib/core/bag_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:overthrone/core/currency_service.dart' as cur;

class BagService {
  BagService._();
  static final I = BagService._();

  static const _kItems = 'bag.items.v1'; // only non-currency items

  /// key -> count (ör: "Keys" -> 3)
  final ValueNotifier<Map<String, int>> itemsVN = ValueNotifier(
    <String, int>{},
  );

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kItems);
    if (s != null && s.isNotEmpty) {
      final raw = Map<String, dynamic>.from(jsonDecode(s));
      itemsVN.value = raw.map((k, v) => MapEntry(k, (v as num).toInt()));
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kItems, jsonEncode(itemsVN.value));
  }

  void add(String key, int count) {
    if (count == 0) return;
    final m = Map<String, int>.from(itemsVN.value);
    m[key] = (m[key] ?? 0) + count;
    itemsVN.value = m;
    _save();
  }

  void addAll(Map<String, int> loot) {
    if (loot.isEmpty) return;
    final m = Map<String, int>.from(itemsVN.value);
    for (final e in loot.entries) {
      m[e.key] = (m[e.key] ?? 0) + e.value;
    }
    itemsVN.value = m;
    _save();
  }

  void setCount(String key, int count) {
    final m = Map<String, int>.from(itemsVN.value);
    if (count <= 0) {
      m.remove(key);
    } else {
      m[key] = count;
    }
    itemsVN.value = m;
    _save();
  }

  void clear() {
    itemsVN.value = {};
    _save();
  }

  /// CurrencyService’teki altın/mücevheri Bag’de göstermek için mirror’lar.
  /// (Persist etmez; CurrencyService değerini olduğu gibi yansıtır.)
  void hookToCurrency() {
    // initial
    setCount('Gold', cur.CurrencyService.goldVN.value);
    setCount('Crystals', cur.CurrencyService.crystalsVN.value);
    // listeners
    cur.CurrencyService.goldVN.addListener(
      () => setCount('Gold', cur.CurrencyService.goldVN.value),
    );
    cur.CurrencyService.crystalsVN.addListener(
      () => setCount('Crystals', cur.CurrencyService.crystalsVN.value),
    );
  }

  /// UI ikon eşlemesi (Home > Bag grid için)
  static IconData iconFor(String key) {
    switch (key) {
      case 'Gold':
        return Icons.attach_money;
      case 'Crystals':
        return Icons.diamond_outlined;
      case 'Arena Coins':
        return Icons.sports_esports;
      case 'Keys':
        return Icons.vpn_key;
      case 'Tokens':
        return Icons.confirmation_num_outlined; // bilet/ticket
      case 'Basic Mats':
        return Icons.handyman;
      case 'Common Gear':
        return Icons.checkroom; // istersen Icons.build
      case 'Boss Chest':
        return Icons.inventory_2;
      case 'Legendary Shards':
        return Icons.auto_awesome;
      case 'Badge':
        return Icons.verified;
      default:
        return Icons.auto_awesome; // fallback
    }
  }
}
