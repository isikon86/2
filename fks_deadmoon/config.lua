Config = {}

---------------------------------------------------------------------------
-- General
---------------------------------------------------------------------------
Config.Framework = 'auto'   -- 'auto' | 'vorp' | 'rsg'
Config.Inventory = 'auto'   -- 'auto' | 'vorp_inventory' | 'rsg-inventory' | 'ox_inventory'
Config.Notify    = 'auto'   -- 'auto' (ox_lib if running, otherwise the framework's) | 'ox' | 'vorp' | 'rsg'
Config.Locale    = 'ru'     -- 'en' | 'pt' (files in locales/; missing keys fall back to English)
Config.Debug     = false    -- true: logs spawns, deaths and groans in the F8 / server console

-- Admin command:  /deadmoon on | off | auto | status | density <level> | horde [id] | sound
--   on      = force the event on (ignores the schedule)
--   off     = force the event off
--   auto    = follow the schedule again
--   density = change the density level (see Config.Density)
--   horde   = send a horde to you (or to the player with that id) - the event must be active
--   sound   = play a groan for you and report whether the sound works
-- (Portuguese aliases also work: densidade, horda, som)
Config.Command     = 'deadmoon'
Config.AdminGroups = { 'admin', 'superadmin', 'god' } -- VORP groups / RSG permissions (ACE "command.deadmoon" also works)

---------------------------------------------------------------------------
-- Event schedule
---------------------------------------------------------------------------
Config.Time = {
    alwaysOn = true, -- TEOT: zombie event stays active all in-game day and night
    source = 'game',    -- 'game' = in-game clock | 'real' = server real time (os.date); red fog always uses the game clock
    start  = '00:00',
    finish = '06:00',   -- may cross midnight, e.g. start '22:00' / finish '04:00'
    checkInterval = 5000,

    -- In 'game' mode the server reads the time from your weathersync (export getTime).
    -- If none is running, the players report their own (weathersync-synced) clock and the majority wins.
    weatherSyncResources = { 'weathersync', 'vorp_weathersync', 'rsg-weathersync' },
}

---------------------------------------------------------------------------
-- Weather (fog with the "MP_Pred" variations)
---------------------------------------------------------------------------
Config.Weather = {
    -- TEOT 1.6.9: red fog event only once per 7 tracked in-game day changes.
    -- The event begins at 22:00 on the 7th day and clears at 06:00 the following morning.
    -- The day counter is saved with resource KVP and survives resource/server restarts.
    redFogEvent = {
        enabled = true,
        everyGameDays = 7,
        start = '22:00',
        finish = '06:00',
    },
    type       = 'FOG',
    transition = 30.0,
    variations = {
        { 'MISTY',  'misty_MP_Pred' },
        { 'SHOWER', 'shower_MP_Pred' },
        { 'FOG',    'fog_MP_Pred' },
    },
    -- weathersync usually forces its own weather back: ours is re-applied every X ms (false = off)
    reapply = 10000,

    restore           = 'CLEAR', -- weather applied at the end (then your weathersync takes over again)
    restoreTransition = 30.0,
}

-- Server hooks (optional): e.g. pause / resume your weathersync
Config.OnStart = function()
    -- exports.weathersync:setWeather('fog', 30.0, true, false)
end
Config.OnEnd = function()
    -- exports.weathersync:resetWeather()
end

---------------------------------------------------------------------------
-- Zombies
---------------------------------------------------------------------------
Config.Zombies = {
    -- TEOT: expanded pool of RDR2 undead / corpse-style ped models.
    -- Removed re_deadbodies_males_01 at TEOT request: it spawned a normal-looking
    -- blond male corpse in a brown coat that did not fit the server's zombie style.
        models = {
        'A_M_M_ArmCholeraCorpse_01',
        'A_F_M_ArmCholeraCorpse_01',
        'A_M_M_UniCorpse_01',
        'A_F_M_UniCorpse_01',
        'CS_SwampFreak',
        'RE_SavageAftermath_Males_01',
        'RE_SavageAftermath_Females_01',
        'RE_SavageWarning_Males_01',
    },
    name   = 'Zombie',      -- name shown when looking at them (false = default name)
    health = 200,

    runnerChance = 30,      -- % of zombies that run (the others shamble)
    walkSpeed    = 1.0,
    runSpeed     = 3.0,
    walkerStyle  = 'very_drunk',   -- walking style of the slow ones (e.g. 'very_drunk', 'injured_general', 'injured_left_leg')
    runnerStyle  = false,          -- walking style of the runners (false = normal)

    aggroRange   = 55.0,    -- distance at which they notice players
    attackRange  = 2.0,     -- distance at which they start attacking
    retask       = 2500,    -- ms between chase updates

    -- Headshots only: any other death makes the zombie get back up after this time (ms)
    reviveTime = { min = 4000, max = 9000 },
    headBones  = { 21030 }, -- SKEL_Head

    despawnDistance = 350.0, -- removed when no player is within this distance
}

---------------------------------------------------------------------------
-- TEOT zombie tiers are geographic regions, not distance-from-Colter progression.
-- Ambarino, New Hanover and Lemoyne are OPEN. Only Armadillo is a no-loot danger zone.
-- Armadillo is Tier IV; container loot and corpse loot are blocked there server-side.
-- Colter remains a zombie-free safe camp. Strawberry remains Tier III; large cities are Tier IV.
---------------------------------------------------------------------------
Config.Tiers = {
    enabled = true,
    origin = vector3(-1350.0, 2430.0, 307.0), -- Colter survivor camp; reference only
    jumpServerDistance = 3.8,
    -- Region overlays are checked before ordinary tiers.
    -- Only Armadillo is excluded from loot; it still spawns Tier IV zombies.
    -- Coordinates are approximate world X/Y polygons and can be tuned after in-game checks.
    regions = {
        tier1 = {
            -- Snowy Grizzlies around Colter and Lake Isabella (kept as a named reference region).
            polygon = {
                { x = -2600.0, y = 1500.0 },
                { x = -1250.0, y = 1350.0 },
                { x = -250.0,  y = 1750.0 },
                { x = -350.0,  y = 2600.0 },
                { x = -950.0,  y = 3150.0 },
                { x = -2350.0, y = 3000.0 },
            },
        },
        tier2 = {
            -- Strawberry / Big Valley / Tall Trees / Great Plains corridor toward Blackwater.
            polygon = {
                { x = -2700.0, y = 300.0 },
                { x = -1900.0, y = 650.0 },
                { x = -950.0,  y = 350.0 },
                { x = -420.0,  y = -450.0 },
                { x = -430.0,  y = -1700.0 },
                { x = -1050.0, y = -2050.0 },
                { x = -2200.0, y = -1750.0 },
                { x = -2950.0, y = -650.0 },
            },
        },
        tier4Restricted = {
            -- Armadillo only: Tier IV danger zone, no loot from containers or zombie corpses.
            { name = 'Armadillo', polygon = {
                { x = -4070.0, y = -2620.0 },
                { x = -3953.0, y = -2903.0 },
                { x = -3670.0, y = -3020.0 },
                { x = -3387.0, y = -2903.0 },
                { x = -3270.0, y = -2620.0 },
                { x = -3387.0, y = -2337.0 },
                { x = -3670.0, y = -2220.0 },
                { x = -3953.0, y = -2337.0 },
            } }
        },
    },
    -- Major city centers are Tier IV. Armadillo is also Tier IV and has no loot.
    -- Strawberry is deliberately Tier III; Tumbleweed remains Tier III.
    cityOverrides = {
        tier4 = { 'Valentine', 'Saint Denis', 'Blackwater', 'Rhodes', 'Van Horn', 'Annesburg', 'Armadillo' },
        tier3 = { 'Strawberry', 'Tumbleweed' },
    },
    -- Expanded visual pools: corpse, cholera-infected, swamp mutant and burnt/savage corpse variants.
    -- All entries are existing RDR2 ped models; outfit presets are selected client-side.
    levels = {
        tier1 = {
            label = 'I — Бродяги',
            models = {'A_M_M_ArmCholeraCorpse_01', 'A_F_M_ArmCholeraCorpse_01', 'A_M_M_UniCorpse_01', 'A_F_M_UniCorpse_01'},
            health = 140, runnerChance = 0, walkSpeed = 0.80, runSpeed = 2.4,
            walkerStyle = 'very_drunk', runnerStyle = false, aggroRange = 42.0, attackRange = 1.8,
            modelScale = 1.0,
            jumperChance = 0, jumpRange = 6.0, jumpMinDistance = 3.0, jumpCooldown = 9000,
            jumpAttack = { ragdollMs = 1500 },
            emptyChance = 30, extraLootSlots = 0, lootItems = {},
        },
        tier2 = {
            label = 'II — Заражённые',
            models = {'A_M_M_ArmCholeraCorpse_01', 'A_F_M_ArmCholeraCorpse_01', 'A_M_M_UniCorpse_01', 'A_F_M_UniCorpse_01', 'CS_SwampFreak'},
            health = 230, runnerChance = 40, walkSpeed = 1.0, runSpeed = 3.35,
            walkerStyle = 'very_drunk', runnerStyle = false, aggroRange = 58.0, attackRange = 2.0,
            modelScale = 1.04,
            jumperChance = 5, jumpRange = 7.0, jumpMinDistance = 3.0, jumpCooldown = 8000,
            jumpAttack = { ragdollMs = 1800 },
            emptyChance = 22, extraLootSlots = 1,
            lootItems = {
                { item = 'morphine', chance = 7, min = 1, max = 1 },
                { item = 'ironbar', chance = 12, min = 1, max = 2 },
                { item = 'nails', chance = 16, min = 1, max = 3 },
                { item = 'ammorevolvernormal', chance = 7, min = 1, max = 3 },
            },
        },
        tier3 = {
            label = 'III — Тяжёлые',
            models = {'A_M_M_ArmCholeraCorpse_01', 'A_F_M_ArmCholeraCorpse_01', 'A_M_M_UniCorpse_01', 'A_F_M_UniCorpse_01', 'CS_SwampFreak', 'RE_SavageAftermath_Males_01', 'RE_SavageAftermath_Females_01', 'RE_SavageWarning_Males_01'},
            -- Rare existing RDR2 dead-man ped; verify the knight-like appearance in-game.
            rareModels = { 'U_M_M_APFDeadMan_01' }, rareModelChance = 4,
            health = 450, runnerChance = 0, walkSpeed = 0.66, runSpeed = 2.1,
            walkerStyle = 'injured_general', runnerStyle = false, modelScale = 1.12,
            aggroRange = 70.0, attackRange = 2.25,
            jumperChance = 8, jumpRange = 7.5, jumpMinDistance = 3.0, jumpCooldown = 7500,
            jumpAttack = { ragdollMs = 2200 },
            emptyChance = 14, extraLootSlots = 1,
            lootItems = {
                { item = 'morphine', chance = 12, min = 1, max = 1 },
                { item = 'ironbar', chance = 18, min = 1, max = 3 },
                { item = 'nails', chance = 20, min = 1, max = 4 },
                { item = 'ammoriflenormal', chance = 6, min = 1, max = 3 },
                { item = 'money_coinpurse', chance = 5, min = 1, max = 1 },
                { item = 'herbal_tonic', chance = 8, min = 1, max = 1 },
            },
        },
        tier4 = {
            label = 'IV — Высшая угроза',
            -- Reuse model names already used by this resource; no new ped assets required.
            models = {'A_M_M_ArmCholeraCorpse_01', 'A_F_M_ArmCholeraCorpse_01', 'A_M_M_UniCorpse_01', 'A_F_M_UniCorpse_01', 'CS_SwampFreak', 'RE_SavageAftermath_Males_01', 'RE_SavageAftermath_Females_01', 'RE_SavageWarning_Males_01'},
            -- Rare existing RDR2 dead-man ped; verify the knight-like appearance in-game.
            rareModels = { 'U_M_M_APFDeadMan_01' }, rareModelChance = 7,
            health = 620, runnerChance = 25, walkSpeed = 0.72, runSpeed = 3.55,
            walkerStyle = 'injured_general', runnerStyle = false, modelScale = 1.14,
            aggroRange = 85.0, attackRange = 2.4,
            jumperChance = 15, jumpRange = 8.0, jumpMinDistance = 3.0, jumpCooldown = 7000,
            jumpAttack = { ragdollMs = 2400 },
            emptyChance = 9, extraLootSlots = 2,
            lootItems = {
                { item = 'consumable_medicine', chance = 14, min = 1, max = 1 },
                { item = 'herbal_medicine', chance = 16, min = 1, max = 1 },
                { item = 'lockpick', chance = 12, min = 1, max = 1 },
                { item = 'ammorevolvernormal', chance = 12, min = 1, max = 3 },
                { item = 'ammorepeaternormal', chance = 10, min = 1, max = 3 },
                { item = 'money_coin', chance = 12, min = 1, max = 3 },
                { item = 'shellcasing', chance = 18, min = 1, max = 4 },
            },
        },
    },
}

---------------------------------------------------------------------------
-- Sounds (3D groans, synced: every player nearby hears the same groan at the same moment)
---------------------------------------------------------------------------
Config.Sounds = {
    enabled  = true,
    -- files in the sounds/ folder (.wav / .mp3 / .ogg, no spaces or '#' in the name); one is picked at random
    files    = {
        'zombie_01.wav', 'zombie_02.wav', 'zombie_03.wav', 'zombie_04.wav', 'zombie_05.wav', 'zombie_06.wav',
        'zombie_07.wav', 'zombie_08.wav', 'zombie_09.wav', 'zombie_10.wav', 'zombie_11.wav', 'zombie_12.wav',
        'zombie_13.wav', 'zombie_14.wav', 'zombie_15.wav', 'zombie_16.wav', 'zombie_17.wav', 'zombie_18.wav',
        'zombie_19.wav', 'zombie_20.wav', 'zombie_21.wav', 'zombie_22.wav', 'zombie_23.wav', 'zombie_24.wav',
        -- TEOT 1.6.9: 8 extra processed variants derived from the included CC0 source recordings.
        'zombie_25_deep_moan.wav', 'zombie_26_feral_growl.wav',
        'zombie_27_hollow_cry.wav', 'zombie_28_raspy_breath.wav',
        'zombie_29_horde_chorus.wav', 'zombie_30_rotten_snarl.wav',
        'zombie_31_drowned_moan.wav', 'zombie_32_infected_scream.wav',
    },
    volume   = 0.6,     -- max volume (0.0 - 1.0)
    distance = 40.0,    -- max distance it can be heard from
    pitch    = { min = 0.9, max = 1.1 }, -- pitch variation (the same for every player)
    idle     = { min = 10000, max = 25000 }, -- ms between groans when not chasing anyone
    chasing  = { min = 4000,  max = 9000 },  -- ms between groans when chasing a player
    maxDuration = 4000,  -- ms the sound follows the zombie (should be >= the longest sound file)
}

---------------------------------------------------------------------------
-- Spawn (around each player)
---------------------------------------------------------------------------
Config.Spawn = {
    countRadius   = 250.0,  -- active area used to count nearby zombies
    clusterRadius = 180.0,  -- nearby rural players share one spawner; separated players get their own waves
    minDistance   = 60.0,   -- minimum spawn distance; fallback can use 45m if terrain search fails
    maxDistance   = 250.0,  -- keep the requested maximum radius
    skipInteriors = true,   -- no zombies while the player is inside an interior
}

-- TEOT: infected town zones. When a player approaches, zombies spawn inside the town
-- footprint and wander there until a player enters their aggro range.
Config.CitySpawns = {
    enabled = true,
    triggerDistance = 300.0, -- activate city population 300m before the city edge
    prewarmDistance = 250.0, -- spawn city residents anywhere in town while the player is still approaching
    ruralBuffer = 300.0, -- legacy setting; wilderness spawning is excluded from the 300m city approach trigger
    positionReportInterval = 2000, -- client position reports used to elect one city spawner
    ownerRefreshInterval = 2000, -- server-side city controller election
    ownerStaleAfter = 8000, -- a disconnected / unresponsive client stops owning a city
    countRefreshInterval = 1000, -- server-wide city census and cleared-city detection

    -- One fixed initial city population; killed zombies are never individually replaced.
    -- After it is cleared, wait 15 minutes, then send horde 1 and horde 2.
    -- After horde 2 is cleared, the next 15-minute cooldown begins.
    clearCooldownMs = 900000, -- 15 minutes after the initial population or second horde wave is fully cleared
    hordeSize = 35, -- first post-clear wave; capped by the city's population cap
    secondHordeSize = 45, -- second, harder wave after the first wave is cleared
    betweenHordeWavesMs = 45000, -- wait 45 seconds after wave 1 is cleared, then launch wave 2
    secondWaveRunnerChance = 65, -- % runners in the second wave
    secondWaveAggroRange = 350.0, -- second wave notices players from farther away
    waveSpawnIntervalMs = 100, -- spread the fixed wave over time to reduce network load
    spawnAckTimeoutMs = 180000, -- recover if the client creating a wave disconnects or model loading is slow

    -- The city cap is global for the whole city, not multiplied by the number of players.
    -- Multiplier is applied to each zone's maxZombies based on the selected density.
    densityMultiplier = {
        low = 0.45,
        medium = 0.70,
        high = 1.00,
        extreme = 1.25,
    },

    zones = {
        { name = 'Valentine',     coords = vector3(-281.0, 783.0, 119.0),    radius = 210.0, maxZombies = 48 },
        { name = 'Saint Denis',   coords = vector3(2632.0, -1312.0, 52.0),   radius = 390.0, maxZombies = 70 },
        { name = 'Blackwater',    coords = vector3(-813.0, -1324.0, 43.0),   radius = 250.0, maxZombies = 52 },
        { name = 'Rhodes',        coords = vector3(1346.0, -1312.0, 77.0),   radius = 210.0, maxZombies = 44 },
        { name = 'Strawberry',    coords = vector3(-1791.0, -386.0, 160.0),  radius = 180.0, maxZombies = 36 },
        { name = 'Tumbleweed',    coords = vector3(-5500.0, -2930.0, -2.0),  radius = 250.0, maxZombies = 44 },
        { name = 'Armadillo',     coords = vector3(-3670.0, -2620.0, -13.0), radius = 230.0, maxZombies = 44 }, -- Tier IV danger zone; no loot
        { name = 'Van Horn',      coords = vector3(2980.0, 500.0, 42.0),     radius = 210.0, maxZombies = 38 },
        { name = 'Annesburg',     coords = vector3(2930.0, 1300.0, 44.0),    radius = 250.0, maxZombies = 42 },
        -- Colter is intentionally NOT a city-spawn zone: it is TEOT's starter survivor camp.
        { name = 'Emerald Ranch', coords = vector3(1416.0, 322.0, 89.0),     radius = 170.0, maxZombies = 28 },

        -- LRRP Paranormal Merge: the two ricx_ghostship locations are staged
        -- as compact dungeon zones. The initial population is followed by the
        -- normal Deadmoon city horde cycle after the zone is cleared.
        { name = 'Ghost Ship North', coords = vector3(506.333, -1585.397, 38.789), radius = 65.0, maxZombies = 16, hordeSize = 12, secondHordeSize = 16 },
        { name = 'Ghost Ship South', coords = vector3(646.265, -1775.798, 39.839), radius = 65.0, maxZombies = 16, hordeSize = 12, secondHordeSize = 16 },
    },
}

---------------------------------------------------------------------------
-- Density levels (change in game with /deadmoon density <level>)
---------------------------------------------------------------------------
--   interval     = ms between waves
--   perWave      = max zombies spawned per wave
--   maxPerPlayer = max zombies spawned by each player
--   maxNearby    = max zombies in the area (counts every player's zombies, radius Config.Spawn.countRadius)
--   hordeChance  = legacy value; automatic horde rolls are disabled and RuralEncounters handles wilderness events
Config.Density = {
    default = 'high', -- TEOT: stronger baseline population
    levels = {
        low     = { interval = 6000, perWave = 2, maxPerPlayer = 10, maxNearby = 20, hordeChance = 0.5 },
        medium  = { interval = 3500, perWave = 3, maxPerPlayer = 20, maxNearby = 35, hordeChance = 1.5 },
        high    = { interval = 2200, perWave = 5, maxPerPlayer = 35, maxNearby = 60, hordeChance = 3.0 },
        extreme = { interval = 1500, perWave = 7, maxPerPlayer = 45, maxNearby = 75, hordeChance = 6.0 },
    },
}

---------------------------------------------------------------------------
-- Hordes: every now and then a big group shows up at once
-- (test: /deadmoon horde [player id])
---------------------------------------------------------------------------
Config.Horde = {
    enabled       = true,
    randomEnabled = false, -- TEOT: automatic hordes are handled by RuralEncounters outside towns
    size          = 25,      -- TEOT: larger hordes
    checkInterval = 45000,   -- roll more often
    cooldown      = 480000,  -- minimum 8 minutes between hordes for one player
    minDistance   = 120.0,   -- keep horde away from the immediate player bubble
    maxDistance   = 220.0,
    spread        = 16.0,
    runnerChance  = 45,
    aggroRange    = 300.0,   -- enough to detect the player across the horde spawn radius
}

-- TEOT rural encounters: a quiet stalker or a horde every 10 minutes while players remain outside all city approach triggers.
-- Nearby players share one encounter so groups do not multiply hordes by player count.
Config.RuralEncounters = {
    enabled = true,
    interval = 600000,       -- 10 minutes between encounters per nearby player cluster
    checkInterval = 5000,    -- server checks position reports every 5 seconds
    hordeChance = 40,        -- 40% of rural encounters are hordes; otherwise one stalker
    clusterRadius = 180.0,   -- players this close share an encounter timer
    cityBuffer = 300.0,      -- no rural encounter inside town footprint + 300m approach trigger
    stalkerDistanceMin = 130.0,
    stalkerDistanceMax = 180.0,
    stalkerAggroRange = 210.0,
    stalkerRunnerChance = 35,
    hordeSize = 20,           -- special rural encounter size; bounded by local population headroom
    hordeMinSize = 8,         -- a special event can add a small group if normal population is already near cap
}

---------------------------------------------------------------------------
-- Progress bar used by corpse searching (no medical/bleeding UI in this resource)
---------------------------------------------------------------------------
Config.Progress = 'auto'

---------------------------------------------------------------------------
-- Searching dead zombies (killed with a headshot)
---------------------------------------------------------------------------
Config.Loot = {
    key         = 0x760A9C6F, -- G: search dead zombies
    distance    = 2.0,
    searchTime  = 4000,
    anim        = { dict = 'amb_work@world_human_crouch_inspect@male_c@idle_a', name = 'idle_a' },
    corpseTime  = 180000,
    emptyChance = 25,
    maxItems    = 2,
    -- All names below exist in the provided TEOT_items.sql. bonusLoot from teot_perks gives a chance for one extra roll.
    items = {
        { item = 'water',                chance = 38, min = 1, max = 1 },
        { item = 'bandage',              chance = 15, min = 1, max = 1 },
        { item = 'cloth',                chance = 34, min = 1, max = 3 },
        { item = 'cigarette',             chance = 22, min = 1, max = 2 },
        { item = 'money_coin',            chance = 18, min = 1, max = 3 },
        { item = 'lockpick',              chance = 5,  min = 1, max = 1 },
        { item = 'consumable_medicine',   chance = 6,  min = 1, max = 1 },
        { item = 'herbal_medicine',       chance = 9,  min = 1, max = 1 },
        { item = 'consumable_coffee',     chance = 16, min = 1, max = 1 },
        { item = 'iron',                  chance = 20, min = 1, max = 2 },
        { item = 'copper',                chance = 16, min = 1, max = 2 },
        { item = 'wood',                  chance = 25, min = 1, max = 3 },
        { item = 'leather',               chance = 15, min = 1, max = 2 },
        { item = 'shellcasing',           chance = 8,  min = 1, max = 3 },
        { item = 'ammorevolvernormal',    chance = 4,  min = 1, max = 3 },
        { item = 'ammorepeaternormal',    chance = 3,  min = 1, max = 3 },
        { item = 'meat',                  chance = 8,  min = 1, max = 1 },
        { item = 'whisky',                chance = 4,  min = 1, max = 1 },
    },
}

---------------------------------------------------------------------------
-- Safe zones: no zombies inside the radius (the ones below are examples - adjust to your map)
---------------------------------------------------------------------------
Config.SafeZones = {
    -- Existing zombies that enter a safe zone are removed, including staged city zombies.
    despawnInside = true,
    zones = {
        {
            name = 'Colter Survivor Camp',
            coords = vector3(-1350.0, 2430.0, 307.0),
            radius = 280.0, -- protects the settlement and a buffer around the starter camp
        },
    },
}

---------------------------------------------------------------------------
-- Paranormal merge: ghost bosses and the nightly ghost train
---------------------------------------------------------------------------
-- Ghost bosses are active only while fksDeadmoonWeather is true. In the
-- supplied schedule this is the red-fog window on every seventh game day
-- (22:00-06:00, including the midnight boundary).
Config.GhostBosses = {
    enabled = true,
    requireSeventhDayEvent = true,
    spawnDistance = 110.0,
    despawnDistance = 165.0,
    ptfxAsset = 'scr_agnesdowd_ghost',
    ptfxName = 'scr_ped_ghost_haze_stage1',
    bosses = {
        {
            id = 'mary',
            name = 'Mary Hargrove',
            model = 'U_M_M_BHT_OUTLAWMAULED',
            models = { 'U_M_M_BHT_OUTLAWMAULED', 'U_M_M_BHT_OLDMAN', 'U_M_M_BHT_SKINNERBROTHER' },
            ptfxAsset = 'scr_agnesdowd_ghost',
            ptfxName = 'scr_ped_ghost_haze_stage1',
            coords = vector3(2945.2383, 517.5995, 45.3310),
            heading = 11.8799,
            health = 1200,
        },
        {
            id = 'ferryman',
            name = 'The Ferryman',
            model = 'U_M_M_BHT_SKINNERBROTHER',
            models = { 'U_M_M_BHT_SKINNERBROTHER', 'U_M_M_BHT_ODRISCOLLMAULED', 'U_M_M_BHT_OUTLAWMAULED' },
            ptfxAsset = 'scr_agnesdowd_ghost',
            ptfxName = 'scr_ped_ghost_haze_stage1',
            coords = vector3(-335.61, -145.71, 50.01),
            heading = 46.90,
            health = 1500,
        },
        {
            id = 'marsh_widow',
            name = 'The Marsh Widow',
            model = 'U_F_M_BHT_WIFE',
            models = { 'U_F_M_BHT_WIFE', 'U_M_M_BHT_LOVER', 'U_M_M_BHT_OLDMAN' },
            coords = vector3(1810.0, -1830.0, 43.0),
            heading = 90.0,
            health = 1100,
        },
        {
            id = 'gallows_miner',
            name = 'The Gallows Miner',
            model = 'U_M_M_BHT_MINEFOREMAN',
            models = { 'U_M_M_BHT_MINEFOREMAN', 'U_M_M_BHT_BANDITOMINE', 'U_M_M_BHT_OUTLAWMAULED' },
            coords = vector3(2930.0, 1300.0, 44.0),
            heading = 270.0,
            health = 1800,
        },
        {
            id = 'blackwater_drifter',
            name = 'The Blackwater Drifter',
            model = 'U_M_M_BHT_BLACKWATERHUNT',
            models = { 'U_M_M_BHT_BLACKWATERHUNT', 'U_M_M_BHT_SKINNERSEARCH', 'U_M_M_BHT_SKINNERBROTHER' },
            coords = vector3(-813.0, -1324.0, 43.0),
            heading = 0.0,
            health = 1400,
        },
        {
            id = 'red_ridge_preacher',
            name = 'The Red Ridge Preacher',
            model = 'MP_U_M_M_CULTPRIEST_01',
            models = { 'MP_U_M_M_CULTPRIEST_01', 'U_M_M_BHT_OLDMAN', 'U_M_M_BHT_MINEFOREMAN' },
            coords = vector3(-281.0, 783.0, 119.0),
            heading = 180.0,
            health = 1600,
        },
        {
            id = 'drowned_bride',
            name = 'The Drowned Bride',
            model = 'U_F_M_BHT_WIFE',
            models = { 'U_F_M_BHT_WIFE', 'U_M_M_BHT_LOVER', 'U_M_M_BHT_OUTLAWMAULED' },
            coords = vector3(646.265, -1775.798, 39.839),
            heading = 126.999,
            health = 1300,
        },
        {
            id = 'tumbleweed_watchman',
            name = 'The Tumbleweed Watchman',
            model = 'U_M_M_BHT_OLDMAN',
            models = { 'U_M_M_BHT_OLDMAN', 'U_M_M_BHT_OUTLAWMAULED', 'U_M_M_BHT_SKINNERSEARCH' },
            coords = vector3(-5500.0, -2930.0, -2.0),
            heading = 45.0,
            health = 1700,
        },
    },
}

-- The original GhostTrainOdds file is a Windows ASI and has no readable Lua
-- route. This is the RedM-native replacement. The first point must be on a
-- valid rail; the train is active every night from 00:00 through 03:00.
Config.GhostTrain = {
    enabled = true,
    startHour = 0,
    endHour = 3,
    variation = 0,
    direction = true,
    cruiseSpeed = 8.0,
    respawnDistance = 35.0,
    route = {
        vector3(-1088.0, -556.0, 81.0),
        vector3(1248.0, -1297.0, 76.0),
    },
}

-- Ship wrecks are part of this resource, so no separate ricx_ghostship
-- resource is required. The same coordinates are also registered below in
-- Config.CitySpawns as zombie dungeon zones.
Config.GhostShips = {
    enabled = true,
    model = 'mp005_s_mp_boatsunk_wreck01',
    ships = {
        {
            coords = vector3(506.333, -1585.397, 38.789),
            rotation = vector3(0.0, 0.0, 0.0),
        },
        {
            coords = vector3(646.265, -1775.798, 39.839),
            rotation = vector3(-0.957, 4.080, 126.999),
        },
    },
}
