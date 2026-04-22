// lib/features/heroes/heroes_abilities_db.dart
import 'dart:math';
import 'hero_types.dart';

/// -------- Helpers (prefix / random pick / autogen) --------------------------

/// Case-insensitive forced rarity lookup (uses S+ / S DB keys).
Rarity? forcedRarityFor(String fullName) {
  final key = fullName.toLowerCase();
  if (_SPLUSkeysLC.contains(key)) return Rarity.sPlus;
  if (_SkeysLC.contains(key)) return Rarity.s;
  return null;
}

/// Prefix used in DB keys for a given faction.
String _factionPrefix(Faction f) => switch (f) {
  Faction.elemental => 'Elemental',
  Faction.dark => 'Dark',
  Faction.nature => 'Nature',
  Faction.mech => 'Mech',
  Faction.voidF => 'Void',
  Faction.light => 'Light',
};

/// Return the DB hero names under this faction & rarity (for pickers etc.)
List<String> dbNamesForFaction(Faction f, Rarity r) {
  final prefix = '${_factionPrefix(f)} ';
  final src = (r == Rarity.sPlus) ? _SPLUS : _S;
  return src.keys.where((k) => k.startsWith(prefix)).toList();
}

/// Theme word lists by faction.
({List<String> a, List<String> p}) _theme(Faction faction) => switch (faction) {
  Faction.elemental => (
    a: ['Shock', 'Flare', 'Frost', 'Quake', 'Torrent'],
    p: ['Charged', 'Smoldering', 'Icy', 'Trembling', 'Flowing'],
  ),
  Faction.dark => (
    a: ['Hex', 'Reap', 'Gloom', 'Curse', 'Haze'],
    p: ['Creeping', 'Umbral', 'Withering', 'Haunting', 'Dreadful'],
  ),
  Faction.nature => (
    a: ['Thorn', 'Maul', 'Bloom', 'Entangle', 'Spore'],
    p: ['Verdant', 'Thorned', 'Wild', 'Barking', 'Blooming'],
  ),
  Faction.mech => (
    a: ['Overclock', 'Pulse', 'Drill', 'Blast', 'Hack'],
    p: ['Calibrated', 'Reinforced', 'Synchronized', 'Shielded', 'Efficient'],
  ),
  Faction.voidF => (
    a: ['Rift', 'Siphon', 'Collapse', 'Echo', 'Phase'],
    p: ['Abyssal', 'Entropic', 'Quantum', 'Null', 'Fractal'],
  ),
  Faction.light => (
    a: ['Smite', 'Ray', 'Vow', 'Grace', 'Beacon'],
    p: ['Radiant', 'Blessed', 'Guiding', 'Holy', 'Shimmering'],
  ),
};

T _pick<T>(List<T> list, Random rng) => list[rng.nextInt(list.length)];

/// Unified autogen for A/B (and can also be used for quick prototypes).
List<Ability> generateAbilities({
  required Faction faction,
  required Rarity rarity,
  required Role role,
  Random? random,
}) {
  final rng = random ?? Random();
  final th = _theme(faction);

  String roleActive() => switch (role) {
    Role.warrior => 'Strike',
    Role.ranger => 'Volley',
    Role.raider => 'Ambush',
    Role.healer => 'Mend',
    Role.mage => 'Surge',
  };
  String rolePassive() => switch (role) {
    Role.warrior => 'Guard',
    Role.ranger => 'Focus',
    Role.raider => 'Predation',
    Role.healer => 'Aegis',
    Role.mage => 'Wisdom',
  };

  // Slight description variety (kept concise)
  String activeDesc() => switch (role) {
    Role.warrior => 'Frontline single-target hit; pierces ~20% armor.',
    Role.ranger => 'Ranged hit that can tag 2 targets; +crit chance briefly.',
    Role.raider =>
      'Marks the weakest foe; first turn damage greatly increased.',
    Role.healer => 'Restores HP to 2–3 allies and may cleanse 1 debuff.',
    Role.mage => 'Small AoE with reduced Energy gain to affected targets.',
  };

  String passiveDesc() => switch (role) {
    Role.warrior => 'Takes less damage; generates extra threat.',
    Role.ranger => 'Improved accuracy at start of battle.',
    Role.raider => 'On kill, restores a bit of Energy and HP.',
    Role.healer => 'Heals lowest-HP ally slightly each turn.',
    Role.mage => 'Magic up; ability costs slightly reduced.',
  };

  final activeName = '${_pick(th.a, rng)} ${roleActive()}';
  final passiveName = '${_pick(th.p, rng)} ${rolePassive()}';

  // Rarity → number of abilities
  final (actives: aCount, passives: pCount) = switch (rarity) {
    Rarity.sPlus => (actives: 2, passives: 2),
    Rarity.s => (actives: 1, passives: 2),
    Rarity.a => (actives: 1, passives: 1),
    Rarity.b => (actives: 1, passives: 0),
  };

  final list = <Ability>[];
  for (var i = 0; i < aCount; i++) {
    list.add(
      Ability(
        i == 0 ? activeName : '${_pick(th.a, rng)} ${roleActive()}',
        activeDesc(),
        true,
      ),
    );
  }
  for (var i = 0; i < pCount; i++) {
    list.add(
      Ability(
        i == 0 ? passiveName : '${_pick(th.p, rng)} ${rolePassive()}',
        passiveDesc(),
        false,
      ),
    );
  }
  return list;
}

