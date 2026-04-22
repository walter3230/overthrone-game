import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EnergyService {
  EnergyService._();
  static final EnergyService I = EnergyService._();

  // Ayarlar
  static const _maxEnergy = 120; // enerji tavanı
  static const _regenEveryMin = 5; // 5 dakikada 1 enerji

  // Persist anahtarları
  static const _kNow = 'energy_now';
  static const _kLast = 'energy_last';

  final ValueNotifier<int> energyVN = ValueNotifier<int>(0);
  Timer? _timer;

  int get maxEnergy => _maxEnergy;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();

    final savedNow = p.getInt(_kNow) ?? _maxEnergy; // ilk girişte full
    final savedLastMs =
        p.getInt(_kLast) ?? DateTime.now().millisecondsSinceEpoch;
    final last = DateTime.fromMillisecondsSinceEpoch(savedLastMs);

    final mins = DateTime.now().difference(last).inMinutes;
    final gained = mins ~/ _regenEveryMin;
    energyVN.value = min(_maxEnergy, savedNow + gained);

    await _persist(); // timestamper
    _startTicker(); // her dakika kontrol et
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (energyVN.value >= _maxEnergy) {
        await _persist();
        return;
      }
      final p = await SharedPreferences.getInstance();
      final last = DateTime.fromMillisecondsSinceEpoch(
        p.getInt(_kLast) ?? DateTime.now().millisecondsSinceEpoch,
      );
      final mins = DateTime.now().difference(last).inMinutes;
      final gained = mins ~/ _regenEveryMin;

      if (gained > 0) {
        energyVN.value = (energyVN.value + gained).clamp(0, _maxEnergy);
        await _persist();
      }
    });
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kNow, energyVN.value);
    await p.setInt(_kLast, DateTime.now().millisecondsSinceEpoch);
  }

  /// Yeterli enerji varsa düşürüp true döner
  Future<bool> spend(int cost) async {
    if (energyVN.value < cost) return false;
    energyVN.value -= cost;
    await _persist();
    return true;
  }

  Future<void> add(int n) async {
    energyVN.value = (energyVN.value + n).clamp(0, _maxEnergy);
    await _persist();
  }
}
