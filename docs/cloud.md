# Cloud DDNS

File: `src/topics/cloud.j`. Path: `/ip/cloud` (`CLOUD_PATH`).

## Background

Most home and small-office WANs get a *dynamic* public address - it
changes, and everything that needs to reach the router from outside
(road-warrior WireGuard, port forwards, Let's Encrypt) breaks with it.
MikroTik's built-in answer is free and one flag away: the router
registers `<serial>.sn.mynetname.net` with MikroTik's DDNS and keeps it
pointed at the current address. Not a pretty name, but a *stable* one -
and a CNAME in your own zone can dress it up.

## Struct

```jennifer
mt.CloudStatus { ddnsEnabled, dnsName, publicAddress, updateTime }
```

## Functions

| Function | Purpose |
|---|---|
| `enableCloudDns(c)` | register + force the first update |
| `routerDnsName(c)` → string | the name, ready to dial (throws until assigned) |
| `cloudStatus(c)` → `CloudStatus` | full state incl. the seen public address |
| `disableCloudDns(c)` | stop updating |

## Examples

The dynamic-IP VPN server recipe:

```jennifer
mt.enableCloudDns($c);
def name as string init mt.routerDnsName($c);
io.printf("road warriors dial: %s:13231\n", $name);
mt.setupWireguardServer($c, "wgvpn", 13231, "10.100.0.1/24");
# the laptop's WireGuard config uses <name> as the endpoint
```

Detecting a WAN address change (host-side check):

```jennifer
def st as mt.CloudStatus init mt.cloudStatus($c);
io.printf("public address per cloud: %s (updated %s)\n",
    $st.publicAddress, $st.updateTime);
```

## Pitfalls

- `routerDnsName` throws until the first update lands - after
  `enableCloudDns`, give it up to a minute (and the router needs
  working internet + DNS).
- `publicAddress` is what MikroTik's servers *saw* - behind CGNAT it
  is not an address anyone can reach, and no DDNS fixes that
  (ask the ISP for a real address, or dial *out* with
  `connectWireguard` instead).
- The updates talk to MikroTik's cloud - a privacy consideration on
  paranoid networks; the alternative is any third-party DDNS via
  scheduler + fetch scripts.
- The name is per-device (serial-bound): replacing the hardware
  changes the name - a CNAME in your own zone insulates users.

## Related

- [wireguard.md](wireguard.md), [certificates.md](certificates.md)
  (`enableLetsEncrypt` wants exactly this name),
  [dhcp.md](dhcp.md) / [ppp.md](ppp.md) (the dynamic WANs this exists
  for).
