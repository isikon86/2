-- Compatibility: framework (vorp / rsg) and inventory (vorp_inventory / rsg-inventory / ox_inventory).

Bridge = {}

local function Started(res) return GetResourceState(res) == 'started' or GetResourceState(res) == 'starting' end

local function Detect()
    local fw = Config.Framework
    if fw == 'auto' then
        fw = (Started('rsg-core') and 'rsg') or (Started('vorp_core') and 'vorp') or nil
    end
    local inv = Config.Inventory
    if inv == 'auto' then
        inv = (Started('ox_inventory') and 'ox_inventory')
            or (Started('rsg-inventory') and 'rsg-inventory')
            or (Started('vorp_inventory') and 'vorp_inventory') or nil
    end
    return fw, inv
end

Bridge.framework, Bridge.inventory = Detect()

local RSG, VORP

local function EnsureFramework()
    if RSG or VORP then return true end
    if not Bridge.framework then Bridge.framework = Detect() end
    if Bridge.framework == 'rsg' and GetResourceState('rsg-core') == 'started' then
        RSG = exports['rsg-core']:GetCoreObject()
    elseif Bridge.framework == 'vorp' and GetResourceState('vorp_core') == 'started' then
        VORP = exports.vorp_core:GetCore()
    end
    return RSG ~= nil or VORP ~= nil
end

function Bridge.Inv()
    if not Bridge.inventory then
        local _, inv = Detect()
        if inv and GetResourceState(inv) == 'started' then Bridge.inventory = inv end
    end
    return Bridge.inventory
end

-- Framework / inventory may start after us: wait up to 60 s, then run the ready callbacks
local readyCbs = {}
function Bridge.OnReady(cb) readyCbs[#readyCbs + 1] = cb end

CreateThread(function()
    local t = GetGameTimer() + 60000
    while GetGameTimer() < t do
        local inv = Bridge.Inv()
        if EnsureFramework() and inv and GetResourceState(inv) == 'started' then break end
        Wait(500)
    end
    if not Bridge.framework then print('^1[fks-deadmoon] No framework found (vorp_core / rsg-core). Set Config.Framework.^0') end
    if not Bridge.inventory then print('^1[fks-deadmoon] No inventory found. Set Config.Inventory.^0') end
    print(('[fks-deadmoon] framework: ^2%s^0 | inventory: ^2%s^0'):format(tostring(Bridge.framework), tostring(Bridge.inventory)))
    for _, cb in ipairs(readyCbs) do CreateThread(cb) end
end)

---------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------
function Bridge.Notify(src, msg, kind, ms)
    TriggerClientEvent('fks-deadmoon:client:notify', src, msg, kind, ms)
end

function Bridge.IsAdmin(src)
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, 'command.' .. Config.Command) then return true end
    EnsureFramework()
    if VORP then
        local user = VORP.getUser(src)
        local group = user and user.getGroup
        for _, g in ipairs(Config.AdminGroups) do if group == g then return true end end
    elseif RSG then
        for _, g in ipairs(Config.AdminGroups) do
            if RSG.Functions.HasPermission(src, g) then return true end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------
-- cb(src) when a player uses the item
function Bridge.RegisterUsable(item, cb)
    EnsureFramework()
    local INV = Bridge.Inv()
    if INV == 'vorp_inventory' then
        exports.vorp_inventory:registerUsableItem(item, function(data)
            pcall(function() exports.vorp_inventory:closeInventory(data.source) end)
            cb(data.source)
        end, GetCurrentResourceName())
    elseif RSG then
        -- rsg-inventory and ox_inventory (rsg bridge) use rsg-core usable items
        RSG.Functions.CreateUseableItem(item, function(src) cb(src) end)
    elseif INV == 'ox_inventory' then
        Bridge._oxUsable = Bridge._oxUsable or {}
        Bridge._oxUsable[item] = cb
    end
end

-- ox_inventory without rsg-core (e.g. vorp + ox)
AddEventHandler('ox_inventory:usedItem', function(src, name)
    if RSG then return end
    local cb = Bridge._oxUsable and Bridge._oxUsable[name]
    if cb then cb(src) end
end)

local function RsgItemBox(src, item, kind, n)
    if RSG and RSG.Shared and RSG.Shared.Items and RSG.Shared.Items[item] then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSG.Shared.Items[item], kind, n)
    end
end

function Bridge.ItemLabel(item)
    local INV = Bridge.Inv()
    local ok, label = pcall(function()
        if INV == 'ox_inventory' then
            local data = exports.ox_inventory:Items(item)
            return data and data.label
        elseif INV == 'vorp_inventory' then
            local data = exports.vorp_inventory:getItemDB(item)
            return data and data.label
        elseif RSG then
            return RSG.Shared.Items[item] and RSG.Shared.Items[item].label
        end
    end)
    return ok and label or item
end

function Bridge.CanCarry(src, item, n)
    local INV = Bridge.Inv()
    local ok, res = pcall(function()
        if INV == 'ox_inventory' then return exports.ox_inventory:CanCarryItem(src, item, n) end
        if INV == 'rsg-inventory' then return exports['rsg-inventory']:CanAddItem(src, item, n) end
        if INV == 'vorp_inventory' then return exports.vorp_inventory:canCarryItem(src, item, n) end
    end)
    if not ok or res == nil then return true end -- export missing: let AddItem decide
    return res and true or false
end

function Bridge.AddItem(src, item, n)
    n = n or 1
    local INV = Bridge.Inv()
    if INV == 'ox_inventory' then
        return exports.ox_inventory:AddItem(src, item, n) and true or false
    elseif INV == 'rsg-inventory' then
        local ok = exports['rsg-inventory']:AddItem(src, item, n, false, false, 'fks-deadmoon') and true or false
        if ok then RsgItemBox(src, item, 'add', n) end
        return ok
    elseif INV == 'vorp_inventory' then
        return exports.vorp_inventory:addItem(src, item, n) ~= false
    end
    return false
end

function Bridge.RemoveItem(src, item, n)
    n = n or 1
    local INV = Bridge.Inv()
    if INV == 'ox_inventory' then
        return exports.ox_inventory:RemoveItem(src, item, n) and true or false
    elseif INV == 'rsg-inventory' then
        local ok = exports['rsg-inventory']:RemoveItem(src, item, n, nil, 'fks-deadmoon') and true or false
        if ok then RsgItemBox(src, item, 'remove', n) end
        return ok
    elseif INV == 'vorp_inventory' then
        if (exports.vorp_inventory:getItemCount(src, nil, item) or 0) < n then return false end
        return exports.vorp_inventory:subItem(src, item, n) ~= false
    end
    return false
end
