local WebhookConfig = {
	[1] = {
		webhook = "",
		botname = "RicX Ghost Ships: Looted Stash",
		icon_url = "https://raw.githubusercontent.com/abdulkadiraktas/rdr3_discoveries/master/useful_info_from_rpfs/textures/pm_awards_mp/images/pm_awards_mp/awards_set_r_007.png",
		color = 15248975,
	},   
}

function ScriptWH(id, wd)
    wd.title = "Information"
    local timestamp = createTimestamp()
	local wh = WebhookConfig[id]

    local _source = wd.source 
	local discord = GetPlayerIdentifierByType(_source, "discord")
	if discord then 
		discord = string.gsub(discord, "discord:", "")
		wd.description = wd.description.."\n".."Discord ID: <@"..discord..">"
	end	

    local embeds = {
        {
            author = {
                name = wh.botname,
                icon_url = wh.icon_url,
            },
            color = wh.color,
            title = wd.title,
            description = wd.description,
            footer = {
                text= wh.botname,
            },
            fields = {
                {
                    name = "Server Date",
                    value = timestamp,
                    inline = true
                }
            }
        },
    }
    PerformHttpRequest(wh.webhook, function(err, text, headers) end, 'POST', json.encode({embeds = embeds, username = wh.botname}), { ['Content-Type'] = 'application/json' })
end