<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# Containers

File: `src/topics/container.j`. Path: `/container` (`CONTAINER_PATH`).

## Background

RouterOS 7 can run OCI (Docker) images directly on the router — a Pi-hole,
an AdGuard, a small agent — on ARM/ARM64/x86 models with enough storage.
It is deliberately gated: the `container` package must be installed and
container support explicitly enabled in the device settings (a
`devel`-signed step, done once at the console). This topic manages the
container entries; the enablement, the veth interface, and the storage
are prerequisites you set up first.

## Struct

```jennifer
mt.Container { id, name, tag, status, running, interfaceName, rootDir }
```

## Functions

| Function | Purpose |
|---|---|
| `containers(c)` → `list of Container` | what is installed |
| `addContainer(c, name, remoteImage, interfaceName, rootDir)` → id | create from a registry image |
| `startContainer(c, name)` | start (pulls the image on first run) |
| `stopContainer(c, name)` | stop |
| `removeContainer(c, name)` | delete (and its extracted filesystem) |

## Example: Pi-hole on the router

```jennifer
# prerequisites (generic verbs, one-time): container package + enable,
# a bridge/veth for container networking, and storage
mt.add($c, "/interface/veth", {"name": "veth1", "address": "172.17.0.2/24",
    "gateway": "172.17.0.1"});
# (bridge the veth, NAT or route 172.17.0.0/24, add a mount + envs as needed)

mt.addContainer($c, "pihole", "pihole/pihole:latest", "veth1", "usb1/pihole");
mt.startContainer($c, "pihole");

def cts as list of mt.Container init mt.containers($c);
for (def ct in $cts) { io.printf("%s (%s): %s\n", $ct.name, $ct.tag, $ct.status); }
```

## Pitfalls

- **Storage.** Containers extract onto the router's disk — a few hundred
  MB each. Small flash fills fast; point `rootDir` at USB/NVMe.
- **Networking is yours.** The container talks through its veth; giving
  it internet and LAN access is ordinary [bridging](bridges.md) /
  [routing](routing.md) / [NAT](nat.md) work.
- **Environment and mounts** (`/container/envs`, `/container/mounts`)
  configure the image — set them (generic verbs) *before* the first
  start, since many images read config only at startup.
- **Security surface.** A container is real software running on your
  router; treat its image and exposure like any other host.
- Enabling container support needs a reboot and a deliberate,
  console-side step — this library will not silently flip that gate.

## Related

- [bridges.md](bridges.md), [nat.md](nat.md), [dns.md](dns.md)
  (a Pi-hole/AdGuard container pairs with pointing DHCP clients at it),
  [files.md](files.md) (storage).
