-- Compatibility (client): framework login state and notifications.

Bridge = {}

local function Started(res) return GetResourceState(res) == 'started' or GetResourceState(res) == 'starting' end

Framework = Config.Framework
if Framework == 'auto' then
    Framework = (Started('rsg-core') and 'rsg') or (Started('vorp_core') and 'vorp') or 'none'
end

-- is the character loaded / in session?
function Bridge.IsLoggedIn()
    if Framework == 'rsg' then return LocalPlayer.state.isLoggedIn == true end
    if Framework == 'vorp' then return LocalPlayer.state.IsInSession == true end
    return true
end

local rsgKinds = { inform = 'primary', error = 'error', success = 'success' }

function Bridge.Notify(msg, kind, ms)
    kind, ms = kind or 'inform', ms or 5000
    local mode = Config.Notify
    if mode == 'auto' then mode = Started('ox_lib') and 'ox' or Framework end
    if mode == 'ox' then
        TriggerEvent('ox_lib:notify', { title = _L('title'), description = msg, type = kind, duration = ms })
    elseif mode == 'vorp' then
        TriggerEvent('vorp:TipRight', msg, ms)
    elseif mode == 'rsg' then
        TriggerEvent('RSGCore:Notify', msg, rsgKinds[kind] or kind, ms)
    else
        print('[fks-deadmoon] ' .. msg)
    end
end

RegisterNetEvent('fks-deadmoon:client:notify', function(msg, kind, ms)
    Bridge.Notify(msg, kind, ms)
end)
