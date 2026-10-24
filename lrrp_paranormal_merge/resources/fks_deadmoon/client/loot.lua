-- "Revistar" prompt on zombies killed with a headshot. The server rolls and gives the items.

local L = Config.Loot

local group = GetRandomIntInRange(0, 0xffffff)
local prompt
local corpse = nil
local busy = false

local function Var(text) return CreateVarString(10, 'LITERAL_STRING', text) end

CreateThread(function()
    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, L.key)
    PromptSetText(prompt, Var(_L('search')))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, true)
    PromptSetGroup(prompt, group, 0)
    PromptRegisterEnd(prompt)
end)

-- nearest corpse that can be searched
CreateThread(function()
    while true do
        corpse = nil
        local me = PlayerPedId()
        if not busy and not IsEntityDead(me) and not IsPedOnMount(me) and not IsPedInAnyVehicle(me, false) then
            local pos, best = GetEntityCoords(me), L.distance
            for _, ped in ipairs(GetGamePool('CPed')) do
                if Zombies.IsZombie(ped) and IsEntityDead(ped) then
                    local st = Entity(ped).state
                    if st.fksDown and not st.fksLooted then
                        local d = #(GetEntityCoords(ped) - pos)
                        if d <= best then corpse, best = ped, d end
                    end
                end
            end
        end
        Wait(corpse and 250 or 750)
    end
end)

local function Search(ped)
    busy = true
    local me = PlayerPedId()
    local mods = LocalPlayer and LocalPlayer.state and LocalPlayer.state.teotMods
    local multiplier = type(mods) == 'table' and tonumber(mods.searchTime) or 1.0
    multiplier = math.max(0.75, math.min(1.25, multiplier or 1.0))
    local duration = math.floor(L.searchTime * multiplier)
    Bridge.Notify(_L('searching'), 'inform', duration)
    local anim = PlayAnim(me, L.anim, duration)
    Wait(duration)
    if anim then ClearPedTasks(me) end
    if DoesEntityExist(ped) and not IsEntityDead(me) then
        TriggerServerEvent('fks-deadmoon:server:loot', NetworkGetNetworkIdFromEntity(ped))
    end
    busy = false
end

CreateThread(function()
    while true do
        if corpse and prompt and not busy then
            PromptSetActiveGroupThisFrame(group, Var(_L('zombie')), 0, 0, 0, 0)
            if PromptHasHoldModeCompleted(prompt) then
                local ped = corpse
                corpse = nil
                Search(ped)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and prompt then PromptDelete(prompt) end
end)
