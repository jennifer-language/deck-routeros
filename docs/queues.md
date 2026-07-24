# Simple queues: bandwidth limiting

File: `src/topics/queues.j`. Path: `/queue/simple` (`QUEUE_SIMPLE_PATH`).

## Background

A simple queue caps how fast a *target* - one device, a whole network,
or an interface - may send and receive. Two directions, and the naming
trips everyone up once:

- **upload** = traffic *from* the target (towards the internet),
- **download** = traffic *to* the target.

Rates use RouterOS notation: `"10M"` (10 megabits/s), `"512k"`,
`"1G"`, plain bits/s (`"2500000"`), and `"0"` for unlimited. routeros
validates and normalizes these locally (`" 10m "` becomes `"10M"`)
before the router ever sees them.

## Struct

```jennifer
mt.SimpleQueue {
    id, name,
    target,                      # who is limited
    maxUpload, maxDownload,      # the "max-limit" pair, already split
    dynamic,                     # created by something else (e.g. PPPoE)
    disabled, comment
}
```

## Functions

| Function | Purpose |
|---|---|
| `limitBandwidth(c, name, target, upload, download)` → id | create a cap |
| `setBandwidthLimit(c, name, upload, download)` | change an existing cap |
| `simpleQueues(c)` → `list of SimpleQueue` | read everything back |
| `removeSimpleQueue(c, name)` | delete (limit gone) |
| `enableSimpleQueue(c, name)` / `disableSimpleQueue(c, name)` | pause / resume |

Targets may be an address (`"192.168.88.50"`), a network
(`"192.168.88.0/24"`), an interface name, or a comma-separated mix;
interface names are verified against the router.

## Examples

Keep the guest network from eating the uplink:

```jennifer
mt.limitBandwidth($c, "guest-wifi", "192.168.90.0/24", "5M", "20M");
```

One chatty device:

```jennifer
mt.limitBandwidth($c, "backup-nas", "192.168.88.50", "50M", "0");
# uploads capped at 50M, downloads unlimited
```

Office hours vs. night - change the cap on a schedule (see
[scheduler.md](scheduler.md) for the RouterOS-script flavor, or run
this from your own host):

```jennifer
mt.setBandwidthLimit($c, "guest-wifi", "2M", "10M");    # tighten
mt.setBandwidthLimit($c, "guest-wifi", "10M", "50M");   # loosen
```

Report:

```jennifer
def qs as list of mt.SimpleQueue init mt.simpleQueues($c);
for (def q in $qs) {
    io.printf("%s on %s: %s up / %s down disabled=%t\n",
        $q.name, $q.target, $q.maxUpload, $q.maxDownload, $q.disabled);
}
```

## Queue trees: hierarchical QoS

Path: `/queue/tree` (`QUEUE_TREE_PATH`). Where simple queues cap *who*
(addresses), a queue tree shares a line by *kind* of traffic - voice
first, backups last, everyone with a guaranteed floor. It runs on
mangle packet marks ([mangle.md](mangle.md)), and the shape is always
the same: one **root** owning the line's budget, **children** per
traffic class.

```jennifer
# 1. classify (mangle topic): marks "voip" and "bulk"
def m as mt.FirewallRule init mt.firewallRule(mt.CHAIN_PREROUTING, mt.ACTION_ACCEPT);
$m = mt.withProtocol($m, "udp");
$m = mt.withDstPort($m, "5060-5200");
mt.setupPacketMark($c, "voip", $m);

# 2. the tree on the upload side (a 40M uplink, budget set below it)
mt.addQueueTreeRoot($c, "qosup", "pppoewan", "38M");
mt.addQueueTreeChild($c, "qosupvoip", "qosup", "voip", "5M", "38M", 1);
mt.addQueueTreeChild($c, "qosupbulk", "qosup", "bulk", "10M", "38M", 8);
```

When the line is idle, everyone may burst to the ceiling (`maxLimit`);
when it is full, each class keeps its guaranteed `limitAt` and
priority breaks the ties (1 = served first). `treeQueues(c)` lists the
hierarchy, `removeTreeQueue(c, name)` removes a node *and its whole
subtree* (children first), `enableTreeQueue` / `disableTreeQueue`
pause a branch.

Guard rails built in: the root's parent must be an interface (or
`global`), a child's parent must exist in the tree, priorities are
checked to 1-8, and a packet mark **no mangle rule creates is
refused** - a tree matching phantom marks shapes nothing and looks
like it works.

## Pitfalls

- **Queue order matters** - the first matching queue wins. A broad
  network queue placed before a per-device queue swallows the device's
  traffic; RouterOS evaluates top-to-bottom and routeros appends.
- Simple queues only see traffic that *passes through* the router.
  LAN-to-LAN traffic over the same bridge is switched in hardware and
  never queued.
- Fasttrack bypasses queues: on a default RouterOS firewall the
  fasttrack rule must be disabled (or exempted) for queues to see the
  connections (see [firewall.md](firewall.md);
  `fasttrack-connection` is a known action).
- Rates are bits per second, not bytes. `"10M"` is 10 Mbit ≈ 1.25
  MByte/s.
- A cap slightly *below* the real line rate is what makes latency
  shaping work - queueing at 100% of the line moves the bottleneck
  back outside the router.
- A tree on an interface shapes that interface's *egress* only: shape
  upload on the WAN interface, download on the LAN-facing one (two
  small trees), or use `global`.
- The `limitAt` sums of the children should not exceed the root's
  budget - guarantees that cannot all be honored are not guarantees.

## Related

- [firewall.md](firewall.md) (fasttrack), [wireless.md](wireless.md)
  (guest networks worth capping), [scheduler.md](scheduler.md).
