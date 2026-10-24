local defeated = {}

local function validBoss(id)
    for _, boss in ipairs(Config.GhostBosses or {}) do
        if boss.id == id then return true end
    end
    return false
end

RegisterNetEvent('lrrp_paranormal_merge:bossDefeated', function(id)
    local src = source
    if type(id) ~= 'string' or not validBoss(id) then return end

    defeated[src] = defeated[src] or {}
    if defeated[src][id] then return end
    defeated[src][id] = os.time()

    -- Framework-specific rewards belong in the server that owns the inventory.
    -- This hook is intentionally safe to override from another resource.
    TriggerEvent('lrrp_paranormal_merge:rewardBoss', src, id)
    TriggerClientEvent('lrrp_paranormal_merge:bossReward', src, id)
end)

AddEventHandler('playerDropped', function()
    defeated[source] = nil
end)
