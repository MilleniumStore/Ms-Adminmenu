MA_Security = {sessions = {}, duty = {}, cooldowns = {}, sqlRoles = {}}

local function identifier(source, prefix)
    for _, value in ipairs(GetPlayerIdentifiers(source)) do
        if value:sub(1, #prefix + 1) == prefix .. ':' then return value end
    end
end

function MA_Security.identifier(source, prefix)
    return identifier(source, prefix or 'license')
end

function MA_Security.role(source)
    local license = identifier(source, 'license')
    if license and Config.Staff[license] then return Config.Staff[license] end
    if license and MA_Security.sqlRoles[license] then return MA_Security.sqlRoles[license] end
    local bestRole, bestLevel
    for role in pairs(Config.Roles) do
        if IsPlayerAceAllowed(source, Config.AcePrefix .. role) then
            local level = Config.Roles[role].level
            if not bestLevel or level > bestLevel then bestRole, bestLevel = role, level end
        end
    end
    if bestRole then return bestRole end
    if Config.ServerAdminAce and Config.ServerAdminAce.enabled then
        for _, mapping in ipairs(Config.ServerAdminAce.permissions or {}) do
            if Config.Roles[mapping.role] and IsPlayerAceAllowed(source, mapping.ace) then
                return mapping.role
            end
        end
    end
    if Config.TxAdmin and Config.TxAdmin.enabled then
        local player = Player(source)
        if player and player.state and player.state.isStaff == true and Config.Roles[Config.TxAdmin.role] then
            return Config.TxAdmin.role
        end
    end
    local group = MA_Framework.group(source)
    return group and Config.FrameworkGroups[group] or nil
end

local function refreshSqlRoles()
    if not MA_DB or not MA_DB.ready() then return end
    MA_DB.query('SELECT identifier, role FROM millennium_staff WHERE active = 1', {}, function(rows)
        local nextRoles = {}
        for _, row in ipairs(rows or {}) do
            if Config.Roles[row.role] then nextRoles[row.identifier] = row.role end
        end
        MA_Security.sqlRoles = nextRoles
    end)
end

CreateThread(function()
    Wait(2000)
    while true do
        refreshSqlRoles()
        Wait(60000)
    end
end)

function MA_Security.allowed(source, permission, ignoreDuty)
    local role = MA_Security.role(source)
    local roleData = role and Config.Roles[role]
    local required = Config.Permissions[permission]
    if not roleData or not required or roleData.level < required then return false end
    if Config.RequireDuty and not ignoreDuty and permission ~= 'menu.open' and permission ~= 'staff.duty' and not MA_Security.duty[source] then
        return false, 'duty'
    end
    return true
end

function MA_Security.token(source)
    local value = ('%s:%s:%s'):format(source, os.time(), math.random(100000, 999999))
    MA_Security.sessions[source] = value
    return value
end

function MA_Security.validate(source, token, permission)
    if type(token) ~= 'string' or MA_Security.sessions[source] ~= token then return false, 'session' end
    return MA_Security.allowed(source, permission)
end

function MA_Security.rateLimit(source, action, delay)
    local key = ('%s:%s'):format(source, action)
    local now = GetGameTimer()
    if (MA_Security.cooldowns[key] or 0) > now then return false end
    MA_Security.cooldowns[key] = now + (delay or Config.Cooldowns.action)
    return true
end

function MA_Security.reason(value)
    value = Millennium.Trim(value)
    return #value >= Config.Limits.reasonMin and #value <= Config.Limits.reasonMax and value or nil
end

function MA_Security.identifiers(source)
    local result = {}
    for _, value in ipairs(GetPlayerIdentifiers(source)) do result[#result + 1] = value end
    return result
end

AddEventHandler('playerDropped', function()
    MA_Security.sessions[source] = nil
    MA_Security.duty[source] = nil
end)

exports('HasPermission', function(source, permission) return MA_Security.allowed(source, permission) end)
