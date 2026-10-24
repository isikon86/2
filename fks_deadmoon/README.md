# TEOT Deadmoon v1.6.9 — красный туман раз в 7 игровых дней и 8 новых вариантов звуков

## Единый ресурс

Эта папка является **одним ресурсом**. Установка требует только:

```cfg
ensure vorp_core        # или rsg-core
ensure vorp_inventory   # или rsg-inventory / ox_inventory
ensure fks_deadmoon
```

Внутри уже находятся зомби, призрачные боссы, поезд и корабельные данжи.
`LRRP_GhostHunting` и `ricx_ghostship` отдельно запускать не нужно.

- `client/ghosts.lua` — боссы-призраки во время события 7-го игрового дня;
- `client/ghost_train.lua` — поезд с 00:00 до 03:00 каждой ночи;
- `client/ghost_ship.lua` — объекты кораблей;
- `server/ghosts.lua` — серверная проверка победы над боссом;
- `Config.CitySpawns.zones` — точки спавна зомби-данжей.

Исходные escrow-файлы двух сторонних ресурсов нельзя физически объединить с
другим `fxmanifest`, поэтому в едином ресурсе реализована самостоятельная
логика нужного сценария. Зомби и звуки взяты из вашего `fks_deadmoon`.

## Что изменено в 1.6.9
- Красный туман теперь запускается **один раз за каждые 7 игровых дней**: начало в 22:00 игрового дня №7, 14, 21 и т. д.; завершение — в 06:00 следующего игрового утра.
- Счётчик игровых дней сохраняется через KVP и не сбрасывается после рестарта ресурса или сервера. День начинает отсчитываться после первого распознанного игрового времени; далее считаются переходы через полночь.
- Обычная активность зомби не меняется: по текущей настройке они остаются активны круглосуточно; по расписанию запускается именно погодное событие с красным туманом.
- Добавлено 8 новых обработанных вариантов стона/рыка на основе уже включённых CC0-записей. Исходные 24 WAV сохранены без изменений; всего в случайном пуле теперь 32 звука.
- `/deadmoon status` дополнительно показывает накопленные игровые дни и сколько дней осталось до ближайшего события. Значение `0` означает, что сегодня день события.

**Проверка:** файлы и логика прошли статическую проверку; фактический вид красного тумана и синхронизацию игрового времени необходимо проверить на тестовом сервере RedM/VORP.

---

# TEOT Deadmoon v1.6.8 — без медицинских эффектов

В этой версии зомби-мод больше не реализует медицинскую механику:
- нет периодического снятия здоровья от нахождения зомби рядом / укуса;
- нет кровотечения, истощения ядра здоровья и экранного эффекта плохого самочувствия;
- нет лечения через `bandage` или `Rags` внутри `fks_deadmoon`;
- у прыгуна сохранён нокдаун, но удалены скриптовый урон и кровотечение;
- убран дополнительный урон по тиру.

Обычный нативный ближний урон RedM от атак зомби остаётся включённым. Предметы `bandage` и medicine могут выпадать как обычный лут, но этот ресурс не назначает им лечебное поведение. Медицинские эффекты планируются отдельным ресурсом TEOT.

**Установка:** остановите сервер, сохраните копию старой папки `fks_deadmoon`, замените её новой, затем выполните `refresh` и `ensure fks_deadmoon` (если папка называется `fks-deadmoon`, используйте это имя). SQL-миграция не нужна. Сборка прошла статическую проверку; обязательно проверьте игровые действия на тестовом сервере.

---

# TEOT Deadmoon v1.6.7 — редкий dead-man спавн

- Добавлена базовая игровая модель `U_M_M_APFDeadMan_01` как редкий особый заражённый.
- Шанс выбора: 4% в Тире III и 7% в Тире IV. Это шанс выбора модели при спавне зомби, не гарантия наличия доспехов.
- Используется базовый outfit preset `0`.
- Визуальный вид нужно проверить на сервере: каталоги подтверждают наличие модели, но не позволяют гарантировать, что она отображается как рыцарь в конкретной сборке.
- Обычные модельные пулы, тиры и настройки лута сохранены.


# TEOT Deadmoon v1.6.6 — больше разнообразия зомби

## Валентайн
Валентайн остаётся Тиром IV — максимальная сложность из четырёх уровней.

