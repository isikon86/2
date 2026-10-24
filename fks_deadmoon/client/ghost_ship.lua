-- Standalone ship visuals for the single-resource fks_deadmoon build.
-- The zombie dungeon itself is handled by Config.CitySpawns in zombies.lua.

local S = Config.GhostShips or {}
local spawned = {}

local function isController()
    local myId = GetPlayerServerId(PlayerId())
    local lowest
    for _, player in ipairs(GetActivePlayers()) do
        local id = GetPlayerServerId(player)
        if not lowest or id < lowest then lowest = id end
    end
    return lowest and myId == lowest
end

local function loadModel(name)
    local hash = type(name) == 'number' and name or joaat(name)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function removeShip(index)
    local object = spawned[index]
    if object and DoesEntityExist(object) then
        SetEntityAsMissionEntity(object, true, true)
        DeleteEntity(object)
    end
    spawned[index] = nil
end

local function createShip(index, entry)
    local hash = loadModel(entry.model or S.model)
    if not hash then
        print(('[fks-deadmoon] ship model unavailable: %s'):format(tostring(entry.model or S.model)))
        return
    end

    local p = entry.coords
    local object = CreateObject(hash, p.x, p.y, p.z, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    if not object or object == 0 or not DoesEntityExist(object) then return end

    SetEntityAsMissionEntity(object, true, true)
    local r = entry.rotation or vector3(0.0, 0.0, 0.0)
    SetEntityRotation(object, r.x, r.y, r.z, 2, true)
    FreezeEntityPosition(object, true)
    if NetworkRegisterEntityAsNetworked then pcall(NetworkRegisterEntityAsNetworked, object) end
    spawned[index] = object
end

CreateThread(function()
    while true do
        if not S.enabled or not isController() then
            for index in pairs(spawned) do removeShip(index) end
        else
            for index, entry in ipairs(S.ships or {}) do
                if not spawned[index] or not DoesEntityExist(spawned[index]) then
                    createShip(index, entry)
                end
            end
        end
        Wait(5000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for index in pairs(spawned) do removeShip(index) end
end)
