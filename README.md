Our Tebex : https://millenium.tebex.store/
Join our discord for support : (https://discord.gg/EM4uF7Wfen)
# Ms-Adminmenu

Plug-and-play, server-authoritative administration resource for FiveM. It includes
a modern NUI, automatic framework/inventory detection, txAdmin and ACE permission
inheritance, staff duty, reports, moderation, economy tools, vehicle tools,
announcements, audit logs and a public export API.

## Compatibility

- ESX Legacy, QBCore, Qbox and standalone
- ox_inventory with automatic item validation
- oxmysql and MySQL-Async
- txAdmin `isStaff` state
- Existing `group.admin`/ACE server permissions
- OneSync
- Millennium HUD notifications with ESX fallback

No framework, inventory, HUD or permission resource needs to be edited.

## Commands and keys

| Command/key | Action |
|---|---|
| `/adminmenu` or `F10` | Open the admin panel |
| `/adminduty` | Toggle staff duty |
| `/adminnoclip` or `F2` | Toggle noclip while on duty |
| `/adminrole` | Display the resolved panel role |
| `/report <message>` | Create a player report |

FiveM key mappings are rebindable from Settings → Key Bindings.

## Included systems

- Dashboard, server metrics and resource overview
- Live player directory and staff duty tags
- Teleport, bring, spectate, freeze, heal, revive and kill
- Private admin messages and full-screen warnings
- Kick, timed/permanent ban and punishment revocation
- ox_inventory give/remove item
- Cash/bank add/remove and framework job management
- Vehicle spawn/give, repair and delete
- Noclip with server-side permission checks
- Full-screen server announcements
- Player reports, SQL audit history and Discord logging
- Safe allowlisted resource start/stop/restart

## Permission resolution

The first matching source grants the role:

1. `Config.Staff`
2. SQL `millennium_staff`
3. Custom `millennium.role.<role>` ACE
4. Existing server admin ACE (`command` by default)
5. txAdmin `isStaff`
6. ESX/QBCore framework groups

All NUI actions and mutating server exports validate permissions on the server.
The browser and game client are never trusted with authority.

## Server exports

Use the actual folder/resource name in the export call. The examples use
`Ms-Adminmenu`.

### Permission and staff state

```lua
local role = exports['Ms-Adminmenu']:GetAdminRole(source)
local level = exports['Ms-Adminmenu']:GetRoleLevel(source)
local isStaff = exports['Ms-Adminmenu']:IsStaff(source)
local onDuty = exports['Ms-Adminmenu']:IsOnDuty(source)
local allowed, reason = exports['Ms-Adminmenu']:HasPermission(source, 'players.warn')

exports['Ms-Adminmenu']:SetDuty(source, true)
local ok, active = exports['Ms-Adminmenu']:ToggleDuty(source)
```

### Notifications and announcements

```lua
exports['Ms-Adminmenu']:NotifyPlayer(targetSource, 'Payment received', 'success')
exports['Ms-Adminmenu']:Announce(staffSource, 'Restart in ten minutes.')
```

### Moderation

```lua
exports['Ms-Adminmenu']:WarnPlayer(staffSource, targetSource, 'Fail RP')
exports['Ms-Adminmenu']:KickPlayer(staffSource, targetSource, 'Rule violation')
exports['Ms-Adminmenu']:BanPlayer(staffSource, targetSource, 'Cheating', 86400, 'clip-123')
exports['Ms-Adminmenu']:AddStaffNote(targetLicense, staffSource, 'Internal note')
```

Ban duration is in seconds. Use `0` for permanent.

### Inventory, money and jobs

```lua
exports['Ms-Adminmenu']:GiveItem(staffSource, targetSource, 'water', 2, 'Event reward')
exports['Ms-Adminmenu']:RemoveItem(staffSource, targetSource, 'weapon_pistol', 1, 'Confiscated')
exports['Ms-Adminmenu']:AddMoney(staffSource, targetSource, 'bank', 5000, 'Compensation')
exports['Ms-Adminmenu']:RemoveMoney(staffSource, targetSource, 'cash', 500, 'Correction')
exports['Ms-Adminmenu']:SetPlayerJob(staffSource, targetSource, 'police', 2, 'Promotion')
```

### Player and vehicle actions

```lua
exports['Ms-Adminmenu']:FreezePlayer(staffSource, targetSource)
exports['Ms-Adminmenu']:HealPlayer(staffSource, targetSource)
exports['Ms-Adminmenu']:RevivePlayer(staffSource, targetSource)
exports['Ms-Adminmenu']:KillPlayer(staffSource, targetSource)
exports['Ms-Adminmenu']:MessagePlayer(staffSource, targetSource, 'Please open a support ticket.')
exports['Ms-Adminmenu']:TeleportToPlayer(staffSource, targetSource)
exports['Ms-Adminmenu']:BringPlayer(staffSource, targetSource)
exports['Ms-Adminmenu']:SpectatePlayer(staffSource, targetSource)
exports['Ms-Adminmenu']:SpawnVehicleForPlayer(staffSource, targetSource, 'adder')
exports['Ms-Adminmenu']:RepairStaffVehicle(staffSource)
exports['Ms-Adminmenu']:DeleteStaffVehicle(staffSource)

local players = exports['Ms-Adminmenu']:GetOnlinePlayers()
local framework = exports['Ms-Adminmenu']:GetFramework()
```

Every mutating export returns `true` on success or `false, errorMessage`.
`staffSource` must be an online authorized staff player and must be on duty unless
the operation is a duty-management operation.

## Client exports

```lua
exports['Ms-Adminmenu']:OpenAdminMenu()
exports['Ms-Adminmenu']:ToggleAdminDuty()
exports['Ms-Adminmenu']:ToggleAdminNoclip()
exports['Ms-Adminmenu']:Notify('Local notification', 'info')
exports['Ms-Adminmenu']:ShowAnnouncement('Local preview')
exports['Ms-Adminmenu']:ShowStaffWarning('Local preview')
```

Client exports are convenience/UI functions. Use server exports for privileged
gameplay actions.

## Configuration

Important settings in `config.lua`:

- `Config.Framework` and `Config.Database`: keep `auto` for plug-and-play detection.
- `Config.Integrations.inventory`: detects ox_inventory automatically.
- `Config.TxAdmin`: maps authenticated txAdmin staff to a panel role.
- `Config.ServerAdminAce`: inherits the server's current admin ACE.
- `Config.FrameworkGroups`: maps ESX/QB groups to panel roles.
- `Config.Permissions`: minimum role level per action.
- `Config.AllowedResources`: resource control allowlist.
- `Config.DutyTags`: overhead staff tag settings.
- `Config.Webhooks`: optional Discord audit webhooks.

See [INSTALL.md](INSTALL.md) for installation and troubleshooting.

## Security notes

- Never invoke privileged behavior from a client event in another resource.
- Call the server exports and always pass the real staff player source.
- Do not expose arbitrary console execution or allow all resources to be stopped.
- Inventory items, amounts, money, jobs, targets, reasons and vehicle models are
  validated before use.
- Every supported administrative mutation is written to the audit logger.
