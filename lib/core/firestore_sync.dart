import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:overthrone/core/auth_service.dart';
import 'package:overthrone/core/power_service.dart';
import 'package:overthrone/features/profile/profile_repo.dart';

/// Firestore sync service for leaderboard & player profiles
class FirestoreSync {
  FirestoreSync._();
  static final FirestoreSync I = FirestoreSync._();

  final _fs = FirebaseFirestore.instance;

  // ---- Collections ----
  CollectionReference get _users => _fs.collection('users');
  CollectionReference get _leaderboard => _fs.collection('leaderboard');
  CollectionReference get _seasons => _fs.collection('seasons');

  // ---- Player Profile ----

  /// Upload current player data to Firestore
  Future<void> syncProfile() async {
    final uid = AuthService.I.uid;
    if (uid.isEmpty) return;

    final name = ProfileRepo.I.name.value;
    final power = PowerService.I.totalPower.value;

    await _users.doc(uid).set({
      'name': name,
      'power': power,
      'lastSeen': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Also update leaderboard entry
    await _leaderboard.doc(uid).set({
      'name': name,
      'power': power,
      'uid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---- Leaderboard ----

  /// Get top N players by power
  Future<List<LeaderboardEntry>> getTopPlayers({int limit = 100}) async {
    try {
      final snap = await _leaderboard
          .orderBy('power', descending: true)
          .limit(limit)
          .get();

      return snap.docs.asMap().entries.map((e) {
        final data = e.value.data() as Map<String, dynamic>;
        return LeaderboardEntry(
          rank: e.key + 1,
          uid: data['uid'] as String? ?? e.value.id,
          name: data['name'] as String? ?? 'Unknown',
          power: data['power'] as int? ?? 0,
          isYou: e.value.id == AuthService.I.uid,
        );
      }).toList();
    } catch (e) {
      // Return demo data if Firestore fails
      return _demoLeaderboard();
    }
  }

  /// Get current player's rank
  Future<int> getMyRank() async {
    final uid = AuthService.I.uid;
    if (uid.isEmpty) return 0;

    try {
      final myDoc = await _leaderboard.doc(uid).get();
      if (!myDoc.exists) return 0;

      final myPower = (myDoc.data() as Map<String, dynamic>)['power'] as int? ?? 0;
      final above = await _leaderboard
          .where('power', isGreaterThan: myPower)
          .count()
          .get();

      return (above.count ?? 0) + 1;
    } catch (_) {
      return 0;
    }
  }

  // ---- Season Data ----

  /// Get current season info
  Future<Map<String, dynamic>> getCurrentSeason() async {
    try {
      final snap = await _seasons
          .orderBy('startDate', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        // Create first season
        await _createDefaultSeason();
        return {
          'id': 'season_1',
          'name': 'Season 1',
          'startDate': DateTime.now(),
          'endDate': DateTime.now().add(const Duration(days: 30)),
        };
      }

      return snap.docs.first.data() as Map<String, dynamic>;
    } catch (_) {
      return {
        'id': 'season_1',
        'name': 'Season 1',
        'startDate': DateTime.now(),
        'endDate': DateTime.now().add(const Duration(days: 30)),
      };
    }
  }

  Future<void> _createDefaultSeason() async {
    await _seasons.doc('season_1').set({
      'name': 'Season 1',
      'startDate': FieldValue.serverTimestamp(),
      'endDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      'active': true,
    });
  }

  // ---- Demo fallback ----
  List<LeaderboardEntry> _demoLeaderboard() {
    return List.generate(50, (i) => LeaderboardEntry(
      rank: i + 1,
      uid: 'demo_$i',
      name: i == 4 ? ProfileRepo.I.name.value : 'Player_${1000 + i}',
      power: 50000 - i * 800,
      isYou: i == 4,
    ));
  }
}

/// Single leaderboard entry
class LeaderboardEntry {
  final int rank;
  final String uid;
  final String name;
  final int power;
  final bool isYou;

  const LeaderboardEntry({
    required this.rank,
    required this.uid,
    required this.name,
    required this.power,
    this.isYou = false,
  });
}