/// ---- Public API: abilitiesForHeroName --------------------------------------

List<Ability> abilitiesForHeroName({
  required String fullName,
  required Rarity rarity,
  Role? role,
  Faction? faction,
}) {
  // Try DB first (S+ / S)
  final db = switch (rarity) {
    Rarity.sPlus => _SPLUS[fullName],
    Rarity.s => _S[fullName],
    _ => null,
  };
  if (db != null) return db;

  // A / B → autogen requires role + faction
  if ((rarity == Rarity.a || rarity == Rarity.b) &&
      role != null &&
      faction != null) {
    return generateAbilities(faction: faction, rarity: rarity, role: role);
  }
  return <Ability>[];
}

/// ============================================================================
/// BELOW: Hand-authored DB for S+ and S heroes (kept exactly as provided)
/// ============================================================================

/// =======================
/// S+ (2 Active + 2 Passive)
/// =======================
Map<String, List<Ability>> _SPLUS = {
  // ---------------- ELEMENTAL (S+) ----------------
  'Elemental Storm': [
    Ability(
      'Tempest Break',
      'Unleashes a spiraling cyclone on the primary target, dealing massive damage and pushing them back. If the target is already slowed or rooted, this strike pierces 25% armor.',
      true,
    ),
    Ability(
      'Ion Cyclone',
      'Calls down charged winds to strike up to 2 additional nearby enemies for splash damage.',
      true,
    ),
    Ability(
      'Static Overcharge',
      'Gains a stack of Overcharge whenever Storm attacks; at 3 stacks, next attack cannot miss and shocks for bonus true damage.',
      false,
    ),
    Ability(
      'Eye of the Gale',
      'Begins combat with 10% speed and 10% dodge. Each time Storm avoids an attack, gain 5% crit chance (2 turns).',
      false,
    ),
  ],
  'Elemental Flare': [
    Ability(
      'Solar Lance',
      'Fires a beam of searing light through the front line, dealing heavy damage and burning for 2 turns.',
      true,
    ),
    Ability(
      'Phoenix Recast',
      'If Solar Lance defeats an enemy, immediately recast at 60% power on the next target.',
      true,
    ),
    Ability(
      'Incandescent Core',
      'Gain 15% crit damage; when Flare crits, burn durations on the target are extended by 1 turn.',
      false,
    ),
    Ability(
      'Blazing Aura',
      'Allies gain 5% attack while any enemy is burning. Flare gains an additional 5% speed during burn uptime.',
      false,
    ),
  ],
  'Elemental Glacier': [
    Ability(
      'Permafrost Prison',
      'Encases the target in ice, dealing damage and applying Freeze for 1 turn (bosses: Slow).',
      true,
    ),
    Ability(
      'Shatterline',
      'Frozen or slowed enemies take 30% more damage from this cast and lose 10% armor for 2 turns.',
      true,
    ),
    Ability(
      'Cold Snap',
      'At the start of Glacier’s turn, the lowest-HP enemy is chilled, reducing their speed by 8% (2 turns).',
      false,
    ),
    Ability(
      'Icebound Bulwark',
      'Takes 12% less damage from ranged sources; whenever Glacier is hit, 10% chance to apply Frostbite for 1 turn.',
      false,
    ),
  ],
  'Elemental Quake': [
    Ability(
      'Tectonic Rift',
      'Smashes the ground, creating a line of ruptures that damages and staggers enemies in a row.',
      true,
    ),
    Ability(
      'Seismic Echo',
      'After using Tectonic Rift, the next basic attack triggers an aftershock for bonus AoE damage.',
      true,
    ),
    Ability(
      'Earthen Guard',
      'Gain a stacking 4% damage reduction when attacked (max 5). Stacks reset at end of turn.',
      false,
    ),
    Ability(
      'Stone Momentum',
      'Every 3rd ability used grants Quake Unstoppable for 1 turn (cannot be displaced).',
      false,
    ),
  ],
  'Elemental Spark': [
    Ability(
      'Arc Surge',
      'Chains lightning between up to 3 enemies, damage increases with each jump.',
      true,
    ),
    Ability(
      'Capacitor Burst',
      'If Arc Surge hits the same enemy twice (via bounce), apply Stun (1 turn; bosses: Shock).',
      true,
    ),
    Ability(
      'Voltage Leak',
      'Basic attacks have 20% chance to apply Shock (reduces Energy gain by 20% for 2 turns).',
      false,
    ),
    Ability(
      'Quickcharge',
      'Starts battle with +20 Energy; on kill, restore 10 Energy.',
      false,
    ),
  ],
  'Elemental Tempest': [
    Ability(
      'Maelstrom',
      'Summons a whirling storm around Tempest, damaging all enemies over 2 turns.',
      true,
    ),
    Ability(
      'Gale Redirect',
      'Recast to relocate the Maelstrom to the targeted enemy, dealing a burst on move.',
      true,
    ),
    Ability(
      'Tailwind',
      'All allies gain 8% speed while Maelstrom is active.',
      false,
    ),
    Ability(
      'Pressure Front',
      'Enemies in Maelstrom suffer -10% accuracy.',
      false,
    ),
  ],

  // ---------------- DARK (S+) ----------------
  'Dark Shade': [
    Ability(
      'Umbral Cleave',
      'Strikes from the shadows; damage is doubled against targets above 75% HP.',
      true,
    ),
    Ability(
      'Veil of Night',
      'Gain Stealth for 1 turn; leaving Stealth grants bonus crit chance for the next attack.',
      true,
    ),
    Ability(
      'Gloom Drinker',
      'Heals for 8% of damage dealt. On kill, gain 10% speed for 2 turns.',
      false,
    ),
    Ability(
      'Ebon Veins',
      'Incoming healing received +15%; Bleed/Poison durations on Shade are reduced by 1.',
      false,
    ),
  ],
  'Dark Hex': [
    Ability(
      'Runic Malediction',
      'Curses the target; their damage is reduced by 25% for 2 turns, and they take damage when using abilities.',
      true,
    ),
    Ability(
      'Witchbrand',
      'If the target already has a curse, silence them for 1 turn.',
      true,
    ),
    Ability(
      'Omen Spiral',
      'Each time Hex applies a debuff, gain +5% attack (stacks 4, refreshes on re-apply).',
      false,
    ),
    Ability(
      'Shroud Scholar',
      'Resist +12%. When Hex resists a debuff, reduce cooldowns by 1 on a random ability.',
      false,
    ),
  ],
  'Dark Gloom': [
    Ability(
      'Grave Bloom',
      'Releases a burst of necrotic pollen, damaging and blinding enemies (1 turn).',
      true,
    ),
    Ability(
      'Pale Harvest',
      'Deals bonus damage to blinded targets and extends blind by 1 if it crits.',
      true,
    ),
    Ability(
      'Night Soil',
      'Enemies that miss attacks against Gloom suffer 5% defense down for 2 turns.',
      false,
    ),
    Ability(
      'Duskwind',
      '+10% dodge. On successful dodge, gain a small shield (scales with level).',
      false,
    ),
  ],
  'Dark Abyss': [
    Ability(
      'Event Horizon',
      'Pulls enemies slightly toward the center and damages them; far enemies take extra damage.',
      true,
    ),
    Ability(
      'Singular Collapse',
      'If Event Horizon hits 3+ enemies, collapse for an additional burst on the center target.',
      true,
    ),
    Ability(
      'Null Hunger',
      'Every 3 enemy abilities used feed Abyss, granting +6% attack (max 3, consumed on next cast).',
      false,
    ),
    Ability(
      'Starless Night',
      'Reduces enemy Energy gain by 10% while Abyss is alive.',
      false,
    ),
  ],
  'Dark Ruin': [
    Ability(
      'Cataclysm',
      'A brutal strike that deals bonus damage per debuff on the target.',
      true,
    ),
    Ability(
      'Black Aftermath',
      'If Cataclysm defeats the target, spread their debuffs to the nearest enemy.',
      true,
    ),
    Ability(
      'Carrion Pact',
      '+15% crit damage; on crit, inflict Weakened (-10% attack) for 1 turn.',
      false,
    ),
    Ability('Hollow Shell', 'Takes 12% less AoE damage.', false),
  ],
  'Dark Dread': [
    Ability(
      'Terror Pulse',
      'Fears the primary target for 1 turn (bosses: -20% speed for 2 turns) and deals damage.',
      true,
    ),
    Ability(
      'Unnerving Echo',
      'Enemies adjacent to the feared target take minor psychic damage and lose 10 Energy.',
      true,
    ),
    Ability(
      'Horror’s Grasp',
      'When Dread damages a crowd-controlled enemy, gain +10% attack (2 turns).',
      false,
    ),
    Ability(
      'Restless Night',
      'At end of Dread’s turn, a random enemy loses 5 Energy.',
      false,
    ),
  ],

  // ---------------- NATURE (S+) ----------------
  'Nature Thorn': [
    Ability(
      'Bramble Snare',
      'Roots the target for 1 turn and deals damage over time.',
      true,
    ),
    Ability(
      'Razor Growth',
      'Snare explodes at the end of its duration for bonus damage and Bleed (2 turns).',
      true,
    ),
    Ability(
      'Barbed Hide',
      'Melee attackers take thorn damage; each trigger grants 3% damage reduction (2 turns).',
      false,
    ),
    Ability('Verdant Rhythm', 'Every 3rd cast refunds 20 Energy.', false),
  ],
  'Nature Grove': [
    Ability(
      'Sylvan Sanctuary',
      'Creates a protective zone healing allies inside over 2 turns.',
      true,
    ),
    Ability(
      'Rooted Resolve',
      'Allies in the zone gain 15% defense; recast relocates the zone to the target ally.',
      true,
    ),
    Ability(
      'Forest’s Favor',
      'At battle start, the lowest-HP ally gains a small shield and +5% resist.',
      false,
    ),
    Ability('Druidic Poise', 'Healing done +15%.', false),
  ],
  'Nature Bloom': [
    Ability(
      'Bloom Burst',
      'Releases restorative petals to 3 allies, healing and granting 10% attack for 1 turn.',
      true,
    ),
    Ability(
      'Pollinate',
      'If the same ally is healed twice in a row, they cleanse 1 debuff.',
      true,
    ),
    Ability(
      'Spring Tide',
      'At turn start, the ally with the lowest HP gains a tiny HoT for 2 turns.',
      false,
    ),
    Ability(
      'Gentle Roots',
      'Allies healed by Bloom gain 5% speed for 1 turn.',
      false,
    ),
  ],
  'Nature Fang': [
    Ability(
      'Alpha Pounce',
      'Leaps to the backline, slashing the weakest enemy for heavy damage.',
      true,
    ),
    Ability(
      'Pack Instinct',
      'If an ally hits the same target this turn, Fang’s next attack deals 20% more damage.',
      true,
    ),
    Ability(
      'Predator’s Mark',
      'On crit, mark the target; marked enemies take 8% more damage from all sources (2 turns).',
      false,
    ),
    Ability(
      'Wild Agility',
      '+10% speed. First attack each battle cannot be dodged.',
      false,
    ),
  ],
  'Nature Bark': [
    Ability(
      'Oakclad Rampart',
      'Raises a bark shield, reducing incoming damage and dealing thorns on hit for 2 turns.',
      true,
    ),
    Ability(
      'Timber Step',
      'While the shield holds, Bark’s basic attack hits all adjacent enemies.',
      true,
    ),
    Ability(
      'Heartwood',
      'Maximum HP +12%. When shield breaks, gain a small heal.',
      false,
    ),
    Ability(
      'Sap Surge',
      'On being hit, 10% chance to root the attacker for 1 turn.',
      false,
    ),
  ],
  'Nature Vine': [
    Ability(
      'Creeping Coil',
      'Sends vines to bind 2 enemies, slowing them and dealing damage over time.',
      true,
    ),
    Ability(
      'Tangle Bloom',
      'Recast detonates the vines for burst damage based on remaining DoT.',
      true,
    ),
    Ability(
      'Green Grasp',
      'When Vine applies a slow, gain +5% attack (stacks 3).',
      false,
    ),
    Ability(
      'Lifeward',
      'Allies standing above 75% HP gain +10% resist.',
      false,
    ),
  ],

  // ---------------- MECH (S+) ----------------
  'Mech Bolt': [
    Ability(
      'Thunderbolt Mk.III',
      'Fires a piercing rail shot; damage increases with distance traveled.',
      true,
    ),
    Ability(
      'Capacitor Overdrive',
      'Next Thunderbolt fires two projectiles and briefly reveals invisible targets.',
      true,
    ),
    Ability(
      'Conductive Mesh',
      'Ranged damage taken -10%; on crit, apply Minor Shock for 1 turn.',
      false,
    ),
    Ability('Power Sync', 'Every 2 casts, gain 20 Energy.', false),
  ],
  'Mech Gear': [
    Ability(
      'Geargrind',
      'Crushes the target with rotating cogs, applying Armor Break for 2 turns.',
      true,
    ),
    Ability(
      'Torque Spike',
      'If the target is Armor Broken, deal additional true damage.',
      true,
    ),
    Ability('Hardened Casing', 'Defense +12%.', false),
    Ability(
      'Lubricants Online',
      'When Gear is healed, reduce cooldowns by 1 on a random ability (once per turn).',
      false,
    ),
  ],
  'Mech Core': [
    Ability(
      'Core Reboot',
      'Restores a burst of Energy to all allies and grants them a small shield.',
      true,
    ),
    Ability(
      'Failsafe Pulse',
      'If an ally falls below 30% HP, auto-trigger a mini Reboot (1 per ally).',
      true,
    ),
    Ability(
      'Stable Clock',
      'Ally ability cooldowns are reduced by 5% while Core is alive (multiplicative).',
      false,
    ),
    Ability(
      'Thermal Buffer',
      'Takes 12% less damage from burn/poison/bleed sources.',
      false,
    ),
  ],
  'Mech Pulse': [
    Ability(
      'Resonance Wave',
      'Sends a cone of sonic damage; enemies hit are silenced for 1 turn.',
      true,
    ),
    Ability(
      'Harmonic Snap',
      'If Resonance hits 3+ enemies, apply Disrupt (cannot gain Energy) for 1 turn.',
      true,
    ),
    Ability(
      'Pulse Stabilizer',
      'Accuracy +10%; silenced enemies deal 8% less damage.',
      false,
    ),
    Ability('Gyro Lock', 'Immune to displacement while casting.', false),
  ],
  'Mech Circuit': [
    Ability(
      'Feedback Loop',
      'Marks an enemy; each time they use an ability, they take damage and lose 5 Energy.',
      true,
    ),
    Ability(
      'Short Fuse',
      'Detonate the mark early for burst damage equal to stored charge.',
      true,
    ),
    Ability(
      'Optimized Routing',
      'Gain +6% speed. When an enemy loses Energy, Circuit gains 5 Energy.',
      false,
    ),
    Ability(
      'Packet Shield',
      'Projectiles against Circuit have -10% accuracy.',
      false,
    ),
  ],
  'Mech Alloy': [
    Ability(
      'Alloy Cleaver',
      'Strikes the primary target and chains to a second, dealing reduced damage.',
      true,
    ),
    Ability(
      'Smelter Heat',
      'If both strikes hit, apply Melted Armor (-15% defense) for 2 turns.',
      true,
    ),
    Ability(
      'Tempered Frame',
      '+10% damage reduction vs. melee attacks.',
      false,
    ),
    Ability(
      'Refit Routine',
      'When below 40% HP, auto-gain a small shield (once per wave).',
      false,
    ),
  ],

  // ---------------- VOID (S+) ----------------
  'Void Rift': [
    Ability(
      'Rift Laceration',
      'Slices across the battlefield ignoring 20% defenses; backline takes bonus damage.',
      true,
    ),
    Ability(
      'Phase Shear',
      'Targets affected by time effects (slow, stun, freeze) take an additional rupture tick.',
      true,
    ),
    Ability(
      'Edge of Unreality',
      '+12% crit chance against enemies above 80% HP.',
      false,
    ),
    Ability(
      'Temporal Slip',
      'First damaging ability each battle is instant (no wind-up).',
      false,
    ),
  ],
  'Void Echo': [
    Ability(
      'Paradox Blast',
      'Deals damage and creates a delayed echo that repeats 1 turn later at 60% power.',
      true,
    ),
    Ability(
      'Hollow Chorus',
      'When the echo triggers on a target, reduce their Energy by 10.',
      true,
    ),
    Ability(
      'Infinite Feedback',
      'Every repeat grants Echo +5% attack (2 turns).',
      false,
    ),
    Ability(
      'Quiet Between',
      'Enemies with 0 Energy take 10% more damage.',
      false,
    ),
  ],
  'Void Singularity': [
    Ability(
      'Micro Singularity',
      'Creates a micro black hole on the target that explodes after 1 turn.',
      true,
    ),
    Ability(
      'Event Chain',
      'If 2+ enemies are affected, link them; when one explodes, others take splash.',
      true,
    ),
    Ability(
      'Warped Mass',
      'Gain a growing shield each time a Singularity explodes (stacks to 3).',
      false,
    ),
    Ability(
      'Gravitic Pull',
      'Basic attacks slightly drag enemies forward.',
      false,
    ),
  ],
  'Void Worm': [
    Ability(
      'Space Tear',
      'Opens a rift under the enemy, dealing damage and applying Vulnerable.',
      true,
    ),
    Ability(
      'Burrow Step',
      'Next ability teleports Worm behind the target, striking again for small bonus damage.',
      true,
    ),
    Ability(
      'Unstable Geometry',
      'Blinking grants +10% dodge for 1 turn.',
      false,
    ),
    Ability('Horizon Crawler', 'Ignores 10% of enemy damage reduction.', false),
  ],
  'Void Aether': [
    Ability(
      'Aether Lance',
      'Pierces defenses and siphons Energy toward Aether.',
      true,
    ),
    Ability(
      'Astral Sink',
      'If Aether Lance reduces the target below 30% Energy, silence them for 1 turn.',
      true,
    ),
    Ability(
      'Aetheric Flow',
      'On Energy gain, also gain 5% speed (2 turns).',
      false,
    ),
    Ability('Stillness', 'While above 60 Energy, take 10% less damage.', false),
  ],
  'Void Phase': [
    Ability(
      'Phase Rift',
      'Deals damage ignoring dodge; then Phase becomes intangible for 1 turn (reduced damage).',
      true,
    ),
    Ability(
      'Quantum Step',
      'While intangible, next attack deals 30% bonus true damage.',
      true,
    ),
    Ability(
      'Fractal Shell',
      '+12% resist; when resisting, inflict -10% speed (1 turn).',
      false,
    ),
    Ability('Tunneling', 'Cannot be displaced while intangible.', false),
  ],

  // ---------------- LIGHT (S+) ----------------
  'Light Halo': [
    Ability(
      'Crown of Radiance',
      'Emits a ring of light, damaging enemies and granting allies a small shield.',
      true,
    ),
    Ability(
      'Sanctified Pulse',
      'Allies inside the ring cleanse 1 debuff and gain 10% speed for 1 turn.',
      true,
    ),
    Ability(
      'Beatific Ward',
      'Halo gains 10% damage reduction while any ally is shielded.',
      false,
    ),
    Ability(
      'Inner Light',
      'Every time a shield is applied, restore 5 Energy to Halo.',
      false,
    ),
  ],
  'Light Celestia': [
    Ability(
      'Starlit Spear',
      'Throws a spear of light that pierces the first target and lightly damages the next.',
      true,
    ),
    Ability(
      'Constellation Bind',
      'Enemies hit become Bound: -10% crit chance and -10% speed (2 turns).',
      true,
    ),
    Ability(
      'Heaven’s Favor',
      'On crit, grant the nearest ally +10% crit chance for 1 turn.',
      false,
    ),
    Ability('Astral Aegis', 'Takes 12% less ranged damage.', false),
  ],
  'Light Radiant': [
    Ability(
      'Radiant Verdict',
      'Smite a single target for heavy holy damage; extra vs. demons/undead (lore tag).',
      true,
    ),
    Ability(
      'Judgment Echo',
      'If the target is already marked by Radiant, Verdict refunds 20 Energy.',
      true,
    ),
    Ability(
      'Oathkeeper',
      'At the start, mark the highest-attack enemy for justice: they take +8% damage (2 turns).',
      false,
    ),
    Ability(
      'Devoted Heart',
      'Allies healed by Radiant receive +10% defense for 1 turn.',
      false,
    ),
  ],
  'Light Vow': [
    Ability(
      'Vow of Dawn',
      'Heals allies in a line and grants them a fragile shield.',
      true,
    ),
    Ability(
      'Sunlit Pledge',
      'If a shield breaks, the owner gains 10% haste for 1 turn.',
      true,
    ),
    Ability('Pledgekeeper', 'Healing done +12%.', false),
    Ability(
      'Morning Grace',
      'At turn start, the ally with the least Energy gains 10 Energy.',
      false,
    ),
  ],
  'Light Dawn': [
    Ability(
      'Daybreak',
      'Explodes light around Dawn, damaging enemies and revealing invisible units.',
      true,
    ),
    Ability(
      'Aurora Trail',
      'After Daybreak, Dawn’s next two basic attacks apply a small burn.',
      true,
    ),
    Ability('Golden Hour', '+10% speed in the first 2 turns.', false),
    Ability(
      'Horizon Watch',
      'Enemies revealed by Dawn take 10% more damage for 1 turn.',
      false,
    ),
  ],
  'Light Seraph': [
    Ability(
      'Seraphic Chorus',
      'Channels a hymn, healing all allies and reducing enemy attack slightly (1 turn).',
      true,
    ),
    Ability(
      'Hallowed Refrain',
      'If 3+ allies are healed, grant them +10% resist for 2 turns.',
      true,
    ),
    Ability(
      'Choir Guard',
      'Seraph takes 12% less damage while channeling.',
      false,
    ),
    Ability(
      'Mercy’s Wing',
      'Once per fight, prevent a fatal blow on an ally and heal them slightly.',
      false,
    ),
  ],
};

