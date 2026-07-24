# SNMP

File: `src/topics/snmp.j`. Paths: `/snmp` (`SNMP_PATH`),
`/snmp/community` (`SNMP_COMMUNITY_PATH`).

## Background

SNMP is how classic monitoring (Zabbix, LibreNMS, PRTG, Observium)
reads a router: interface counters, CPU, memory, temperatures. Access
is granted per *community* - a shared string that acts exactly like a
password but, in the common v2c, travels in cleartext. The sane
defaults are therefore built into `enableSnmp`: read-only, restricted
to the monitoring network, and a name of your choosing (not `public`).

## Structs

```jennifer
mt.SnmpSettings  { enabled, contact, location }
mt.SnmpCommunity { id, name, addresses, readAccess, writeAccess, disabled }
```

## Functions

| Function | Purpose |
|---|---|
| `enableSnmp(c, community, addresses)` → id | read-only community + agent on (idempotent) |
| `setSnmpInfo(c, contact, location)` | what monitoring displays |
| `snmpSettings(c)` → `SnmpSettings` | agent state |
| `snmpCommunities(c)` → `list of SnmpCommunity` | who may query |
| `disableSnmp(c)` | agent off |

## Examples

Plug the router into monitoring:

```jennifer
mt.enableSnmp($c, "mon4711", "10.0.9.0/24");
mt.setSnmpInfo($c, "noc@example.org", "rack 3, office Berlin");
```

Audit and close the default community:

```jennifer
def coms as list of mt.SnmpCommunity init mt.snmpCommunities($c);
for (def com in $coms) {
    if ($com.name == "public" and not $com.disabled) {
        io.printf("default community still open - disabling\n");
        mt.disable($c, mt.SNMP_COMMUNITY_PATH, $com.id);
    }
    if ($com.writeAccess) {
        io.printf("WARNING: community %s has write access\n", $com.name);
    }
}
```

## Pitfalls

- **v2c is cleartext**: the community and all data cross the wire
  readable. Restrict sources, treat the community as a password, and
  keep SNMP off the WAN (the `addresses` restriction plus a firewall
  rule for UDP 161 - see [firewall.md](firewall.md)). SNMPv3 with
  authentication exists in RouterOS via the generic verbs.
- The default `public` community ships enabled on some configs - the
  audit above closes it.
- Write access over SNMP is almost never needed; `enableSnmp` always
  sets read-only.
- Interface counters via SNMP are the classic way to graph bandwidth -
  if graphs show zeros, check the monitoring system polls the right
  ifIndex after interface changes.

## Related

- [services.md](services.md) (the same restrict-the-sources
  philosophy), [firewall.md](firewall.md),
  [users.md](users.md) (API-based monitoring with a `read` account is
  the SNMP alternative this module itself enables).
