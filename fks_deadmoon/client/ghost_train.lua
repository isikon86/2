-- A single elected client creates the shared native train so players do not
-- each create a duplicate. It is present every night from 00:00 to 03:00.

local T = Config.GhostTrain or {}
local train

local function currentHour()
    return GetClockHours()
end

local function inWindow(hour)
    local startHour = tonumber(T.startHour) or 0
    local endHour = tonumber(T.endHour) or 3
    if startHour == endHour then return false end
    if startHour < endHour then return hour >= startHour and hour < endHour end
    return hour >= startHour or hour < endHour
end

local function isController()
    local myId = GetPlayerServerId(PlayerId())
    local lowest
    for _, player in ipairs(GetActivePlayers()) do
        local id = GetPlayerServerId(player)
        if not lowest or id < lowest then lowest = id end
    end
    return lowest and myId == lowest
end

local function deleteTrain()
    if train and DoesEntityExist(train) then
        SetEntityAsMissionEntity(train, true, true)
        DeleteMissionTrain(train)
        DeleteEntity(train)
    end
    train = nil
end

local function spawnTrain()
    if train or not T.enabled or not T.route or not T.route[1] then return end
    local p = T.route[1]
    train = CreateMissionTrain(T.variation or 0, p.x, p.y, p.z, T.direction ~= false, false, false)
    if not train or train == 0 or not DoesEntityExist(train) then
        train = nil
        return
    end

    if NetworkRegisterEntityAsNetworked then pcall(NetworkRegisterEntityAsNetworked, train) end
    local speed = tonumber(T.cruiseSpeed) or 8.0
    SetTrainCruiseSpeed(train, speed)
    SetTrainSpeed(train, speed)
end

CreateThread(function()
    while true do
        if not T.enabled or not inWindow(currentHour()) or not isController() then
            deleteTrain()
        else
            spawnTrain()
            if train and DoesEntityExist(train) then
                local speed = tonumber(T.cruiseSpeed) or 8.0
                SetTrainCruiseSpeed(train, speed)
                SetTrainSpeed(train, speed)
                local last = T.route[#T.route]
                if last and #(GetEntityCoords(train) - last) <= (T.respawnDistance or 35.0) then
                    deleteTrain()
                end
            end
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then deleteTrain() end
end)