## Визуальное разнообразие
- Добавлены существующие игровые модели: мужские и женские cholera corpse, мужские и женские generic corpse, swamp mutant и обгоревшие/изуродованные corpse-варианты.
- Для четырёх corpse-моделей подключены curated outfit presets: один и тот же базовый пед может появляться с разными совместимыми вариантами внешности.
- Тир I: 4 базовых corpse-модели.
- Тир II: 5 моделей, включая мутанта.
- Тиры III и IV: 8 моделей, включая обгоревшие corpse-варианты и мутанта.
- Не добавлены обратно вампир, Chelonian/черепаший костюм, ребёнок и `re_deadbodies_males_01`.

Используются штатные игровые модели и outfit presets, а не сгенерированные изображения или выдуманные имена моделей.


# TEOT — географические тиры зомби v1.6.5

## Политика территорий
- **Тир I:** снежная область около Колтера и озера Изабелла. Колтер остаётся безопасной зоной без зомби.
- **Тир II:** региональный коридор между Строберри и Блэк-Вотером; сам город Строберри — Тир III.
- **Тир III:** все остальные открытые территории по умолчанию, включая открытые районы Амбарино, Нью-Ганновера и Лемойна; Тумблвид — Тир III.
- **Тир IV:** крупные города (Валентайн, Сент-Дени, Блэк-Вотер, Родс, Ван-Хорн, Аннесберг) и Армадилло.
- **Армадилло:** единственная зона без лута. Зомби остаются опасными Тира IV, но контейнеры и трупы заражённых не выдают предметы.

## Важно
Амбарино, Нью-Ганновер и Лемойна больше не являются запрещёнными зонами. В них работают обычные тиры и добыча. Только Armadillo исключён из добычи.


# FKS Dead Moon

## Paranormal merge integration

This bundled build also contains `client/ghosts.lua`, `client/ghost_train.lua` and
`server/ghosts.lua`. Ghost bosses run only while `GlobalState.fksDeadmoonWeather`
is active (the seventh-game-day red-fog event), the native ghost train runs from
00:00 to 03:00 every night, and the two `ricx_ghostship` coordinates are registered
as compact city-style dungeon zones in `Config.CitySpawns.zones`.

A Halloween zombie night for **RedM**. On every seventh tracked in-game day, between **22:00 and 06:00** (in-game time), the red fog event rolls in
and the dead rise around the players: shamblers and runners that only die to a **headshot**, random **hordes**, bodies to **search** for loot and **safe zones** where nothing spawns. This TEOT build has no scripted bleeding or medical effects.

Works with **VORP** and **RSG**, with **vorp_inventory**, **rsg-inventory** or **ox_inventory**.
No hard dependencies besides the framework: `ox_lib` is used for notifications / progress bar when it is running.

> License: **GPL-3.0-or-later** — see [LICENSE](LICENSE).
>
> **TEOT build: 1.6.8 — medical logic removed.** This patch was checked statically; it still needs in-game testing on the target RedM artifact. Multiplayer-specific ownership and city waves should be tested on the server before release.

---

