local reports, nextReportId = {}, 1
local startedAt = os.time()

function MA_SyncDutyTags(target)
    if not Config.DutyTags or not Config.DutyTags.enabled then return end
    local tags = {}
    for player, active in pairs(MA_Security.duty) do
        if active and GetPlayerName(player) then
            local role = MA_Security.role(player)
            tags[tostring(player)] = {
                name = GetPlayerName(player),
                role = role and Config.Roles[role] and Config.Roles[role].label or 'Staff'
            }
        end
    end
    TriggerClientEvent('millennium:client:dutyTags', target or -1, tags)
end

local function reply(source, requestId, ok, data, error)
    TriggerClientEvent('millennium:client:response', source, requestId, ok, data, error)
end

local function playerData(id)
    id = tonumber(id)
    if not id or not GetPlayerName(id) then return nil end
    local identity = MA_Framework.identity(id)
    local ped = GetPlayerPed(id)
    local coords = ped > 0 and GetEntityCoords(ped) or vector3(0, 0, 0)
    return {
        id = id, name = identity.name, rockstar = GetPlayerName(id), job = identity.job, grade = identity.grade,
        cash = identity.cash, bank = identity.bank, ping = GetPlayerPing(id), duty = MA_Security.duty[id] == true,
        coords = {x = coords.x, y = coords.y, z = coords.z}, identifiers = MA_Security.identifiers(id)
    }
end

