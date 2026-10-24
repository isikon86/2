## TEOT 1.6.9 — red fog every 7 in-game days + expanded zombie audio
- Replaced nightly fog with a red-fog event that runs from 22:00 to 06:00 once per 7 tracked in-game day transitions.
- Persisted the game-day counter and last observed game-clock minute in resource KVP to avoid resets after restart.
- Kept regular zombie activity unchanged (24/7 under the existing configuration); only the fog event follows the seven-day cadence.
- Added 8 processed zombie audio variants derived from the included CC0 source recordings; all original 24 files remain unchanged.
- Extended `/deadmoon status` with elapsed in-game days and the number of days until the next fog event.
- Static checks only; live RedM/VORP weather and multiplayer timing still require in-game testing.

## TEOT 1.6.8 — remove scripted medical effects
- Removed the bite proximity loop that applied scripted periodic player health loss.
- Removed bleeding state, screen effect, health-core drain and bandage/Rags treatment registration.
- Removed scripted jumper impact damage and bleeding chance; the jumper still knocks players down.
- Removed tier-based bonus damage applied by the zombie script.
- Preserved normal RedM native melee damage, zombie AI, tiers, spawning, loot, city waves and sounds.
- Medical and injury effects are intentionally left for a future separate TEOT medical resource.

## TEOT 1.6.5 — Open counties, Armadillo no-loot
- Opened Ambarino, New Hanover and Lemoyne for tier-based zombie and loot progression.
- Made Armadillo Tier IV and the only no-loot exclusion area.
- Kept Colter as a zombie-free safe zone.
- Large cities remain Tier IV; Strawberry and Tumbleweed remain Tier III.
- Kept the previously excluded brown-coat corpse model removed.

## TEOT 1.5.1 — Removed normal-looking brown-coat corpse
- Removed `re_deadbodies_males_01` from the global zombie pool and every geographic tier pool.
- Other zombie models, tier rules, city spawn logic and loot tables are unchanged.

## TEOT restricted regions update
- Ambarino, New Hanover and Lemoyne now override lower tiers as Tier IV.
- Disabled zombie corpse loot inside these regions.
- Kept existing spawn triggers and population scheduling unchanged.

## TEOT geographic zombie tiers
- Replaced distance-from-Colter tier selection with geographic regions.
- Tier I: snowy Grizzlies around Colter/Lake Isabella.
- Tier II: Strawberry / Big Valley / Tall Trees / Great Plains corridor toward Blackwater.
- Tier III: the rest of the map and frontier towns; Strawberry city is explicitly Tier III.
- Tier IV: major city centers (Valentine, Saint Denis, Blackwater, Rhodes, Van Horn, Annesburg).
- Added replicated per-player tier state (`fksPlayerTier`).
- Kept zombie spawn scheduling, spawn triggers, city population caps and wave mechanics unchanged.

## TEOT 1.6.1 — Tier scope cleanup
- Kept this patch limited to zombie tiers, tier combat, and corpse loot.
- Removed the temporary fracture mechanic and its movement restrictions; no medical or splint changes are included.
- Tier I now contains slow walkers only; rare jumpers are reserved for Tiers II and III.
- Kept the existing `teot_looting` container resource unchanged and outside this replacement archive.

## TEOT 1.6.0 — Zombie Tiers
- Added distance-based Tier I / II / III progression from Colter.
- Added tier-specific health, movement, aggro, model pools, runner chance and tier-based loot.
- Added rare jumper attacks with server validation, knockdown, damage, bleeding chance and extra damage and knockdown.
- Added tier damage bonus on confirmed zombie damage events.
- Kept the existing city population, rural spawn logic, Colter safe zone, and container-looting resource.

## TEOT Looting integration

- Expanded zombie corpse loot with existing item names from TEOT_items.sql.
- Replaced the example `bread` and `consumable_water` entries with items present in the supplied TEOT database.
- Added `teot_perks` integration: `searchTime` adjusts corpse search duration and `bonusLoot` can grant one extra roll.

## TEOT — строгий пул трупов и нежити

По скриншотам убраны модели, которые могут выглядеть как обычные живые NPC, включая `u_m_m_apfdeadman_01`, `U_M_M_APFDeadMan_01`, `A_M_M_UniCorpse_01` и `A_F_M_UniCorpse_01`, а также модели событий. В основном пуле оставлены только `re_deadbodies_males_01`, обе модели холерных трупов и `CS_SwampFreak`.

## TEOT — очистка пула зомби

Удалены модели событий и персонажи, которые могли выглядеть как обычные живые NPC: RE_SavageAftermath_Males_01, RE_SavageWarning_Males_01, RE_SavageAftermath_Females_01, RE_CorpseCart_Males_01, RE_LostFriend_Males_01, U_M_M_CircusWagon_01, CS_MrAdler, CS_ODProstitute, RE_Voice_Females_01 и A_M_Y_UniCorpse_01. Пул оставлен на моделях трупов, холерных трупов и болотной нежити.


## TEOT — удаление неподходящих NPC

Удалены из дополнительного пула `U_M_M_CircusWagon_01` и `CS_MrAdler`. В `Config.Zombies.models` отдельная модель ребёнка не обнаружена; детские модели в пул не добавлялись.


## TEOT — очистка пула моделей

