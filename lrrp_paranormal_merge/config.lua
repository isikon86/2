Config = {}

-- This resource is deliberately framework-neutral.  The original resources
-- remain intact and can keep their own VORP/RSG/RedEM configuration.
Config.Debug = false
Config.NotifyEvent = nil -- e.g. 'vorp:TipRight' if your server uses a custom notifier

-- The two coordinates come from ricx_ghostship/config.lua.  Add or remove
-- entries to match the ship instances that are enabled on your server.
Config.ShipDungeon = {
    enabled = true,
    radius = 65.0,
    spawnDistance = 90.0,
    waveDelayMs = 15000,
    maxAlive = 8,
    waves = { 4, 6, 8 },
    zombieModels = {
        'U_M_M_ZOMBIE_01',
        'U_M_M_ZOMBIE_02',
        'U_M_M_ZOMBIE_03',
    },
    centers = {
        vector3(506.333, -1585.397, 38.789),
        vector3(646.265, -1775.798, 39.839),
    },
}

-- The base ghost-hunting script is escrowed, so its case coordinates cannot
-- be read or changed by this integration layer. These are safe, editable
-- boss arenas. Replace them with your case locations in the server map.
Config.GhostBosses = {
    {
        id = 'mary',
        name = 'Mary Hargrove',
        model = 'A_F_M_BHT_GHOST_01',
        coords = vector3(2945.2383, 517.5995, 45.3310),
        heading = 11.8799,
        health = 1200,
        spawnDistance = 110.0,
        combatRange = 45.0,
    },
    {
        id = 'ferryman',
        name = 'The Ferryman',
        model = 'A_M_M_BHT_GHOST_01',
        coords = vector3(504.0, -1585.0, 39.0),
        heading = 180.0,
        health = 1500,
        spawnDistance = 110.0,
        combatRange = 50.0,
    },
}

-- CreateMissionTrain makes the game use its native rail system. The route
-- points are only used for respawning the train; choose points on valid rails
-- for your map. The train has no encounter logic and simply keeps moving.
Config.Train = {
    enabled = true,
    variation = 0,
    direction = true,
    cruiseSpeed = 8.0,
    respawnDistance = 35.0,
    route = {
        vector3(-1088.0, -556.0, 81.0),
        vector3(1248.0, -1297.0, 76.0),
    },
}

Config.Text = {
    shipWave = 'The ghost ship stirs. Wave %d is coming.',
    shipClear = 'The ship is quiet... for now.',
    bossSpawn = '%s has manifested.',
    bossDefeated = '%s has been banished.',
    trainStarted = 'The ghost train is passing through.',
}
