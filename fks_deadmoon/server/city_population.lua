-- TEOT city population coordinator 1.5.0.
-- Each town has one fixed initial population; individual kills are never replaced.
-- Once the city is fully cleared, a 15-minute cooldown starts. Then horde wave 1
-- arrives. After that wave is cleared, wave 2 arrives after a short warning delay.
-- Once wave 2 is cleared, the next 15-minute city cooldown begins.

local CityConfig = Config.CitySpawns or { enabled = false, zones = {} }
local RuralConfig = Config.RuralEncounters or { enabled = false }
local positions, lastReport, clientCountReports = {}, {}, {}

GlobalState.fksDeadmoonCityOwners = GlobalState.fksDeadmoonCityOwners or {}
GlobalState.fksDeadmoonCityCounts = GlobalState.fksDeadmoonCityCounts or {}
GlobalState.fksDeadmoonCityLiveCounts = GlobalState.fksDeadmoonCityLiveCounts or {}
GlobalState.fksDeadmoonCityRespawnBlocked = GlobalState.fksDeadmoonCityRespawnBlocked or {}
GlobalState.fksDeadmoonCityHasPopulated = GlobalState.fksDeadmoonCityHasPopulated or {}
GlobalState.fksDeadmoonCityStates = GlobalState.fksDeadmoonCityStates or {}

local function CopyMap(source)
    local copy = {}
    for key, value in pairs(source or {}) do copy[key] = value end
    return copy
end

local function CopyState(source)
    local copy = {}
    for key, value in pairs(source or {}) do copy[key] = value end
    return copy
end

local function SameMap(a, b)
    a, b = a or {}, b or {}
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end

local function FindCity(name)
    for _, city in ipairs(CityConfig.zones or {}) do
        if city.name == name then return city end
    end
    return nil
end

local function GetCityState(name)
    local state = (GlobalState.fksDeadmoonCityStates or {})[name]
    if type(state) == 'table' then return state end
    return { phase = 'unseeded', generation = 0, waveType = 'initial' }
end

local function SetCityState(name, state)
    local states = CopyMap(GlobalState.fksDeadmoonCityStates)
    states[name] = state
    GlobalState.fksDeadmoonCityStates = states
end

-- Preserve the old populated marker on an upgrade so an already-populated city
-- is not immediately given a duplicate initial wave.
do
    local states = CopyMap(GlobalState.fksDeadmoonCityStates)
    local legacyPopulated = GlobalState.fksDeadmoonCityHasPopulated or {}
    local changed = false
    for _, city in ipairs(CityConfig.zones or {}) do
        if type(states[city.name]) ~= 'table' then
            local phase = legacyPopulated[city.name] == true and 'active' or 'unseeded'
            states[city.name] = {
                phase = phase,
                generation = 0,
                waveType = 'initial',
                activeSinceMs = phase == 'active' and (GetGameTimer() + 1500) or nil,
            }
            changed = true
        end
    end
    if changed then GlobalState.fksDeadmoonCityStates = states end
end

RegisterNetEvent('fks-deadmoon:server:cityPosition', function(x, y, z, eligible)
    local src, now = source, GetGameTimer()
    if lastReport[src] and now - lastReport[src] < 500 then return end
    lastReport[src] = now

    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return end
    if math.abs(x) > 10000.0 or math.abs(y) > 10000.0 or z < -1500.0 or z > 3000.0 then return end
    positions[src] = { x = x, y = y, z = z, eligible = eligible == true, at = now }
end)

RegisterNetEvent('fks-deadmoon:server:cityCount', function(cityName, totalCount, aliveCount)
    local src = source
    if type(cityName) ~= 'string' or not FindCity(cityName) then return end

    local owners = GlobalState.fksDeadmoonCityOwners or {}
    if tonumber(owners[cityName]) ~= src then return end

    totalCount, aliveCount = tonumber(totalCount), tonumber(aliveCount)
    if not totalCount or not aliveCount or totalCount ~= totalCount or aliveCount ~= aliveCount then return end
    totalCount = math.max(0, math.min(300, math.floor(totalCount)))
    aliveCount = math.max(0, math.min(totalCount, math.floor(aliveCount)))

    clientCountReports[cityName] = {
        src = src, total = totalCount, alive = aliveCount, at = GetGameTimer()
    }
end)

