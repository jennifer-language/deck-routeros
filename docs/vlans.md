# VLANs

File: `src/topics/vlans.j`. Path: `/interface/vlan` (`VLAN_PATH`).

## Background

A VLAN (802.1Q) lets several separate networks share one physical
cable: every frame carries a numeric *tag* (1-4094), and both ends -
your router and the switch or router opposite - must agree on the tag.
In RouterOS a VLAN is a virtual interface on top of a *parent*
(an ethernet port or a bridge): traffic sent through it leaves the
parent tagged, and incoming frames with that tag arrive on it.

The VLAN interface then behaves like any other interface: give it an
address, serve DHCP on it, route or firewall it.

## Struct

```jennifer
mt.Vlan {
    id, name,
    vlanId,          # int, the 802.1Q tag
    interfaceName,   # the parent
    mtu, running, disabled, comment
}
```

## Functions

| Function | Purpose |
|---|---|
| `vlans(c)` → `list of Vlan` | all VLAN interfaces |
| `vlanByName(c, name)` → `Vlan` | one VLAN, error if absent |
| `addVlan(c, name, vlanId, interfaceName)` → id | create a tagged interface |
| `removeVlan(c, name)` | delete |
| `enableVlan(c, name)` / `disableVlan(c, name)` | switch on / off |

`addVlan` validates the tag range (1-4094) and that the parent exists.

## Examples

A separate office network on the cable to a managed switch:

```jennifer
mt.addVlan($c, "vlanoffice", 20, "ether2");
mt.addIpAddress($c, "10.20.0.1/24", "vlanoffice");
mt.setupDhcp($c, "dhcpoffice", "vlanoffice", "10.20.0.0/24",
    "10.20.0.1", "10.20.0.10", "10.20.0.199", "10.20.0.1");
```

The switch port on the other end must be configured for tagged VLAN 20
(a "trunk" or "tagged" port in switch terms).

Router-on-a-stick - several networks over one uplink cable:

```jennifer
mt.addVlan($c, "vlanstaff", 10, "ether2");
mt.addVlan($c, "vlanguest", 30, "ether2");
mt.addIpAddress($c, "10.10.0.1/24", "vlanstaff");
mt.addIpAddress($c, "10.30.0.1/24", "vlanguest");
# firewall between them is YOUR job - see firewall.md
```

Inventory:

```jennifer
def vs as list of mt.Vlan init mt.vlans($c);
for (def v in $vs) {
    io.printf("vlan %s: tag %d on %s\n", $v.name, $v.vlanId, $v.interfaceName);
}
```

## The modern model: VLAN-aware bridge

`/interface/vlan` sub-interfaces (above) are the router-on-a-stick
model. The modern, managed-switch model puts the VLANs *on the bridge*:
one VLAN-aware bridge tags, untags, and filters per port in hardware.
This lives in the bridges topic (`BRIDGE_VLAN_PATH`):

```jennifer
# ports: ether1 is the trunk to a switch (tagged), ether2/3 are access
# ports for VLAN 10 (untagged); build the table and PVIDs FIRST
mt.addBridgeVlan($c, "brlan", 10, "ether1", "ether2,ether3");
mt.setPortPvid($c, "brlan", "ether2", 10);
mt.setPortPvid($c, "brlan", "ether3", 10);
mt.addBridgeVlan($c, "brlan", 20, "ether1", "ether4");
mt.setPortPvid($c, "brlan", "ether4", 20);

# ...enable filtering LAST, once the table is right
mt.enableVlanFiltering($c, "brlan");
```

`tagged` ports keep the VLAN tag (trunks - links to switches, or the
bridge itself for inter-VLAN routing); `untagged` ports strip it
(access ports for end devices), and each access port's **PVID** assigns
untagged incoming frames to its VLAN. `bridgeVlans(c)` lists the table,
`removeBridgeVlan` / `disableVlanFiltering` undo it.

**Which model?** Sub-interfaces are simpler for a handful of VLANs
terminated on the router (each becomes a routed interface). The
VLAN-aware bridge is right when the router is also switching VLANs
between ports, or driving a managed-switch topology - it is what
hardware offload accelerates.

### Danger: order matters

Enabling `vlan-filtering` before the table and PVIDs are correct drops
untagged traffic - **including your own management session** if it rides
that bridge. Always: build the VLAN table and PVIDs first, enable
filtering last, and keep a second way in (a separate management port, or
a console cable) the first time.

## Pitfalls

- **Both ends must agree on the tag.** A VLAN whose opposite end is
  untagged (or tagged differently) is a silent black hole - `running`
  stays true because the parent link is up.
- Tags 0 and 4095 are reserved by the standard; routeros rejects them
  (and everything else outside 1-4094) before the router sees it.
- VLANs separate traffic at layer 2, but the *router* still routes
  between the VLAN interfaces by default - add firewall forward rules
  if the networks must not talk to each other.
- For VLAN-aware bridging (tags filtered inside a bridge), RouterOS
  uses `/interface/bridge/vlan` - drive that with the generic verbs.

## Related

- [bridges.md](bridges.md), [ip.md](ip.md), [dhcp.md](dhcp.md),
  [firewall.md](firewall.md).
