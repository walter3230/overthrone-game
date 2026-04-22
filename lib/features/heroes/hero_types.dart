// lib/features/heroes/hero_types.dart
import 'package:flutter/material.dart';

enum Rarity { sPlus, s, a, b }

enum Faction { elemental, dark, nature, mech, voidF, light }

enum Role { warrior, ranger, raider, healer, mage }

class Ability {
  final String name;
  final String desc;
  final bool active; // true = Active, false = Passive
  const Ability(this.name, this.desc, this.active);
}

// (İsteğe bağlı) Etiket / rozet renkleri – heroes_page.dart da kullanıyor
extension RarityX on Rarity {
  String get label => switch (this) {
    Rarity.sPlus => 'S+',
    Rarity.s => 'S',
    Rarity.a => 'A',
    Rarity.b => 'B',
  };
  int get sort => switch (this) {
    Rarity.sPlus => 0,
    Rarity.s => 1,
    Rarity.a => 2,
    Rarity.b => 3,
  };
  Color badge(ColorScheme cs) => switch (this) {
    Rarity.sPlus => cs.tertiary,
    Rarity.s => cs.primary,
    Rarity.a => cs.secondary,
    Rarity.b => cs.outline,
  };
}

extension FactionX on Faction {
  String get label => switch (this) {
    Faction.elemental => 'Elemental',
    Faction.dark => 'Dark',
    Faction.nature => 'Nature',
    Faction.mech => 'Mech',
    Faction.voidF => 'Void',
    Faction.light => 'Light',
  };
  IconData get icon => switch (this) {
    Faction.elemental => Icons.auto_awesome,
    Faction.dark => Icons.nightlight,
    Faction.nature => Icons.forest,
    Faction.mech => Icons.memory,
    Faction.voidF => Icons.blur_on,
    Faction.light => Icons.wb_sunny,
  };
}

/// Damage type for combat
enum DamageType {
  physical,
  magical,
  pure,
  holy,
  dark,
  nature,
}

/// Defense type for combat
enum DefenseType {
  armored,
  warded,
  balanced,
  ethereal,
  fortified,
}

/// Map faction+role to damage/defense types
extension FactionCombatX on Faction {
  DamageType get defaultDmgType => switch (this) {
    Faction.elemental => DamageType.magical,
    Faction.dark => DamageType.dark,
    Faction.nature => DamageType.nature,
    Faction.mech => DamageType.physical,
    Faction.voidF => DamageType.pure,
    Faction.light => DamageType.holy,
  };
}

extension RoleCombatX on Role {
  DefenseType get defaultDefType => switch (this) {
    Role.warrior => DefenseType.armored,
    Role.ranger => DefenseType.balanced,
    Role.raider => DefenseType.ethereal,
    Role.healer => DefenseType.warded,
    Role.mage => DefenseType.warded,
  };
}

// YENİ: RoleX
extension RoleX on Role {
  String get label => switch (this) {
    Role.warrior => 'Warrior',
    Role.ranger => 'Ranger',
    Role.raider => 'Raider',
    Role.healer => 'Healer',
    Role.mage => 'Mage',
  };

  IconData get icon => switch (this) {
    Role.warrior => Icons.shield,
    Role.ranger => Icons.near_me, // istersen gite_rounded da olur
    Role.raider => Icons.back_hand, // suikast/baskın
    Role.healer => Icons.healing,
    Role.mage => Icons.auto_awesome,
  };
}
