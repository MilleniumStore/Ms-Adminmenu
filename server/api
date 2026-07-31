-- Public server API. Every mutating export requires the staff source and
-- resolves permissions server-side; calling resources never bypass security.

local function online(source)
    source = tonumber(source)
    return source and source > 0 and GetPlayerName(source) ~= nil and source or nil
end

local function authorize(staffSource, permission, ignoreDuty)
    staffSource = online(staffSource)
    if not staffSource then return nil, 'Invalid staff source' end
    local allowed, why = MA_Security.allowed(staffSource, permission, ignoreDuty == true)
    if not allowed then return nil, why == 'duty' and 'Staff duty is required' or 'Permission denied' end
    return staffSource
end

local function targetAndStaff(staffSource, target, permission)
    local staff, err = authorize(staffSource, permission)
    if not staff then return nil, nil, err end
    target = online(target)
    if not target then return nil, nil, 'Target is offline' end
    return staff, target
end

local function audit(staff, action, target, reason, data, category)
    MA_Log.action(staff, action, target, reason, nil, data, category)
end

exports('GetAdminRole', function(source)
    return MA_Security.role(tonumber(source))
end)

exports('GetRoleLevel', function(source)
    local role = MA_Security.role(tonumber(source))
    return role and Config.Roles[role] and Config.Roles[role].level or 0
end)

exports('IsStaff', function(source)
    return MA_Security.role(tonumber(source)) ~= nil
end)

exports('IsOnDuty', function(source)
    return MA_Security.duty[tonumber(source)] == true
end)

exports('SetDuty', function(source, active)
    local staff, err = authorize(source, 'staff.duty', true)
    if not staff then return false, err end
    MA_Security.duty[staff] = active == true
    audit(staff, 'staff_duty_export', nil, active and 'On duty' or 'Off duty')
    TriggerClientEvent('millennium:client:dutyState', staff, MA_Security.duty[staff])
    if MA_SyncDutyTags then MA_SyncDutyTags(-1) end
    return true
end)

exports('ToggleDuty', function(source)
    local staff, err = authorize(source, 'staff.duty', true)
    if not staff then return false, err end
    MA_Security.duty[staff] = not MA_Security.duty[staff]
    audit(staff, 'staff_duty_export', nil, MA_Security.duty[staff] and 'On duty' or 'Off duty')
    TriggerClientEvent('millennium:client:dutyState', staff, MA_Security.duty[staff])
    if MA_SyncDutyTags then MA_SyncDutyTags(-1) end
    return true, MA_Security.duty[staff]
end)

exports('NotifyPlayer', function(target, message, kind)
    target = online(target)
    message = Millennium.Trim(message)
    if not target or #message < 1 or #message > Config.Limits.messageMax then return false, 'Invalid notification' end
    TriggerClientEvent('millennium:client:notify', target, message, kind or 'info')
    return true
end)

exports('Announce', function(staffSource, message)
    local staff, err = authorize(staffSource, 'server.announce')
    message = Millennium.Trim(message)
    if not staff then return false, err end
    if #message < 3 or #message > Config.Limits.messageMax then return false, 'Invalid announcement' end
    TriggerClientEvent('millennium:client:announcement', -1, message)
    audit(staff, 'announcement_export', nil, message)
    return true
end)

exports('WarnPlayer', function(staffSource, target, reason)
    local staff, player, err = targetAndStaff(staffSource, target, 'players.warn')
    reason = MA_Security.reason(reason)
    if not staff then return false, err end
    if not reason then return false, 'Invalid reason' end
    if MA_DB.ready() then
        MA_DB.insert('INSERT INTO millennium_punishments (target_identifier, target_name, staff_identifier, staff_name, type, reason, expires_at, active) VALUES (?, ?, ?, ?, ?, ?, NULL, 1)',
            {MA_Security.identifier(player, 'license'), GetPlayerName(player), MA_Security.identifier(staff, 'license'), GetPlayerName(staff), 'warning', reason})
    end
    TriggerClientEvent('millennium:client:staffWarning', player, reason)
    audit(staff, 'warning_export', player, reason, nil, 'punishments')
    return true
end)