-- Only the elected city controller can request a new wave. The server owns the
-- state transition, so two nearby clients cannot spawn duplicate town populations.
RegisterNetEvent('fks-deadmoon:server:cityRequestWave', function(cityName)
    local src = source
    if not CityConfig.enabled or not GlobalState.fksDeadmoon then return end
    if type(cityName) ~= 'string' or not FindCity(cityName) then return end

    local owners = GlobalState.fksDeadmoonCityOwners or {}
    if tonumber(owners[cityName]) ~= src then return end

    local state = GetCityState(cityName)
    local allowedPhases = {
        unseeded = true,
        horde_due = true, -- compatibility with v1.4.0 state
        wave1_due = true,
        wave2_due = true,
    }
    if not allowedPhases[state.phase] then return end

    -- If this resource was upgraded while a legacy wave is still alive, adopt it
    -- rather than stacking a fresh population on top of it.
    if state.phase == 'unseeded' then
        local serverCount = tonumber((GlobalState.fksDeadmoonCityCounts or {})[cityName]) or 0
        local report = clientCountReports[cityName]
        local freshReport = report and report.src == src and GetGameTimer() - report.at <= 5000
        if serverCount > 0 or (freshReport and (report.total or 0) > 0) then
            local adopted = CopyState(state)
            adopted.phase = 'active'
            adopted.waveType = 'initial'
            adopted.startedAt = os.time()
            adopted.activeSinceMs = GetGameTimer() + 1500
            SetCityState(cityName, adopted)
            return
        end
    end

    local waveType
    if state.phase == 'unseeded' then
        waveType = 'initial'
    elseif state.phase == 'wave2_due' then
        waveType = 'horde2'
    else
        waveType = 'horde1'
    end

    local nextState = CopyState(state)
    nextState.phase = 'spawning'
    nextState.waveType = waveType
    nextState.generation = (tonumber(state.generation) or 0) + 1
    nextState.requestedAt = os.time()
    nextState.requestedBy = src
    nextState.cooldownUntil = nil
    nextState.wave2At = nil
    nextState.clearedAt = nil
    SetCityState(cityName, nextState)

    TriggerClientEvent('fks-deadmoon:client:spawnCityWave', src, cityName, nextState.generation, waveType)
    print(('^2[fks-deadmoon]^7 City "%s": requested %s wave #%d by %s.'):format(
        cityName, waveType, nextState.generation, GetPlayerName(src) or tostring(src)
    ))
end)

RegisterNetEvent('fks-deadmoon:server:cityWaveSpawned', function(cityName, generation, spawnedCount)
    local src = source
    if type(cityName) ~= 'string' or not FindCity(cityName) then return end

    local state = GetCityState(cityName)
    if state.phase ~= 'spawning'
        or tonumber(state.requestedBy) ~= src
        or tonumber(state.generation) ~= tonumber(generation) then
        return
    end

    spawnedCount = tonumber(spawnedCount)
    if not spawnedCount or spawnedCount ~= spawnedCount then return end
    spawnedCount = math.max(0, math.min(300, math.floor(spawnedCount)))

    local nextState = CopyState(state)
    nextState.requestedAt = nil
    nextState.requestedBy = nil
    nextState.spawnedTotal = spawnedCount

    if spawnedCount > 0 then
        nextState.phase = 'active'
        nextState.startedAt = os.time()
        nextState.activeSinceMs = GetGameTimer() + 1500
        nextState.lastCount = spawnedCount
        print(('^2[fks-deadmoon]^7 City "%s": %d zombies spawned for %s wave #%d; no refill until the city is cleared.'):format(
            cityName, spawnedCount, state.waveType or 'initial', tonumber(generation) or 0
        ))
    else
        if state.waveType == 'horde2' then
            nextState.phase = 'wave2_due'
        elseif state.waveType == 'horde1' or state.waveType == 'horde' then
            nextState.phase = 'wave1_due'
        else
            nextState.phase = 'unseeded'
        end
        print(('^3[fks-deadmoon]^7 City "%s": %s spawn failed; it can be retried.'):format(cityName, tostring(state.waveType or 'initial')))
    end

    SetCityState(cityName, nextState)
end)

AddEventHandler('playerDropped', function()
    local src = source
    positions[src], lastReport[src] = nil, nil
    for cityName, report in pairs(clientCountReports) do
        if report.src == src then clientCountReports[cityName] = nil end
    end

    -- If the controller disconnects during a spawn, the watchdog will adopt any
    -- peds that already exist or retry the wave if nothing was created.
end)

