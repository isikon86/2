-- Zombies: spawn around the local player, AI, headshot-only death and getting back up.
--
-- Zombies are networked peds. The client that OWNS a zombie (network owner) drives it; ownership can move
-- between clients, so every client runs the AI for the zombies it owns at that moment.
-- Entity state:  fksZombie (ours) · fksRunner · fksAggro (own detection range, hordes) · fksHead (killed by a headshot) · fksDown (dead for good) · fksLooted

Zombies = {}

local Z, S = Config.Zombies, Config.Spawn
local TierConfig = Config.Tiers or { enabled = false, levels = {} }

local function TierSettings(tierName)
    return TierConfig.levels and TierConfig.levels[tierName or 'tier1'] or nil
end

local function PointInPolygon(pos, polygon)
    if type(polygon) ~= 'table' or #polygon < 3 then return false end
    local inside = false
    local j = #polygon
    for i = 1, #polygon do
        local xi, yi = tonumber(polygon[i].x) or 0.0, tonumber(polygon[i].y) or 0.0
        local xj, yj = tonumber(polygon[j].x) or 0.0, tonumber(polygon[j].y) or 0.0
        local crosses = ((yi > pos.y) ~= (yj > pos.y))
            and (pos.x < ((xj - xi) * (pos.y - yi) / ((yj - yi) == 0 and 0.000001 or (yj - yi))) + xi)
        if crosses then inside = not inside end
        j = i
    end
    return inside
end

local function CityTierAtPosition(pos)
    local cityCfg = Config.CitySpawns
    if not cityCfg or cityCfg.enabled ~= true or type(cityCfg.zones) ~= 'table' then return nil end
    local overrides = TierConfig.cityOverrides or {}
    local tier4Names, tier3Names = {}, {}
    for _, name in ipairs(overrides.tier4 or {}) do tier4Names[name] = true end
    for _, name in ipairs(overrides.tier3 or {}) do tier3Names[name] = true end

    for _, city in ipairs(cityCfg.zones) do
        local c = city.coords
        if c then
            local dx, dy = pos.x - c.x, pos.y - c.y
            local radius = tonumber(city.radius) or 200.0
            if (dx * dx + dy * dy) <= (radius * radius) then
                if tier3Names[city.name] then return 'tier3' end
                if tier4Names[city.name] then return 'tier4' end
            end
        end
    end
    return nil
end

local function TierAtPosition(pos)
    if not TierConfig.enabled then return 'tier1' end

    -- Armadillo's exclusion polygon overrides ordinary tiers. It is Tier IV;
    -- corpse loot is disabled there by the server.
    local regions = TierConfig.regions or {}
    for _, area in ipairs(regions.tier4Restricted or {}) do
        if PointInPolygon(pos, area.polygon) then return 'tier4' end
    end

    -- City overrides apply outside restricted-state overlays. Strawberry remains Tier III.
    local cityTier = CityTierAtPosition(pos)
    if cityTier then return cityTier end

    if regions.tier1 and PointInPolygon(pos, regions.tier1.polygon) then return 'tier1' end
    if regions.tier2 and PointInPolygon(pos, regions.tier2.polygon) then return 'tier2' end

    -- The rest of the world, including Tumbleweed and open counties, is Tier III.
    return 'tier3'
end
local CityConfig = Config.CitySpawns or { enabled = false, zones = {} }
local RuralConfig = Config.RuralEncounters or { enabled = false }

-- Replicated player state tracks which geographic tier each player currently occupies.
-- This is independent from the existing zombie spawn scheduler.
CreateThread(function()
    local lastTier = nil
    while true do
        if TierConfig.enabled and PlayerPedId() ~= 0 then
            local pos = GetEntityCoords(PlayerPedId())
            local tier = TierAtPosition(pos)
            if tier ~= lastTier then
                lastTier = tier
                if LocalPlayer and LocalPlayer.state then
                    LocalPlayer.state:set('fksPlayerTier', tier, true)
                end
                TriggerServerEvent('fks-deadmoon:server:playerTierChanged', tier)
                Utils.Debug('player tier changed', GetPlayerServerId(PlayerId()), tier)
            end
        end
        Wait(2000)
    end
end)

local cityWaveRequests = {} -- [cityName] = last request time (client-side anti-spam)
local cityWaveRunning = {}  -- [cityName] = generation currently being spawned
local lastCityApproachDebug = 0

local _, relGroup = AddRelationshipGroup('FKS_ZOMBIE')
SetRelationshipBetweenGroups(5, relGroup, joaat('PLAYER'))
SetRelationshipBetweenGroups(5, joaat('PLAYER'), relGroup)
SetRelationshipBetweenGroups(1, relGroup, relGroup)

local setup = {}      -- [ped] = true  configured by this client (as owner)
local tasks = {}      -- [ped] = { kind, target, at }
local deadAt = {}     -- [ped] = time it died (owner)
local reviveAt = {}   -- [ped] = time to get back up (owner)
local downAt = {}     -- [ped] = time it died for good (owner)
local shotSeen = {}   -- [ped] = time this client first saw it dead (headshot report)
local groanAt = {}    -- [ped] = next time it groans (owner)
local jumperJumpAt = {} -- [ped] = next allowed leap time

-- TEOT admin invisibility is server-authoritative. The state bag is the primary
-- source; the admin panel's broadcast is a fallback for clients where state-bag
-- replication is delayed or a RedM artifact exposes it late.
local TeotInvisibleAdmins = {}
RegisterNetEvent('teot_admin:client:worldState', function(data)
    if type(data) == 'table' and type(data.invisibleAdmins) == 'table' then
        TeotInvisibleAdmins = data.invisibleAdmins
    end
end)

