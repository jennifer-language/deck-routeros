# Wireless (WiFi)

File: `src/topics/wireless.j`. Paths: `/interface/wireless`
(`WIRELESS_PATH`), `/interface/wireless/security-profiles`
(`WIRELESS_SECURITY_PATH`), `/interface/wireless/registration-table`
(`WIRELESS_REGISTRATION_PATH`).

## Background

This targets RouterOS's **classic wireless menu** (the "wireless"
package). Newer wifiwave2 / ax hardware uses `/interface/wifi` with
different properties - drive that with the generic verbs; the read
functions here simply return empty lists on such routers.

The piece newcomers always miss: the WiFi **password does not live on
the interface**. It lives in a *security profile*, and the interface
references the profile by name. Fresh routers put everything on the
shared `default` profile - which means naively "changing the password"
changes it for every radio at once. routeros never touches `default`:
it manages one dedicated profile per interface, named
`routeros-<interface>`, created or updated idempotently.

## Structs

```jennifer
mt.WirelessInterface {
    id, name, ssid, mode,        # "ap-bridge" = access point, "station" = client
    band, frequency,
    securityProfile,
    masterInterface,             # "" = physical radio; set = virtual AP
    running, disabled, comment
}
mt.WifiClient {
    interfaceName, mac, signalStrength, txRate, rxRate, uptime
}
```

## Functions

| Function | Purpose |
|---|---|
| `setupWifiAccessPoint(c, iface, ssid, password)` | SSID + WPA2 + AP mode + enable, in one call (idempotent) |
| `setWifiSsid(c, iface, ssid)` | rename the network |
| `setWifiPassword(c, iface, password)` | change the passphrase (migrates off `default` automatically) |
| `addVirtualAp(c, master, name, ssid, password)` → id | second SSID on the same radio (guest WiFi) |
| `removeVirtualAp(c, name)` | remove a virtual AP (refuses physical radios) |
| `enableWifi(c, iface)` / `disableWifi(c, iface)` | radio on / off |
| `wirelessInterfaces(c)` → `list of WirelessInterface` | all radios and virtual APs |
| `wifiClients(c)` → `list of WifiClient` | who is connected right now |

Validation: SSIDs 1-32 characters (spaces fine), passphrases 8-63
characters (the WPA2 rules), both explained in the error messages.

## Examples

A working access point in one call:

```jennifer
mt.setupWifiAccessPoint($c, "wlan1", "My Home WiFi", "correct horse battery");
mt.addBridgePort($c, "brlan", "wlan1");     # WiFi joins the LAN
```

Guest WiFi - own SSID, own password, same radio:

```jennifer
mt.addVirtualAp($c, "wlan1", "wlanguest", "Guest WiFi", "changeme123");
# put it in its own bridge/network + firewall it away from the LAN:
mt.addBridge($c, "brguest");
mt.addBridgePort($c, "brguest", "wlanguest");
```

Who is on the WiFi, with signal:

```jennifer
def clients as list of mt.WifiClient init mt.wifiClients($c);
for (def cl in $clients) {
    io.printf("%s on %s, signal %s, %s\n",
        $cl.mac, $cl.interfaceName, $cl.signalStrength, $cl.uptime);
}
```

Rotate the password (clients must re-join):

```jennifer
mt.setWifiPassword($c, "wlan1", "a new long passphrase");
```

## Pitfalls

- **Changing SSID or password kicks every connected client** - they
  reconnect with the new settings (or you walk to the printer).
- A virtual AP shares the master radio's channel and airtime; two SSIDs
  do not double the capacity.
- A guest SSID without its own bridge + firewall is only *cosmetically*
  separate - the traffic still lands in the same LAN. Combine with
  [bridges.md](bridges.md) and [firewall.md](firewall.md), and consider
  a cap from [queues.md](queues.md).
- `wifiClients` reads the classic registration table; wifiwave2 routers
  report nothing here.
- Signal strengths around -50 dBm are excellent, -70 usable, -85
  hopeless; the values are strings as the router reports them.

## Related

- [bridges.md](bridges.md), [firewall.md](firewall.md),
  [queues.md](queues.md), [vlans.md](vlans.md).
