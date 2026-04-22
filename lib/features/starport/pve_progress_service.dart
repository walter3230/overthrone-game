import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PveArea { dungeon, boss, arena }
enum PveDifficulty { normal }

/// Persistent PvE progress service with star tracking
class PveProgressService {
  PveProgressService._();
  static final PveProgressService I = PveProgressService._();

  static const _kProgress = 'pve_progress_v2';
  static const _kStars = 'pve_stars_v2';

  // stage absolute index -> unlocked
  int _unlockedStageIndex = 0;

  // stage absolute index -> stars (1-3)
  final Map<int, int> _stars = {};

  final ValueNotifier<int> version = ValueNotifier(0);

  int get unlockedIndex => _unlockedStageIndex;
  int get totalStars => _stars.values.fold(0, (a, b) => a + b);

  int starsFor(int absoluteIndex) => _stars[absoluteIndex] ?? 0;

  bool isUnlocked(int absoluteIndex) => absoluteIndex <= _unlockedStageIndex;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _unlockedStageIndex = p.getInt(_kProgress) ?? 0;

    final raw = p.getString(_kStars);
    if (raw != null) {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      _stars.clear();
      map.forEach((k, v) => _stars[int.parse(k)] = v as int);
    }
    version.value++;
  }

  Future<void> markCleared(int absoluteIndex, int stars) async {
    // Update stars (keep best)
    final prev = _stars[absoluteIndex] ?? 0;
    if (stars > prev) {
      _stars[absoluteIndex] = stars;
    }

    // Unlock next stage
    if (absoluteIndex >= _unlockedStageIndex) {
      _unlockedStageIndex = absoluteIndex + 1;
    }

    await _save();
    version.value++;
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kProgress, _unlockedStageIndex);
    await p.setString(
      _kStars,
      jsonEncode(_stars.map((k, v) => MapEntry('$k', v))),
    );
  }

  // Legacy compatibility
  Future<int> unlockedIndexForArea(PveArea area, PveDifficulty diff) async {
    return _unlockedStageIndex;
  }

  Future<void> markClearedLegacy(
    PveArea area,
    PveDifficulty diff,
    int levelIndex,
  ) async {
    await markCleared(levelIndex, 1);
  }

  Future<void> reset(PveArea area, PveDifficulty diff) async {
    _unlockedStageIndex = 0;
    _stars.clear();
    await _save();
    version.value++;
  }
}