local function playerList()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local data = playerData(id)
        if data then list[#list + 1] = data end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function dashboard(players)
    players = players or playerList()
    local staff, ping = 0, 0
    for _, p in ipairs(players) do
        ping = ping + p.ping
        if p.duty then staff = staff + 1 end
    end
    local active = 0
    for _, report in pairs(reports) do if report.status ~= 'closed' then active = active + 1 end end
    return {
        players = #players, maxPlayers = GetConvarInt('sv_maxclients', 48), staff = staff, reports = active,
        averagePing = #players > 0 and math.floor(ping / #players) or 0, uptime = os.time() - startedAt,
        resources = GetNumResources(), framework = MA_Framework.name, database = MA_DB.driver
    }
end

local function liveData()
    local players = playerList()
    return {dashboard = dashboard(players), players = players, reports = reports}
end

RegisterNetEvent('millennium:server:open', function()
    local src = source
    local allowed = MA_Security.allowed(src, 'menu.open', true)
    if not allowed then return TriggerClientEvent('millennium:client:notify', src, Millennium.T('no_permission'), 'error') end
    local snapshot = liveData()
    TriggerClientEvent('millennium:client:open', src, {
        token = MA_Security.token(src), role = MA_Security.role(src), duty = MA_Security.duty[src] == true,
        config = {accent = Config.Accent, serverName = Config.ServerName, features = Config.Features},
        dashboard = snapshot.dashboard, players = snapshot.players, reports = snapshot.reports
    })
end)

RegisterNetEvent('millennium:server:request', function(requestId, token, action, payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}
    local permissions = {
        refresh = 'menu.open', duty = 'staff.duty', teleport = 'players.teleport', bring = 'players.teleport',
        freeze = 'players.freeze', heal = 'players.heal', revive = 'players.heal', kill = 'players.heal',
        message = 'players.message', kick = 'players.kick', warn = 'players.warn', ban = 'players.ban',
        money = 'players.economy', item = 'players.inventory', setjob = 'players.job',
        spectate = 'players.spectate', noclip = 'staff.noclip',
        vehicle_spawn = 'vehicles.manage', vehicle_give = 'vehicles.manage',
        vehicle_repair = 'vehicles.manage', vehicle_delete = 'vehicles.manage',
        load_punishments = 'players.warn', punishment_revoke = 'players.ban',
        load_audit = 'audit.view', resource_list = 'server.view', resource_control = 'server.resources',
        report = 'reports.manage', announce = 'server.announce'
    }
    local permission = permissions[action]
    if not permission then return reply(src, requestId, false, nil, 'Unknown action') end
    local valid, why = MA_Security.validate(src, token, permission)
    if not valid then return reply(src, requestId, false, nil, why == 'duty' and Millennium.T('duty_required') or Millennium.T('no_permission')) end
    if not MA_Security.rateLimit(src, action) then return reply(src, requestId, false, nil, 'Please slow down') end

    if action == 'load_punishments' then
        if not MA_DB.ready() then return reply(src, requestId, false, nil, 'Database integration is unavailable') end
        return MA_DB.query([[SELECT id, target_name, target_identifier, staff_name, type, reason, evidence,
            expires_at, active, created_at FROM millennium_punishments ORDER BY id DESC LIMIT 200]], {}, function(rows)
            reply(src, requestId, true, {punishments = rows or {}})
        end)
    elseif action == 'load_audit' then
        if not MA_DB.ready() then return reply(src, requestId, false, nil, 'Database integration is unavailable') end
        return MA_DB.query([[SELECT id, staff_name, target_name, action, reason, coordinates, created_at
            FROM millennium_audit ORDER BY id DESC LIMIT 250]], {}, function(rows)
            reply(src, requestId, true, {audit = rows or {}})
        end)
    elseif action == 'resource_list' then
        local resources = {}
        for index = 0, GetNumResources() - 1 do
            local name = GetResourceByFindIndex(index)
            if name then
                resources[#resources + 1] = {
                    name = name,
                    state = GetResourceState(name),
                    allowed = Config.Features.resourceManagement and Config.AllowedResources[name] == true
                        and MA_Security.allowed(src, 'server.resources') == true
                }
            end
        end
        table.sort(resources, function(a, b) return a.name < b.name end)
        return reply(src, requestId, true, {resources = resources})
    elseif action == 'punishment_revoke' then
        if not MA_DB.ready() then return reply(src, requestId, false, nil, 'Database integration is unavailable') end
        local id = tonumber(payload.id)
        local reason = MA_Security.reason(payload.reason)
        if not id or not reason then return reply(src, requestId, false, nil, 'Valid punishment and reason required') end
        return MA_DB.update('UPDATE millennium_punishments SET active = 0 WHERE id = ? AND active = 1', {id}, function(changed)
            if not changed or changed < 1 then return reply(src, requestId, false, nil, 'Punishment is already inactive or unavailable') end
            MA_Log.action(src, 'punishment_revoke', nil, reason, {id = id, active = true}, {id = id, active = false}, 'punishments')
            MA_DB.query([[SELECT id, target_name, target_identifier, staff_name, type, reason, evidence,
                expires_at, active, created_at FROM millennium_punishments ORDER BY id DESC LIMIT 200]], {}, function(rows)
                reply(src, requestId, true, {punishments = rows or {}})
            end)
        end)
    elseif action == 'resource_control' then
        local name = type(payload.resource) == 'string' and payload.resource or ''
        local operation = payload.operation
        if not Config.Features.resourceManagement or not Config.AllowedResources[name] or name == GetCurrentResourceName() then
            return reply(src, requestId, false, nil, 'This resource is not allowlisted for management')
        end
        if operation == 'start' then StartResource(name)
        elseif operation == 'stop' then StopResource(name)
        elseif operation == 'restart' then
            StopResource(name)
            Wait(250)
            StartResource(name)
        else return reply(src, requestId, false, nil, 'Invalid resource operation') end
        MA_Log.action(src, 'resource_' .. operation, nil, name)
        return reply(src, requestId, true, {resourceChanged = name})
    end

    if action == 'refresh' then
        return reply(src, requestId, true, liveData())
    elseif action == 'duty' then
        MA_Security.duty[src] = not MA_Security.duty[src]
        MA_Log.action(src, 'staff_duty', nil, MA_Security.duty[src] and 'On duty' or 'Off duty')
        MA_SyncDutyTags(-1)
        return reply(src, requestId, true, {duty = MA_Security.duty[src], dashboard = dashboard()})
    end

    local noTarget = action == 'announce' or action == 'report' or action == 'noclip'
        or action == 'vehicle_spawn' or action == 'vehicle_repair' or action == 'vehicle_delete'
    local target = tonumber(payload.target)
    if not noTarget and (not target or not GetPlayerName(target)) then
        return reply(src, requestId, false, nil, Millennium.T('invalid_target'))
    end
    local reason
    if action == 'kick' or action == 'warn' or action == 'ban' or action == 'money' or action == 'item' or action == 'setjob' then
        reason = MA_Security.reason(payload.reason)
        if not reason then return reply(src, requestId, false, nil, 'A valid reason is required') end
    end

    if action == 'teleport' then
        local targetPed, staffPed = GetPlayerPed(target), GetPlayerPed(src)
        if targetPed <= 0 or staffPed <= 0 then return reply(src, requestId, false, nil, 'Entity unavailable') end
        local c = GetEntityCoords(targetPed)
        TriggerClientEvent('millennium:client:teleport', src, {x = c.x, y = c.y, z = c.z})
    elseif action == 'bring' then
        local staffPed = GetPlayerPed(src)
        if staffPed <= 0 then return reply(src, requestId, false, nil, 'Entity unavailable') end
        local c = GetEntityCoords(staffPed)
        TriggerClientEvent('millennium:client:teleport', target, {x = c.x, y = c.y, z = c.z})
    elseif action == 'freeze' then
        TriggerClientEvent('millennium:client:freeze', target)
    elseif action == 'spectate' then
        TriggerClientEvent('millennium:client:spectate', src, target)
    elseif action == 'noclip' then
        TriggerClientEvent('millennium:client:noclip', src)
    elseif action == 'heal' or action == 'revive' or action == 'kill' then
        TriggerClientEvent('millennium:client:vitals', target, action)
    elseif action == 'message' then
        local message = Millennium.Trim(payload.message)
        if #message < 1 or #message > Config.Limits.messageMax then return reply(src, requestId, false, nil, 'Invalid message') end
        TriggerClientEvent('millennium:client:adminMessage', target, GetPlayerName(src), message)
        reason = message
    elseif action == 'kick' then
        MA_Log.action(src, 'kick', target, reason, nil, nil, 'punishments')
        reply(src, requestId, true, {})
        return DropPlayer(target, ('%s\nReason: %s'):format(Millennium.T('kicked'), reason))
    elseif action == 'warn' then
        if MA_DB.ready() then
            MA_DB.insert('INSERT INTO millennium_punishments (target_identifier, target_name, staff_identifier, staff_name, type, reason, expires_at, active) VALUES (?, ?, ?, ?, ?, ?, NULL, 1)',
                {MA_Security.identifier(target, 'license'), GetPlayerName(target), MA_Security.identifier(src, 'license'), GetPlayerName(src), 'warning', reason})
        end
        TriggerClientEvent('millennium:client:staffWarning', target, reason)
    elseif action == 'ban' then
        local seconds = Millennium.Clamp(payload.duration, 0, Config.Limits.banMaxDays * 86400)
        if seconds == nil then return reply(src, requestId, false, nil, 'Invalid duration') end
        local expires = seconds == 0 and nil or os.date('!%Y-%m-%d %H:%M:%S', os.time() + seconds)
        if MA_DB.ready() then
            MA_DB.insert('INSERT INTO millennium_punishments (target_identifier, target_name, staff_identifier, staff_name, type, reason, evidence, expires_at, active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)',
                {MA_Security.identifier(target, 'license'), GetPlayerName(target), MA_Security.identifier(src, 'license'), GetPlayerName(src), 'ban', reason, Millennium.Trim(payload.evidence), expires})
        end
        MA_Log.action(src, 'ban', target, reason, nil, {expires = expires}, 'punishments')
        reply(src, requestId, true, {})
        return DropPlayer(target, ('%s\nReason: %s'):format(Millennium.T('banned'), reason))
    elseif action == 'money' then
        local amount = Millennium.Clamp(payload.amount, 1, Config.Limits.moneyMax)
        local operation = payload.operation == 'remove' and 'remove' or payload.operation == 'add' and 'add' or nil
        local account = payload.account == 'bank' and 'bank' or payload.account == 'cash' and 'cash' or nil
        if not amount or not operation or not account then return reply(src, requestId, false, nil, 'Invalid transaction') end
        local ok, err = MA_Framework.money(target, operation, account, amount, 'millennium:' .. reason)
        if not ok then return reply(src, requestId, false, nil, err) end
        MA_Log.action(src, 'money_' .. operation, target, reason, nil, {account = account, amount = amount}, 'economy')
    elseif action == 'item' then
        local item = type(payload.item) == 'string' and payload.item:lower():match('^[%w_%-]+$') or nil
        local amount = Millennium.Clamp(payload.amount, 1, Config.Limits.itemMax)
        local operation = payload.operation == 'remove' and 'remove' or payload.operation == 'add' and 'add' or nil
        if not item or not amount or not operation then return reply(src, requestId, false, nil, 'Invalid inventory operation') end
        local ok, err = MA_Framework.item(target, operation, item, amount)
        if not ok then return reply(src, requestId, false, nil, err or 'Inventory action failed') end
        MA_Log.action(src, 'item_' .. operation, target, reason, nil, {item = item, amount = amount})
    elseif action == 'setjob' then
        local job = type(payload.job) == 'string' and payload.job:lower():match('^[%w_%-]+$') or nil
        local grade = Millennium.Clamp(payload.grade, 0, 100)
        if not job or grade == nil then return reply(src, requestId, false, nil, 'Invalid job or grade') end
        local ok, err = MA_Framework.setJob(target, job, grade)
        if not ok then return reply(src, requestId, false, nil, err) end
        MA_Log.action(src, 'set_job', target, reason, nil, {job = job, grade = grade})
    elseif action == 'vehicle_spawn' or action == 'vehicle_give' then
        local model = type(payload.model) == 'string' and payload.model:lower():match('^[%w_%-]+$') or nil
        if not model or #model > 40 then return reply(src, requestId, false, nil, 'Invalid vehicle model') end
        TriggerClientEvent('millennium:client:vehicle', action == 'vehicle_give' and target or src, 'spawn', model)
        reason = model
    elseif action == 'vehicle_repair' then
        TriggerClientEvent('millennium:client:vehicle', src, 'repair')
    elseif action == 'vehicle_delete' then
        TriggerClientEvent('millennium:client:vehicle', src, 'delete')
    elseif action == 'report' then
        local id = tonumber(payload.id)
        local report = id and reports[id]
        if not report then return reply(src, requestId, false, nil, 'Report unavailable') end
        if payload.operation == 'claim' then report.claimedBy, report.status = GetPlayerName(src), 'claimed'
        elseif payload.operation == 'close' then
            reason = MA_Security.reason(payload.reason)
            if not reason then return reply(src, requestId, false, nil, 'Resolution reason required') end
            report.status, report.resolution, report.closedAt = 'closed', reason, os.time()
        else return reply(src, requestId, false, nil, 'Invalid report operation') end
        MA_Log.action(src, 'report_' .. payload.operation, report.source, reason or ('Report #' .. id), nil, report, 'reports')
    elseif action == 'announce' then
        local message = Millennium.Trim(payload.message)
        if #message < 3 or #message > Config.Limits.messageMax then return reply(src, requestId, false, nil, 'Invalid announcement') end
        TriggerClientEvent('millennium:client:announcement', -1, message)
        reason = message
    end
    MA_Log.action(src, action, target, reason or payload.reason)
    reply(src, requestId, true, liveData())
end)

local function createReport(src, category, message)
    if not Config.Features.reports or not MA_Security.rateLimit(src, 'createReport', Config.Cooldowns.report) then
        return TriggerClientEvent('millennium:client:notify', src, Millennium.T('report_cooldown'), 'error')
    end
    message = Millennium.Trim(message)
    if #message < 8 or #message > Config.Limits.messageMax then return end
    local validCategory = false
    for _, value in ipairs(Config.ReportCategories) do if category == value then validCategory = true break end end
    if not validCategory then category = 'Other' end
    local id = nextReportId
    nextReportId = nextReportId + 1
    reports[id] = {id = id, source = src, player = GetPlayerName(src), category = category, message = message, status = 'open', createdAt = os.time()}
    TriggerClientEvent('millennium:client:notify', src, Millennium.T('report_created'), 'success')
    for _, player in ipairs(GetPlayers()) do
        if MA_Security.allowed(tonumber(player), 'reports.manage') then
            TriggerClientEvent('millennium:client:notify', tonumber(player), ('New report #%s from %s'):format(id, GetPlayerName(src)), 'warning')
        end
    end
end

RegisterNetEvent('millennium:server:createReport', function(category, message)
    createReport(source, category, message)
end)

RegisterNetEvent('millennium:server:requestDutyTags', function()
    MA_SyncDutyTags(source)
end)

RegisterNetEvent('millennium:server:toggleDuty', function()
    local src = source
    local allowed = MA_Security.allowed(src, 'staff.duty', true)
    if not allowed then
        return TriggerClientEvent('millennium:client:notify', src, Millennium.T('no_permission'), 'error')
    end
    if not MA_Security.rateLimit(src, 'duty_command', Config.Cooldowns.action) then return end
    MA_Security.duty[src] = not MA_Security.duty[src]
    MA_Log.action(src, 'staff_duty', nil, MA_Security.duty[src] and 'On duty' or 'Off duty')
    MA_SyncDutyTags(-1)
    TriggerClientEvent('millennium:client:dutyState', src, MA_Security.duty[src])
    TriggerClientEvent('millennium:client:notify', src, MA_Security.duty[src] and 'You are now on duty' or 'You are now off duty', 'success')
end)

RegisterNetEvent('millennium:server:toggleNoclip', function()
    local src = source
    local allowed, why = MA_Security.allowed(src, 'staff.noclip')
    if not allowed then
        return TriggerClientEvent('millennium:client:notify', src,
            why == 'duty' and Millennium.T('duty_required') or Millennium.T('no_permission'), 'error')
    end
    if not MA_Security.rateLimit(src, 'noclip_keybind', Config.Cooldowns.action) then return end
    MA_Log.action(src, 'noclip_toggle', nil, 'Keybind toggle')
    TriggerClientEvent('millennium:client:noclip', src)
end)

RegisterCommand(Config.Command, function(source) if source > 0 then TriggerClientEvent('millennium:client:requestOpen', source) end end)
RegisterCommand('adminrole', function(source)
    if source <= 0 then return end
    local role = MA_Security.role(source)
    local label = role and Config.Roles[role] and Config.Roles[role].label or 'No admin access'
    TriggerClientEvent('millennium:client:notify', source, ('Admin panel role: %s'):format(label), role and 'success' or 'error')
end)
RegisterCommand('report', function(source, args)
    if source > 0 and #args > 0 then createReport(source, 'Other', table.concat(args, ' ')) end
end)

AddEventHandler('playerDropped', function()
    local dropped = source
    SetTimeout(250, function()
        MA_Security.duty[dropped] = nil
        MA_SyncDutyTags(-1)
    end)
end)

CreateThread(function()
    while true do
        Wait(15000)
        MA_SyncDutyTags(-1)
    end
end)

AddEventHandler('playerConnecting', function(_, setKickReason, deferrals)
    if not MA_DB.ready() then return end
    local src = source
    deferrals.defer()
    Wait(0)
    local primary = MA_Security.identifier(src, 'license')
    if not primary then return deferrals.done('A valid FiveM license identifier is required.') end
    MA_DB.query('SELECT reason, expires_at FROM millennium_punishments WHERE target_identifier = ? AND type = ? AND active = 1 AND (expires_at IS NULL OR expires_at > UTC_TIMESTAMP()) ORDER BY id DESC LIMIT 1',
        {primary, 'ban'}, function(rows)
            if rows and rows[1] then deferrals.done(('You are banned.\nReason: %s'):format(rows[1].reason))
            else deferrals.done() end
        end)
end)

exports('AddStaffNote', function(targetIdentifier, staffSource, note)
    if not MA_Security.allowed(staffSource, 'players.warn') or not MA_Security.reason(note) or not MA_DB.ready() then return false end
    MA_DB.insert('INSERT INTO millennium_notes (target_identifier, staff_identifier, staff_name, note) VALUES (?, ?, ?, ?)',
        {targetIdentifier, MA_Security.identifier(staffSource, 'license'), GetPlayerName(staffSource), note})
    return true
end)