local function IsTeotAdminInvisiblePlayer(playerIndex)
    local serverId = GetPlayerServerId(playerIndex)
    if not serverId or serverId <= 0 then return false end

    if TeotInvisibleAdmins[tostring(serverId)] == true or TeotInvisibleAdmins[serverId] == true then
        return true
    end

    local ok, invisible = pcall(function()
        local state = Player(serverId).state
        return state ~= nil and state.teotAdminInvisible == true
    end)
    return ok and invisible == true
end

local function IsLocalAdminInvisible()
    return IsTeotAdminInvisiblePlayer(PlayerId())
end

function Zombies.IsZombie(ped)
    return ZombieModels[GetEntityModel(ped)] ~= nil and Entity(ped).state.fksZombie == true
end

-- alive or knocked down (will get back up)
function Zombies.IsThreat(ped)
    return not IsEntityDead(ped)
end

local function Delete(ped)
    SetEntityAsMissionEntity(ped, true, true)
    DeleteEntity(ped)
    setup[ped], tasks[ped], deadAt[ped], reviveAt[ped], downAt[ped], groanAt[ped], jumperJumpAt[ped] = nil, nil, nil, nil, nil, nil, nil
end

local function Owned(ped)
    return NetworkGetEntityOwner(ped) == PlayerId()
end

local function IsHeadshot(ped)
    local hit, bone = GetPedLastDamageBone(ped)
    return hit and HeadBones[bone] == true
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
local function Setup(ped)
    local st = Entity(ped).state
    local runner = st.fksRunner
    local tier = TierSettings(st.fksTier) or {}
    SetPedRelationshipGroupHash(ped, relGroup)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAttributes(ped, 5, true)
    SetPedCombatAttributes(ped, 17, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    RemoveAllPedWeapons(ped, true, true)
    SetPedCanRagdoll(ped, true)

    -- Do not refill health when network ownership migrates between players.
    if st.fksTierApplied ~= true then
        local health = math.max(1, tonumber(tier.health) or Z.health)
        SetEntityMaxHealth(ped, health)
        SetEntityHealth(ped, health, 0)
        st:set('fksTierApplied', true, true)
    end
    if tonumber(tier.modelScale) and tonumber(tier.modelScale) > 1.0 and type(SetPedScale) == 'function' then
        pcall(SetPedScale, ped, tonumber(tier.modelScale))
    end
    if Z.name then
        local label = tier.label and ('%s · %s'):format(Z.name, tier.label) or Z.name
        Citizen.InvokeNative(0x4A48B6E03BABB4AC, ped, label)
    end
    local style
    if runner then
        if tier.runnerStyle ~= nil then style = tier.runnerStyle else style = Z.runnerStyle end
    else
        if tier.walkerStyle ~= nil then style = tier.walkerStyle else style = Z.walkerStyle end
    end
    if style then
        Citizen.InvokeNative(0x923583741DC87BCE, ped, 'default')
        Citizen.InvokeNative(0x89F5E7ADECCCB49C, ped, style)
    end
    setup[ped] = true
    tasks[ped] = nil
end

local function LoadModel(hash)
    if not IsModelValid(hash) then return false end
    RequestModel(hash)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(50) end
    return HasModelLoaded(hash)
end

-- The city trigger consists of the town footprint plus its approach ring.
-- It activates a city population but must never become a rural spawn area.
local function IsInsideCityFootprint(pos, buffer)
    if not CityConfig.enabled then return false end
    buffer = tonumber(buffer) or 0.0
    for _, city in ipairs(CityConfig.zones or {}) do
        if #(pos - city.coords) <= (city.radius or 200.0) + buffer then return true, city end
    end
    return false
end


-- Overlapping city approach rings must not create a dead zone.
-- The town footprint itself always blocks rural spawns. In an outer approach
-- ring, rural spawns are suppressed only while that city's population is not
-- in the 15-minute cooldown. If every nearby city is cooling down, wilderness
-- population may resume outside the actual town footprints.
local function CityApproachBlocksRural(pos)
    if not CityConfig.enabled then return false end
    if IsInsideCityFootprint(pos, 0.0) then return true end

    local trigger = tonumber(CityConfig.triggerDistance) or 300.0
    local states = GlobalState.fksDeadmoonCityStates
    for _, city in ipairs(CityConfig.zones or {}) do
        local distance = #(pos - city.coords)
        if distance <= (city.radius or 200.0) + trigger then
            local state = type(states) == 'table' and states[city.name] or nil
            local phase = type(state) == 'table' and state.phase or 'unseeded'
            if phase ~= 'cooldown' then
                return true
            end
        end
    end
    return false
end

-- Curated outfit presets for existing corpse/undead models.
-- Preset IDs are based on the public RedM undead model/outfit lists; each spawned ped
-- picks a random supported preset, greatly increasing visual variety without normal civilians.
ZombieOutfitPresets = {
    ['a_m_m_armcholeraCorpse_01'] = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 28, 29, 30, 34, 35, 36, 37 },
    ['a_f_m_armcholeraCorpse_01'] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33 },
    ['a_m_m_unicorpse_01'] = { 0, 3, 4, 5, 8, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 30, 31, 33, 34, 35, 36, 37, 41, 45, 46, 47, 48, 49, 50, 52, 53, 54, 55, 56, 59, 67, 68, 69, 72, 73, 74, 81, 82, 83, 85, 86, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 107, 108, 110, 111, 112, 113, 114, 115, 116, 117, 118, 120, 122, 125, 126, 127, 128, 130, 131, 132, 133, 134, 136, 137, 138, 139, 141, 142, 143, 148, 149, 158, 159, 160, 161, 162, 163, 164, 165, 167, 168, 170, 175, 180 },
    ['a_f_m_unicorpse_01'] = { 0, 1, 2, 4, 5, 6, 7, 8, 11, 12, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 37, 38, 39, 40, 41, 42, 43, 44, 48 },
    ['cs_swampfreak'] = { 0 },
    ['re_savageaftermath_males_01'] = { 0, 1, 2, 3, 4 },
    ['re_savageaftermath_females_01'] = { 0, 1 },
    ['re_savagewarning_males_01'] = { 3, 4, 5, 6 },
    ['u_m_m_apfdeadman_01'] = { 0 }, -- unique base-game dead-man outfit
}

