-- Ghost bosses for the seventh-day Deadmoon event.

local G = Config.GhostBosses or {}
local spawned = {}
local escorts = {}
local haze = {}
local defeated = {}
local spawnBlockedUntil = {}
local testLocations = {}

local function notify(message)
    if Bridge and Bridge.Notify then
        Bridge.Notify(message, 'error', 7000)
    else
        print('[fks-deadmoon] ' .. tostring(message))
    end
end

local function loadModel(names)
    names = type(names) == 'table' and names or { names }
    for _, name in ipairs(names) do
        local hash = type(name) == 'number' and name or joaat(name)
        if IsModelValid(hash) then
            RequestModel(hash)
            local deadline = GetGameTimer() + 10000
            while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
            if HasModelLoaded(hash) then return hash, name end
        end
    end
    return nil
end

local function createGhostPed(hash, coords, heading)
    -- RedM artifacts differ: some accept the model as the first argument,
    -- while ghost/story peds need the explicit RDR3 pedType (4).
    local ped = CreatePed(hash, coords.x, coords.y, coords.z,
        heading or 0.0, true, true, false, false)
    if ped and ped ~= 0 and DoesEntityExist(ped) then return ped end
    return CreatePed(4, hash, coords.x, coords.y, coords.z,
        heading or 0.0, true, true, false, false)
end

local function removeBoss(index)
    local ped = spawned[index]
    if haze[index] and DoesParticleFxLoopedExist and DoesParticleFxLoopedExist(haze[index]) then
        if StopParticleFxLooped then StopParticleFxLooped(haze[index], false) end
    end
    haze[index] = nil
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, true, true)
        DeletePed(ped)
    end
    spawned[index] = nil
end

local function attachHaze(index, boss, ped)
    local asset = boss.ptfxAsset or G.ptfxAsset
    local effect = boss.ptfxName or G.ptfxName
    if not asset or not effect then return end
    if not RequestNamedPtfxAsset or not HasNamedPtfxAssetLoaded
        or not UseParticleFxAsset or not StartParticleFxLoopedOnEntity then return end
    RequestNamedPtfxAsset(asset)
    local deadline = GetGameTimer() + 5000
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < deadline do Wait(0) end
    if not HasNamedPtfxAssetLoaded(asset) then return end
    UseParticleFxAsset(asset)
    haze[index] = StartParticleFxLoopedOnEntity(
        effect, ped, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, false, false, false
    )
end

local function removeEscort(index)
    local group = escorts[index]
    if group then
        for i = #group, 1, -1 do
            local ped = group[i]
            if ped and DoesEntityExist(ped) then
                SetEntityAsMissionEntity(ped, true, true)
                DeleteEntity(ped)
            end
            table.remove(group, i)
        end
    end
    escorts[index] = nil
end

