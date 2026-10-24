local TEXTS = Config.Texts
local TEXTURES = Config.Textures
local notifSettings = {}
-----------------------------------------------------------------------------------------------------
local notifSettings = {
	[1] = {
		TEXTS.Stash, TEXTS.CantDo, TEXTURES.alert[1], TEXTURES.alert[2], 3000,
	},
	[2] = {
		TEXTS.Stash, TEXTS.AlreadyLooted, TEXTURES.alert[1], TEXTURES.alert[2], 3000,
	},
	[3] = {
		TEXTS.Stash, TEXTS.AddedItem, TEXTURES.alert[1], TEXTURES.alert[2], 3000,
	},
	[4] = {
		TEXTS.Stash, TEXTS.NothingFound, TEXTURES.alert[1], TEXTURES.alert[2], 3000,
	},
	--[[
	[] = {
		TEXTS.TEXT, TEXTS.Saved, TEXTURES.alert[1], TEXTURES.alert[2], 3000,
	},
]]
}

-----------------------------------------------------------------------------------------------------
function CallScriptNotif(id, extra)
	local _id = tonumber(id)
	local title = notifSettings[_id][1]
	local text = notifSettings[_id][2]
	local dict = notifSettings[_id][3]
	local texture = notifSettings[_id][4]
	local timer = notifSettings[_id][5]

------------------EXTRA CODE START------------------
	if extra ~= nil then 						 --|
		if extra.title ~= nil then 				 --|
			title = extra.title					 --|
		end									 	 --|
		if extra.text ~= nil then 				 --|
			text = extra.text					 --|
		end										 --|
		if extra.dict ~= nil then 				 --|
			dict = extra.dict					 --|
		end										 --|
		if extra.texture ~= nil then 			 --|
			texture = extra.texture				 --|
		end										 --|
		if extra.timer ~= nil then 				 --|
			timer = extra.timer					 --|
		end										 --|
	end											 --|
------------------EXTRA CODE END------------------
	TriggerEvent("Notification:ricx_ghostship", title, text, dict, texture, timer)--change this to a different notification logic if you want
end
-----------------------------------------------------------------------------------------------------
RegisterNetEvent("ricx_ghostship:call_notif", function(id, extra)
	local _id = tonumber(id)
	CallScriptNotif(_id, extra)
end)
----------------------------Basic Notification----------------------------
RegisterNetEvent('Notification:ricx_ghostship', function(t1, t2, dict, txtr, timer)
    local _dict = tostring(dict)
    PrepareTexture(_dict)
    exports.ricx_ghostship.LeftNot(0, tostring(t1), tostring(t2), tostring(dict), tostring(txtr), tonumber(timer))
    SetStreamedTextureDictAsNoLongerNeeded(_dict)
end)
--------------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function() -- RSG CORE
    TriggerServerEvent("ricx_ghostship:custom_load")
end)
--------------------------------------------------------------------------------------------------------------------------------------------
function EyeTarget(id, radius, pos, label)
	local zone = exports.ox_target:addSphereZone({
		coords = pos,
		radius = radius,
		options = {
			{
				name = "ghostship_"..id,
				icon = "fa-solid fa-circle",
				label = label,
				onSelect = function()
					searching = id
					TriggerServerEvent('ricx_ghostship:check_search', id)
				end
			},
		},
	})
	return zone
end
--------------------------------------------------------------------------------------------------------------------------------------------
function EyeTargetRemove(id)
	exports.ox_target:removeZone(id)
end
--------------------------------------------------------------------------------------------------------------------------------------------
