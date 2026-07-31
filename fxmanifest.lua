fx_version 'cerulean'
game 'gta5'

name 'Ms-Adminmenu'
author 'Millennium Systems'
description 'Millennium Admin - server-authoritative administration suite'
version '1.0.0'

lua54 'yes'

ui_page 'web/index.html'

shared_scripts {
    'config.lua',
    'locales/*.lua',
    'shared/*.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    'server/*.lua'
}

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

dependencies {
    '/onesync'
}

server_exports {
    'HasPermission',
    'AddStaffNote',
    'GetFramework',
    'GetAdminRole',
    'GetRoleLevel',
    'IsStaff',
    'IsOnDuty',
    'SetDuty',
    'ToggleDuty',
    'NotifyPlayer',
    'Announce',
    'WarnPlayer',
    'KickPlayer',
    'BanPlayer',
    'GiveItem',
    'RemoveItem',
    'AddMoney',
    'RemoveMoney',
    'SetPlayerJob',
    'FreezePlayer',
    'HealPlayer',
    'RevivePlayer',
    'KillPlayer',
    'SpawnVehicleForPlayer',
    'MessagePlayer',
    'TeleportToPlayer',
    'BringPlayer',
    'SpectatePlayer',
    'RepairStaffVehicle',
    'DeleteStaffVehicle',
    'GetOnlinePlayers'
}

client_exports {
    'OpenAdminMenu',
    'ToggleAdminDuty',
    'ToggleAdminNoclip',
    'Notify',
    'ShowAnnouncement',
    'ShowStaffWarning'
}

escrow_ignore {
    'config.lua',
    'client/api.lua',
    'fxmanifest.lua',
    'locales/*.lua',
    'server/api.lua',
    'server/database.lua',
    'server/framework.lua',
    'server/logging.lua',
    'server/security.lua',
    'shared/*.lua',
    'README.md',
    'INSTALL.md',
    'sql/install.sql',
    'web/index.html',
    'web/style.css',
    'web/app.js'
}
