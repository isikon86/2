-- Zombie groans (NUI / Web Audio). The server sends the same groan (file + pitch) at the same moment to every
-- player near the zombie; each client sets the volume by distance and the left/right side from the camera,
-- and keeps following the zombie while the sound plays.

local SND = Config.Sounds
local active = {} -- [id] = { ent, pos, untilT }
local nextId = 0

-- volume (0..1) and pan (-1 left .. 1 right) of a sound at `pos` for the local player
local function Mix(pos)
    local cam = GetGameplayCamCoord()
    local d = #(GetEntityCoords(PlayerPedId()) - pos)
    if d >= SND.distance then return 0.0, 0.0 end
    local f = 1.0 - d / SND.distance
    local volume = SND.volume * f * f

    local heading = math.rad(GetGameplayCamRot(2).z)
    local dx, dy = pos.x - cam.x, pos.y - cam.y
    local len = math.sqrt(dx * dx + dy * dy)
    local pan = 0.0
    if len > 0.5 then
        -- camera right vector = (cos h, sin h)
        pan = (dx * math.cos(heading) + dy * math.sin(heading)) / len
        pan = math.max(-1.0, math.min(1.0, pan)) * 0.8 -- never fully on one ear
    end
    return volume, pan
end

RegisterNetEvent('fks-deadmoon:client:groan', function(netId, file, rate)
    if not SND.enabled or not NetworkDoesNetworkIdExist(netId) then return Utils.Debug('groan: unknown netId', netId) end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(ent) then return Utils.Debug('groan: entity not found', netId) end

    local pos = GetEntityCoords(ent)
    local volume, pan = Mix(pos)
    Utils.Debug(('groan %s | %s | vol %.2f pan %.2f'):format(netId, file, volume, pan))
    if volume <= 0.0 then return end

    nextId = nextId + 1
    active[nextId] = { ent = ent, pos = pos, untilT = GetGameTimer() + SND.maxDuration }
    SendNUIMessage({ action = 'play', id = nextId, file = file, rate = rate, volume = volume, pan = pan })
end)

-- follow the zombies / the camera while the sounds play
CreateThread(function()
    while true do
        if next(active) then
            local now = GetGameTimer()
            for id, s in pairs(active) do
                if now > s.untilT then
                    active[id] = nil
                else
                    if DoesEntityExist(s.ent) then s.pos = GetEntityCoords(s.ent) end
                    local volume, pan = Mix(s.pos)
                    SendNUIMessage({ action = 'update', id = id, volume = volume, pan = pan })
                end
            end
            Wait(100)
        else
            Wait(500)
        end
    end
end)

-- /deadmoon som: plays the first sound at full volume and reports where it fails
RegisterNetEvent('fks-deadmoon:client:testSound', function()
    TriggerServerEvent('fks-deadmoon:server:soundReport', 'client received the test (client/sounds.lua is loaded)')
    Bridge.Notify(_L('sound_test'), 'inform', 3000)
    SendNUIMessage({ action = 'play', id = -1, test = true, file = SND.files[1], rate = 1.0, volume = SND.volume, pan = 0.0 })
end)

RegisterNUICallback('soundState', function(data, cb)
    cb('ok')
    local result = ('NUI result: ok=%s AudioContext=%s %s'):format(tostring(data.ok), tostring(data.state), tostring(data.error))
    print('[fks-deadmoon] sound test ' .. result)
    TriggerServerEvent('fks-deadmoon:server:soundReport', result)
    if data.ok then
        Bridge.Notify(_L('sound_ok'), 'success', 5000)
    else
        Bridge.Notify(_L('sound_fail', tostring(data.error)), 'error', 8000)
    end
end)

CreateThread(function()
    Wait(2000)
    if SND.enabled then SendNUIMessage({ action = 'preload', files = SND.files }) end
end)
