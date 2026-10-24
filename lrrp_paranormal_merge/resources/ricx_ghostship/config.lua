Config = {}
Config.framework = "redemrp-reboot"--"redemrp" or "vorp" or "qbr" or "qbr2" or "redemrp-reboot" or "rsg"
Config.Debug = true

Config.EyeTarget = false -- Set true for enable eye target settings | by default using ox_target | change events.lua EyeTarget and EyeTargetRemove functions for any custom

Config.RefreshRate = 5
Config.InteractDistance = 1.0
Config.ViewDistance = 200.0
Config.ViewDistanceStash = 50.0

Config.FogPTFX = true

Config.Prompts = {
    Prompt1 = 0x05CA7C52,
}

Config.SearchAnim = {
    dict = "script_re@locked_safe@sledge_hammer",
    name = "search_male_b",
    duration = 5000,
    flag = 1,
}

Config.Texts = {
    Prompt1 = "Search",
    --TEXTS
    Stash = "Stash",
    --Notifications
    CantDo = "Cant do that now!",
    AlreadyLooted = "Already looted stash!",
    NothingFound = "Nothing found!",
    AddedItem = "You have found %sx %s!",
    --Webhooks
    W_Source = "Source",
    W_ID = "Identifiers",
    W_PName = "Name",
    W_Stash = "Stash",
    W_Loot = "Loot",
}

Config.Textures = {
    cross = {"scoretimer_textures", "scoretimer_generic_cross"},
    locked = {"menu_textures","stamp_locked_rank"},
    tick = {"scoretimer_textures","scoretimer_generic_tick"},
    money = {"inventory_items", "money_moneystack"},
    alert = {"menu_textures", "menu_icon_alert"},
}

Config.Coords = {
    {
        name = "Ghost Ship", --1
        blip = {enable = true, sprite = -1031152097, style = `BLIP_STYLE_ADVERSARY`, distance = 50.0},
        coords = vector3(506.333, -1585.397, 38.789),
        ptfx = vector3(506.333, -1585.397, 42.789),
        rotate = vector3(0.0, 0.0, 0.0),
        all_player_collect = true,--if false, only first player can collect the stash
        stashes = {
            {
                model = `p_chestmedburied01x`,
                offset = vector3(6.100, -0.010, 3.450),
                rot = vector3(0.0, 0.0, 180.0),
                rewards = {
                    {item = "bread", label = "Bread", chance = 100, amount = {min = 1, max = 2}},
                    {item = "water", label = "Water", chance = 50, amount = {min = 1, max = 2}},
                },
            },
            {
                model = `p_chestmedburied01x`,
                offset = vector3(16.810, 0.020, 3.210),
                rot = vector3(0.0, -6.0, 270.0),
                rewards = {
                    {item = "bread", label = "Bread", chance = 100, amount = {min = 1, max = 2}},
                    {item = "water", label = "Water", chance = 50, amount = {min = 1, max = 2}},
                },
            },
            {
                model = `p_chestmedburied01x`,
                offset = vector3(8.000, 4.140, 2.900),
                rot = vector3(-8.000, 3.000, 0.000),
                rewards = {
                    {item = "bread", label = "Bread", chance = 100, amount = {min = 1, max = 2}},
                    {item = "water", label = "Water", chance = 50, amount = {min = 1, max = 2}},
                },
            },
            {
                model = `p_chestmedburied01x`,
                offset = vector3(0.000, -1.940, 3.470),
                rot = vector3(0.000, 0.000, 76.000),
                rewards = {
                    {item = "bread", label = "Bread", chance = 100, amount = {min = 1, max = 2}},
                    {item = "water", label = "Water", chance = 50, amount = {min = 1, max = 2}},
                },
            },
            {
                model = `p_chestmedburied01x`,
                offset = vector3(-4.000, -2.120, 3.500),
                rot = vector3(0.000, 0.000, 0.000),
                rewards = {
                    {item = "bread", label = "Bread", chance = 100, amount = {min = 1, max = 2}},
                    {item = "water", label = "Water", chance = 50, amount = {min = 1, max = 2}},
                },
            },
            {
                model = `p_chestmedburied01x`,
                offset = vector3(-6.860, 4.280, 3.420),
                rot = vector3(0.000, -3.000, 0.000),
                rewards = {
                    {item = "bread", label = "Bread", chance = 100, amount = {min = 1, max = 2}},
                    {item = "water", label = "Water", chance = 50, amount = {min = 1, max = 2}},
                },
            },
            {
                model = `p_chestmedburied01x`,
                offset = vector3(-3.110, 0.210, 3.460),
                rot = vector3(2.000, 0.000, 270.000),
                rewards = {
                    {item = "bread", label = "Bread", chance = 100, amount = {min = 1, max = 2}},
                    {item = "water", label = "Water", chance = 50, amount = {min = 1, max = 2}},
                },
            },
        }
    },
    {
        name = "Ghost Ship", --2
        blip = {enable = true, sprite = -1031152097, style = `BLIP_STYLE_ADVERSARY`, distance = 50.0},
        coords = vector3(646.265, -1775.798, 39.839),
        ptfx = vector3(646.265, -1775.798, 42.839),
        rotate = vector3(-0.957, 4.080, 126.999),
        all_player_collect = true,--if false, only first player can collect the stash
        stashes = {
            {
                model = `p_chestmedburied01x`,
                offset = vector3(6.100, -0.010, 3.450),
                rot = vector3(0.0, 6.0, 122.0),
                rewards = {
                    {item = "bread", label = "Bread", chance = 50, amount = {min = 1, max = 2}},
                    {item = "water", label = "Water", chance = 50, amount = {min = 1, max = 2}},
                },
            },
            {
                model = `p_chestmedburied01x`,
                offset = vector3(16.810, 0.020, 3.210),
                rot = vector3(0.0, 9.0, -136.0),
                rewards = {
                    {item = "bread", label = "Bread", chance = 50, amount = {min = 1, max = 2}},
                    {item = "water", label = "Water", chance = 50, amount = {min = 1, max = 2}},
                },
            },
        }
    },
}