exports('KickPlayer', function(staffSource, target, reason)
    local staff, player, err = targetAndStaff(staffSource, target, 'players.kick')
    reason = MA_Security.reason(reason)
    if not staff then return false, err end
    if not reason then return false, 'Invalid reason' end
    audit(staff, 'kick_export', player, reason, nil, 'punishments')
    DropPlayer(player, ('%s\nReason: %s'):format(Millennium.T('kicked'), reason))
    return true
end)

exports('BanPlayer', function(staffSource, target, reason, duration, evidence)
    local staff, player, err = targetAndStaff(staffSource, target, 'players.ban')
    reason = MA_Security.reason(reason)
    duration = Millennium.Clamp(duration, 0, Config.Limits.banMaxDays * 86400)
    if not staff then return false, err end
    if not reason or duration == nil then return false, 'Invalid ban data' end
    local expires = duration == 0 and nil or os.date('!%Y-%m-%d %H:%M:%S', os.time() + duration)
    if MA_DB.ready() then
        MA_DB.insert('INSERT INTO millennium_punishments (target_identifier, target_name, staff_identifier, staff_name, type, reason, evidence, expires_at, active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)',
            {MA_Security.identifier(player, 'license'), GetPlayerName(player), MA_Security.identifier(staff, 'license'), GetPlayerName(staff), 'ban', reason, Millennium.Trim(evidence), expires})
    end
    audit(staff, 'ban_export', player, reason, {expires = expires}, 'punishments')
    DropPlayer(player, ('%s\nReason: %s'):format(Millennium.T('banned'), reason))
    return true
end)

local function inventory(staffSource, target, operation, item, amount, reason)
    local staff, player, err = targetAndStaff(staffSource, target, 'players.inventory')
    item = type(item) == 'string' and item:lower():match('^[%w_%-]+$') or nil
    amount = Millennium.Clamp(amount, 1, Config.Limits.itemMax)
    reason = MA_Security.reason(reason)
    if not staff then return false, err end
    if not item or not amount or not reason then return false, 'Invalid inventory data' end
    local ok, frameworkError = MA_Framework.item(player, operation, item, amount)
    if not ok then return false, frameworkError end
    audit(staff, 'item_' .. operation .. '_export', player, reason, {item = item, amount = amount})
    return true
end

exports('GiveItem', function(staffSource, target, item, amount, reason)
    return inventory(staffSource, target, 'add', item, amount, reason)
end)

exports('RemoveItem', function(staffSource, target, item, amount, reason)
    return inventory(staffSource, target, 'remove', item, amount, reason)
end)

local function money(staffSource, target, operation, account, amount, reason)
    local staff, player, err = targetAndStaff(staffSource, target, 'players.economy')
    account = account == 'cash' and 'cash' or account == 'bank' and 'bank' or nil
    amount = Millennium.Clamp(amount, 1, Config.Limits.moneyMax)
    reason = MA_Security.reason(reason)
    if not staff then return false, err end
    if not account or not amount or not reason then return false, 'Invalid transaction data' end
    local ok, frameworkError = MA_Framework.money(player, operation, account, amount, 'admin-export:' .. reason)
    if not ok then return false, frameworkError end
    audit(staff, 'money_' .. operation .. '_export', player, reason, {account = account, amount = amount}, 'economy')
    return true
end

exports('AddMoney', function(staffSource, target, account, amount, reason)
    return money(staffSource, target, 'add', account, amount, reason)
end)

exports('RemoveMoney', function(staffSource, target, account, amount, reason)
    return money(staffSource, target, 'remove', account, amount, reason)
end)

exports('SetPlayerJob', function(staffSource, target, job, grade, reason)
    local staff, player, err = targetAndStaff(staffSource, target, 'players.job')
    reason = MA_Security.reason(reason)
    if not staff then return false, err end
    if type(job) ~= 'string' or not job:match('^[%w_%-]+$') or not reason then return false, 'Invalid job data' end
    local ok, frameworkError = MA_Framework.setJob(player, job:lower(), grade)
    if not ok then return false, frameworkError end
    audit(staff, 'set_job_export', player, reason, {job = job, grade = grade})
    return true
end)

