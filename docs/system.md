# System: packages, updates, firmware, reboot

File: `src/topics/system.j`. Paths: `/system/package`,
`/system/package/update`, `/system/routerboard`, `/system/resource`,
`/system/identity` (`SYSTEM_PACKAGE_PATH`, `SYSTEM_UPDATE_PATH`,
`SYSTEM_ROUTERBOARD_PATH`, `SYSTEM_RESOURCE_PATH`,
`SYSTEM_IDENTITY_PATH`).

## Background

Keeping a MikroTik healthy involves two separate update tracks that
newcomers conflate:

1. **RouterOS packages** - the operating system. Checked and installed
   via the package updater; installing reboots the router.
2. **Routerboard firmware** - the boot loader underneath. Every
   RouterOS update *ships* a matching firmware, but it is only flashed
   when you ask, and it takes effect at the *next* reboot.

So the full update dance is: check → install (reboots) → reconnect →
upgrade routerboard → reboot again. routeros gives you each step and
tells you which ones drop the connection.

## Structs

```jennifer
mt.SystemInfo   { version, boardName, architecture, uptime, cpuLoad, freeMemory, totalMemory }
mt.Package      { id, name, version, disabled }
mt.UpdateStatus { channel, installedVersion, latestVersion, status, updateAvailable }
mt.Routerboard  { model, serialNumber, firmwareType, currentFirmware, upgradeFirmware, upgradeAvailable }
```

`updateAvailable` / `upgradeAvailable` are computed for you (both
versions known and different).

## Functions

| Function | Purpose |
|---|---|
| `systemInfo(c)` → `SystemInfo` | version, hardware, uptime, load |
| `identity(c)` / `setIdentity(c, name)` | the router's name |
| `packages(c)` → `list of Package` | installed packages |
| `checkForUpdates(c)` → `UpdateStatus` | read-only check (needs internet) |
| `downloadUpdates(c)` → `UpdateStatus` | fetch now, install on next reboot |
| `installUpdates(c)` | download + install; **reboots the router** |
| `routerboard(c)` → `Routerboard` | firmware state |
| `upgradeRouterboard(c)` | stage the firmware flash (applies at next reboot) |
| `reboot(c)` | reboot now; connection drops |
| `shutdown(c)` | power off; someone must push the button |
| `deviceMode(c)` → `DeviceMode` | the active mode and the features it gates |
| `updateDeviceMode(c, mode)` | **request** a mode change (needs physical confirmation) |

## Examples

Health report:

```jennifer
def info as mt.SystemInfo init mt.systemInfo($c);
io.printf("%s: RouterOS %s on %s, up %s, cpu %s\n",
    mt.identity($c), $info.version, $info.boardName, $info.uptime, $info.cpuLoad);
```

The full, safe update sequence:

```jennifer
def st as mt.UpdateStatus init mt.checkForUpdates($c);
if ($st.updateAvailable) {
    io.printf("updating %s -> %s\n", $st.installedVersion, $st.latestVersion);
    mt.installUpdates($c);          # router reboots itself; client is dead now
    # ... wait for the router to come back, then reconnect ...
    # def c2 as mt.Client init mt.connect($host, $user, $password);
    # if (mt.routerboard($c2).upgradeAvailable) {
    #     mt.upgradeRouterboard($c2);
    #     mt.reboot($c2);           # firmware takes effect
    # }
}
```

Rename a batch of routers:

```jennifer
mt.setIdentity($c, "office-gw");
```

## Device mode

RouterOS gates the features that can execute code - the scheduler,
`/tool/fetch`, e-mail, containers - behind a *device mode*. On a router
in `home` mode those menus report as missing rather than refused, which
is worth checking first when a feature "does not exist":

```jennifer
def d as mt.DeviceMode init mt.deviceMode($c);
io.printf("mode=%s scheduler=%t container=%t\n", $d.mode, $d.scheduler, $d.container);
```

Raising the mode is deliberately not something a remote script can
finish on its own:

```jennifer
mt.updateDeviceMode($c, mt.DEVICE_MODE_ADVANCED);
```

That call only makes the change **pending**. The router applies it when
someone power-cycles it - a cold boot, *not* `reboot(c)` - or presses
the reset button, within a few minutes. Miss the window and the request
is discarded silently, leaving the mode as it was. Modes are
`DEVICE_MODE_HOME`, `DEVICE_MODE_ADVANCED`, and
`DEVICE_MODE_ENTERPRISE`.

## Connection-dropping semantics

`installUpdates`, `reboot`, and `shutdown` succeed by killing the
connection. routeros distinguishes the two outcomes: a **router
refusal** (`!trap`, e.g. the user lacks the `reboot` policy) is
re-thrown as `Error{kind: "mikrotik"}`, while the transport error from
the dropped connection is swallowed - that is what success looks like.
After any of them, the `Client` is unusable; reconnect with
`mt.connect`.

## Pitfalls

- `checkForUpdates` needs the router itself to have working internet
  *and DNS* ([dns.md](dns.md)); a failure comes back as
  `kind: "mikrotik"` with the updater's message.
- Update, *then* firmware: `upgradeRouterboard` flashes the firmware
  version that shipped with the currently installed RouterOS, so run it
  after `installUpdates` and its reboot.
- `shutdown` on a remote router means a car ride. The docblock says as
  much; prefer `reboot`.
- Version strings are reported verbatim (e.g. `"7.15.2 (stable)"` in
  `SystemInfo.version`); comparisons beyond equality are on you.

## Related

- [scheduler.md](scheduler.md) (nightly backups before updating is a
  good habit), [tools.md](tools.md) (verify the uplink after a reboot).
