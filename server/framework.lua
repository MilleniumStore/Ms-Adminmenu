MA_Framework = {name = 'standalone', object = nil}

local function detectFramework()
    local wanted = Config.Framework
    if wanted == 'auto' then
        if GetResourceState('qbx_core') == 'started' then wanted = 'qbox'
        elseif GetResourceState('qb-core') == 'started' then wanted = 'qbcore'
        elseif GetResourceState('es_extended') == 'started' then wanted = 'esx'
        else wanted = 'standalone' end
    end
    MA_Framework.name = wanted
    if wanted == 'qbcore' then MA_Framework.object = exports['qb-core']:GetCoreObject()
    elseif wanted == 'esx' then MA_Framework.object = exports.es_extended:getSharedObject() end
    print(('[Millennium Admin] Framework: %s | Database: %s'):format(wanted, MA_DB.driver))
end

CreateThread(function()
    Wait(1000)
    detectFramework()
end)

function MA_Framework.player(source)
    if MA_Framework.name == 'qbcore' then return MA_Framework.object.Functions.GetPlayer(source)
    elseif MA_Framework.name == 'qbox' then return exports.qbx_core:GetPlayer(source)
    elseif MA_Framework.name == 'esx' then return MA_Framework.object.GetPlayerFromId(source) end
end

function MA_Framework.group(source)
    local player = MA_Framework.player(source)
    if not player then return nil end
    if MA_Framework.name == 'esx' then return player.getGroup() end
    if MA_Framework.name == 'qbcore' then
        for group in pairs(Config.FrameworkGroups) do
            if MA_Framework.object.Functions.HasPermission(source, group) then return group end
        end
    end
    return nil
end

function MA_Framework.identity(source)
    local player = MA_Framework.player(source)
    if MA_Framework.name == 'esx' and player then
        return {name = player.getName(), job = player.job and player.job.label or 'Unemployed',
            grade = player.job and player.job.grade_label or '', cash = player.getMoney(),
            bank = player.getAccount('bank') and player.getAccount('bank').money or 0}
    elseif (MA_Framework.name == 'qbcore' or MA_Framework.name == 'qbox') and player then
        local d = player.PlayerData
        local c = d.charinfo or {}
        return {name = ((c.firstname or '') .. ' ' .. (c.lastname or '')):gsub('^%s*(.-)%s*$', '%1'),
            job = d.job and d.job.label or 'Unemployed', grade = d.job and d.job.grade and (d.job.grade.name or d.job.grade.level) or '',
            cash = d.money and d.money.cash or 0, bank = d.money and d.money.bank or 0}
    end
    return {name = GetPlayerName(source) or ('Player %s'):format(source), job = 'Standalone', grade = '', cash = 0, bank = 0}
end

function MA_Framework.money(source, operation, account, amount, reason)
    local player = MA_Framework.player(source)
    if not player then return false, 'Framework player unavailable' end
    if MA_Framework.name == 'esx' then
        local kind = account == 'cash' and 'money' or account
        if operation == 'add' then
            if kind == 'money' then player.addMoney(amount) else player.addAccountMoney(kind, amount, reason) end
        elseif operation == 'remove' then
            if kind == 'money' then player.removeMoney(amount) else player.removeAccountMoney(kind, amount, reason) end
        else return false, 'Unsupported operation' end
    else
        if operation == 'add' then player.Functions.AddMoney(account, amount, reason)
        elseif operation == 'remove' then player.Functions.RemoveMoney(account, amount, reason)
        else return false, 'Unsupported operation' end
    end
    return true
end

function MA_Framework.item(source, operation, item, amount)
    if GetResourceState('ox_inventory') == 'started' and (Config.Integrations.inventory == 'auto' or Config.Integrations.inventory == 'ox_inventory') then
        local definition = exports.ox_inventory:Items(item)
        if not definition then return false, 'Unknown inventory item' end
        if operation == 'add' then
            local success, response = exports.ox_inventory:AddItem(source, item, amount)
            return success == true, success and nil or (response or 'Inventory is full')
        elseif operation == 'remove' then
            local success, response = exports.ox_inventory:RemoveItem(source, item, amount)
            return success == true, success and nil or (response or 'Player does not have enough items')
        end
    end
    local player = MA_Framework.player(source)
    if not player then return false, 'Framework player unavailable' end
    if MA_Framework.name == 'esx' then
        if operation == 'add' then player.addInventoryItem(item, amount)
        elseif operation == 'remove' then player.removeInventoryItem(item, amount)
        else return false, 'Unsupported operation' end
        return true
    elseif MA_Framework.name == 'qbcore' then
        if operation == 'add' then return player.Functions.AddItem(item, amount) == true
        elseif operation == 'remove' then return player.Functions.RemoveItem(item, amount) == true end
    end
    return false, 'No supported inventory integration is running'
end

function MA_Framework.setJob(source, job, grade)
    local player = MA_Framework.player(source)
    if not player then return false, 'Framework player unavailable' end
    grade = tonumber(grade)
    if not grade or grade < 0 then return false, 'Invalid job grade' end
    if MA_Framework.name == 'esx' then
        player.setJob(job, grade)
        return true
    elseif MA_Framework.name == 'qbcore' then
        return player.Functions.SetJob(job, grade) == true
    elseif MA_Framework.name == 'qbox' then
        local ok = exports.qbx_core:SetJob(source, job, grade)
        return ok == true
    end
    return false, 'Job management requires ESX, QBCore or Qbox'
end

exports('GetFramework', function() return MA_Framework.name end)