local function RefreshCityOwners()
    local owners = {}
    if CityConfig.enabled and GlobalState.fksDeadmoon then
        local now = GetGameTimer()
        local staleAfter = CityConfig.ownerStaleAfter or 8000
        local triggerDistance = CityConfig.triggerDistance or 300.0

        for _, city in ipairs(CityConfig.zones or {}) do
            local bestSrc, bestDist
            for src, p in pairs(positions) do
                if p.eligible and now - p.at <= staleAfter then
                    local dx, dy, dz = p.x - city.coords.x, p.y - city.coords.y, p.z - city.coords.z
                    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
                    local trigger = (city.radius or 200.0) + triggerDistance
                    if dist <= trigger and (not bestDist or dist < bestDist or (dist == bestDist and src < bestSrc)) then
                        bestSrc, bestDist = src, dist
                    end
                end
            end
            if bestSrc then owners[city.name] = bestSrc end
        end
    end
    if not SameMap(GlobalState.fksDeadmoonCityOwners, owners) then
        GlobalState.fksDeadmoonCityOwners = owners
    end
end

local function PedIsDead(ped, state)
    if state and (state.fksCorpse == true or state.fksDown == true) then return true end
    local ok, dead = pcall(IsEntityDead, ped)
    return ok and dead == true
end

