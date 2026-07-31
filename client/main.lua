local open, token, frozen, noclip, spectating = false, nil, false, false, false
local dutyTags = {}

local function serverNotify(message, kind, title, duration)
    kind = kind == 'warning' and 'warning' or kind == 'error' and 'error' or kind == 'success' and 'success' or 'info'
    title = title or 'Admin System'
    duration = tonumber(duration) or 4500
    if GetResourceState('millenium_hud') == 'started' then
        local ok = pcall(function()
            exports['millenium_hud']:Notify(kind, title, tostring(message), duration)
        end)
        if ok then return end
    end
    if GetResourceState('es_extended') == 'started' then
        TriggerEvent('esx:showNotification', tostring(message))
        return
    end
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(message))
    EndTextCommandThefeedPostTicker(false, false)
end

RegisterNetEvent('millennium:client:requestOpen', function()
    TriggerServerEvent('millennium:server:open')
end)

RegisterCommand(Config.Command, function()
    TriggerServerEvent('millennium:server:open')
end, false)

RegisterKeyMapping(Config.Command, 'Open Millennium Admin', 'keyboard', Config.Keybind)

RegisterCommand(Config.DutyCommand, function()
    TriggerServerEvent('millennium:server:toggleDuty')
end, false)

RegisterCommand(Config.NoclipCommand, function()
    TriggerServerEvent('millennium:server:toggleNoclip')
end, false)

RegisterKeyMapping(Config.NoclipCommand, 'Toggle Admin Noclip', 'keyboard', Config.NoclipKeybind)

RegisterNetEvent('millennium:client:open', function(data)
    open, token = true, data.token
    SetNuiFocus(true, true)
    SendNUIMessage({type = 'open', payload = data})
end)

RegisterNUICallback('close', function(_, cb)
    open = false
    SetNuiFocus(false, false)
    cb({ok = true})
end)

RegisterNUICallback('action', function(data, cb)
    local requestId = ('%s:%s'):format(GetGameTimer(), math.random(1000, 9999))
    TriggerServerEvent('millennium:server:request', requestId, token, data.action, data.payload or {})
    cb({accepted = true, requestId = requestId})
end)

RegisterNUICallback('notify', function(data, cb)
    serverNotify(data.message or 'Notification', data.kind, data.title, data.duration)
    cb({ok = true})
end)

RegisterNetEvent('millennium:client:response', function(requestId, ok, data, error)
    SendNUIMessage({type = 'response', requestId = requestId, ok = ok, payload = data, error = error})
end)

RegisterNetEvent('millennium:client:notify', function(message, kind)
    serverNotify(message, kind)
end)

RegisterNetEvent('millennium:client:teleport', function(coords)
    SetEntityCoords(PlayerPedId(), coords.x + 0.0, coords.y + 0.0, coords.z + 0.5, false, false, false, false)
end)

RegisterNetEvent('millennium:client:freeze', function()
    frozen = not frozen
    FreezeEntityPosition(PlayerPedId(), frozen)
    TriggerEvent('millennium:client:notify', frozen and 'You were frozen by staff' or 'You were unfrozen by staff', 'warning')
end)

RegisterNetEvent('millennium:client:vitals', function(action)
    local ped = PlayerPedId()
    if action == 'kill' then SetEntityHealth(ped, 0)
    elseif action == 'heal' then SetEntityHealth(ped, GetEntityMaxHealth(ped)); SetPedArmour(ped, 100)
    elseif action == 'revive' then
        local c = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
    end
end)

RegisterNetEvent('millennium:client:adminMessage', function(staff, message)
    TriggerEvent('millennium:client:notify', ('Message from %s: %s'):format(staff, message), 'warning')
end)

RegisterNetEvent('millennium:client:announcement', function(message)
    PlaySoundFrontend(-1, 'CONFIRM_BEEP', 'HUD_MINI_GAME_SOUNDSET', true)
    SendNUIMessage({type = 'announcement', message = message})
end)

RegisterNetEvent('millennium:client:staffWarning', function(message)
    PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
    SendNUIMessage({type = 'staffWarning', message = message})
end)

RegisterNetEvent('millennium:client:dutyTags', function(tags)
    dutyTags = type(tags) == 'table' and tags or {}
end)

RegisterNetEvent('millennium:client:dutyState', function(active)
    SendNUIMessage({type = 'dutyState', active = active == true})
end)

local function drawDutyText(text, x, y, scale, colour)
    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextCentre(true)
    SetTextColour(colour[1], colour[2], colour[3], colour[4])
    SetTextDropShadow(2, 0, 0, 0, math.min(255, colour[4]))
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function drawDutyTag(coords, name, role)
    local visible, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not visible then return end
    local camera = GetGameplayCamCoords()
    local distance = #(camera - coords)
    local fade = math.floor(math.max(190, 255 - (distance / (Config.DutyTags.distance or 25.0)) * 60))
    local scale = math.max(0.27, math.min(0.38, 0.68 / math.max(distance * 0.075, 1.0)))
    local displayName = tostring(name or 'Staff')
    local status = ('%s  •  %s'):format(string.upper(role or 'STAFF'), Config.DutyTags.text or 'ON DUTY')
    -- Layered translucent text gives a soft glass-like finish without a badge background.
    drawDutyText(displayName, x + 0.0012, y - 0.0038, scale * 1.04, {5, 7, 12, math.floor(fade * 0.85)})
    drawDutyText(displayName, x, y - 0.005, scale, {255, 255, 255, fade})
    drawDutyText(status, x + 0.001, y + 0.015, scale * 0.82, {7, 9, 16, math.floor(fade * 0.8)})
    drawDutyText(status, x, y + 0.014, scale * 0.8, {183, 194, 255, fade})