## Table of contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Items](#items)
- [Configuration](#configuration)
- [Commands](#commands)
- [How it works](#how-it-works)
- [Languages](#languages)
- [Folder structure](#folder-structure)
- [Known limitations](#known-limitations)
- [Troubleshooting](#troubleshooting)
- [Credits](#credits)
- [License](#license)

---

## Features

- **Scheduled event** — starts and ends with the in-game clock (read from weathersync) or the server's real time.
  Fully configurable window, may cross midnight. Admins can force it on / off.
- **Dead Moon weather** — fog with the `MP_Pred` weather variations, re-applied while the event lasts and cleanly
  restored at the end.
- **Zombies around every player** — `re_deadbodies_males_01` and `u_m_m_apfdeadman_01` by default. A share of them run,
  the others shamble with an injured / drunk walk. They chase the closest player and attack in melee.
- **Headshots only** — any other death knocks the zombie down and it gets back up a few seconds later.
- **TEOT city waves** — the town trigger activates 300m before the city edge. The initial city population is fixed and never individually replenished; ordinary player-relative spawns and rural encounters are suppressed inside the trigger. After the city is cleared, wait 15 minutes, then face two fixed horde waves, with 45 seconds between them. The second wave is harder (up to 45 zombies, 65% runners and 350m aggro range, bounded by the city cap).
- **No scripted medical effects** — the zombie resource does not add bite-tick damage, bleeding, health-core drain, screen effects, bandage treatment, jumper damage, or tier-based bonus damage. Native RedM melee damage from ordinary zombie attacks remains active. Jumper attacks can still knock the player down; a separate TEOT medical resource can add injuries later.
- **Density levels** — `low`, `medium`, `high`, `extreme` (or your own), switchable in game.
- **TEOT city cycles** — each city spawns one fixed population wave, killed zombies are not replaced, and a fully cleared city gets a new horde after 15 minutes. Rural spawns and ambushes stay outside the city approach trigger.
- **Hordes** — a small chance of 20 zombies at once around a player, with a cooldown.
- **Search the bodies** — zombies killed with a headshot show a native **Search** prompt with random, configurable loot
  (validated on the server).
- **3D synced groans** — 32 zombie sound variants (24 original CC0 recordings plus 8 processed variants) included: the server sends the same groan at the same moment to every player near a
  zombie, and each client plays it with distance volume and left / right panning that follows the zombie.
- **Safe zones** — coordinates + radius where no zombie spawns (and zombies that walk in disappear).

---

## Requirements

| Resource | Notes |
|---|---|
| [vorp_core](https://github.com/VORPCORE/vorp-core-lua) **or** [rsg-core](https://github.com/Rexshack-RedM/rsg-core) | framework |
| vorp_inventory, rsg-inventory **or** [ox_inventory](https://github.com/overextended/ox_inventory) | items |
| A weathersync (e.g. [weathersync](https://github.com/kibook/weathersync)) | optional — used to read the in-game time |
| [ox_lib](https://github.com/overextended/ox_lib) | optional — notifications and progress bar |
| vorp_progressbar | optional — progress bar on VORP without ox_lib |

OneSync must be enabled (default on RedM servers).

---

## Installation

1. **Download** the latest release and put the `fks-deadmoon` folder in your `resources` folder.
2. **Add it to your server config** after the framework and inventory:
   ```cfg
   ensure vorp_core        # or rsg-core
   ensure vorp_inventory   # or rsg-inventory / ox_inventory
   ensure fks_deadmoon
   ```
3. **Create the items** in your inventory — see [Items](#items).
4. **Configure** `config.lua` — at least `Config.Locale`, the schedule (`Config.Time`) and your safe zones
   (`Config.SafeZones`, the included ones are examples).
5. **Start the server.** The console prints what was detected:
   ```
   [fks-deadmoon] framework: vorp | inventory: vorp_inventory
   ```
6. Test it: `/deadmoon on`, then `/deadmoon horde` and `/deadmoon sound`.

> If you had another "blood moon" weather script, remove it — this one already sets the same weather and cleans the
> weather variations at the end.
>
> When you change `fxmanifest.lua` or add files, run `refresh` before `ensure fks_deadmoon`
> (a plain `restart` does not read the manifest again).

---

## Items

This resource does not register or consume medical items and does not implement treatment. The `Config.Loot.items` table still controls ordinary corpse drops; entries such as `bandage`, `consumable_medicine`, and `herbal_medicine` are only loot items here. Their medical effects, if any, must be implemented by your inventory or a future separate TEOT medical resource.

No SQL migration is required for this no-medical patch. Keep only loot item names that exist in your own inventory database.

---

## Configuration

Everything is in [`config.lua`](config.lua) and commented. The main blocks:

| Block | What it controls |
|---|---|
| `Config.Time` | schedule (`start` / `finish`), time source (`game` / `real`), weathersync resources |
| `Config.Weather` | weather type, variations, re-apply interval, weather restored at the end; `Config.OnStart` / `Config.OnEnd` hooks |
| `Config.Zombies` | models, health, runners %, walking styles, aggro / attack range, revive time, head bones |
| `Config.Sounds` | sound files, volume, hearing distance, pitch variation, groan intervals |
| `Config.Spawn` | spawn distance around the player, interiors |
| `Config.Density` | density levels and the default one (each level has its own horde chance) |
| `Config.Horde` | horde size, roll interval, cooldown, distance, spread |
| `Config.Tiers` | geographic difficulty, zombie stats and jumper knockdown duration; no scripted player damage or medical effects |
| `Config.Loot` | search prompt key, time, corpse lifetime, loot table |
| `Config.SafeZones` | safe zones (coordinates + radius) |

### Custom sounds
Put `.wav`, `.mp3` or `.ogg` files in the `sounds/` folder (no spaces or `#` in the name) and list them in
`Config.Sounds.files` — remove the included ones you don't like. The server picks one at random for each groan — the
same one for every player. The original 24 CC0 recordings are preserved; the additional 8 variants are documented in `sounds/TEOT_SOUND_VARIANTS.txt`. Run `refresh` after adding files.

---

## Commands

All commands are admin only (VORP group / RSG permission in `Config.AdminGroups`, or the ACE `command.deadmoon`).

| Command | Description |
|---|---|
| `/deadmoon status` | event state, mode, current time and density |
| `/deadmoon on` / `off` | force the event on / off (ignores the schedule until `auto`) |
| `/deadmoon auto` | follow the schedule again |
| `/deadmoon ghost on` / `off` / `auto` | test or release the seventh-day ghost event; `auto` returns to the schedule |
| `/deadmoon density <level>` | change the density level in game |
| `/deadmoon horde [id]` | send a horde to you or to a player (the event must be active) |
| `/deadmoon sound` | play a groan for you and report whether the sound works |

Portuguese aliases: `densidade`, `horda`, `som`.

---

## How it works

- **State** — the server decides when the event is active and shares it with `GlobalState.fksDeadmoon`.
- **Time** — in `game` mode the server reads `getTime()` from your weathersync. Without one, every player reports
  their synced clock and the time most players agree on is used (a single modified client can't toggle the event).
- **Zombies** are networked peds spawned by each player's client around themselves, capped by the density level
  (counting every player's zombies in the area). The client that **owns** a zombie runs its AI; when ownership moves,
  the new owner takes over.
- **Headshots** — the owner checks the last damaged bone; a player that kills a zombie it doesn't own reports the
  headshot to the server, which validates it.
- **Loot** — the server checks distance, that the body is really down and not searched yet, then rolls the loot.
- **Groans** — the zombie's owner asks the server; the server validates the owner, picks the file and pitch and sends
  it to every player in range. Each client plays it through a hidden NUI page (Web Audio) with 3D volume / panning.

---

## Languages

English (`en`), Português (`pt`) and Russian (`ru`). Set `Config.Locale`; missing keys fall back to English.
To add a language, copy `locales/en.lua`, translate it and set `Config.Locale` to its key.

---

## Folder structure

```
fks-deadmoon/
├── fxmanifest.lua
├── config.lua
├── client/      bridge, main (state + progress bar), weather, zombies, tier combat (knockdown only), loot, sounds
├── server/      bridge (framework / inventory), main (schedule, hordes, loot, groans, commands)
├── shared/      locale, utils
├── locales/     en, pt
├── html/        hidden NUI page that plays the sounds
└── sounds/      zombie sounds (CC0, see Credits)
```

---

## Known limitations

- **`sv_stateBagStrictMode`** — zombie state is marked with state bags set by clients. If you enable `setr sv_stateBagStrictMode true`, those may be rejected and the script may not work properly.
- **City populations (TEOT 1.5.4)** — city trigger starts at 300m before the town edge. One elected client creates one fixed initial population. No rural/player-relative spawning occurs while inside a city's 300m approach trigger. After all city zombies are permanently killed, a 15-minute cooldown begins, then one fixed horde arrives; once it is cleared, a second harder wave arrives after 45 seconds. Clearing the second wave starts another 15-minute cooldown.
- **Multiplayer** — see the status note at the top: tested with one player so far.
- **Native "search" on corpses** — the game's own loot prompt may also show on zombie bodies; it gives no framework
  items, only the script's **Search** prompt does.

---

## Troubleshooting

- **Nothing happens** — check the console line `[fks-deadmoon] framework: ... | inventory: ...`. If one is `nil`,
  set `Config.Framework` / `Config.Inventory`. Then use `/deadmoon status`.
- **The fog stays during the day** — check `/deadmoon status`: `mode: on` means it was forced; use `/deadmoon auto`.
- **No sound** — run `/deadmoon sound`. No notification at all means the client part is not loaded: run `refresh` and
  restart the resource (or the server). The server console prints every step of the test.
- **Zombies spawn in weird places / in towns** — the safe zones in the config are examples; set your own.
- **Debug** — set `Config.Debug = true` to log spawns, deaths and groans in the F8 and server consoles.

---

## Credits

- Built for the RedM community. Thanks to the VORP, RSG and Overextended teams, and to
  [femga/rdr3_discoveries](https://github.com/femga/rdr3_discoveries) for the weather variation research.
- Zombie sounds: [Zombies Sound Pack](https://opengameart.org/content/zombies-sound-pack) by **artisticdude**
  (made for [Summoning Wars](https://sumwars.org)) — **CC0 / public domain**. Converted to mono 16-bit and normalised.

---

## License

Copyright (C) 2026 FKS

This program is free software: you can redistribute it and/or modify it under the terms of the
**GNU General Public License** as published by the Free Software Foundation, either **version 3** of the License, or
(at your option) any later version. It is distributed in the hope that it will be useful, but **WITHOUT ANY WARRANTY**.
See [LICENSE](LICENSE) for the full text.


## TEOT 1.5.4 — разделение городского и дикого спавна

- Городской координатор работает отдельным потоком и только запрашивает фиксированную популяцию города, когда игрок входит в радиус города + `Config.CitySpawns.triggerDistance`.
- Обычный спавн в лесах/горах/на дорогах вынесен в независимый поток. Он работает со своим интервалом и лимитами `Config.Density`, когда игрок находится за пределами всех городских триггеров.
- Состояние городских волн и 15-минутный таймер не могут блокировать дикий спавн.
- За пределами триггеров остаются радиус спавна до 250 м, обычные лимиты и отдельные встречи каждые 10 минут с шансом орды 40%.
- Колтер по-прежнему защищён `Config.SafeZones`.

Для диагностики временно установите `Config.Debug = true`: в консоли будут сообщения о паузе внутри городского триггера и успешных спавнах в дикой местности.


## TEOT 1.5.4 — городской триггер 300 метров

- Радиус активации городского населения уменьшен с 800 до 300 метров от границы зоны города.
- Дикий спавн и сельские встречи исключаются только внутри нового 300-метрового подходного триггера.
- Безопасная зона Колтера и лимиты городских волн сохранены.


## TEOT Zombie Tiers 1.6.1
- Tier selection is geographic (not distance-from-Colter): Tier I is the snowy Grizzlies around Colter/Lake Isabella; Tier II covers the Strawberry/Big Valley/Tall Trees/Great Plains corridor toward Blackwater; Tier III is the rest of the map and frontier towns; Tier IV is used inside major city footprints. Strawberry remains Tier III. Current player tier is replicated as `fksPlayerTier` and recalculated every 2 seconds. Zombie spawn scheduling and city wave mechanics are unchanged.
- Tier I: slow walkers, low health, common loot.
- Tier II: 40% runner chance, medium health, occasional jumper, more crafting materials in loot.
- Tier III: slow heavy zombies with high health and added damage, rare valuable loot. Rare jumpers can appear as a special variant.
- Historical behavior in earlier versions: rare jumpers could deal extra damage and cause bleeding. Since TEOT 1.6.8, scripted damage and bleeding are removed; the knockdown remains.
- Existing approved model names are reused. The optional `SetPedScale` call attempts to scale Tier III models up if available in the current RedM build.
- No medical, fracture, or splint system is added by this patch.
- Historical behavior in earlier versions: tier bonus damage used `CEventNetworkEntityDamage`. Since TEOT 1.6.8, that scripted bonus damage is removed.


## TEOT restricted regions (v1.4)

- Ambarino, New Hanover and Lemoyne are currently treated as Tier IV regions.
- Zombie corpse loot is disabled inside those regions; trying to search a corpse there consumes the search and shows a notice. This does not delete existing inventory items or alter unrelated world-item resources.
- Colter remains protected by the existing SafeZones configuration. The restricted-region polygons are approximate and should be verified in-game before opening the server.
- The region polygons can be edited in `config.lua` under `Config.Tiers.regions.tier4Restricted`.
