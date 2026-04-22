// lib/features/equipment/equipment_models.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

enum EqRarity { elite, epic, legendary, mythic }

extension EqRarityX on EqRarity {
  String get label => switch (this) {
    EqRarity.elite => 'Elite',
    EqRarity.epic => 'Epic',
    EqRarity.legendary => 'Legendary',
    EqRarity.mythic => 'Mythic',
  };

  Color color(BuildContext c) => switch (this) {
    EqRarity.elite => Colors.blueGrey,
    EqRarity.epic => Colors.purpleAccent,
    EqRarity.legendary => Colors.amber,
    EqRarity.mythic => Colors.redAccent,
  };
}

/// Sentinel tipi: copyWith'te "değiştirme" ile "null ata"yı ayırmak için
class _NoChange {
  const _NoChange();
}

const _noChange = _NoChange();

/// Genişletilmiş ekipman modeli (geriye uyumlu):
/// - uid: tekil kimlik (multi-equip'i önlemek için)
/// - equippedHeroId: takılı olduğu kahraman (null ise takılı değil)
/// - setKind: set bilgisi (void/light/...)
class EqItem {
  EqItem({
    this.uid, // eski kayıtlarda yoksa ensureUid() ile üret
    required this.rarity,
    required this.level,
    this.setKind,
    this.equippedHeroId,
  });

  /// Tekil kimlik. Persist’te yoksa runtime’da üretilebilir.
  String? uid;

  final EqRarity rarity;
  final int level; // 1..5
  String? setKind; // null | 'void' | 'light' | ...

  /// Şu an hangi kahramanda takılı? (null → takılı değil)
  int? equippedHeroId;

  /// Takılı mı?
  bool get isEquipped => equippedHeroId != null;

  /// Kayıtlarda yoksa güvenli bir UID üretir.
  void ensureUid() {
    if (uid != null && uid!.isNotEmpty) return;
    final micros = DateTime.now().microsecondsSinceEpoch;
    final r = math.Random().nextInt(0xFFFF);
    uid = 'eq_${micros}_$r';
  }

  /// copyWith:
  /// - equippedHeroId için sentinel kullanıyoruz.
  ///   * varsayılan: _noChange → alanı aynı bırak
  ///   * null geçersen: alanı SIFIRLA
  ///   * int geçersen: yeni kahramana ata
  EqItem copyWith({
    String? uid,
    EqRarity? rarity,
    int? level,
    String? setKind,
    Object? equippedHeroId = _noChange,
  }) {
    final int? newEquipped = identical(equippedHeroId, _noChange)
        ? this.equippedHeroId
        : equippedHeroId as int?;
    return EqItem(
      uid: uid ?? this.uid,
      rarity: rarity ?? this.rarity,
      level: level ?? this.level,
      setKind: setKind ?? this.setKind,
      equippedHeroId: newEquipped,
    );
  }

  /// Kimlik karşılaştırması: uid varsa uid ile, yoksa alan bileşimi ile.
  bool sameIdentity(EqItem other) {
    if (uid != null && other.uid != null) return uid == other.uid;
    return rarity == other.rarity &&
        level == other.level &&
        setKind == other.setKind;
  }

  Map<String, dynamic> toJson() => {
    'uid': uid, // opsiyonel (yeni alan)
    'rarity': rarity.name,
    'level': level,
    'set': setKind,
    'eqBy': equippedHeroId, // opsiyonel (yeni alan)
  };

  /// Geriye uyumlu parse (uid/eqBy olmayabilir)
  static EqItem fromJson(Map<String, dynamic> j) => EqItem(
    uid: j['uid'] as String?, // eski kayıtlarda yok
    rarity: EqRarity.values.firstWhere(
      (e) => e.name == (j['rarity'] as String? ?? 'elite'),
      orElse: () => EqRarity.elite,
    ),
    level: (j['level'] as int?) ?? 1,
    setKind: j['set'] as String?,
    equippedHeroId: j['eqBy'] as int?, // eski kayıtlarda yok
  );

  /// Görsel isim
  String displayName() =>
      '${rarity.label} +$level${setKind != null ? ' (${setKind!})' : ''}';

  // ---------- equality & hash ----------
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EqItem) return false;
    if (uid != null && other.uid != null) return uid == other.uid;
    return rarity == other.rarity &&
        level == other.level &&
        setKind == other.setKind &&
        equippedHeroId == other.equippedHeroId;
  }

  @override
  int get hashCode {
    if (uid != null) return uid.hashCode;
    return Object.hash(rarity, level, setKind, equippedHeroId);
  }
}