local function RefreshCityCounts()
    local counts, liveCounts = {}, {}
    local nowMs, nowEpoch = GetGameTimer(), os.time()
    for _, city in ipairs(CityConfig.zones or {}) do
        counts[city.name], liveCounts[city.name] = 0, 0
    end

    if CityConfig.enabled then
        for _, ped in ipairs(GetAllPeds()) do
            if DoesEntityExist(ped) then
                local ok, state = pcall(function() return Entity(ped).state end)
                if ok and state and state.fksZombie == true and state.fksCityZombie == true
                    and type(state.fksCityZone) == 'string' and counts[state.fksCityZone] ~= nil
                    and not state.fksDown then
                    counts[state.fksCityZone] = counts[state.fksCityZone] + 1
                    if not PedIsDead(ped, state) then
                        liveCounts[state.fksCityZone] = liveCounts[state.fksCityZone] + 1
                    end
                end
            end
        end
    end

    -- Some RedM artifacts do not expose every client-created ped through the server
    -- census immediately. Merge fresh reports from the elected city controller.
    local owners = GlobalState.fksDeadmoonCityOwners or {}
    for _, city in ipairs(CityConfig.zones or {}) do
        local report = clientCountReports[city.name]
        if report and nowMs - report.at <= 5000 and tonumber(owners[city.name]) == report.src then
            counts[city.name] = math.max(counts[city.name] or 0, report.total or 0)
            liveCounts[city.name] = math.max(liveCounts[city.name] or 0, report.alive or 0)
        elseif report and nowMs - report.at > 5000 then
            clientCountReports[city.name] = nil
        end
    end

    if not SameMap(GlobalState.fksDeadmoonCityCounts, counts) then
        GlobalState.fksDeadmoonCityCounts = counts
    end
    if not SameMap(GlobalState.fksDeadmoonCityLiveCounts, liveCounts) then
        GlobalState.fksDeadmoonCityLiveCounts = liveCounts
    end

    local cooldownSeconds = math.max(1, math.floor((tonumber(CityConfig.clearCooldownMs) or 900000) / 1000))
    local spawnTimeoutSeconds = math.max(10, math.floor((tonumber(CityConfig.spawnAckTimeoutMs) or 60000) / 1000))
    local states = CopyMap(GlobalState.fksDeadmoonCityStates)
    local statesChanged = false
    local blocked, populated = {}, {}

    for _, city in ipairs(CityConfig.zones or {}) do
        local name = city.name
        local state = states[name]
        if type(state) ~= 'table' then
            state = { phase = 'unseeded', generation = 0, waveType = 'initial' }
            states[name] = state
            statesChanged = true
        end

        local phase = state.phase or 'unseeded'
        if phase == 'spawning' then
            local requestedAt = tonumber(state.requestedAt) or nowEpoch
            if nowEpoch - requestedAt >= spawnTimeoutSeconds then
                local existingCount = counts[name] or 0
                local nextState = CopyState(state)
                if existingCount > 0 then
                    nextState.phase = 'active'
                elseif state.waveType == 'horde2' then
                    nextState.phase = 'wave2_due'
                elseif state.waveType == 'horde1' or state.waveType == 'horde' then
                    nextState.phase = 'wave1_due'
                else
                    nextState.phase = 'unseeded'
                end
                if nextState.phase == 'active' then nextState.activeSinceMs = nowMs + 1500 end
                nextState.requestedAt = nil
                nextState.requestedBy = nil
                states[name] = nextState
                state, phase, statesChanged = nextState, nextState.phase, true
                print(('^3[fks-deadmoon]^7 City "%s": spawn acknowledgement timed out; phase is now %s.'):format(name, phase))
            end
        end

        if phase == 'active' then
            local owner = tonumber(owners[name])
            local report = clientCountReports[name]
            local reportAfterWave = report and report.at >= (tonumber(state.activeSinceMs) or 0)
                and nowMs - report.at <= 15000
            local reportConfirmsEmpty = reportAfterWave and (report.total or 0) == 0
            local freshOwnerReport = reportAfterWave and owner and report.src == owner and nowMs - report.at <= 5000
            -- Count only zombies that are not permanently dead. A non-headshot corpse
            -- remains part of the wave because it can revive after a few seconds. If the
            -- player leaves right after reporting zero, accept that recent zero report too.
            if (counts[name] or 0) == 0 and reportConfirmsEmpty and (freshOwnerReport or not owner) then
                local nextState = CopyState(state)
                nextState.clearedAt = nowEpoch
                nextState.requestedAt = nil
                nextState.requestedBy = nil

                if state.waveType == 'horde1' or state.waveType == 'horde' then
                    -- Exactly two post-clear waves per cycle. Wave 2 starts only after
                    -- wave 1 has been fully cleared, with a short warning window.
                    local delaySeconds = math.max(0, math.floor((tonumber(CityConfig.betweenHordeWavesMs) or 45000) / 1000))
                    nextState.phase = 'wave2_wait'
                    nextState.wave2At = nowEpoch + delaySeconds
                    nextState.cooldownUntil = nil
                    print(('^3[fks-deadmoon]^7 City "%s": first horde cleared. Second wave in %d seconds.'):format(name, delaySeconds))
                else
                    -- Initial population and wave 2 both start the 15-minute cooldown.
                    nextState.phase = 'cooldown'
                    nextState.cooldownUntil = nowEpoch + cooldownSeconds
                    nextState.wave2At = nil
                    local clearedLabel = state.waveType == 'horde2' and 'second horde' or 'initial population'
                    print(('^3[fks-deadmoon]^7 City "%s": %s cleared. Next two-wave cycle starts in 15 minutes.'):format(name, clearedLabel))
                end

                states[name] = nextState
                state, phase, statesChanged = nextState, nextState.phase, true
            end
        elseif phase == 'cooldown' then
            local dueAt = tonumber(state.cooldownUntil)
            if not dueAt then
                local nextState = CopyState(state)
                nextState.cooldownUntil = nowEpoch + cooldownSeconds
                states[name] = nextState
                state, dueAt, statesChanged = nextState, nextState.cooldownUntil, true
            end
            if nowEpoch >= dueAt then
                local nextState = CopyState(state)
                nextState.phase = 'wave1_due'
                nextState.cooldownUntil = nil
                states[name] = nextState
                state, phase, statesChanged = nextState, 'wave1_due', true
                print(('^2[fks-deadmoon]^7 City "%s": 15-minute cooldown ended; first horde is due when a player approaches.'):format(name))
            end
        elseif phase == 'wave2_wait' then
            local dueAt = tonumber(state.wave2At)
            if not dueAt then
                local nextState = CopyState(state)
                nextState.wave2At = nowEpoch + math.max(0, math.floor((tonumber(CityConfig.betweenHordeWavesMs) or 45000) / 1000))
                states[name] = nextState
                state, dueAt, statesChanged = nextState, nextState.wave2At, true
            end
            if nowEpoch >= dueAt then
                local nextState = CopyState(state)
                nextState.phase = 'wave2_due'
                nextState.wave2At = nil
                states[name] = nextState
                state, phase, statesChanged = nextState, 'wave2_due', true
                print(('^2[fks-deadmoon]^7 City "%s": second horde is due when a player is nearby.'):format(name))
            end
        end

        if phase == 'cooldown' then blocked[name] = tonumber(state.cooldownUntil) end
        if phase == 'wave2_wait' then blocked[name] = tonumber(state.wave2At) end
        if phase ~= 'unseeded' then populated[name] = true end
    end

    if statesChanged then GlobalState.fksDeadmoonCityStates = states end
    if not SameMap(GlobalState.fksDeadmoonCityRespawnBlocked, blocked) then
        GlobalState.fksDeadmoonCityRespawnBlocked = blocked
    end
    if not SameMap(GlobalState.fksDeadmoonCityHasPopulated, populated) then
        GlobalState.fksDeadmoonCityHasPopulated = populated
    end
