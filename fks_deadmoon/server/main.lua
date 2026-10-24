-- Event state, time source, headshots, tier combat knockdowns and looting.

local forced = nil              -- nil = follow the schedule | true / false = forced by an admin
local weatherForced = nil       -- nil = follow the seventh-day red-fog schedule
local clock = { h = nil, m = 0 } -- last clock reported by the clients (fallback when no weathersync export)
local lootCooldown = {}

GlobalState.fksDeadmoon = false
GlobalState.fksDeadmoonClock = false -- true = clients must report their game clock
GlobalState.fksDeadmoonWeather = false -- independent night-weather state

---------------------------------------------------------------------------
-- TEOT geographic tier tracking (does not alter zombie spawn scheduling)
---------------------------------------------------------------------------
local function TierPointInPolygon(pos, polygon)
    if type(polygon) ~= 'table' or #polygon < 3 then return false end
    local inside, j = false, #polygon
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

local function ServerTierAtPosition(pos)
    local tiers = Config.Tiers or {}
    if not tiers.enabled then return 'tier1' end
    local cityCfg = Config.CitySpawns
    local overrides = tiers.cityOverrides or {}
    local tier4, tier3 = {}, {}
    for _, name in ipairs(overrides.tier4 or {}) do tier4[name] = true end
    for _, name in ipairs(overrides.tier3 or {}) do tier3[name] = true end

    local regions = tiers.regions or {}
    for _, area in ipairs(regions.tier4Restricted or {}) do
        if TierPointInPolygon(pos, area.polygon) then return 'tier4' end
    end

    if cityCfg and cityCfg.enabled and type(cityCfg.zones) == 'table' then
        for _, city in ipairs(cityCfg.zones) do
            local c = city.coords
            if c then
                local dx, dy = pos.x - c.x, pos.y - c.y
                local radius = tonumber(city.radius) or 200.0
                if dx * dx + dy * dy <= radius * radius then
                    if tier3[city.name] then return 'tier3' end
                    if tier4[city.name] then return 'tier4' end
                end
            end
        end
    end

    if regions.tier1 and TierPointInPolygon(pos, regions.tier1.polygon) then return 'tier1' end
    if regions.tier2 and TierPointInPolygon(pos, regions.tier2.polygon) then return 'tier2' end
    return 'tier3'
end

local function IsLootRestrictedAt(pos)
    local regions = Config.Tiers and Config.Tiers.regions or {}
    for _, area in ipairs(regions.tier4Restricted or {}) do
        if TierPointInPolygon(pos, area.polygon) then return true, area.name end
    end
    return false, nil
end

RegisterNetEvent('fks-deadmoon:server:playerTierChanged', function(clientTier)
    local src = source
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    local pos = GetEntityCoords(ped)
    local tier = ServerTierAtPosition(pos)
    local player = Player(src)
    if player and player.state then
        player.state:set('fksPlayerTier', tier, true)
    end
end)


if not Config.Density.levels[Config.Density.default] then
    print(('^1[fks-deadmoon] Config.Density.default "%s" is not a level.^0'):format(tostring(Config.Density.default)))
end
GlobalState.fksDeadmoonDensity = Config.Density.default

