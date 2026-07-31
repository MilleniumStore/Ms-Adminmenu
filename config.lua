Config = {}

Config.Framework = 'auto' -- auto, esx, qbcore, qbox, standalone
Config.Locale = 'en'
Config.Command = 'adminmenu'
Config.Keybind = 'F10'
Config.DutyCommand = 'adminduty'
Config.NoclipCommand = 'adminnoclip'
Config.NoclipKeybind = 'F2'
Config.Accent = '#7188ff'
Config.ServerName = 'Millennium Roleplay'
Config.RequireDuty = true
Config.Database = 'auto' -- auto, oxmysql, mysql-async, none

Config.DutyTags = {
    enabled = true,
    distance = 25.0,
    text = 'ON DUTY'
}

Config.Integrations = {
    inventory = 'auto', -- auto, ox_inventory, qb-inventory, qs-inventory, none
    voice = 'auto',
    discordRoles = false
}

-- txAdmin marks authenticated staff through this replicated state bag.
-- The fallback role still obeys every Millennium permission and duty check.
Config.TxAdmin = {
    enabled = true,
    role = 'owner'
}

-- Inherit the server's existing ACE admin system. The default ESX Legacy
-- server.cfg grants `command` to group.admin, so those admins automatically
-- receive this panel role without duplicating identifiers.
Config.ServerAdminAce = {
    enabled = true,
    permissions = {
        {ace = 'command', role = 'owner'}
    }
}

Config.Features = {
    reports = true,
    punishments = true,
    economy = true,
    vehicleTools = true,
    worldTools = true,
    developerTools = true,
    resourceManagement = true,
    screenshotRequest = false,
    screenWatch = false
}

Config.Cooldowns = {
    action = 750,
    report = 60000,
    announcement = 10000
}

Config.Limits = {
    reasonMin = 3,
    reasonMax = 500,
    messageMax = 600,
    moneyMax = 10000000,
    itemMax = 1000,
    banMaxDays = 3650
}

Config.ReportCategories = {'Player', 'Bug', 'Question', 'Other'}
Config.BanDurations = {
    {label = '1 hour', seconds = 3600},
    {label = '1 day', seconds = 86400},
    {label = '7 days', seconds = 604800},
    {label = '30 days', seconds = 2592000},
    {label = 'Permanent', seconds = 0}
}
Config.NoclipSpeeds = {0.5, 1.0, 2.5, 5.0, 10.0}

Config.Webhooks = {
    default = '',
    punishments = '',
    reports = '',
    economy = ''
}

-- Higher number inherits every permission granted to lower levels.
Config.Roles = {
    support = {level = 10, label = 'Support'},
    trialmod = {level = 20, label = 'Trial Moderator'},
    moderator = {level = 30, label = 'Moderator'},
    admin = {level = 40, label = 'Admin'},
    senioradmin = {level = 50, label = 'Senior Admin'},
    headadmin = {level = 60, label = 'Head Admin'},
    management = {level = 80, label = 'Management'},
    owner = {level = 100, label = 'Owner'}
}

Config.Permissions = {
    ['menu.open'] = 10,
    ['staff.duty'] = 10,
    ['reports.manage'] = 10,
    ['players.message'] = 10,
    ['players.spectate'] = 20,
    ['players.teleport'] = 20,
    ['players.freeze'] = 20,
    ['players.heal'] = 30,
    ['players.inventory'] = 40,
    ['players.job'] = 50,
    ['players.economy'] = 50,
    ['players.kick'] = 30,
    ['players.warn'] = 30,
    ['players.ban'] = 40,
    ['vehicles.manage'] = 30,
    ['staff.noclip'] = 20,
    ['world.manage'] = 50,
    ['developer.use'] = 40,
    ['server.announce'] = 40,
    ['server.view'] = 40,
    ['server.resources'] = 100,
    ['audit.view'] = 50
}

-- ACE example: add_ace identifier.license:xxx millennium.role.admin allow
Config.AcePrefix = 'millennium.role.'
Config.FrameworkGroups = {
    superadmin = 'owner',
    admin = 'admin',
    mod = 'moderator'
}

Config.Staff = {
    -- ['license:xxxxxxxx'] = 'owner'
}

Config.DiscordRoleMap = {
    -- ['123456789012345678'] = 'admin'
}

Config.AllowedResources = {
    ['pma-voice'] = true,
    ['ox_target'] = true,
    ['nexify_textui'] = true,
    ['millenium_hud'] = true
}

Config.Logging = {
    sql = true,
    discord = true,
    includeCoordinates = true
}