local function spawnEscort(index, boss, playerPed)
    local escort = boss.escort
    if type(escort) ~= 'table' or (tonumber(escort.count) or 0) <= 0 then return end
    local tier = Config.Tiers and Config.Tiers.levels and Config.Tiers.levels[escort.tier or 'tier2']
    if not tier or type(tier.models) ~= 'table' then return end

    -- Never overwrite a live group: doing that would orphan the old peds and
    -- create another group every time the boss entity is recreated.
    removeEscort(index)
    escorts[index] = {}
    local count = math.max(0, math.floor(tonumber(escort.count) or 0))
    local radius = tonumber(escort.radius) or 6.0
    for i = 1, count do
        local angle = (i / count) * math.pi * 2.0
        local pos = vector3(
            boss.coords.x + math.cos(angle) * radius,
            boss.coords.y + math.sin(angle) * radius,
            boss.coords.z
        )
        local model = tier.models[math.random(1, #tier.models)]
        local hash = loadModel(model)
        if hash then
            local ped = createGhostPed(hash, pos, boss.heading)
            SetModelAsNoLongerNeeded(hash)
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                SetEntityAsMissionEntity(ped, true, true)
                pcall(Citizen.InvokeNative, 0x283978A15512B2FE, ped, true)
                local state = Entity(ped).state
                state:set('fksZombie', true, true)
                state:set('fksCorpse', false, true)
                state:set('fksTier', escort.tier or 'tier2', true)
                state:set('fksRunner', math.random(100) <= (tonumber(tier.runnerChance) or 0), true)
                state:set('fksJumper', math.random(100) <= (tonumber(tier.jumperChance) or 0), true)
                state:set('fksAggro', tonumber(tier.aggroRange) or 58.0, true)
                if playerPed and DoesEntityExist(playerPed) then
                    TaskCombatPed(ped, playerPed, 0, 16)
                end
                escorts[index][#escorts[index] + 1] = ped
            end
        end
    end
end

local function spawnBoss(index, boss, playerPed, position)
    local hash, modelName = loadModel(boss.models or boss.model)
    if not hash then
        print(('[fks-deadmoon] ghost model unavailable: %s'):format(tostring(boss.model)))
        return
    end

    local spawnCoords = position or boss.coords
    local ped = createGhostPed(hash, spawnCoords, boss.heading)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        print(('[fks-deadmoon] CreatePed failed for ghost %s using %s'):format(boss.id, tostring(modelName)))
        return
    end

    SetEntityAsMissionEntity(ped, true, true)
    if SetEntityVisible then SetEntityVisible(ped, true, false) end
    if ResetEntityAlpha then ResetEntityAlpha(ped) end
    if SetEntityAlpha then SetEntityAlpha(ped, 255, false) end
    -- Give corpse fallback models a visible outfit, matching the zombie spawner.
    pcall(Citizen.InvokeNative, 0x283978A15512B2FE, ped, true)
    SetEntityMaxHealth(ped, boss.health or 1000)
    SetEntityHealth(ped, boss.health or 1000)
    SetPedCanRagdoll(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAttributes(ped, 5, true)
    SetPedCombatMovement(ped, 3)
    SetPedCombatRange(ped, 2)
    SetPedAccuracy(ped, 35)
    -- SetPedAsEnemy is not exposed by every RedM artifact. Combat task and
    -- combat attributes already make the boss hostile, so keep this optional.
    if SetPedAsEnemy then SetPedAsEnemy(ped, true) end
    SetPedKeepTask(ped, true)
    if playerPed and DoesEntityExist(playerPed) then
        TaskCombatPed(ped, playerPed, 0, 16)
    end

    -- Register the boss before attaching optional effects. If a particle native
    -- fails on an older artifact, the next tick must not create another escort.
    spawned[index] = ped
    attachHaze(index, boss, ped)
    spawnEscort(index, boss, playerPed)
    spawnBlockedUntil[index] = GetGameTimer() + 10000
    notify(('%s has manifested.'):format(boss.name))
end

local function eventActive()
    if not G.enabled then return false end
    if G.requireSeventhDayEvent ~= false then
        return GlobalState.fksDeadmoonWeather == true
    end
    return GlobalState.fksDeadmoon == true
end

local function process()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local active = eventActive()

    for index, boss in ipairs(G.bosses or {}) do
        local ped = spawned[index]
        local testPosition = testLocations[index]
        if (not active and not testPosition) or defeated[index] then
            removeEscort(index)
            removeBoss(index)
        elseif ped and DoesEntityExist(ped) then
            if IsEntityDead(ped) then
                defeated[index] = true
                TriggerServerEvent('fks-deadmoon:server:ghostBossDefeated', boss.id)
                notify(('%s has been banished.'):format(boss.name))
                removeEscort(index)
                removeBoss(index)
            elseif #(playerCoords - GetEntityCoords(ped)) > (G.despawnDistance or 165.0) then
                removeEscort(index)
                removeBoss(index)
            end
        elseif not ped then
            if GetGameTimer() >= (spawnBlockedUntil[index] or 0)
                and #(playerCoords - (testPosition or boss.coords)) <= (boss.spawnDistance or 110.0) then
                removeEscort(index)
                spawnBoss(index, boss, playerPed, testPosition)
            end
        elseif not DoesEntityExist(ped) then
            -- The boss can disappear during model/streaming cleanup. Always
            -- remove its escort before allowing a fresh spawn attempt.
            removeEscort(index)
            spawned[index] = nil
            spawnBlockedUntil[index] = GetGameTimer() + 10000
        elseif #(playerCoords - (testPosition or boss.coords)) <= (boss.spawnDistance or 110.0) then
            spawnBoss(index, boss, playerPed, testPosition)
        end
    end
end

CreateThread(function()
    while true do
        process()
        Wait(1000)
    end
end)

RegisterNetEvent('fks-deadmoon:client:ghostTest', function(id)
    local playerCoords = GetEntityCoords(PlayerPedId())
    for index, boss in ipairs(G.bosses or {}) do
        if not id or id == boss.id then
            testLocations[index] = playerCoords
            defeated[index] = nil
            removeEscort(index)
            removeBoss(index)
            print(('[fks-deadmoon] ghost test armed: %s at %.2f %.2f %.2f'):format(
                boss.id, playerCoords.x, playerCoords.y, playerCoords.z
            ))
            return
        end
    end
    print(('[fks-deadmoon] unknown ghost id: %s'):format(tostring(id)))
end)

RegisterNetEvent('fks-deadmoon:client:ghostTestClear', function()
    testLocations = {}
end)

AddStateBagChangeHandler('fksDeadmoonWeather', 'global', function(_, _, value)
    if value ~= true then
        for index in pairs(spawned) do removeEscort(index); removeBoss(index) end
        defeated = {}
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for index in pairs(spawned) do removeEscort(index); removeBoss(index) end
end)