local function Spawn(pos, runnerChance, aggro, city, cityGeneration, cityWaveType)
    -- Hard safety check: rural zombies may not spawn anywhere inside the 300m
    -- city approach trigger. Only city-tagged waves may spawn there, and those
    -- are constrained to the actual town radius, not the outer trigger ring.
    if city then
        if #(pos - city.coords) > (tonumber(city.radius) or 200.0) + 5.0 then
            Utils.Debug('blocked city zombie outside city footprint', city.name)
            return false
        end
    elseif IsInsideCityFootprint(pos, 0.0) then
        Utils.Debug('blocked rural zombie inside actual city footprint')
        return false
    end

    local tierName = TierAtPosition(pos)
    local tier = TierSettings(tierName) or {}
    local modelPool = type(tier.models) == 'table' and #tier.models > 0 and tier.models or Z.models
    -- Rare Tier III/IV dead-man spawn. Kept separate from the regular pool so it does not
    -- replace common zombie appearances; the exact visual preset is checked in-game.
    local name
    local rarePool = type(tier.rareModels) == 'table' and tier.rareModels or nil
    local rareChance = math.max(0, math.min(100, tonumber(tier.rareModelChance) or 0))
    if rarePool and #rarePool > 0 and math.random(100) <= rareChance then
        name = rarePool[math.random(#rarePool)]
    else
        name = modelPool[math.random(#modelPool)]
    end
    local hash = joaat(name)
    if not LoadModel(hash) then
        print(('^1[fks-deadmoon] Model "%s" could not be loaded.^0'):format(name))
        return false
    end
    local ped = CreatePed(hash, pos.x, pos.y, pos.z, math.random(0, 359) + 0.0, true, true, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    local presetPool = ZombieOutfitPresets and ZombieOutfitPresets[string.lower(name)]
    local chosenPreset = type(presetPool) == 'table' and #presetPool > 0 and presetPool[math.random(#presetPool)] or nil
    if chosenPreset ~= nil then
        local applied = pcall(Citizen.InvokeNative, 0x77FF8D35EEC6BBC4, ped, chosenPreset, false)
        if not applied then Citizen.InvokeNative(0x283978A15512B2FE, ped, true) end
    else
        Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- random outfit for models without curated presets
    end
    SetEntityAsMissionEntity(ped, true, true)
    local st = Entity(ped).state
    st:set('fksZombie', true, true)
    st:set('fksCorpse', false, true) -- replicated marker: not currently a dead body
    st:set('fksTier', tierName, true)
    st:set('fksJumper', math.random(100) <= (tonumber(tier.jumperChance) or 0), true)
    local effectiveRunnerChance = TierConfig.enabled and (tonumber(tier.runnerChance) or 0) or (runnerChance or Z.runnerChance)
    st:set('fksRunner', math.random(100) <= effectiveRunnerChance, true)
    if aggro then st:set('fksAggro', aggro, true) end
    if city then
        st:set('fksCityZombie', true, true)
        st:set('fksCityZone', city.name, true)
        st:set('fksCityAlerted', false, true)
        if cityGeneration then st:set('fksCityGeneration', tonumber(cityGeneration) or 0, true) end
        if cityWaveType then st:set('fksCityWaveType', tostring(cityWaveType), true) end
    end
    Setup(ped)
    Utils.Debug('spawned', name, ped, tierName, st.fksJumper and 'jumper' or (st.fksRunner and 'runner' or 'walker'))

    SetTimeout(1000, function()
        if DoesEntityExist(ped) and IsEntityInWater(ped) and Owned(ped) then Delete(ped) end
    end)
    return true
end

-- Find a valid ground point around the player. Probe several elevations because the
-- old single-height probe often failed in mountain regions and deep valleys.
local function TrySpawnPoint(origin, minD, maxD, maxDz, excludeCities)
    local ang = math.random() * math.pi * 2
    -- Bias points somewhat closer to the player, where terrain collision is more likely loaded.
    local t = math.random() ^ 1.5
    local dist = minD + t * (maxD - minD)
    local x, y = origin.x + math.cos(ang) * dist, origin.y + math.sin(ang) * dist
    local probes = {
        math.max(origin.z + 250.0, 300.0),
        math.max(origin.z + 100.0, 200.0),
        math.max(origin.z + 500.0, 600.0),
        1000.0,
    }
    for _, probeZ in ipairs(probes) do RequestCollisionAtCoord(x, y, probeZ) end
    RequestCollisionAtCoord(x, y, origin.z)
    Wait(10)

    local groundZ
    for _, probeZ in ipairs(probes) do
        local found, z = GetGroundZFor_3dCoord(x, y, probeZ, false)
        if found and type(z) == 'number' and math.abs(z - origin.z) <= (maxDz or 180.0) then
            groundZ = z
            break
        end
    end
    if not groundZ then return nil end

    local p = vector3(x, y, groundZ)
    if Utils.InSafeZone(p) then return nil end
    -- Rural spawns must stay outside the full city approach trigger, not merely outside the town center.
    if excludeCities and IsInsideCityFootprint(p, 0.0) then return nil end
    return p
end

local function FindSpawnPoint(origin, minD, maxD, maxDz, excludeCities)
    local verticalTolerance = maxDz or 120.0

    -- First try the full configured ring (up to 250m).
    for _ = 1, 32 do
        local p = TrySpawnPoint(origin, minD, maxD, verticalTolerance, excludeCities)
        if p then return p end
    end

    -- Fallback ring: closer to the player, where collision is more likely to be loaded.
    -- This is still far enough to avoid spawning directly on top of the player.
    local fallbackMin, fallbackMax
    if maxD <= 40.0 then
        -- Short-radius spread used by stalker/horde encounters still needs a fallback.
        fallbackMin = math.max(0.0, math.min(minD, maxD * 0.25))
        fallbackMax = maxD
    else
        fallbackMin = math.max(40.0, math.min(minD, 45.0))
        fallbackMax = math.min(maxD, 130.0)
    end
    if fallbackMax > fallbackMin then
        for _ = 1, 20 do
            local p = TrySpawnPoint(origin, fallbackMin, fallbackMax, math.max(verticalTolerance, 180.0), excludeCities)
            if p then return p end
        end
    end

    return nil
end

-- City zone lookup and spawn-point selection.

local function FindCityForPlayer(pos)
    if not CityConfig.enabled then return nil end
    local best, bestDist
    for _, city in ipairs(CityConfig.zones or {}) do
        local d = #(pos - city.coords)
        local trigger = (city.radius or 200.0) + (CityConfig.triggerDistance or S.maxDistance)
        if d <= trigger and (not bestDist or d < bestDist) then
            best, bestDist = city, d
        end
    end
    return best
end

local function FindCitySpawnPoint(playerPos, city, minD, maxD, edgeSpawn)
    if not city then return nil end
    local radius = city.radius or 200.0
    local distanceToCenter = #(playerPos - city.coords)
    local prewarm = distanceToCenter > radius + (tonumber(CityConfig.prewarmDistance) or maxD or 250.0)

    -- At the 300m approach trigger, pre-populate the town footprint instead of
    -- trying to spawn a city zombie beside a player who is still far from town.
    -- Initial residents are distributed across town; later horde waves arrive from
    -- the outer streets/perimeter and push inward.
    for attempt = 1, 60 do
        local ang = math.random() * math.pi * 2
        local r
        if edgeSpawn then
            r = radius * (0.70 + math.random() * 0.30)
        else
            r = math.sqrt(math.random()) * radius
        end
        local x = city.coords.x + math.cos(ang) * r
        local y = city.coords.y + math.sin(ang) * r
        local probes = {
            math.max(playerPos.z + 250.0, city.coords.z + 250.0, 300.0),
            math.max(playerPos.z + 100.0, city.coords.z + 100.0, 200.0),
            math.max(playerPos.z + 500.0, city.coords.z + 500.0, 600.0),
            1000.0,
        }
        for _, probeZ in ipairs(probes) do RequestCollisionAtCoord(x, y, probeZ) end
        Wait(10)
        local groundZ
        for _, probeZ in ipairs(probes) do
            local found, z = GetGroundZFor_3dCoord(x, y, probeZ, false)
            if found and type(z) == 'number' and math.abs(z - city.coords.z) < 160.0 then
                groundZ = z
                break
            end
        end
        if groundZ then
            local p = vector3(x, y, groundZ)
            local d = #(p - playerPos)
            if not Utils.InSafeZone(p) and (prewarm or (d >= minD and d <= maxD)) then
                return p
            end
        end
    end
    return nil
end

local function CountCity(cityName, aliveOnly)
    local count = 0
    for _, ped in ipairs(GetGamePool('CPed')) do
        if Zombies.IsZombie(ped) then
            local st = Entity(ped).state
            if st.fksCityZone == cityName and not st.fksDown then
                local corpse = st.fksCorpse == true or IsEntityDead(ped)
                if not aliveOnly or not corpse then
                    count = count + 1
                end
            end
        end
    end
    return count
end

local function CityPopulation(city)
    local localCount = CountCity(city.name)
    local globalCounts = GlobalState.fksDeadmoonCityCounts
    local serverCount = tonumber(globalCounts and globalCounts[city.name]) or 0
    -- Local count catches freshly spawned peds before the server's next census;
    -- server count catches peds outside this client's streaming range.
    return math.max(localCount, serverCount)
end

local function CityCap(city)
    local level = GlobalState.fksDeadmoonDensity or Config.Density.default
    local multipliers = CityConfig.densityMultiplier or {}
    local multiplier = tonumber(multipliers[level]) or 1.0
    return math.max(1, math.floor((city.maxZombies or 20) * multiplier))
end

local function IsCityController(city)
    local owners = GlobalState.fksDeadmoonCityOwners
    if type(owners) ~= 'table' then return false end
    return tonumber(owners[city.name]) == GetPlayerServerId(PlayerId())
end

-- Report city population from the elected controller as a fallback for server
-- artifacts where client-created ped state is not fully reflected by GetAllPeds().
-- The server accepts reports only from the currently elected city controller.
CreateThread(function()
    while true do
        Wait(CityConfig.countRefreshInterval or 1000)
        if Deadmoon.active and Bridge.IsLoggedIn() then
            for _, city in ipairs(CityConfig.zones or {}) do
                if IsCityController(city) then
                    local totalCount = CountCity(city.name, false)
                    local aliveCount = CountCity(city.name, true)
                    TriggerServerEvent('fks-deadmoon:server:cityCount', city.name, totalCount, aliveCount)
                end
            end
        end
    end
end)

-- Only one client in a nearby rural player cluster creates new waves.
-- This prevents 20-30 players standing together from each starting their own spawner.
local function IsRuralSpawnController(pos)
    if IsLocalAdminInvisible() then return false end
    local myServerId = GetPlayerServerId(PlayerId())
    if not myServerId or myServerId <= 0 then return false end
    local lowestId = myServerId
    local clusterRadius = S.clusterRadius or S.countRadius

    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local ped = GetPlayerPed(pid)
            if not IsTeotAdminInvisiblePlayer(pid) and DoesEntityExist(ped) and not IsEntityDead(ped) then
                local ppos = GetEntityCoords(ped)
                local inInterior = S.skipInteriors and GetInteriorFromEntity(ped) ~= 0
                if not inInterior and not Utils.InSafeZone(ppos)
                    and not CityApproachBlocksRural(ppos)
                    and #(ppos - pos) <= clusterRadius then
                    local sid = GetPlayerServerId(pid)
                    if sid and sid > 0 and sid < lowestId then lowestId = sid end
                end
            end
        end
    end

    return lowestId == myServerId
end

-- The server elects a single city controller and maintains a global city population
-- census. Position reports are sent even when spawning is currently ineligible so
-- a dead/interior player does not keep control of a city.
CreateThread(function()
    local interval = (CityConfig.positionReportInterval or 2000)
    while true do
        Wait(interval)
        local me = PlayerPedId()
        local eligible = Deadmoon.active and Bridge.IsLoggedIn()
            and not IsLocalAdminInvisible()
            and DoesEntityExist(me) and not IsEntityDead(me)
            and not (S.skipInteriors and GetInteriorFromEntity(me) ~= 0)

        local pos = DoesEntityExist(me) and GetEntityCoords(me) or vector3(0.0, 0.0, 0.0)
        if eligible and Utils.InSafeZone(pos) then eligible = false end
        TriggerServerEvent('fks-deadmoon:server:cityPosition', pos.x, pos.y, pos.z, eligible == true)
    end
end)

-- zombies around `pos` (all clients) and zombies owned by this client
local function Count(pos)
    local near, owned = 0, 0
    for _, ped in ipairs(GetGamePool('CPed')) do
        if Zombies.IsZombie(ped) and not Entity(ped).state.fksDown then
            local d = #(GetEntityCoords(ped) - pos)
            if d <= S.countRadius then
                near = near + 1
                if Owned(ped) then owned = owned + 1 end
            end
        end
    end
    return near, owned
end

---------------------------------------------------------------------------
-- AI
---------------------------------------------------------------------------
local function FindTarget(zpos, range)
    local best, bestDist
    for _, pid in ipairs(GetActivePlayers()) do
        local pp = GetPlayerPed(pid)
        -- Invisibility must break both new targeting and an existing chase/attack.
        if not IsTeotAdminInvisiblePlayer(pid) and DoesEntityExist(pp) and not IsEntityDead(pp) then
            local pc = GetEntityCoords(pp)
            local d = #(pc - zpos)
            if d < range and (not bestDist or d < bestDist) and not Utils.InSafeZone(pc) then
                best, bestDist = pp, d
            end
        end
    end
    return best, bestDist
end

-- the owner decides when it groans; the server plays it for every player nearby (client/sounds.lua)
local SND = Config.Sounds
local function Groan(ped, now, chasing)
    if not SND.enabled then return end
    local range = chasing and SND.chasing or SND.idle
    if not groanAt[ped] then
        groanAt[ped] = now + math.random(0, range.max) -- spread the first ones
    elseif now >= groanAt[ped] then
        groanAt[ped] = now + math.random(range.min, range.max)
        TriggerServerEvent('fks-deadmoon:server:groan', NetworkGetNetworkIdFromEntity(ped))
    end
end

local function Drive(ped, now)
    local st = Entity(ped).state
    local tier = TierSettings(st.fksTier) or {}
    local target, dist = FindTarget(GetEntityCoords(ped), st.fksAggro or tier.aggroRange or Z.aggroRange)
    local t = tasks[ped]
    Groan(ped, now, target ~= nil)

    if target and st.fksCityZombie and not st.fksCityAlerted then
        st:set('fksCityAlerted', true, true)
    end

    if not target then
        if not t or t.kind ~= 'wander' then
            ClearPedTasks(ped)
            local cityName = st.fksCityZone
            local city
            if cityName and CityConfig.enabled then
                for _, candidate in ipairs(CityConfig.zones or {}) do
                    if candidate.name == cityName then city = candidate break end
                end
            end
            if city and type(TaskWanderInArea) == 'function' then
                local wanderRadius = math.min((city.radius or 200.0) * 0.65, 150.0)
                TaskWanderInArea(ped, city.coords.x, city.coords.y, city.coords.z, wanderRadius, 5.0, 10.0)
            else
                TaskWanderStandard(ped, 10.0, 10)
            end
            tasks[ped] = { kind = 'wander', at = now }
        end
        return
    end

    -- Rare jumpers leap at nearby survivors. The server validates the hit and injuries.
    if st.fksJumper then
        local jumpTask = tasks[ped]
        if jumpTask and jumpTask.kind == 'jump' and jumpTask.target == target then
            local elapsed = now - jumpTask.at
            if not jumpTask.hit and elapsed >= 250 and elapsed <= 1450 and dist <= 3.0 then
                jumpTask.hit = true
                local playerIndex = NetworkGetPlayerIndexFromPed(target)
                if playerIndex and playerIndex ~= -1 then
                    local targetServerId = GetPlayerServerId(playerIndex)
                    if targetServerId and targetServerId > 0 then
                        TriggerServerEvent('fks-deadmoon:server:jumperHit',
                            NetworkGetNetworkIdFromEntity(ped), targetServerId)
                    end
                end
            end
            if elapsed < 1250 then return end
            tasks[ped] = nil
        elseif dist and dist >= (tonumber(tier.jumpMinDistance) or 3.0)
            and dist <= (tonumber(tier.jumpRange) or 7.0)
            and now >= (jumperJumpAt[ped] or 0) then
            if type(TaskJump) == 'function' then
                pcall(TaskJump, ped, true)
            else
                TaskCombatPed(ped, target, 0, 16)
            end
            tasks[ped] = { kind = 'jump', target = target, at = now, hit = false }
            jumperJumpAt[ped] = now + (tonumber(tier.jumpCooldown) or 8000)
            return
        end
    end

    -- small gap between "attack" and "chase" so it doesn't flip every tick
    local attacking = t and t.kind == 'attack' and t.target == target
    local attackRange = tonumber(tier.attackRange) or Z.attackRange
    local reach = attacking and attackRange + 1.5 or attackRange

    if dist <= reach then
        if not attacking or now - t.at > 5000 then
            TaskCombatPed(ped, target, 0, 16)
            tasks[ped] = { kind = 'attack', target = target, at = now }
        end
    elseif not t or t.kind ~= 'chase' or t.target ~= target or now - t.at > Z.retask then
        local speed = st.fksRunner and (tonumber(tier.runSpeed) or Z.runSpeed) or (tonumber(tier.walkSpeed) or Z.walkSpeed)
        TaskGoToEntity(ped, target, -1, 1.0, speed + 0.0, 0, 0)
        tasks[ped] = { kind = 'chase', target = target, at = now }
    end
end

local function Revive(ped)
    ResurrectPed(ped)
    ReviveInjuredPed(ped)
    Entity(ped).state:set('fksCorpse', false, true)
    ClearPedTasksImmediately(ped)
    if ClearPedLastDamageBone then ClearPedLastDamageBone(ped) end
    Setup(ped)
    deadAt[ped], reviveAt[ped] = nil, nil
    Utils.Debug('got back up', ped)
end

local function MarkDown(ped, now)
    Entity(ped).state:set('fksCorpse', true, true)
    Entity(ped).state:set('fksDown', true, true)
    downAt[ped] = now
    deadAt[ped], reviveAt[ped] = nil, nil
    Utils.Debug('dead for good', ped)
end

-- owner: decides if the zombie stays dead (headshot) or gets back up
local function HandleDead(ped, now)
    local st = Entity(ped).state
    if st.fksDown then
        downAt[ped] = downAt[ped] or now
        if now - downAt[ped] > Config.Loot.corpseTime then Delete(ped) end
        return
    end
    if not deadAt[ped] then
        deadAt[ped] = now
        Entity(ped).state:set('fksCorpse', true, true)
        reviveAt[ped] = now + math.random(Z.reviveTime.min, Z.reviveTime.max)
        tasks[ped] = nil
    end
    if st.fksHead or IsHeadshot(ped) then return MarkDown(ped, now) end
    if now >= reviveAt[ped] then Revive(ped) end
end

-- any client: a zombie this player killed with a headshot is reported (its owner may be another client)
local function CheckMyKill(ped, me, now)
    if not IsEntityDead(ped) then shotSeen[ped] = nil return end
    if shotSeen[ped] == false or Entity(ped).state.fksDown then return end
    shotSeen[ped] = shotSeen[ped] or now
    if now - shotSeen[ped] > 2500 then shotSeen[ped] = false return end -- give up
    if GetPedSourceOfDeath(ped) == me and IsHeadshot(ped) then
        shotSeen[ped] = false
        if Owned(ped) then
            MarkDown(ped, now)
        else
            TriggerServerEvent('fks-deadmoon:server:headshot', NetworkGetNetworkIdFromEntity(ped))
        end
    end
end

local function NoPlayerNear(pos)
    for _, pid in ipairs(GetActivePlayers()) do
        if #(GetEntityCoords(GetPlayerPed(pid)) - pos) <= Z.despawnDistance then return false end
    end
    return true
end

local function ShouldDespawn(ped)
    local st = Entity(ped).state
    local pos = GetEntityCoords(ped)

    -- Safe zones take priority over staged-city persistence. This removes existing
    -- zombies from Colter as well as preventing any new spawns there.
    if Config.SafeZones.despawnInside and Utils.InSafeZone(pos) then return true end

    -- Keep every not-permanently-killed city zombie in the town, even after it has
    -- noticed a player. Otherwise leaving the trigger would despawn survivors and
    -- falsely start the 15-minute city-clear timer. Safe zones were checked above.
    if st.fksCityZombie and not st.fksDown then return false end

    if NoPlayerNear(pos) then return true end
    return false
end

CreateThread(function()
    while true do
        local me, now = PlayerPedId(), GetGameTimer()
        local seen = {}
        for _, ped in ipairs(GetGamePool('CPed')) do
            if Zombies.IsZombie(ped) then
                seen[ped] = true
                if Owned(ped) then
                    if not Deadmoon.active or ShouldDespawn(ped) then
                        Delete(ped)
                    elseif IsEntityDead(ped) then
                        HandleDead(ped, now)
                    else
                        if not setup[ped] then Setup(ped) end -- just became the owner
                        Drive(ped, now)
                    end
                else
                    setup[ped], tasks[ped], groanAt[ped] = nil, nil, nil
                end
                if DoesEntityExist(ped) then CheckMyKill(ped, me, now) end
            end
        end
        for _, list in ipairs({ setup, tasks, deadAt, reviveAt, downAt, shotSeen, groanAt, jumperJumpAt }) do
            for ped in pairs(list) do if not seen[ped] then list[ped] = nil end end
        end
        Wait(Deadmoon.active and 300 or 2000)
    end
end)

----------------------------------------------------------------------------
-- Spawn loop: one global controller per city; one spawner per nearby rural cluster
---------------------------------------------------------------------------
local function Density()
    local levels = Config.Density.levels
    return levels[GlobalState.fksDeadmoonDensity] or levels[Config.Density.default]
end

local function CanSpawnAround(me)
    return Deadmoon.active and Bridge.IsLoggedIn() and not IsLocalAdminInvisible() and not IsEntityDead(me)
        and not (S.skipInteriors and GetInteriorFromEntity(me) ~= 0)
        and not Utils.InSafeZone(GetEntityCoords(me))
end

local function FindCityByName(cityName)
    for _, city in ipairs(CityConfig.zones or {}) do
        if city.name == cityName then return city end
    end
    return nil
end

RegisterNetEvent('fks-deadmoon:client:spawnCityWave', function(cityName, generation, waveType)
    local city = FindCityByName(cityName)
    generation = tonumber(generation)
    if not city or not generation or cityWaveRunning[cityName] then return end
    cityWaveRunning[cityName] = generation

    local me = PlayerPedId()
    if not CanSpawnAround(me) then
        TriggerServerEvent('fks-deadmoon:server:cityWaveSpawned', cityName, generation, 0)
        cityWaveRunning[cityName] = nil
        return
    end

    local targetCount, spawned = 0, 0
    local ok, err = pcall(function()
        local H = Config.Horde or {}
        if waveType == 'horde1' or waveType == 'horde' then
            local configuredHorde = tonumber(city.hordeSize) or tonumber(CityConfig.hordeSize) or tonumber(H.size) or 30
            targetCount = math.min(CityCap(city), math.max(1, math.floor(configuredHorde)))
            Bridge.Notify('Слышен рёв за окраиной. Первая орда движется в город!', 'error', 8000)
        elseif waveType == 'horde2' then
            local configuredHorde = tonumber(city.secondHordeSize) or tonumber(CityConfig.secondHordeSize) or 45
            targetCount = math.min(CityCap(city), math.max(1, math.floor(configuredHorde)))
            Bridge.Notify('ВТОРАЯ ВОЛНА! Заражённые прорываются в город со всех сторон!', 'error', 10000)
        else
            targetCount = CityCap(city)
            Bridge.Notify(('Заражение обнаружено: %s больше не безопасен.'):format(city.name), 'error', 7000)
        end

        local attempts = 0
        local maxAttempts = math.max(targetCount, targetCount * 4)
        while spawned < targetCount and attempts < maxAttempts do
            attempts = attempts + 1
            if not Deadmoon.active then break end

            -- Spawn throughout the town footprint, never behind the player on the approach road.
            local spawnPos = FindCitySpawnPoint(city.coords, city, 0.0, city.radius or 200.0, waveType ~= 'initial')
            if spawnPos then
                local runnerChance, aggroRange
                if waveType == 'horde2' then
                    runnerChance = tonumber(CityConfig.secondWaveRunnerChance) or 65
                    aggroRange = tonumber(CityConfig.secondWaveAggroRange) or 350.0
                elseif waveType == 'horde1' or waveType == 'horde' then
                    runnerChance = tonumber(H.runnerChance) or Z.runnerChance
                    aggroRange = tonumber(H.aggroRange) or Z.aggroRange
                end
                if Spawn(spawnPos, runnerChance, aggroRange, city, generation, waveType) then
                    spawned = spawned + 1
                end
            end
            Wait(CityConfig.waveSpawnIntervalMs or 100)
        end
    end)

    if not ok then
        print(('^1[fks-deadmoon]^7 City "%s" wave error: %s'):format(cityName, tostring(err)))
    end
    TriggerServerEvent('fks-deadmoon:server:cityWaveSpawned', cityName, generation, spawned)
    Utils.Debug(('city "%s" %s wave #%d spawned %d/%d zombies'):format(
        cityName, tostring(waveType or 'initial'), generation, spawned, targetCount
    ))
    cityWaveRunning[cityName] = nil
end)

-- CITY TRIGGER COORDINATOR
-- Check every city whose 300m approach ring contains the player. Overlapping
-- triggers can seed both towns independently; a cooldown in one town must not
-- prevent a nearby eligible town from activating.
CreateThread(function()
    while true do
        Wait(1000)

        local me = PlayerPedId()
        if CanSpawnAround(me) and CityConfig.enabled then
            local pos = GetEntityCoords(me)
            local triggerDistance = tonumber(CityConfig.triggerDistance) or 300.0
            local states = GlobalState.fksDeadmoonCityStates
            local now = GetGameTimer()

            for _, city in ipairs(CityConfig.zones or {}) do
                local distance = #(pos - city.coords)
                if distance <= (city.radius or 200.0) + triggerDistance and IsCityController(city) then
                    local cityState = type(states) == 'table' and states[city.name] or nil
                    local phase = type(cityState) == 'table' and cityState.phase or 'unseeded'

                    if (phase == 'unseeded' or phase == 'horde_due' or phase == 'wave1_due' or phase == 'wave2_due')
                        and (not cityWaveRequests[city.name] or now - cityWaveRequests[city.name] >= 5000) then
                        cityWaveRequests[city.name] = now
                        TriggerServerEvent('fks-deadmoon:server:cityRequestWave', city.name)
                    end
                end
            end
        end
    end
end)

-- WILDERNESS POPULATION
-- Independent of city population state. As soon as the player is outside every
-- city approach trigger, the normal around-player spawn runs with its own limits.
-- City cooldowns, cleared city state, or an inactive city controller must never
-- disable this rural loop.
CreateThread(function()
    while true do
        local D = Density()
        Wait(math.max(500, tonumber(D.interval) or 2200))

        local me = PlayerPedId()
        if CanSpawnAround(me) then
            local pos = GetEntityCoords(me)
            local inCityApproach = CityApproachBlocksRural(pos)

            if not inCityApproach and IsRuralSpawnController(pos) then
                local near, owned = Count(pos)
                local maxNearby = tonumber(D.maxNearby) or 60
                local maxPerPlayer = tonumber(D.maxPerPlayer) or 35
                local perWave = tonumber(D.perWave) or 5
                local want = math.max(0, math.min(perWave, maxNearby - near, maxPerPlayer - owned))
                local spawned = 0

                for _ = 1, want do
                    local spawnPos = FindSpawnPoint(
                        pos,
                        tonumber(S.minDistance) or 60.0,
                        tonumber(S.maxDistance) or 250.0,
                        250.0,
                        true
                    )

                    if spawnPos then
                        if Spawn(spawnPos) then
                            spawned = spawned + 1
                        end
                    elseif Config.Debug then
                        Utils.Debug('wilderness spawn: no valid point after terrain retries')
                    end
                    Wait(80)
                end

                if Config.Debug and spawned > 0 then
                    Utils.Debug(('wilderness population spawned %d zombie(s); nearby=%d owned=%d'):format(
                        spawned, near, owned
                    ))
                end
            elseif Config.Debug and inCityApproach then
                -- One low-frequency log helps diagnose trigger classification without
                -- flooding the console; normal city spawning is handled by the other thread.
                local now = GetGameTimer()
                if not lastCityApproachDebug or now - lastCityApproachDebug > 15000 then
                    lastCityApproachDebug = now
                    Utils.Debug('wilderness population paused: player is inside a city approach trigger')
                end
            end
        end
    end
end)


--------------------------------------------------------------------------
-- Horde: a big group at once, sent by the server (random chance or admin command).
-- It ignores the density limits (while it is alive, the normal spawns stop because the area is full).
---------------------------------------------------------------------------
local hordeBusy = false

RegisterNetEvent('fks-deadmoon:client:horde', function()
    local H = Config.Horde
    local me = PlayerPedId()
    if hordeBusy or not CanSpawnAround(me) then return end

    local playerPos = GetEntityCoords(me)
    -- Manual/admin hordes may target a town itself, but never spawn behind a player
    -- who is only passing through the town's approach trigger.
    local inCity, city = IsInsideCityFootprint(playerPos, 0.0)
    if not inCity then city = nil end
    if not city and FindCityForPlayer(playerPos) then return end
    if city then
        local states = GlobalState.fksDeadmoonCityStates
        local cityState = type(states) == 'table' and states[city.name] or nil
        local phase = type(cityState) == 'table' and cityState.phase or 'unseeded'
        if phase ~= 'active' then
            return -- no manual/event horde can bypass the city's 15-minute clear cycle
        end
    end

    local center
    if city then
        center = FindCitySpawnPoint(playerPos, city, H.minDistance, H.maxDistance)
    else
        center = FindSpawnPoint(playerPos, H.minDistance, H.maxDistance, 180.0, true)
    end
    if not center then return end

    hordeBusy = true
    Bridge.Notify(_L('horde'), 'error', 8000)
    for _ = 1, H.size do
        if not Deadmoon.active then break end
        local spawnPos
        if city then
            spawnPos = FindCitySpawnPoint(center, city, 0.0, H.spread) or center
            Spawn(spawnPos, H.runnerChance, H.aggroRange, city)
        else
            spawnPos = FindSpawnPoint(center, 0.0, H.spread, 80.0, true) or center
            Spawn(spawnPos, H.runnerChance, H.aggroRange)
        end
        Wait(100) -- spread the network load
    end
    hordeBusy = false
end)

-- Scheduled wilderness encounter: either one stalker spawns behind the player,
-- or a bounded horde. The server sends this only outside town footprints and safe zones.
RegisterNetEvent('fks-deadmoon:client:ruralEncounter', function(isHorde)
    local R = Config.RuralEncounters or {}
    local me = PlayerPedId()
    if not R.enabled or not CanSpawnAround(me) then return end

    local playerPos = GetEntityCoords(me)
    if CityApproachBlocksRural(playerPos) or Utils.InSafeZone(playerPos) then return end

    local D = Density()
    if isHorde then
        if hordeBusy then return end
        local H = Config.Horde
        local center = FindSpawnPoint(playerPos, H.minDistance, H.maxDistance, 180.0, true)
        if not center then
            if Config.Debug then Utils.Debug('rural horde event skipped: no valid spawn point') end
            return
        end

        local near = Count(playerPos)
        local configured = math.max(1, tonumber(R.hordeSize) or tonumber(H.size) or 20)
        local free = math.max(0, (tonumber(D.maxNearby) or 60) - near)
        local amount = math.min(configured, math.max(tonumber(R.hordeMinSize) or 8, free))
        hordeBusy = true
        Bridge.Notify('Ты слышишь рёв и движение со всех сторон...', 'error', 8000)
        for _ = 1, amount do
            if not Deadmoon.active then break end
            local p = FindSpawnPoint(center, 0.0, tonumber(H.spread) or 16.0, 80.0, true) or center
            Spawn(p, H.runnerChance, R.stalkerAggroRange or H.aggroRange)
            Wait(100)
        end
        hordeBusy = false
        Utils.Debug(('rural horde encounter spawned %d zombies'):format(amount))
        return
    end

    -- The single stalker is positioned behind the player's current heading. If
    -- terrain/collision cannot be found there, fall back to the normal rural ring.
    local forward = GetEntityForwardVector(me)
    local minBack = tonumber(R.stalkerDistanceMin) or 130.0
    local maxBack = tonumber(R.stalkerDistanceMax) or 180.0
    local backDistance = math.random(math.floor(minBack), math.floor(maxBack))
    local behind = vector3(
        playerPos.x - forward.x * backDistance,
        playerPos.y - forward.y * backDistance,
        playerPos.z
    )
    local spawnPos = FindSpawnPoint(behind, 0.0, 35.0, 180.0, true)
        or FindSpawnPoint(playerPos, minBack, maxBack, 180.0, true)
    if spawnPos then
        Spawn(spawnPos, tonumber(R.stalkerRunnerChance) or 35, tonumber(R.stalkerAggroRange) or 210.0)
        Utils.Debug('rural stalker spawned behind player')
    elseif Config.Debug then
        Utils.Debug('rural stalker event skipped: no valid ground point')
    end
end)

-- removes every zombie this client owns (end of the event / resource stop)
function Zombies.Clear()
    for _, ped in ipairs(GetGamePool('CPed')) do
        if Zombies.IsZombie(ped) and Owned(ped) then Delete(ped) end
    end
end
