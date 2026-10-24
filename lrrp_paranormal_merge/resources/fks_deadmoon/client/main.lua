-- Follows zombie event state and independent night-weather state.
-- TEOT: zombies may stay active 24/7 while Dead Moon weather is night-only.

Deadmoon = { active = false }

math.randomseed(GetGameTimer())

function Deadmoon.SetActive(on)
    if on == Deadmoon.active then return end
    Deadmoon.active = on

    -- Weather is deliberately NOT controlled here.
    -- Zombie activity and weather now have independent state bags.
    if not on then
        Zombies.Clear()
    end
end

AddStateBagChangeHandler('fksDeadmoon', 'global', function(_, _, value)
    Deadmoon.SetActive(value == true)
end)

AddStateBagChangeHandler('fksDeadmoonWeather', 'global', function(_, _, value)
    if value == true then
        Weather.Start()
    else
        Weather.Stop()
    end
end)

CreateThread(function()
    Wait(1000)

    -- Restore current zombie state after a resource restart / player join.
    if GlobalState.fksDeadmoon then
        Deadmoon.SetActive(true)
    end

    -- Restore the correct weather state independently of the zombie state.
    if GlobalState.fksDeadmoonWeather then
        Weather.Start()
    else
        Weather.Stop()
    end
end)

-- No weathersync export on the server: the clients send their (synced) clock.
CreateThread(function()
    while true do
        Wait(10000)
        if GlobalState.fksDeadmoonClock and Bridge.IsLoggedIn() then
            TriggerServerEvent('fks-deadmoon:server:clock', GetClockHours(), GetClockMinutes())
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end

    -- Always clean up weather independently of whether zombies are active.
    Weather.Stop()

    if Deadmoon.active then
        Zombies.Clear()
    end
end)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
function PlayAnim(ped, anim, ms)
    if not anim or not anim.dict then return false end
    RequestAnimDict(anim.dict)
    local t = GetGameTimer() + 2000
    while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < t do Wait(50) end
    if not HasAnimDictLoaded(anim.dict) then return false end
    TaskPlayAnim(ped, anim.dict, anim.name, 4.0, -4.0, ms or -1, anim.flag or 1, 0.0, false, false, false)
    return true
end

-- Progress bar: ox_lib > vorp_progressbar > simple bar drawn here. Returns true if it reached the end.
-- `stop()` is checked every frame and fails the bar when it returns true (death, ragdoll...).
local function Started(res) return GetResourceState(res) == 'started' end

-- waits `ms` checking stop() every frame; draw = also draws a simple bar
local function SimpleBar(ms, stop, draw)
    local t0 = GetGameTimer()
    while GetGameTimer() - t0 < ms do
        if stop() then return false end
        if draw then
            local p = (GetGameTimer() - t0) / ms
            DrawRect(0.5, 0.92, 0.2, 0.012, 0, 0, 0, 160, false, false)
            DrawRect(0.4 + 0.1 * p, 0.92, 0.2 * p, 0.012, 150, 20, 20, 220, false, false)
        end
        Wait(0)
    end
    return true
end

function Progress(ms, label, canCancel, stop)
    local mode = Config.Progress
    if mode == 'auto' then
        mode = (Started('ox_lib') and 'ox') or (Started('vorp_progressbar') and 'vorp') or 'simple'
    end

    if mode == 'ox' then
        local failed = false
        CreateThread(function()
            Wait(0) -- let the bar start
            while exports.ox_lib:progressActive() do
                if stop() then failed = true exports.ox_lib:cancelProgress() break end
                Wait(100)
            end
        end)
        local done = exports.ox_lib:progressBar({
            duration = ms, label = label, useWhileDead = false, canCancel = canCancel,
            disable = { combat = true, sprint = true },
        })
        return done and not failed
    end

    if mode == 'vorp' then
        local p = promise.new()
        exports.vorp_progressbar:initiate().start(label, ms, function() p:resolve(true) end, 'linear')
        local ok = SimpleBar(ms, stop, false) -- vorp draws its own bar, here we only watch stop()
        return ok and Citizen.Await(p)
    end

    return SimpleBar(ms, stop, true)
end
