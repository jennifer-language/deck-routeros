# Modern WiFi (wifiwave2 / ax)

File: `src/topics/wifi.j`. Paths: `/interface/wifi` (`WIFI_PATH`),
`/interface/wifi/registration-table` (`WIFI_REGISTRATION_PATH`).
RouterOS v7 on ax-generation hardware.

## Background

MikroTik has two WiFi stacks. Older boards use the classic
`/interface/wireless` menu ([wireless.md](wireless.md)); ax-generation
hardware uses `/interface/wifi` with a different configuration model -
properties grouped into dotted keys (`configuration.ssid`,
`security.passphrase`) and **no separate security profiles**: the
passphrase lives on the interface. This topic mirrors the classic
topic's surface for the modern menu; the read functions of each return
empty lists on the other kind of router, so a script can probe both:

```jennifer
def classic as list of mt.WirelessInterface init mt.wirelessInterfaces($c);
def modern as list of mt.WifiInterface init mt.wifiInterfaces($c);
```

## Structs

```jennifer
mt.WifiInterface    { id, name, ssid, band, masterInterface, running, disabled, comment }
mt.WifiRegistration { interfaceName, ssid, mac, signal, uptime }
```

## Functions

| Function | Purpose |
|---|---|
| `setupWifi(c, iface, ssid, password)` | SSID + WPA2/WPA3 + AP mode + enable |
| `setWifiPassphrase(c, iface, password)` | rotate the passphrase |
| `addVirtualWifi(c, master, name, ssid, password)` → id | guest network on the same radio |
| `removeVirtualWifi(c, name)` | remove a virtual AP (refuses radios) |
| `wifiInterfaces(c)` → `list of WifiInterface` | radios and virtual APs |
| `wifiRegistrations(c)` → `list of WifiRegistration` | connected clients |

Enable/disable go through the interface topic (`enableInterface` /
`disableInterface`) - WiFi interfaces are interfaces. Validation is
shared with the classic topic: SSIDs 1-32 chars, passphrases 8-63.

## Examples

A working access point, WPA2+WPA3:

```jennifer
mt.setupWifi($c, "wifi1", "My Home WiFi", "correct horse battery");
mt.addBridgePort($c, "brlan", "wifi1");
```

Guest WiFi with its own bridge and a bandwidth cap:

```jennifer
mt.addVirtualWifi($c, "wifi1", "wifiguest", "Guest WiFi", "changeme123");
mt.addBridge($c, "brguest");
mt.addBridgePort($c, "brguest", "wifiguest");
mt.limitBandwidth($c, "qguest", "192.168.90.0/24", "5M", "20M");
```

Who is on, with signal:

```jennifer
def regs as list of mt.WifiRegistration init mt.wifiRegistrations($c);
for (def r in $regs) {
    io.printf("%s on %s (%s), signal %s dBm, %s\n",
        $r.mac, $r.interfaceName, $r.ssid, $r.signal, $r.uptime);
}
```

## Pitfalls

- **Know your stack first**: `setupWifi` on a classic-wireless board
  fails with "WiFi interface not found" - probe with `wifiInterfaces`
  vs `wirelessInterfaces` when the hardware is unknown.
- `setupWifi` enables WPA2+WPA3 mixed mode; a rare legacy client that
  chokes on WPA3 transition mode can be accommodated via the generic
  `set` (`security.authentication-types=wpa2-psk`).
- Passphrase changes drop all clients (same as classic).
- Dual-band boards have `wifi1` and `wifi2` (2.4/5 GHz) - give both the
  same SSID and passphrase for seamless roaming, or distinct ones to
  steer devices.
- CAPsMAN-managed radios ignore local settings; that controller is
  outside this topic (generic verbs).

## Related

- [wireless.md](wireless.md) (the classic stack),
  [bridges.md](bridges.md), [queues.md](queues.md),
  [firewall.md](firewall.md) (isolate the guest bridge).
