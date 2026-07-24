# Hotspot: the guest portal

File: `src/topics/hotspot.j`. Paths: `/ip/hotspot` (`HOTSPOT_PATH`),
`.../profile`, `.../user`, `.../active`, `.../ip-binding`,
`.../walled-garden` (`HOTSPOT_PROFILE_PATH`, `HOTSPOT_USER_PATH`,
`HOTSPOT_ACTIVE_PATH`, `HOTSPOT_BINDING_PATH`, `WALLED_GARDEN_PATH`).

## Background

A hotspot turns an interface into a captive portal: guests get an
address, but every web request lands on a login page until they
authenticate. The pieces RouterOS needs (and the console wizard
creates) are a DHCP stack for the guest network, a *server profile*
(portal address, login method), and the *hotspot server* binding it
all to the interface - `setupHotspot` composes exactly that on top of
this module's `setupDhcp`.

The operational vocabulary around it:

- **users / vouchers**: portal logins, optionally with a total-time
  limit (the front-desk day pass);
- **active sessions**: who is on, with usage counters - and `kick`;
- **ip-bindings**: devices that bypass the portal (printers, TVs);
- **walled garden**: destinations reachable *before* login (your
  website, terms pages, a payment provider).

## Structs

```jennifer
mt.HotspotServer  { id, name, interfaceName, addressPool, profile, disabled }
mt.HotspotUser    { id, name, profile, limitUptime, uptime, disabled, comment }
mt.HotspotSession { user, address, mac, uptime, idleTime, bytesIn, bytesOut }
```

## Functions

| Function | Purpose |
|---|---|
| `setupHotspot(c, name, iface, network, gateway, from, to)` → id | the whole portal (idempotent) |
| `teardownHotspot(c, name, network)` | undo it (users/bindings stay) |
| `addHotspotUser(c, name, password, comment)` → id | a login |
| `addHotspotVoucher(c, name, password, uptimeLimit, comment)` → id | a time-limited login |
| `hotspotUsers(c)` / `removeHotspotUser(c, name)` | manage logins |
| `hotspotActive(c)` → sessions | who is on, with counters |
| `kickHotspotUser(c, user)` | end a session now |
| `bypassHotspotMac(c, mac, comment)` → id | device skips the portal |
| `removeHotspotBypass(c, mac)` | back behind the portal |
| `allowBeforeLogin(c, dstHost, comment)` → id | walled-garden entry |
| `removeWalledGardenEntry(c, dstHost)` | remove it |

## Example: a complete guest network

Dedicated bridge, guest WiFi, portal, day-pass voucher:

```jennifer
mt.addBridge($c, "brguest");
mt.addBridgePort($c, "brguest", "wifiguest");     # see wireless.md / wifi.md
mt.addIpAddress($c, "10.5.50.1/24", "brguest");

mt.setupHotspot($c, "guests", "brguest", "10.5.50.0/24",
    "10.5.50.1", "10.5.50.10", "10.5.50.254");

mt.addHotspotVoucher($c, "visitor", "day pass 123", "1d", "front desk");
mt.allowBeforeLogin($c, "*.example.org", "our own site");
mt.bypassHotspotMac($c, "AA:BB:CC:DD:EE:FF", "lobby TV");
```

The front desk hands out `visitor` / `day pass 123`; the voucher dies
after 24 hours of connect time.

## Example: the operations view

```jennifer
def sessions as list of mt.HotspotSession init mt.hotspotActive($c);
for (def s in $sessions) {
    io.printf("%s from %s (%s): up %s, %d MB down\n",
        $s.user, $s.address, $s.mac, $s.uptime, $s.bytesOut // 1048576);
}
mt.kickHotspotUser($c, "visitor");
```

## Pitfalls

- **Never on the management LAN.** The portal intercepts *all* traffic
  on its interface - putting it on `brlan` locks every device (and
  your management session's network) behind a login page. Dedicated
  bridge, always.
- HTTPS pages cannot be redirected to the portal (that is TLS working
  as designed) - modern devices detect the portal via their
  captive-portal probes and pop the login automatically; a guest who
  "only opened an HTTPS site" on an old device sees timeouts, not the
  portal.
- The login page is customizable: HTML lives on the router's storage
  (`html-directory` in the profile; upload via [files.md](files.md) /
  FTP).
- Vouchers limit *connect time*, not calendar time - a `1d` voucher
  used one hour a day lasts 24 days. Calendar expiry needs user
  `limit-uptime` plus a scheduler cleanup, or RADIUS.
- Guests share one network: isolate them from the LAN with forward
  rules ([firewall.md](firewall.md)) and consider a bandwidth cap
  ([queues.md](queues.md)) - the guest recipe in
  [wireless.md](wireless.md) composes all of it.

## Related

- [dhcp.md](dhcp.md) (the stack underneath),
  [wireless.md](wireless.md) / [wifi.md](wifi.md) (the guest SSID),
  [firewall.md](firewall.md), [queues.md](queues.md),
  [files.md](files.md) (custom portal pages).
