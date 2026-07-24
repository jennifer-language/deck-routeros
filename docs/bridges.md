# Bridges

File: `src/topics/bridges.j`. Paths: `/interface/bridge` (`BRIDGE_PATH`),
`/interface/bridge/port` (`BRIDGE_PORT_PATH`).

## Background

A bridge is a virtual switch inside the router: every interface you add
to it as a *port* shares one layer-2 network, as if plugged into the
same physical switch. This is how a MikroTik becomes a home router in
the classic sense - LAN ports and WiFi bridged into one network, with
the router's LAN address sitting *on the bridge*, not on any single
port.

Two lists are involved: the bridges themselves, and the bridge *ports*
(the membership records that say "ether2 belongs to brlan").

## Structs

```jennifer
mt.Bridge     { id, name, mac, running, disabled, comment }
mt.BridgePort { id, bridge, interfaceName, disabled }
```

## Functions

| Function | Purpose |
|---|---|
| `bridges(c)` → `list of Bridge` | all bridges |
| `addBridge(c, name)` → id | create a bridge |
| `removeBridge(c, name)` | delete a bridge by name |
| `bridgePorts(c, bridgeName)` → `list of BridgePort` | members of one bridge |
| `addBridgePort(c, bridgeName, interfaceName)` → id | attach an interface |
| `removeBridgePort(c, interfaceName)` | detach an interface from its bridge |

`addBridgePort` verifies the bridge exists first, so a typo in the
bridge name fails with a clear message instead of creating an orphan
port.

## Examples

The classic home-router LAN - three wired ports and the WiFi in one
network:

```jennifer
mt.addBridge($c, "brlan");
mt.addBridgePort($c, "brlan", "ether2");
mt.addBridgePort($c, "brlan", "ether3");
mt.addBridgePort($c, "brlan", "ether4");
mt.addBridgePort($c, "brlan", "wlan1");

# the LAN address lives on the bridge
mt.addIpAddress($c, "192.168.88.1/24", "brlan");
```

Audit which port belongs where:

```jennifer
def ports as list of mt.BridgePort init mt.bridgePorts($c, "brlan");
for (def p in $ports) {
    io.printf("%s is on %s\n", $p.interfaceName, $p.bridge);
}
```

Move a port to another bridge (detach, then attach):

```jennifer
mt.removeBridgePort($c, "ether4");
mt.addBridgePort($c, "brguest", "ether4");
```

## Pitfalls

- **Never bridge the WAN port into the LAN** - that connects your ISP
  to your internal network at layer 2.
- An interface can be a port of only one bridge; `removeBridgePort`
  takes just the interface name for that reason.
- Addresses belong on the **bridge**, not on member ports. An address
  on `ether2` stops working the moment `ether2` joins a bridge.
- Removing a bridge does not fail on existing ports - RouterOS drops
  the memberships; remove the ports first if you want an explicit
  teardown.

## Related

- [vlans.md](vlans.md) - VLANs often ride on a bridge.
- [dhcp.md](dhcp.md) - serve DHCP on the bridge to make the LAN
  plug-and-play.
