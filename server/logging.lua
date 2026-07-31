MA_Log = {}

local function webhook(category, payload)
    if not Config.Logging.discord then return end
    local url = Config.Webhooks[category] ~= '' and Config.Webhooks[category] or Config.Webhooks.default
    if not url or url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = 'Millennium Admin',
        embeds = {{title = payload.action, description = payload.reason or 'No reason', color = 14206551,
            fields = {{name = 'Staff', value = payload.staff}, {name = 'Target', value = payload.target or 'N/A'}},
            footer = {text = os.date('!%Y-%m-%d %H:%M:%S UTC')}}}
    }), {['Content-Type'] = 'application/json'})
end

function MA_Log.action(source, action, target, reason, previous, newValue, category)
    local coords
    local ped = GetPlayerPed(source)
    if Config.Logging.includeCoordinates and ped and ped > 0 then
        local c = GetEntityCoords(ped)
        coords = ('%.2f, %.2f, %.2f'):format(c.x, c.y, c.z)
    end
    local payload = {
        staff = ('%s [%s]'):format(GetPlayerName(source) or 'Console', source),
        staff_license = MA_Security.identifier(source, 'license') or MA_Security.identifiers(source)[1],
        target = target and ('%s [%s]'):format(GetPlayerName(target) or 'Offline', target) or nil,
        action = action, reason = reason, coordinates = coords, previous = previous, new_value = newValue,
        session_id = MA_Security.sessions[source]
    }
    if Config.Logging.sql and MA_DB.ready() then
        MA_DB.insert([[INSERT INTO millennium_audit
            (staff_identifier, staff_name, target_identifier, target_name, action, reason, coordinates, previous_value, new_value, session_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
            {payload.staff_license, payload.staff, target and (MA_Security.identifier(target, 'license') or MA_Security.identifiers(target)[1]), payload.target, action, reason,
             coords, previous and json.encode(previous), newValue and json.encode(newValue), payload.session_id})
    end
    webhook(category or 'default', payload)
end
