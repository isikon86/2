Utils = {}

-- TEOT 1.3.1: add more built-in RDR2 undead/corpse-style peds without replacing
-- the server owner's config.lua. Keep these as strings so the existing model
-- registry and server-side corpse checks continue to work unchanged.
local TEOTExtraZombieModels = {
}

-- model hash -> model name
ZombieModels = {}
for _, name in ipairs(Config.Zombies.models) do ZombieModels[joaat(name)] = name end

HeadBones = {}
for _, bone in ipairs(Config.Zombies.headBones) do HeadBones[bone] = true end

function Utils.IsZombieModel(hash)
    return ZombieModels[hash] ~= nil
end

-- '06:30' / 6 -> minutes of the day
function Utils.ToMinutes(t)
    if type(t) == 'number' then return math.floor(t * 60) end
    local h, m = tostring(t):match('^(%d+):?(%d*)$')
    return (tonumber(h) or 0) * 60 + (tonumber(m) or 0)
end

-- Is hh:mm inside the event window? (supports windows that cross midnight)
function Utils.InWindow(h, m)
    local now = h * 60 + (m or 0)
    local s, e = Utils.ToMinutes(Config.Time.start), Utils.ToMinutes(Config.Time.finish)
    if s == e then return false end
    if s < e then return now >= s and now < e end
    return now >= s or now < e
end

function Utils.InSafeZone(coords)
    for _, zone in ipairs(Config.SafeZones.zones) do
        if #(coords - zone.coords) <= zone.radius then return true, zone end
    end
    return false
end

function Utils.Debug(...)
    if Config.Debug then print('[fks-deadmoon]', ...) end
end