end

RegisterNetEvent('millennium:client:vehicle', function(action, model)
    local ped = PlayerPedId()
    if action == 'spawn' then
        local hash = joaat(model)
        if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
            return TriggerEvent('millennium:client:notify', 'Invalid vehicle model', 'error')
        end
        RequestModel(hash)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
        if not HasModelLoaded(hash) then return TriggerEvent('millennium:client:notify', 'Vehicle model failed to load', 'error') end
        local c, heading = GetEntityCoords(ped), GetEntityHeading(ped)
        local vehicle = CreateVehicle(hash, c.x, c.y, c.z, heading, true, true)
        SetVehicleOnGroundProperly(vehicle)
        SetPedIntoVehicle(ped, vehicle, -1)
        SetEntityAsMissionEntity(vehicle, true, true)
        SetModelAsNoLongerNeeded(hash)
    else
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle == 0 then
            local c = GetEntityCoords(ped)
            vehicle = GetClosestVehicle(c.x, c.y, c.z, 8.0, 0, 70)
        end
        if vehicle == 0 then return TriggerEvent('millennium:client:notify', 'No nearby vehicle', 'error') end
        if action == 'repair' then
            SetVehicleFixed(vehicle); SetVehicleDirtLevel(vehicle, 0.0); SetVehicleEngineHealth(vehicle, 1000.0)
        elseif action == 'delete' then
            NetworkRequestControlOfEntity(vehicle)
            local timeout = GetGameTimer() + 1500
            while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < timeout do Wait(0); NetworkRequestControlOfEntity(vehicle) end
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end
end)

RegisterNetEvent('millennium:client:noclip', function()
    noclip = not noclip
    local ped = PlayerPedId()
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({type = 'close'})
    SetEntityCollision(ped, not noclip, not noclip)
    FreezeEntityPosition(ped, noclip)
    SetEntityInvincible(ped, noclip)
    TriggerEvent('millennium:client:notify', noclip and 'Noclip enabled' or 'Noclip disabled', 'success')
end)

RegisterNetEvent('millennium:client:spectate', function(target)
    if spectating then
        NetworkSetInSpectatorMode(false, PlayerPedId())
        spectating = false
        return
    end
    local player = GetPlayerFromServerId(target)
    if player == -1 then return TriggerEvent('millennium:client:notify', 'Target is not streamed', 'error') end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({type = 'close'})
    NetworkSetInSpectatorMode(true, GetPlayerPed(player))
    spectating = true
end)

RegisterNUICallback('report', function(data, cb)
    TriggerServerEvent('millennium:server:createReport', data.category, data.message)
    cb({ok = true})
end)

CreateThread(function()
    while true do
        if open then
            Wait(0)
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 200, true)
            if IsDisabledControlJustReleased(0, 200) then
                open = false
                SetNuiFocus(false, false)
                SendNUIMessage({type = 'close'})
            end
        else Wait(500) end
    end
end)

CreateThread(function()
    TriggerServerEvent('millennium:server:requestDutyTags')
    while true do
        local wait = 750
        if Config.DutyTags and Config.DutyTags.enabled and next(dutyTags) then
            local myCoords = GetEntityCoords(PlayerPedId())
            for serverId, data in pairs(dutyTags) do
                local player = GetPlayerFromServerId(tonumber(serverId))
                if player ~= -1 then
                    local ped = GetPlayerPed(player)
                    if ped > 0 then
                        local coords = GetEntityCoords(ped)
                        if #(myCoords - coords) <= (Config.DutyTags.distance or 25.0) then
                            wait = 0
                            drawDutyTag(coords + vector3(0.0, 0.0, 1.15), data.name, data.role)
                        end
                    end
                end
            end
        end
        Wait(wait)
    end
end)

CreateThread(function()
    while true do
        if noclip then
            Wait(0)
            local ped = PlayerPedId()
            local position = GetEntityCoords(ped)
            local forward = GetGameplayCamRot(2)
            local heading, pitch = math.rad(forward.z), math.rad(forward.x)
            local direction = vector3(-math.sin(heading) * math.cos(pitch), math.cos(heading) * math.cos(pitch), math.sin(pitch))
            local speed = IsControlPressed(0, 21) and 3.0 or 1.0
            if IsControlPressed(0, 32) then position = position + direction * speed end
            if IsControlPressed(0, 33) then position = position - direction * speed end
            if IsControlPressed(0, 22) then position = position + vector3(0, 0, speed) end
            if IsControlPressed(0, 36) then position = position - vector3(0, 0, speed) end
            SetEntityCoordsNoOffset(ped, position.x, position.y, position.z, true, true, true)
        else Wait(500) end
    end
end)
