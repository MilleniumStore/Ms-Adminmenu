-- Public client convenience API. Privileged actions still route to the server.

exports('OpenAdminMenu', function()
    TriggerServerEvent('millennium:server:open')
end)

exports('ToggleAdminDuty', function()
    TriggerServerEvent('millennium:server:toggleDuty')
end)

exports('ToggleAdminNoclip', function()
    TriggerServerEvent('millennium:server:toggleNoclip')
end)

exports('Notify', function(message, kind)
    TriggerEvent('millennium:client:notify', message, kind or 'info')
end)

exports('ShowAnnouncement', function(message)
    SendNUIMessage({type = 'announcement', message = tostring(message)})
end)

exports('ShowStaffWarning', function(message)
    SendNUIMessage({type = 'staffWarning', message = tostring(message)})
end)
