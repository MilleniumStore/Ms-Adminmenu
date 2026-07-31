# Installation Guide

## 1. Install the resource

Place the folder in your server resources directory. The current resource name is
`Ms-Adminmenu`. If you rename it, use the new name in `ensure` and export calls.

Recommended load order:

```cfg
ensure oxmysql
ensure es_extended
ensure ox_lib
ensure ox_inventory
ensure millenium_hud
ensure Ms-Adminmenu
```

Only installed dependencies need to be listed. The admin resource detects ESX,
QBCore, Qbox, ox_inventory, oxmysql and MySQL-Async automatically.

OneSync must be enabled.

## 2. Import the database

Import:

```text
sql/install.sql
```

into the same database used by the framework. It creates:

- `millennium_punishments`
- `millennium_audit`
- `millennium_notes`
- `millennium_staff`

Without a database, live actions still work, but bans, warnings, notes and audit
history are not persistent.

## 3. Permissions

Existing server admins are inherited automatically. A standard ESX Legacy config
usually contains:

```cfg
add_principal identifier.fivem:YOUR_ID group.admin
add_ace group.admin command allow
```

The `command` ACE maps to the panel `owner` role through
`Config.ServerAdminAce`. txAdmin staff are also detected through `isStaff`.

You can alternatively grant a panel-specific role:

```cfg
add_ace identifier.license:YOUR_LICENSE millennium.role.owner allow
```

Available roles:

- `support`
- `trialmod`
- `moderator`
- `admin`
- `senioradmin`
- `headadmin`
- `management`
- `owner`

Other options are `Config.Staff`, `Config.FrameworkGroups`, or inserting a row in
`millennium_staff`.

After joining, verify access:

```text
/adminrole
/adminmenu
/adminduty
```

## 4. Configure integrations

The defaults are plug-and-play:

```lua
Config.Framework = 'auto'
Config.Database = 'auto'
Config.Integrations.inventory = 'auto'
```

For notifications, `millenium_hud` is used when running, with ESX notification
fallback. No HUD edits are required.

For ox_inventory, item names are checked against its registered item list before
`AddItem` or `RemoveItem` is called.

## 5. Configure safe resource management

Only resources explicitly listed here can be started, stopped or restarted:

```lua
Config.AllowedResources = {
    ['pma-voice'] = true,
    ['ox_target'] = true
}
```

Never allowlist `oxmysql`, your framework, txAdmin components, or `Ms-Adminmenu`
unless you understand the consequences. The admin resource blocks managing itself.

## 6. Discord logging

Add webhook URLs in `Config.Webhooks`:

```lua
Config.Webhooks = {
    default = '',
    punishments = '',
    reports = '',
    economy = ''
}
```

Leave them empty to disable webhook delivery. SQL logging is independently
controlled by `Config.Logging.sql`.

## 7. Verify the installation

Restart the server or run:

```text
restart Ms-Adminmenu
```

Check the server console for detected framework/database information. Then verify:

1. `/adminrole` resolves the expected role.
2. `/adminmenu` or F10 opens the panel.
3. `/adminduty` enables the duty tag.
4. F2 toggles noclip while on duty.
5. Give/remove item works with a valid ox_inventory item.
6. Warnings and announcements appear on the target screen.
7. Punishment and audit pages load SQL records.

## Export integration

No edits to ESX, inventory, HUD or txAdmin are required. Other resources can call
the separate exports documented in [README.md](README.md).

Server example:

```lua
RegisterCommand('rewardplayer', function(source, args)
    local target = tonumber(args[1])
    local ok, err = exports['Ms-Adminmenu']:GiveItem(source, target, 'water', 1, 'Admin reward')
    if not ok then
        exports['Ms-Adminmenu']:NotifyPlayer(source, err, 'error')
    end
end)
```

## Troubleshooting

### Menu does not open

- Run `/adminrole`.
- Confirm the player has `group.admin`, txAdmin staff, a mapped framework group,
  or a Millennium role.
- Check that `Ms-Adminmenu` started without errors.

### Action requires duty

Run `/adminduty` or use the panel duty button.

### Punishments or audit logs do not load

- Import `sql/install.sql`.
- Start oxmysql/MySQL-Async before this resource.
- Confirm the detected database driver in the server console.
- Audit view requires the configured `audit.view` role level.

### Give item fails

- Confirm ox_inventory is started first.
- Use the exact registered item name.
- Check inventory capacity.
- Review `Config.Limits.itemMax`.

### Existing server admin has no panel access

- Confirm `Config.ServerAdminAce.enabled = true`.
- Confirm the admin principal has the mapped ACE (`command` by default).
- Run `/adminrole` after reconnecting.

### Resource controls are read-only

- The user must meet `server.resources` permission level.
- The resource must be in `Config.AllowedResources`.
- `Config.Features.resourceManagement` must be enabled.

### Notification does not appear

- Ensure `millenium_hud` starts before this resource, or ensure ESX notification
  events are available.

## Updating

Back up `config.lua` and the database. Review new configuration keys, merge your
role/resource allowlists, apply SQL migrations if provided, and restart the
resource.