end

CreateThread(function()
    print('^2[fks-deadmoon]^7 TEOT city population coordinator 1.5.4 started: fixed city population, 15-minute clear cooldown, two hard horde waves.')
    while true do
        RefreshCityOwners()
        Wait(CityConfig.ownerRefreshInterval or 2000)
    end
end)

CreateThread(function()
    while true do
        RefreshCityCounts()
        Wait(CityConfig.countRefreshInterval or 1000)
    end
end)

---------------------------------------------------------------------------
-- TEOT rural encounter scheduler. Rural ambushes only happen outside a city's
-- full approach trigger, so they cannot create zombies behind a player who is
-- approaching or looting an infected town.
---------------------------------------------------------------------------
local ruralEncounterDue = {}

local function IsRuralPosition(p)
    local triggerDistance = tonumber(CityConfig.triggerDistance) or tonumber(RuralConfig.cityBuffer) or 300.0
    for _, city in ipairs(CityConfig.zones or {}) do
        local dx, dy, dz = p.x - city.coords.x, p.y - city.coords.y, p.z - city.coords.z
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        local radius = city.radius or 200.0

        -- Never run rural encounters inside the town itself.
        if dist <= radius then return false end

        -- An approach ring only suppresses wilderness encounters while its city
        -- population is active/due. Cooldown rings must not overlap into a dead zone.
        if dist <= radius + triggerDistance then
            local state = GetCityState(city.name)
            if (state.phase or 'unseeded') ~= 'cooldown' then
                return false
            end
        end
    end
    return true
end

CreateThread(function()
    print(('^2[fks-deadmoon]^7 TEOT rural encounters: %d min interval, %d%% horde chance.'):format(
        math.floor((tonumber(RuralConfig.interval) or 600000) / 60000),
        math.floor(tonumber(RuralConfig.hordeChance) or 40)
    ))
    while true do
        Wait(RuralConfig.checkInterval or 5000)
        local now = GetGameTimer()
        local candidates, visited = {}, {}

        if RuralConfig.enabled and GlobalState.fksDeadmoon then
            for src, p in pairs(positions) do
                if p.eligible and now - p.at <= (CityConfig.ownerStaleAfter or 8000) and IsRuralPosition(p) then
                    candidates[src] = p
                end
            end
        end

        for src, p in pairs(candidates) do
            if not visited[src] then
                local members = { src }
                visited[src] = true
                local clusterRadius = tonumber(RuralConfig.clusterRadius) or 180.0
                for other, op in pairs(candidates) do
                    if not visited[other] then
                        local dx, dy, dz = p.x - op.x, p.y - op.y, p.z - op.z
                        if math.sqrt(dx * dx + dy * dy + dz * dz) <= clusterRadius then
                            members[#members + 1] = other
                            visited[other] = true
                        end
                    end
                end

                local owner = members[1]
                for _, member in ipairs(members) do
                    if member < owner then owner = member end
                end
                for _, member in ipairs(members) do
                    if member ~= owner then ruralEncounterDue[member] = nil end
                end

                if not ruralEncounterDue[owner] then
                    ruralEncounterDue[owner] = now + (tonumber(RuralConfig.interval) or 600000)
                elseif now >= ruralEncounterDue[owner] then
                    local chance = math.max(0, math.min(100, tonumber(RuralConfig.hordeChance) or 40))
                    local isHorde = math.random(1, 100) <= chance
                    TriggerClientEvent('fks-deadmoon:client:ruralEncounter', owner, isHorde)
                    ruralEncounterDue[owner] = now + (tonumber(RuralConfig.interval) or 600000)
                    print(('^3[fks-deadmoon]^7 Rural encounter sent to %s (%s): %s.'):format(
                        GetPlayerName(owner) or '?', owner, isHorde and 'horde' or 'stalker'
                    ))
                end
            end
        end

        for src in pairs(ruralEncounterDue) do
            if not candidates[src] then ruralEncounterDue[src] = nil end
        end
    end
end)
