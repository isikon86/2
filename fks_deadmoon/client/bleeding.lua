-- Bites (zombie stuck to the player) and bleeding until a Rags item is used.

local B, BL = Config.Bite, Config.Bleeding

local bleeding = false
local nextBite = 0

local function SetBleeding(on)
    if bleeding == on then return end
    bleeding = on
    LocalPlayer.state:set('fksBleeding', on, true) -- the server checks it before using the Rags
    if BL.screenEffect then
        if on then AnimpostfxPlay(BL.screenEffect) else AnimpostfxStop(BL.screenEffect) end
    end
end

RegisterNetEvent('fks-deadmoon:client:forceBleeding', function()
    if not IsEntityDead(PlayerPedId()) then SetBleeding(true) end
end)

local function Hurt(ped, amount)
    SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - amount), 0)
end

local function ZombieOnMe(me)
    local pos = GetEntityCoords(me)
    for _, ped in ipairs(GetGamePool('CPed')) do
        if Zombies.IsZombie(ped) and Zombies.IsThreat(ped) and #(GetEntityCoords(ped) - pos) <= B.distance then
            return true
        end
    end
    return false
end

-- bites
CreateThread(function()
    while true do
        Wait(B.tick)
        local me = PlayerPedId()
        if Deadmoon.active and not IsEntityDead(me) and not (B.ignoreMounted and IsPedOnMount(me)) and ZombieOnMe(me) then
            Hurt(me, B.damage)
            local now = GetGameTimer()
            if now >= nextBite then
                nextBite = now + B.cooldown
                if not bleeding and math.random(100) <= B.bleedChance then
                    SetBleeding(true)
                    Bridge.Notify(_L('bitten'), 'error', 7000)
                end
            end
        end
    end
end)

-- bleeding (keeps going after the event ends, until Rags or death)
CreateThread(function()
    while true do
        Wait(BL.interval)
        if bleeding then
            local me = PlayerPedId()
            if IsEntityDead(me) then
                SetBleeding(false)
            else
                if BL.drainCore and BL.drainCore > 0 then -- stops the health core from refilling the health
                    local core = Citizen.InvokeNative(0x36731AC041289BB1, me, 0, Citizen.ResultAsInteger())
                    Citizen.InvokeNative(0xC6258F41D86676E0, me, 0, math.max(0, (core or 0) - BL.drainCore))
                end
                Hurt(me, BL.damage)
            end
        end
    end
end)

-- Rags: 1) the server allows it -> animation + progress bar -> 2) the server removes the item -> 3) stop bleeding
local bandaging = false

RegisterNetEvent('fks-deadmoon:client:bandage', function()
    local me = PlayerPedId()
    local mounted = IsPedOnMount(me) or IsPedInAnyVehicle(me, false)
    if bandaging or IsEntityDead(me) or IsPedSwimming(me) or IsPedRagdoll(me) or (mounted and not BL.allowMounted) then
        Bridge.Notify(_L('cant_now'), 'error')
        return TriggerServerEvent('fks-deadmoon:server:bandage', false)
    end

    bandaging = true
    SetCurrentPedWeapon(me, joaat('WEAPON_UNARMED'), true, 0, false, false)
    Wait(150)
    local anim = PlayAnim(me, BL.anim, -1)

    local done = Progress(BL.useTime, _L('bandaging'), BL.canCancel, function()
        return IsEntityDead(me) or IsPedRagdoll(me) or IsPedSwimming(me)
    end)

    if anim then ClearPedTasks(me) end
    bandaging = false
    if not done and not IsEntityDead(me) then Bridge.Notify(_L('cancelled'), 'error', 2500) end
    TriggerServerEvent('fks-deadmoon:server:bandage', done)
end)

RegisterNetEvent('fks-deadmoon:client:bandaged', function()
    local me = PlayerPedId()
    if IsEntityDead(me) then return end
    SetBleeding(false)
    if BL.healOnUse > 0 then SetEntityHealth(me, math.min(GetEntityMaxHealth(me), GetEntityHealth(me) + BL.healOnUse), 0) end
    Bridge.Notify(_L('bleeding_stop'), 'success')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then SetBleeding(false) end
end)
