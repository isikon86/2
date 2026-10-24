-- TEOT tier combat integration.
-- This resource only handles the jumper knockdown animation. It deliberately does not
-- apply scripted player damage, bleeding, health-core drain, or any medical status effects.
-- Native RedM melee damage from ordinary zombie attacks remains unchanged.
local function notify(message, kind)
    if Bridge and Bridge.Notify then
        Bridge.Notify(message, kind or 'inform', 6500)
    else
        TriggerEvent('vorp:TipRight', message, 6500)
    end
end

RegisterNetEvent('fks-deadmoon:client:jumperImpact', function(data)
    if type(data) ~= 'table' then return end

    local ped = PlayerPedId()
    if not ped or ped == 0 or IsEntityDead(ped) then return end

    local ragdollMs = math.max(700, math.min(3500, tonumber(data.ragdollMs) or 1600))
    pcall(SetPedToRagdoll, ped, ragdollMs, ragdollMs, 0, false, false, false)
    notify('Прыгун сбил тебя с ног!', 'error')
end)
