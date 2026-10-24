local spawnedBosses = {}
local bossDefeated = {}
local shipStates = {}
local train = nil
local trainAnnounced = false

local function notify(message)
    if Config.NotifyEvent then
        TriggerEvent(Config.NotifyEvent, message, 5000)
        return
    end
    -- Both events are harmless when their source resource is not installed.
    TriggerEvent('vorp:TipRight', message, 5000)
    TriggerEvent('rNotify:Tip', message)
end

local function hashModel(model)
    return type(model) == 'number' and model or GetHashKey(model)
end

local function loadModel(model)
    local hash = hashModel(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function distance(a, b)
    return #(a - b)
end

local function spawnPed(model, coords, heading)
    local hash = loadModel(model)
    if not hash then return nil end
    local ped = CreatePed(hash, coords.x, coords.y, coords.z, heading or 0.0, true, true, true)
    if ped == 0 or not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(hash)
        return nil
    end
    SetEntityAsMissionEntity(ped, true, true)
    SetModelAsNoLongerNeeded(hash)
    return ped
end

local function configureEnemy(ped, health, target)
    SetEntityMaxHealth(ped, health)
    SetEntityHealth(ped, health)
    SetPedCanRagdoll(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAttributes(ped, 5, true)
    SetPedCombatMovement(ped, 3)
    SetPedCombatRange(ped, 2)
    SetPedAccuracy(ped, 35)
    SetPedAsEnemy(ped, true)
    if target and DoesEntityExist(target) then
        TaskCombatPed(ped, target, 0, 16)
    end
end

local function cleanupPed(ped)
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, true, true)
        DeletePed(ped)
    end
end

local function spawnBoss(index, boss, playerPed)
    local ped = spawnPed(boss.model, boss.coords, boss.heading)
    if not ped then
        if Config.Debug then print(('[lrrp_paranormal_merge] model unavailable: %s'):format(boss.model)) end
        return
    end
    configureEnemy(ped, boss.health or 1000, playerPed)
    SetPedKeepTask(ped, true)
    spawnedBosses[index] = ped
    notify((Config.Text.bossSpawn):format(boss.name))
end

local function processBosses(playerPed, playerCoords)
    for index, boss in ipairs(Config.GhostBosses or {}) do
        local existing = spawnedBosses[index]
        if bossDefeated[index] then
            if existing then cleanupPed(existing); spawnedBosses[index] = nil end
        elseif existing and DoesEntityExist(existing) then
            if IsEntityDead(existing) then
                bossDefeated[index] = true
                TriggerServerEvent('lrrp_paranormal_merge:bossDefeated', boss.id)
                notify((Config.Text.bossDefeated):format(boss.name))
                cleanupPed(existing)
                spawnedBosses[index] = nil
            elseif distance(playerCoords, GetEntityCoords(existing)) > (boss.spawnDistance or 110.0) * 1.5 then
                cleanupPed(existing)
                spawnedBosses[index] = nil
            end
        elseif distance(playerCoords, boss.coords) <= (boss.spawnDistance or 110.0) then
            spawnBoss(index, boss, playerPed)
        end
    end
end

local function alivePeds(list)
    local alive = 0
    for i = #list, 1, -1 do
        local ped = list[i]
        if not DoesEntityExist(ped) or IsEntityDead(ped) then
            cleanupPed(ped)
            table.remove(list, i)
        else
            alive = alive + 1
        end
    end
    return alive
end

local function spawnZombieWave(state, center, amount, playerPed)
    local models = Config.ShipDungeon.zombieModels
    for i = 1, amount do
        local angle = math.random() * math.pi * 2.0
        local radius = 12.0 + math.random() * 24.0
        local pos = vector3(center.x + math.cos(angle) * radius, center.y + math.sin(angle) * radius, center.z)
        local model = models[math.random(1, #models)]
        local ped = spawnPed(model, pos, math.random(0, 359) + 0.0)
        if ped then
            configureEnemy(ped, 350, playerPed)
            state.peds[#state.peds + 1] = ped
        end
    end
end

local function processShipDungeons(playerPed, playerCoords)
    local dungeon = Config.ShipDungeon
    if not dungeon.enabled then return end
    for index, center in ipairs(dungeon.centers or {}) do
        local state = shipStates[index]
        if not state then
            state = { wave = 0, peds = {}, nextWave = 0, complete = false }
            shipStates[index] = state
        end
        local near = distance(playerCoords, center) <= dungeon.spawnDistance
        if near then
            local alive = alivePeds(state.peds)
            if not state.complete and alive == 0 and GetGameTimer() >= state.nextWave then
                if state.wave < #dungeon.waves then
                    state.wave = state.wave + 1
                    spawnZombieWave(state, center, math.min(dungeon.waves[state.wave], dungeon.maxAlive), playerPed)
                    state.nextWave = GetGameTimer() + dungeon.waveDelayMs
                    notify((Config.Text.shipWave):format(state.wave))
                else
                    state.complete = true
                    notify(Config.Text.shipClear)
                end
            end
        elseif distance(playerCoords, center) > dungeon.radius * 2.5 then
            for i = #state.peds, 1, -1 do cleanupPed(state.peds[i]); table.remove(state.peds, i) end
            if not state.complete then state.nextWave = GetGameTimer() + dungeon.waveDelayMs end
        end
    end
end

local function spawnTrain()
    if not Config.Train.enabled or train then return end
    local first = Config.Train.route[1]
    if not first then return end
    train = CreateMissionTrain(Config.Train.variation or 0, first.x, first.y, first.z, Config.Train.direction ~= false, false, false)
    if train and train ~= 0 and DoesEntityExist(train) then
        SetTrainCruiseSpeed(train, Config.Train.cruiseSpeed or 8.0)
        SetTrainSpeed(train, Config.Train.cruiseSpeed or 8.0)
        if not trainAnnounced then notify(Config.Text.trainStarted); trainAnnounced = true end
    else
        train = nil
    end
end

local function processTrain()
    if not Config.Train.enabled then return end
    if not train or not DoesEntityExist(train) then
        spawnTrain()
        return
    end
    SetTrainCruiseSpeed(train, Config.Train.cruiseSpeed or 8.0)
    SetTrainSpeed(train, Config.Train.cruiseSpeed or 8.0)
    local last = Config.Train.route[#Config.Train.route]
    if last and distance(GetEntityCoords(train), last) <= (Config.Train.respawnDistance or 35.0) then
        DeleteMissionTrain(train)
        train = nil
    end
end

RegisterNetEvent('lrrp_paranormal_merge:bossReward', function(id)
    -- Add inventory code in a server-side handler for your chosen framework.
    TriggerEvent('lrrp_paranormal_merge:localBossReward', id)
end)

CreateThread(function()
    math.randomseed(GetGameTimer())
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        processBosses(playerPed, playerCoords)
        processShipDungeons(playerPed, playerCoords)
        processTrain()
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for index, ped in pairs(spawnedBosses) do cleanupPed(ped); spawnedBosses[index] = nil end
    for _, state in pairs(shipStates) do
        for i = #state.peds, 1, -1 do cleanupPed(state.peds[i]); table.remove(state.peds, i) end
    end
    if train and DoesEntityExist(train) then DeleteMissionTrain(train) end
end)