/// =======================
/// S (1 Active + 2 Passive)
/// =======================
Map<String, List<Ability>> _S = {
  // ---------------- ELEMENTAL (S) ----------------
  'Elemental Cinder': [
    Ability(
      'Cinder Flash',
      'Hurls a burst of embers that ignites the target for 2 turns.',
      true,
    ),
    Ability(
      'Smolder Trail',
      'Burning enemies take +8% damage from all sources.',
      false,
    ),
    Ability(
      'Ashen Wake',
      'On kill, spread burn to the nearest enemy with reduced duration.',
      false,
    ),
  ],
  'Elemental Torrent': [
    Ability(
      'Riptide',
      'Creates a rapid water arc that damages and slows the target.',
      true,
    ),
    Ability('Undercurrent', 'Slowed enemies have -10% dodge.', false),
    Ability('Surgecaller', 'Every 3rd cast refunds 15 Energy.', false),
  ],
  'Elemental Pyra': [
    Ability(
      'Pyrebrand',
      'Marks and scorches the target, dealing steady damage over time.',
      true,
    ),
    Ability(
      'Kindling',
      'Critical hits extend burn by 1 turn (once per target per turn).',
      false,
    ),
    Ability('Warmth', 'Allies adjacent to Pyra gain +5% resist.', false),
  ],
  'Elemental Ignis': [
    Ability(
      'Ignition Ray',
      'A focused flame ray that pierces light cover.',
      true,
    ),
    Ability(
      'Fuel the Fire',
      'Gains +5% attack when hitting a burning target (2 turns).',
      false,
    ),
    Ability('Heated Core', 'While above 60 Energy, crit chance +8%.', false),
  ],
  'Elemental Frostveil': [
    Ability(
      'Crystal Dart',
      'Fires a shard that slightly slows the target.',
      true,
    ),
    Ability(
      'Veil of Cold',
      'Incoming crit chance against Frostveil is reduced by 10%.',
      false,
    ),
    Ability('Snowblind', 'First attack each battle has +20% accuracy.', false),
  ],
  'Elemental Seirra': [
    Ability(
      'Mistral Cut',
      'A quick wind slash that can chain to a second nearby enemy.',
      true,
    ),
    Ability('Updraft', 'On chain hit, gain +8% speed (1 turn).', false),
    Ability('Featherstep', 'Dodge +8%.', false),
  ],

  // ---------------- DARK (S) ----------------
  'Dark Noctis': [
    Ability(
      'Night Slash',
      'Strikes from concealment; bonus damage vs. targets above 70% HP.',
      true,
    ),
    Ability('Moon Veil', 'Dodge +8% while stealthed or concealed.', false),
    Ability('Quietus', 'On crit, drain 5 Energy.', false),
  ],
  'Dark Morrow': [
    Ability(
      'Tide of Sorrow',
      'Sends a wave of despair, lowering enemy attack briefly.',
      true,
    ),
    Ability(
      'Languor',
      'Enemies with reduced attack also have -5% speed.',
      false,
    ),
    Ability(
      'Afterglow',
      'When an enemy is defeated, gain +10% attack (1 turn).',
      false,
    ),
  ],
  'Dark Malice': [
    Ability(
      'Sinister Bolt',
      'Deals dark damage and weakens the target\'s defense slightly.',
      true,
    ),
    Ability('Cruel Edge', '+10% crit damage.', false),
    Ability('Grudge', 'Deals +8% damage to enemies with a debuff.', false),
  ],
  'Dark Cinderveil': [
    Ability(
      'Veilburn',
      'A smoky lash that burns and obscures the target (reduced accuracy).',
      true,
    ),
    Ability('Smog Cover', 'Ranged damage received -8%.', false),
    Ability('Sootmark', 'Targets under burn deal -5% damage.', false),
  ],
  'Dark Morgrim': [
    Ability('Ossuary Spike', 'Hurls bone shards that bleed the target.', true),
    Ability(
      'Grave Pact',
      'Heals for a small amount when defeating an enemy.',
      false,
    ),
    Ability('Dreadbone', 'Bleeding enemies take +6% damage.', false),
  ],
  'Dark Tenebris': [
    Ability(
      'Creeping Shadow',
      'A creeping strike that slows the target.',
      true,
    ),
    Ability('Black Shroud', 'Resist +10%.', false),
    Ability(
      'Shadowstep',
      'When Tenebris dodges, gain +8% speed for 1 turn.',
      false,
    ),
  ],

  // ---------------- NATURE (S) ----------------
  'Nature Wild': [
    Ability('Feralswipe', 'A savage swipe that applies minor bleed.', true),
    Ability(
      'Blood Scent',
      'Bleeding enemies are 5% more likely to be crit.',
      false,
    ),
    Ability('Untamed', '+8% speed on the first two turns.', false),
  ],
  'Nature Antler': [
    Ability('Gore Rush', 'Dashes forward and strikes the nearest enemy.', true),
    Ability(
      'Stagheart',
      'When below 40% HP, gain a small shield (once per fight).',
      false,
    ),
    Ability('Forest Pace', 'While shielded, +8% speed.', false),
  ],
  'Nature Sylva': [
    Ability(
      'Sylvan Bolt',
      'A nature bolt that reduces enemy speed slightly.',
      true,
    ),
    Ability('Green Whisper', 'Allies healed this turn gain +5% resist.', false),
    Ability('Bower', 'Takes -8% damage from ranged attacks.', false),
  ],
  'Nature Oakheart': [
    Ability(
      'Barkbash',
      'A sturdy bash that can briefly stagger the target.',
      true,
    ),
    Ability('Old Growth', 'Max HP +10%.', false),
    Ability(
      'Oak’s Guard',
      'After using Barkbash, gain 6% defense for 1 turn.',
      false,
    ),
  ],
  'Nature Bramblescar': [
    Ability('Bramblespike', 'Launches thorns that apply short bleed.', true),
    Ability(
      'Bria’s Bite',
      'When an enemy bleeds out, restore 10 Energy.',
      false,
    ),
    Ability('Tanglehide', 'Melee damage received -8%.', false),
  ],
  'Nature Leafshade': [
    Ability(
      'Leafdart',
      'A precise dart that reduces target accuracy briefly.',
      true,
    ),
    Ability('Shade Dance', '+8% dodge for 1 turn after using Leafdart.', false),
    Ability('Green Veil', 'When dodging, gain a tiny HoT.', false),
  ],

  // ---------------- MECH (S) ----------------
  'Mech Drive': [
    Ability(
      'Overdrive Jab',
      'A quick servo strike with a chance to hit twice.',
      true,
    ),
    Ability('Clutch', 'On double-hit, gain 10 Energy.', false),
    Ability('Cooling Fins', 'Energy above 60 grants -8% damage taken.', false),
  ],
  'Mech Vector': [
    Ability(
      'Vector Pierce',
      'Fires a focused shot that ignores 10% armor.',
      true,
    ),
    Ability('Telemetry', 'After hitting, next attack has +8% accuracy.', false),
    Ability('Servo Sync', 'Every 3rd hit grants 5% speed for 1 turn.', false),
  ],
  'Mech Mechron': [
    Ability('Servo Slam', 'A heavy slam that can stagger the target.', true),
    Ability(
      'Auto-Repair',
      'Heals for a small amount over 2 turns after using Servo Slam.',
      false,
    ),
    Ability('Plated Joints', 'Melee damage received -8%.', false),
  ],
  'Mech Synthra': [
    Ability('Synth Shard', 'Launches a synth shard that bounces once.', true),
    Ability(
      'Recalibrate',
      'On bounce, gain +8% crit chance for 1 turn.',
      false,
    ),
    Ability('Soft Shield', 'At battle start, gain a tiny shield.', false),
  ],
  'Mech Axion': [
    Ability(
      'Axial Shot',
      'A precise energy shot that reduces enemy Energy slightly.',
      true,
    ),
    Ability('Focus Node', 'While above 50 Energy, +8% crit chance.', false),
    Ability('Pulse Plate', 'Ranged damage received -8%.', false),
  ],
  'Mech Voltforge': [
    Ability(
      'Volt Hammer',
      'Strikes with an electrified hammer that can shock.',
      true,
    ),
    Ability('Induction', 'Shocked enemies deal -5% damage.', false),
    Ability('Hardface', 'Defense +8%.', false),
  ],

  // ---------------- VOID (S) ----------------
  'Void Oblivion': [
    Ability(
      'Obliviate',
      'A void blast that reduces the target’s Energy.',
      true,
    ),
    Ability('Blank Field', 'Enemies below 30 Energy take +8% damage.', false),
    Ability('Void Skin', 'Resist +10%.', false),
  ],
  'Void Nyx': [
    Ability(
      'Nyx Dagger',
      'Backstab that deals bonus damage from stealth or invisibility.',
      true,
    ),
    Ability('Night Drift', '+8% dodge on the turn Nyx enters stealth.', false),
    Ability('Silent Step', 'After dodging, gain 10 Energy.', false),
  ],
  'Void Eclipse': [
    Ability('Half-Light', 'A strike that slightly blinds the target.', true),
    Ability('Umbral Edge', 'Blinded enemies have -8% speed.', false),
    Ability(
      'Dimming',
      'While no enemies can see Eclipse (stealth/invis), take -10% damage.',
      false,
    ),
  ],
  'Void Anomaly': [
    Ability(
      'Warp Bolt',
      'A warped projectile that distorts enemy position slightly.',
      true,
    ),
    Ability('Offset', 'Displaced enemies take +6% damage next hit.', false),
    Ability('Stable Tear', '+10% resist against pushes/pulls.', false),
  ],
  'Void Fractis': [
    Ability(
      'Fractured Lance',
      'A jagged beam that can split to a second target.',
      true,
    ),
    Ability('Crack Propagate', 'On split, both targets lose 5 Energy.', false),
    Ability('Sharp Silence', 'Enemies at 0 Energy take +8% damage.', false),
  ],
  'Void Eventide': [
    Ability(
      'Twilight Lash',
      'A lash of dusk-light that slows the target.',
      true,
    ),
    Ability('Evenfall', 'Slowed enemies have -8% accuracy.', false),
    Ability('Quiet Realm', 'Energy above 60 grants -8% damage taken.', false),
  ],

  // ---------------- LIGHT (S) ----------------
  'Light Beacon': [
    Ability(
      'Beacon Shot',
      'A bright shot that marks the target briefly.',
      true,
    ),
    Ability('Guidance', 'Marked enemies take +6% damage from allies.', false),
    Ability('Lampguard', '+8% speed on the first turn.', false),
  ],
  'Light Lumina': [
    Ability(
      'Lumen Ray',
      'A thin beam of light that slightly reduces enemy crit chance.',
      true,
    ),
    Ability(
      'Glint',
      'After casting, the next basic is guaranteed to hit.',
      false,
    ),
    Ability('Softshine', 'Heal received +8%.', false),
  ],
  'Light Solaria': [
    Ability('Solar Kiss', 'A radiant strike that applies a short burn.', true),
    Ability('Warm Oath', 'Burned enemies deal -5% damage.', false),
    Ability('Helio Step', '+8% speed while Solaria is above 60 Energy.', false),
  ],
  'Light Althea': [
    Ability(
      'Aegis Beam',
      'Heals a single ally and grants a thin shield.',
      true,
    ),
    Ability('Safekeep', 'Shielded allies take -6% damage.', false),
    Ability(
      'Tranquil',
      'At start of turn, the lowest-HP ally gains a tiny HoT.',
      false,
    ),
  ],
  'Light Divina': [
    Ability(
      'Divine Mark',
      'Marks an enemy; your allies have +5% accuracy against them.',
      true,
    ),
    Ability(
      'Pledge of Light',
      'Allies who hit a marked target gain +5% speed (1 turn).',
      false,
    ),
    Ability('Faithward', 'Resist +10%.', false),
  ],
  'Light Auriel': [
    Ability(
      'Auric Arrow',
      'An arrow of light that pierces lightly and cannot be dodged.',
      true,
    ),
    Ability('Dawnedge', 'On hit, reduce target speed by 5% for 1 turn.', false),
    Ability('Grace Step', '+8% dodge while above 50% HP.', false),
  ],
};

/// ---- lowercase key sets for fast case-insensitive checks
final Set<String> _SPLUSkeysLC = _SPLUS.keys
    .map((e) => e.toLowerCase())
    .toSet();
final Set<String> _SkeysLC = _S.keys.map((e) => e.toLowerCase()).toSet();
