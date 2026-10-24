-- Dead Moon weather (fog + "MP_Pred" variations), controlled by the independent night schedule.

Weather = {}

local W = Config.Weather
local loop = 0
Weather.active = false

local function SetWeather(name, transition)
    -- SET_WEATHER_TYPE(hash, p1, p2, overrideNetwork, transitionTime, p5)
    Citizen.InvokeNative(0x59174F1AFE095B5A, joaat(name), true, true, true, transition + 0.0, false)
end

local function Apply(transition)
    SetWeather(W.type, transition)
    for _, v in ipairs(W.variations) do
        Citizen.InvokeNative(0x3373779BAF7CAF48, v[1], v[2]) -- weather variation
    end
end

function Weather.Start()
    if Weather.active then return end

    Weather.active = true
    Apply(W.transition)

    if not W.reapply then return end

    loop = loop + 1
    local id = loop
    CreateThread(function()
        Wait(math.floor(W.transition * 1000))
        while Weather.active and loop == id do
            Apply(2.0) -- re-apply only while the night-weather state is active
            Wait(W.reapply)
        end
    end)
end

-- The variations can remain on the client after a resource restart, so always clear them.
local function ClearVariations()
    for _, v in ipairs(W.variations) do
        Citizen.InvokeNative(0x0E71C80FA4EC8147, v[1], true) -- _CLEAR_WEATHER_VARIATION
    end
end

function Weather.Stop()
    local wasActive = Weather.active
    Weather.active = false
    loop = loop + 1 -- cancel any running re-apply loop

    ClearVariations()

    -- Restore the configured weather when ending an active fog period.
    if wasActive then
        SetWeather(W.restore, W.restoreTransition)
    end

    -- Also clear leftover overrides after a resource restart.
    ClearOverrideWeather()
    ClearWeatherTypePersist()
end

-- Clean leftovers on join / resource restart without tying cleanup to zombie activity.
CreateThread(function()
    Wait(1500)
    if not Weather.active then
        ClearVariations()
    end
end)