local function DensityNames()
    local names = {}
    for name in pairs(Config.Density.levels) do names[#names + 1] = name end
    table.sort(names)
    return table.concat(names, ', ')
end

---------------------------------------------------------------------------
-- Time
---------------------------------------------------------------------------
-- weathersync's getTime() return value differs between versions: table or (h, m, s)
local function ParseTime(a, b)
    if type(a) == 'table' then
        local h = tonumber(a.hour or a.hours or a.h or a[1])
        local m = tonumber(a.minute or a.minutes or a.m or a[2]) or 0
        return h, m
    end
    return tonumber(a), tonumber(b) or 0
end

local function ExportTime()
    for _, res in ipairs(Config.Time.weatherSyncResources) do
        if GetResourceState(res) == 'started' then
            local ok, a, b = pcall(function() return exports[res]:getTime() end)
            if ok then
                local h, m = ParseTime(a, b)
                if h and h >= 0 and h < 24 then return math.floor(h), math.floor(m) end
            end
        end
    end
end

local function CurrentTime()
    if Config.Time.source == 'real' then
        local t = os.date('*t')
        return t.hour, t.min
    end
    local h, m = ExportTime()
    local needClients = h == nil
    if GlobalState.fksDeadmoonClock ~= needClients then GlobalState.fksDeadmoonClock = needClients end
    if h then return h, m end
    return clock.h, clock.m
end

-- Always use the synced in-game clock for the seven-day fog cadence, even if the
-- separate zombie schedule is later configured to use real-world time.
local function CurrentGameTime()
    local h, m = ExportTime()
    local needClients = h == nil
    if GlobalState.fksDeadmoonClock ~= needClients then GlobalState.fksDeadmoonClock = needClients end
    if h then return h, m end
    return clock.h, clock.m
end

-- Fallback clock: every player reports theirs (synced by weathersync). The time most players agree on wins,
-- so a single modified client can't start / stop the event.
local reports = {} -- [src] = { min = minute of the day, at = GetGameTimer() }

local function CircularGap(a, b)
    local d = math.abs(a - b) % 1440
    return math.min(d, 1440 - d)
end

local function ConsensusClock()
    local now, list = GetGameTimer(), {}
    for src, r in pairs(reports) do
        if now - r.at > 30000 then reports[src] = nil else list[#list + 1] = r.min end
    end
    local best, bestVotes = nil, 0
    for _, a in ipairs(list) do
        local votes = 0
        for _, b in ipairs(list) do if CircularGap(a, b) <= 3 then votes = votes + 1 end end
        if votes > bestVotes then best, bestVotes = a, votes end
    end
    if best then clock.h, clock.m = best // 60, best % 60 end
end

RegisterNetEvent('fks-deadmoon:server:clock', function(h, m)
    h, m = tonumber(h), tonumber(m) or 0
    if not h or h < 0 or h > 23 or m < 0 or m > 59 then return end
    reports[source] = { min = math.floor(h) * 60 + math.floor(m), at = GetGameTimer() }
    ConsensusClock()
end)

AddEventHandler('playerDropped', function() reports[source] = nil end)

---------------------------------------------------------------------------
-- Persistent in-game day counter for the scheduled red-fog event.
-- The game clock exposes hours/minutes, not a reliable server-wide calendar date,
-- so we count midnight transitions and persist both the counter and last observed minute.
local RED_FOG_DAY_KEY = 'teot_deadmoon_game_days_elapsed_v1'
local RED_FOG_MINUTE_KEY = 'teot_deadmoon_last_game_minute_v1'
local gameDaysElapsed = math.max(0, GetResourceKvpInt(RED_FOG_DAY_KEY) or 0)
local lastObservedGameMinute = tonumber(GetResourceKvpString(RED_FOG_MINUTE_KEY))

local function TrackGameDays(h, m)
    if h == nil then return gameDaysElapsed end
    local minute = math.floor(h) * 60 + math.floor(m or 0)

    if lastObservedGameMinute == nil then
        -- First-ever observation starts the calendar; it does not falsely count a day.
        lastObservedGameMinute = minute
        SetResourceKvp(RED_FOG_MINUTE_KEY, tostring(minute))
        print(('[fks-deadmoon] red-fog calendar initialized at game time %02d:%02d; day counter=%d'):format(h, m or 0, gameDaysElapsed))
        return gameDaysElapsed
    end

    if minute ~= lastObservedGameMinute then
        -- Midnight wrap guard: ordinary clock changes don't count as a new day.
        if lastObservedGameMinute >= (22 * 60) and minute <= (2 * 60) then
            gameDaysElapsed = gameDaysElapsed + 1
            SetResourceKvpInt(RED_FOG_DAY_KEY, gameDaysElapsed)
            print(('[fks-deadmoon] in-game day %d reached; red fog interval=%d game days'):format(
                gameDaysElapsed,
                math.max(1, tonumber(Config.Weather.redFogEvent and Config.Weather.redFogEvent.everyGameDays) or 7)
            ))
        end
        lastObservedGameMinute = minute
        SetResourceKvp(RED_FOG_MINUTE_KEY, tostring(minute))
    end

    return gameDaysElapsed
end

---------------------------------------------------------------------------
-- Time-window helper used by the scheduled red-fog event.
-- The event window may cross midnight (for example, 22:00-06:00).
if not Utils.InWindowRange then
    function Utils.InWindowRange(h, m, startTime, finishTime)
        local now = h * 60 + (m or 0)
        local startMinute = Utils.ToMinutes(startTime)
        local finishMinute = Utils.ToMinutes(finishTime)

        if startMinute == finishMinute then return false end
        if startMinute < finishMinute then
            return now >= startMinute and now < finishMinute
        end
        return now >= startMinute or now < finishMinute
    end
end

---------------------------------------------------------------------------
-- Event on / off
---------------------------------------------------------------------------
local function CleanupZombies()
    for _, ent in ipairs(GetAllPeds()) do
        if DoesEntityExist(ent) and Utils.IsZombieModel(GetEntityModel(ent)) and Entity(ent).state.fksZombie then
            DeleteEntity(ent)
        end
    end
end

local function SetActive(on)
    GlobalState.fksDeadmoon = on
    print(('[fks-deadmoon] event %s'):format(on and '^2started^0' or '^3ended^0'))
    Bridge.Notify(-1, _L(on and 'started' or 'ended'), on and 'error' or 'success', 8000)
    local hook = on and Config.OnStart or Config.OnEnd
    if hook then
        local ok, err = pcall(hook)
        if not ok then print('^1[fks-deadmoon] ' .. (on and 'OnStart' or 'OnEnd') .. ' error: ' .. tostring(err) .. '^0') end
    end
    if not on then
        lootCooldown = {}
        -- clients delete the zombies they own; whatever is left is removed here
        SetTimeout(15000, function() if not GlobalState.fksDeadmoon then CleanupZombies() end end)
    end
end

local function Tick()
    local active

    if forced ~= nil then
        -- Admin /deadmoon on|off overrides the automatic mode.
        active = forced
    elseif Config.Time.alwaysOn == true then
        -- TEOT: keep the zombie event active throughout the in-game day and night.
        active = true
    else
        local h, m = CurrentTime()
        if h == nil then return end -- clock still unknown
        active = Utils.InWindow(h, m)
    end

    if active ~= GlobalState.fksDeadmoon then SetActive(active) end
end

-- Weather is scheduled independently from zombie activity. The red fog runs only
-- during the configured night window on every Nth tracked in-game day.
local function TickWeather()
    local schedule = Config.Weather and Config.Weather.redFogEvent
    local active = false

    if weatherForced ~= nil then
        active = weatherForced
    elseif schedule and schedule.enabled then
        local h, m = CurrentGameTime()
        if h == nil then return end -- clock still unknown; retry on the next tick

        local elapsed = TrackGameDays(h, m)
        local interval = math.max(1, math.floor(tonumber(schedule.everyGameDays) or 7))
        local inWindow = Utils.InWindowRange
            and Utils.InWindowRange(h, m, schedule.start, schedule.finish)
            or false

        if inWindow then
            local now = h * 60 + (m or 0)
            local startMinute = Utils.ToMinutes(schedule.start)
            local finishMinute = Utils.ToMinutes(schedule.finish)
            local eventDay = elapsed

            -- For a window that crosses midnight, the early-morning tail belongs to
            -- the event that began on the previous in-game day.
            if startMinute > finishMinute and now < finishMinute then
                eventDay = elapsed - 1
            end

            active = eventDay > 0 and (eventDay % interval == 0)
        end
    end

    if active ~= GlobalState.fksDeadmoonWeather then
        GlobalState.fksDeadmoonWeather = active
        print(('[fks-deadmoon] red fog event %s | in-game days elapsed: %d'):format(
            active and '^2started^0' or '^3ended^0', gameDaysElapsed
        ))
    end
end

CreateThread(function()
    Wait(2000)
    CleanupZombies() -- leftovers from a restart
    while true do
        Tick()
        TickWeather()
        Wait(Config.Time.checkInterval)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    CleanupZombies()
end)

---------------------------------------------------------------------------
-- Hordes
---------------------------------------------------------------------------
local hordeCooldown = {} -- [src] = GetGameTimer() when the player can get another horde

local function SendHorde(src)
    hordeCooldown[src] = GetGameTimer() + Config.Horde.cooldown
    TriggerClientEvent('fks-deadmoon:client:horde', src)
    print(('[fks-deadmoon] horde sent to %s (%s)'):format(GetPlayerName(src) or '?', src))
end

CreateThread(function()
    while true do
        Wait(Config.Horde.checkInterval)
        local level = Config.Density.levels[GlobalState.fksDeadmoonDensity]
        local chance = level and level.hordeChance or 0
        if Config.Horde.enabled and Config.Horde.randomEnabled ~= false and GlobalState.fksDeadmoon and chance > 0 then
            local now = GetGameTimer()
            for _, id in ipairs(GetPlayers()) do
                local src = tonumber(id)
                -- math.random() * 100 so decimal chances (0.5%) work
                if now >= (hordeCooldown[src] or 0) and math.random() * 100 < chance then SendHorde(src) end
            end
        end
    end
end)

AddEventHandler('playerDropped', function() hordeCooldown[source] = nil end)

---------------------------------------------------------------------------
-- Admin command
---------------------------------------------------------------------------
local function Reply(src, msg)
    if src == 0 then print('[fks-deadmoon] ' .. msg) else Bridge.Notify(src, msg, 'inform', 6000) end
end

local function Status(src)
    local h, m = CurrentTime()
    Reply(src, _L('cmd_status',
        _L(GlobalState.fksDeadmoon and 'cmd_on' or 'cmd_off'),
        forced == nil and 'auto' or (forced and 'on' or 'off'),
        h and ('%02d:%02d'):format(h, m or 0) or '?',
        tostring(GlobalState.fksDeadmoonDensity)))
    local interval = math.max(1, math.floor(tonumber(Config.Weather.redFogEvent and Config.Weather.redFogEvent.everyGameDays) or 7))
    local remainder = gameDaysElapsed % interval
    local daysUntilFog = (remainder == 0 and gameDaysElapsed > 0) and 0 or (interval - remainder)
    Reply(src, _L('fog_status', tostring(gameDaysElapsed), tostring(daysUntilFog)))
end

RegisterCommand(Config.Command, function(src, args)
    if not Bridge.IsAdmin(src) then return end
    local a = (args[1] or ''):lower()

    if a == 'densidade' or a == 'density' then
        local level = (args[2] or ''):lower()
        if not Config.Density.levels[level] then return Reply(src, _L('density_bad', DensityNames())) end
        GlobalState.fksDeadmoonDensity = level
        return Reply(src, _L('density_set', level))
    end

    if a == 'horda' or a == 'horde' then
        if not GlobalState.fksDeadmoon then return Reply(src, _L('horde_off')) end
        local target = tonumber(args[2]) or src
        if target == 0 or not GetPlayerName(target) then return Reply(src, _L('no_player')) end
        SendHorde(target)
        return Reply(src, _L('horde_sent', target))
    end

    if a == 'som' or a == 'sound' then
        if src == 0 then return end
        print(('[fks-deadmoon] sound test requested by %s (%s)'):format(GetPlayerName(src) or '?', src))
        return TriggerClientEvent('fks-deadmoon:client:testSound', src)
    end

    if a == 'ghost' or a == 'ghosts' then
        local mode = (args[2] or 'auto'):lower()
        if mode == 'test' then
            local id = args[3]
            TriggerClientEvent('fks-deadmoon:client:ghostTest', src, id)
            return Reply(src, ('ghost test: %s'):format(id or 'first boss'))
        elseif mode == 'on' then
            weatherForced = true
        elseif mode == 'off' then
            weatherForced = false
        elseif mode == 'auto' then
            weatherForced = nil
            TriggerClientEvent('fks-deadmoon:client:ghostTestClear', src)
        else
            return Reply(src, '/deadmoon ghost on | off | auto | test [id]')
        end
        TickWeather()
        return Reply(src, ('ghost event: %s'):format(weatherForced == nil and 'auto' or (weatherForced and 'on' or 'off')))
    end

    if a == 'on' then forced = true
    elseif a == 'off' then forced = false
    elseif a == 'auto' then forced = nil; weatherForced = nil
    elseif a ~= 'status' then return Reply(src, _L('cmd_help')) end
    Tick()
    Status(src)
end, false)

---------------------------------------------------------------------------
-- Zombies
---------------------------------------------------------------------------
local function GetZombie(netId)
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    if not Utils.IsZombieModel(GetEntityModel(ent)) or not Entity(ent).state.fksZombie then return nil end
    return ent
end

local function Dist(src, ent)
    return #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ent))
end

-- A client that killed a zombie with a headshot tells the server (the owner of the zombie may be someone else)
local lastHeadshot = {} -- [src] = GetGameTimer() (flood guard)

RegisterNetEvent('fks-deadmoon:server:headshot', function(netId)
    local src = source
    local now = GetGameTimer()
    if lastHeadshot[src] and now - lastHeadshot[src] < 250 then return end
    lastHeadshot[src] = now
    local ent = GetZombie(netId)
    -- only a zombie that is really down, within weapon range of the shooter
    if not ent or GetEntityHealth(ent) > 0 or Dist(src, ent) > 300.0 then return end
    Entity(ent).state:set('fksHead', true, true)
end)

AddEventHandler('playerDropped', function() lastHeadshot[source] = nil end)


-- Server-validated jumper impact. The zombie resource only requests a knockdown; medical effects belong to a separate resource.
local jumperHitCooldown = {}
RegisterNetEvent('fks-deadmoon:server:jumperHit', function(netId, targetId)
    local src = source
    local ent = GetZombie(netId)
    targetId = tonumber(targetId)
    if not ent or not targetId or not GetPlayerName(targetId) then return end
    local st = Entity(ent).state
    if st.fksJumper ~= true or st.fksDown or IsEntityDead(ent) then return end
    if NetworkGetEntityOwner(ent) ~= src then return end

    local victim = GetPlayerPed(targetId)
    if not victim or victim == 0 or not DoesEntityExist(victim) or IsEntityDead(victim) then return end
    if #(GetEntityCoords(ent) - GetEntityCoords(victim)) > (tonumber(Config.Tiers and Config.Tiers.jumpServerDistance) or 3.8) then return end

    local now = GetGameTimer()
    local key = tostring(tonumber(netId) or 0) .. ':' .. tostring(targetId)
    if jumperHitCooldown[key] and now - jumperHitCooldown[key] < 6000 then return end
    jumperHitCooldown[key] = now
    SetTimeout(30000, function() jumperHitCooldown[key] = nil end)

    local tier = Config.Tiers and Config.Tiers.levels and Config.Tiers.levels[st.fksTier or 'tier2'] or {}
    local attack = tier.jumpAttack or {}
    TriggerClientEvent('fks-deadmoon:client:jumperImpact', targetId, {
        ragdollMs = tonumber(attack.ragdollMs) or 1600,
        tier = st.fksTier or 'tier2'
    })
end)

-- Groans: the owner of the zombie asks, the server picks the file + pitch and sends the SAME groan
-- at the same moment to every player in range (so everyone nearby hears it together).
local lastGroan = {} -- [src] = GetGameTimer() of the last request (flood guard)

RegisterNetEvent('fks-deadmoon:server:groan', function(netId)
    local src = source
    local SND = Config.Sounds
    if not SND.enabled or #SND.files == 0 then return end
    local now = GetGameTimer()
    if lastGroan[src] and now - lastGroan[src] < 100 then return end
    lastGroan[src] = now

    local ent = GetZombie(netId)
    if not ent then return Utils.Debug('groan: not a zombie', netId) end
    if NetworkGetEntityOwner(ent) ~= src then return Utils.Debug('groan: not the owner', netId, src) end

    local file = SND.files[math.random(#SND.files)]
    local rate = SND.pitch.min + math.random() * (SND.pitch.max - SND.pitch.min)
    local pos = GetEntityCoords(ent)
    local sent = 0
    for _, id in ipairs(GetPlayers()) do
        local p = tonumber(id)
        if #(GetEntityCoords(GetPlayerPed(p)) - pos) <= SND.distance then
            TriggerClientEvent('fks-deadmoon:client:groan', p, netId, file, rate)
            sent = sent + 1
        end
    end
    Utils.Debug(('groan %s -> %d player(s)'):format(netId, sent))
end)

AddEventHandler('playerDropped', function() lastGroan[source] = nil end)

-- /deadmoon som: each step of the test is written to the server console (easier to diagnose)
RegisterNetEvent('fks-deadmoon:server:soundReport', function(msg)
    print(('[fks-deadmoon] sound test (%s): %s'):format(source, tostring(msg):sub(1, 200)))
end)

local function GetPerkModifier(src, key, fallback)
    if GetResourceState('teot_perks') ~= 'started' then return fallback end
    local ok, value = pcall(function()
        return exports.teot_perks:GetModifier(src, key, fallback)
    end)
    if ok and tonumber(value) then return tonumber(value) end
    return fallback
end

local function RollLoot(src, tierName)
    local L = Config.Loot
    local tier = Config.Tiers and Config.Tiers.levels and Config.Tiers.levels[tierName or 'tier1'] or {}
    local bonusLoot = math.max(0, math.min(25, GetPerkModifier(src, 'bonusLoot', 0)))
    -- Higher tiers are more rewarding but their zombies are harder to kill.
    if math.random(100) <= (tonumber(tier.emptyChance) or L.emptyChance) then return {} end
    local pool = {}
    for _, it in ipairs(L.items) do pool[#pool + 1] = it end
    for _, it in ipairs(tier.lootItems or {}) do pool[#pool + 1] = it end
    for i = #pool, 2, -1 do local j = math.random(i) pool[i], pool[j] = pool[j], pool[i] end
    local out = {}
    local maxItems = L.maxItems + (tonumber(tier.extraLootSlots) or 0) + (math.random(100) <= bonusLoot and 1 or 0)
    for _, it in ipairs(pool) do
        if #out >= maxItems then break end
        if math.random(100) <= it.chance then
            out[#out + 1] = { item = it.item, amount = math.random(it.min or 1, it.max or it.min or 1) }
        end
    end
    return out
end

RegisterNetEvent('fks-deadmoon:server:loot', function(netId)
    local src = source
    local now = GetGameTimer()
    if lootCooldown[src] and now < lootCooldown[src] then return end
    lootCooldown[src] = now + 1500

    local ent = GetZombie(netId)
    if not ent then return end
    local st = Entity(ent).state
    if not st.fksDown then return end
    if st.fksLooted then return Bridge.Notify(src, _L('already_looted'), 'error') end
    if Dist(src, ent) > Config.Loot.distance + 3.0 then return end

    local restricted, regionName = IsLootRestrictedAt(GetEntityCoords(ent))
    if restricted then
        st:set('fksLooted', true, true)
        return Bridge.Notify(src, ('В регионе %s добыча с заражённых недоступна.'):format(regionName or 'ограниченном'), 'inform')
    end

    st:set('fksLooted', true, true)

    local got = {}
    for _, drop in ipairs(RollLoot(src, st.fksTier)) do
        local label = Bridge.ItemLabel(drop.item)
        if Bridge.CanCarry(src, drop.item, drop.amount) and Bridge.AddItem(src, drop.item, drop.amount) then
            got[#got + 1] = ('%dx %s'):format(drop.amount, label)
        else
            Bridge.Notify(src, _L('inv_full', label), 'error')
        end
    end
    if #got > 0 then
        Bridge.Notify(src, _L('found', table.concat(got, ', ')), 'success')
    else
        Bridge.Notify(src, _L('found_nothing'), 'inform')
    end
end)

AddEventHandler('playerDropped', function() lootCooldown[source] = nil end)
