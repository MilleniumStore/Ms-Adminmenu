MA_DB = {driver = 'none', connected = false}

function MA_DB.detect()
    if Config.Database == 'oxmysql' or (Config.Database == 'auto' and GetResourceState('oxmysql') == 'started') then
        MA_DB.driver = 'oxmysql'
        MA_DB.connected = true
        print('[Millennium Admin] Database driver: oxmysql')
        return true
    elseif Config.Database == 'mysql-async' or (Config.Database == 'auto' and GetResourceState('mysql-async') == 'started') then
        MA_DB.driver = 'mysql-async'
        -- Verify mysql-async is fully ready by attempting a simple query
        MySQL.Async.fetchAll('SELECT 1 AS test', {}, function(result)
            if result then
                MA_DB.connected = true
                print('[Millennium Admin] Database driver: mysql-async (connected)')
            else
                MA_DB.connected = false
                print('[Millennium Admin] [WARNING] mysql-async detected but connection failed, will retry...')
            end
        end)
        return true
    end
    MA_DB.connected = false
    return false
end

-- Retry loop: keeps trying until a database driver is found and connected
CreateThread(function()
    Wait(2000) -- Give other resources time to start
    while true do
        if MA_DB.detect() then
            -- For oxmysql we assume it's connected since exports exist
            if MA_DB.driver == 'oxmysql' then
                break
            end
            -- For mysql-async wait until the connection test completes
            if MA_DB.connected then
                break
            end
        else
            local drv = Config.Database ~= 'auto' and Config.Database or 'auto'
            print(('[Millennium Admin] [WARNING] Database driver (%s) not available yet, retrying in 5 seconds...'):format(drv))
        end
        Wait(5000)
    end
end)

function MA_DB.ready()
    return MA_DB.driver ~= 'none' and MA_DB.connected == true
end

function MA_DB.query(sql, params, callback)
    params = params or {}
    callback = callback or function() end
    if not MA_DB.ready() then
        print(('[Millennium Admin] [ERROR] Database query attempted but no driver available:\n%s'):format(sql))
        callback({})
        return
    end
    if MA_DB.driver == 'oxmysql' then
        exports.oxmysql:query(sql, params, callback)
    elseif MA_DB.driver == 'mysql-async' then
        MySQL.Async.fetchAll(sql, params, callback)
    else
        callback({})
    end
end

function MA_DB.insert(sql, params, callback)
    params = params or {}
    callback = callback or function() end
    if not MA_DB.ready() then
        print(('[Millennium Admin] [ERROR] Database insert attempted but no driver available:\n%s'):format(sql))
        callback(nil)
        return
    end
    if MA_DB.driver == 'oxmysql' then
        exports.oxmysql:insert(sql, params, callback)
    elseif MA_DB.driver == 'mysql-async' then
        MySQL.Async.insert(sql, params, callback)
    else
        callback(nil)
    end
end

function MA_DB.update(sql, params, callback)
    params = params or {}
    callback = callback or function() end
    if not MA_DB.ready() then
        print(('[Millennium Admin] [ERROR] Database update attempted but no driver available:\n%s'):format(sql))
        callback(0)
        return
    end
    if MA_DB.driver == 'oxmysql' then
        exports.oxmysql:update(sql, params, callback)
    elseif MA_DB.driver == 'mysql-async' then
        MySQL.Async.execute(sql, params, callback)
    else
        callback(0)
    end
end
