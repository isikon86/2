-- Server validation and extension hook for ghost-boss rewards.

local claimed = {}

local function validBoss(id)
    for _, boss in ipairs((Config.GhostBosses or {}).bosses or {}) do
        if boss.id == id then return true end
    end
    return false
end

RegisterNetEvent('fks-deadmoon:server:ghostBossDefeated', function(id)
    local src = source
    if type(id) ~= 'string' or not validBoss(id) then return end
    claimed[src] = claimed[src] or {}
    if claimed[src][id] then return end
    claimed[src][id] = os.time()

    -- Add VORP/RSG inventory code in a separate server resource if desired.
    TriggerEvent('fks-deadmoon:server:ghostBossReward', src, id)
    TriggerClientEvent('fks-deadmoon:client:ghostBossReward', src, id)
end)

AddEventHandler('playerDropped', function()
    claimed[source] = nil
end)