По запросу TEOT убраны модели, которые могут выглядеть как обычные живые NPC: A_M_Y_UniCorpse_01, CS_ODProstitute, RE_CORPSECART_FEMALES_01, RE_DARKALLEYAMBUSH_MALES_01, RE_DARKALLEYBUM_MALES_01, RE_DARKALLEYSTABBING_MALES_01, RE_DEADJOHN_FEMALES_01, RE_DEADJOHN_MALES_01, RE_DROWNMURDER_FEMALES_01, RE_DROWNMURDER_MALES_01, RE_EXECUTIONS_MALES_01, RE_FROZENTODEATH_FEMALES_01, RE_FROZENTODEATH_MALES_01, RE_Voice_Females_01. Также исключены `CS_Vampire` и `CS_ChelonianMaster`.


## TEOT — дополнительный пул трупов и погибших NPC

Добавлены дополнительные встроенные модели RDR2: RE_DEADJOHN_MALES_01, RE_DEADJOHN_FEMALES_01, RE_DARKALLEYAMBUSH_MALES_01, RE_DARKALLEYBUM_MALES_01, RE_DARKALLEYSTABBING_MALES_01, RE_DROWNMURDER_MALES_01, RE_DROWNMURDER_FEMALES_01, RE_FROZENTODEATH_MALES_01, RE_FROZENTODEATH_FEMALES_01, RE_EXECUTIONS_MALES_01, RE_CORPSECART_FEMALES_01, A_M_Y_UniCorpse_01. Удалены из дополнительного пула `CS_Vampire` и `CS_ChelonianMaster` по запросу TEOT.

## 1.5.3
- Reduced city approach trigger from 800m to 300m.
- Aligned client/server fallback distances and rural encounter exclusion buffer.

# Changelog

## TEOT 1.5.0 — 2026-10-22
- Kept one fixed initial population per city; individual zombie kills are never refilled.
- Suppressed player-relative spawns and rural encounters throughout the full 800m city approach trigger.
- After the initial city population is permanently cleared, starts a 15-minute cooldown.
- After cooldown, sends a first fixed horde into the city.
- After horde 1 is cleared, waits 45 seconds and sends a second, harder fixed wave.
- Second wave defaults to 45 zombies (limited by city cap), 65% runners and 350m aggro range.
- After horde 2 is cleared, starts the next 15-minute cooldown.
- Preserved legacy v1.4.0 city state (`horde_due`, `horde`) during upgrade.

## TEOT 1.4.0 — Fixed city waves and 15-minute horde cycle
- Cities spawn one fixed population wave; killed zombies are never individually replaced.
- The 15-minute countdown starts only when every zombie in the current wave is permanently dead.
- After the countdown, a horde is spawned inside the city and becomes its new population wave.
- City zombies no longer despawn just because the player leaves the immediate area, preventing false city-clear timers.
- Rural spawns and scheduled stalker/horde encounters are suppressed throughout the city approach trigger, so zombies do not spawn behind players near town.
- Kept TEOT admin-invisibility immunity, expanded undead models, curated outfits, and the Colter safe zone.

## TEOT 1.3.1
- Fixed zombie target selection so admins with TEOT invisibility are ignored, including active chases/attacks.
- Invisible admins are excluded from city/rural spawn ownership and new spawn triggers.
- Added six built-in undead-style ped models and curated outfit presets for additional appearance variety.
- No external texture files required; existing custom config values are preserved by the patch.

# Changelog

## TEOT 1.3.0 — Hybrid city/rural spawn
- City population trigger starts 800m before the town edge and prewarms zombies inside the town.
- Rural spawning remains active outside the actual city footprint, including city approach areas.
- Ground search probes multiple elevations to improve spawn reliability in mountains and valleys.
- Added one rural encounter every 10 minutes per nearby player cluster: 40% chance for a horde, otherwise one stalker behind the player.
- Automatic legacy horde rolls disabled to avoid duplicate random events; manual admin horde command remains available.
- Preserved Colter safe zone and 5% bite bleeding chance.

## 1.2.1 — TEOT city cooldown fix
- Cooldown now counts living zombies, not corpses waiting to revive.
- Added replicated corpse state and validated controller count reports.
- Added clearer cooldown log output.

## TEOT population overhaul 1.1.0
- Added server-elected city spawn controllers and server-wide city zombie counts.
- Separated city population caps from rural player-cluster spawning.
- Added city density multipliers and increased infected-town population targets.
- Improved city ground probing and reduced duplicate spawn streams in nearby player groups.

# Changelog

## 0.9.0 (beta)

First public release.

- Scheduled Dead Moon event (in-game clock via weathersync or server real time), admin force on / off.
- Fog weather with the `MP_Pred` variations, re-applied during the event and cleared at the end.
- Zombies around every player: runners and shamblers, chase and melee, headshot-only deaths, getting back up.
- Bites drain health and can cause bleeding until death; the `Rags` item stops it (animation + progress bar).
- Density levels and random hordes of 20 zombies (`/deadmoon horde` to test).
- Searchable bodies with a configurable loot table, validated on the server.
- 3D groans synced between players (24 CC0 sounds included, NUI / Web Audio), `/deadmoon sound` to test.
- Safe zones (coordinates + radius).
- Frameworks: VORP and RSG · Inventories: vorp_inventory, rsg-inventory, ox_inventory.
- Languages: English, Português (PT).

## v1.6.6 — Zombie visual variety
- Expanded tier model pools from 2–3 model types to 4–8 corpse/undead archetypes.
- Added curated outfit preset pools for existing corpse models.
- Kept Valentine as Tier IV.
- Kept removed vampire, Chelonian/turtle outfit, child and brown-coat model excluded.

## v1.6.7 — Rare dead-man spawn
- Added `U_M_M_APFDeadMan_01` as a rare special spawn: 4% Tier III, 7% Tier IV.
- Added default outfit preset 0.
- Kept regular model pools and loot/tier rules unchanged.