local function playerAction(staffSource, target, permission, action, event, payload)
    local staff, player, err = targetAndStaff(staffSource, target, permission)
    if not staff then return false, err end
    TriggerClientEvent(event, player, payload)
    audit(staff, action .. '_export', player, action)
    return true
end

exports('FreezePlayer', function(staffSource, target) return playerAction(staffSource, target, 'players.freeze', 'freeze', 'millennium:client:freeze') end)
exports('HealPlayer', function(staffSource, target) return playerAction(staffSource, target, 'players.heal', 'heal', 'millennium:client:vitals', 'heal') end)
exports('RevivePlayer', function(staffSource, target) return playerAction(staffSource, target, 'players.heal', 'revive', 'millennium:client:vitals', 'revive') end)
exports('KillPlayer', function(staffSource, target) return playerAction(staffSource, target, 'players.heal', 'kill', 'millennium:client:vitals', 'kill') end)
exports('SpawnVehicleForPlayer', function(staffSource, target, model)
    local staff, player, err = targetAndStaff(staffSource, target, 'vehicles.manage')
    model = type(model) == 'string' and model:lower():match('^[%w_%-]+$') or nil
    if not staff then return false, err end
    if not model or #model > 40 then return false, 'Invalid vehicle model' end
    TriggerClientEvent('millennium:client:vehicle', player, 'spawn', model)
    audit(staff, 'vehicle_spawn_export', player, model)
    return true
end)

exports('MessagePlayer', function(staffSource, target, message)
    local staff, player, err = targetAndStaff(staffSource, target, 'players.message')
    message = Millennium.Trim(message)
    if not staff then return false, err end
    if #message < 1 or #message > Config.Limits.messageMax then return false, 'Invalid message' end
    TriggerClientEvent('millennium:client:adminMessage', player, GetPlayerName(staff), message)
    audit(staff, 'message_export', player, message)
    return true
end)

exports('TeleportToPlayer', function(staffSource, target)
    local staff, player, err = targetAndStaff(staffSource, target, 'players.teleport')
    if not staff then return false, err end
    local ped = GetPlayerPed(player)
    if ped <= 0 then return false, 'Target entity unavailable' end
    local coords = GetEntityCoords(ped)
    TriggerClientEvent('millennium:client:teleport', staff, {x = coords.x, y = coords.y, z = coords.z})
    audit(staff, 'teleport_export', player, 'Teleport to player')
    return true
end)

exports('BringPlayer', function(staffSource, target)
    local staff, player, err = targetAndStaff(staffSource, target, 'players.teleport')
    if not staff then return false, err end
    local ped = GetPlayerPed(staff)
    if ped <= 0 then return false, 'Staff entity unavailable' end
    local coords = GetEntityCoords(ped)
    TriggerClientEvent('millennium:client:teleport', player, {x = coords.x, y = coords.y, z = coords.z})
    audit(staff, 'bring_export', player, 'Bring player')
    return true
end)

exports('SpectatePlayer', function(staffSource, target)
    local staff, player, err = targetAndStaff(staffSource, target, 'players.spectate')
    if not staff then return false, err end
    TriggerClientEvent('millennium:client:spectate', staff, player)
    audit(staff, 'spectate_export', player, 'Toggle spectate')
    return true
end)

exports('RepairStaffVehicle', function(staffSource)
    local staff, err = authorize(staffSource, 'vehicles.manage')
    if not staff then return false, err end
    TriggerClientEvent('millennium:client:vehicle', staff, 'repair')
    audit(staff, 'vehicle_repair_export', nil, 'Repair vehicle')
    return true
end)

exports('DeleteStaffVehicle', function(staffSource)
    local staff, err = authorize(staffSource, 'vehicles.manage')
    if not staff then return false, err end
    TriggerClientEvent('millennium:client:vehicle', staff, 'delete')
    audit(staff, 'vehicle_delete_export', nil, 'Delete vehicle')
    return true
end)

exports('GetOnlinePlayers', function()
    local result = {}
    for _, id in ipairs(GetPlayers()) do
        local source = tonumber(id)
        local identity = MA_Framework.identity(source)
        result[#result + 1] = {source = source, name = identity.name, rockstar = GetPlayerName(source), job = identity.job, ping = GetPlayerPing(source)}
    end
    return result
end)
