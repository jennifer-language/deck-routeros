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

## Structs

```jennifer
mt.Container      { id, name, tag, status, running, interfaceName, rootDir,
                    envLists, mountLists }
mt.ContainerEnv   { id, listName, key, value }
mt.ContainerMount { id, listName, src, dst }
```

`Container.name` is the handle **you** gave it — its `comment`. RouterOS's
own `name` property on a container row is read-only and reports the image
tag (`pihole:latest`), so `name` falls back to that only when there is no
comment. `running` reads the router's plain `running` flag, falling back
to the `status` word on builds that send one.

## Functions

| Function | Purpose |
|---|---|
| `containers(c)` → `list of Container` | what is installed |
| `addContainer(c, name, remoteImage, interfaceName, rootDir)` → id | create from a registry image |
| `startContainer(c, name)` | start (pulls the image on first run) |
| `stopContainer(c, name)` | stop |
| `removeContainer(c, name)` | delete (and its extracted filesystem) |
| `containerEnvs(c)` → `list of ContainerEnv` | every env variable, all lists |
| `addContainerEnv(c, listName, key, value)` → id | add a variable to an env list |
| `removeContainerEnvList(c, listName)` → int | delete every variable in a list |
| `containerMounts(c)` → `list of ContainerMount` | every mount, all lists |
| `addContainerMount(c, listName, src, dst)` → id | add a mount to a mount list |
| `removeContainerMountList(c, listName)` → int | delete every mount in a list |
| `setContainerEnvLists(c, name, listNames)` | attach env lists to a container |
| `setContainerMountLists(c, name, listNames)` | attach mount lists to a container |

## Environment and mounts

An image is configured by environment variables and by mounts — a
container's own `/etc` mounted out onto a disk is what makes its state
survive a re-pull. Both are **named lists** on the router
(`/container/envs`, `/container/mounts`): entries carry a `list` name,
and a container references the lists it wants by name.

Order matters. Create the entries, create the container, attach the
lists, *then* start it — most images read their config only at startup,
so attaching afterwards is a stop/start away from taking effect.

```jennifer
mt.addContainerEnv($c, "pihole-env", "TZ", "Europe/Vienna");
mt.addContainerEnv($c, "pihole-env", "FTLCONF_dns_upstreams", "9.9.9.9");
mt.addContainerMount($c, "pihole-etc", "usb1/pihole/etc", "/etc/pihole");

mt.setContainerEnvLists($c, "pihole", ["pihole-env"]);
mt.setContainerMountLists($c, "pihole", ["pihole-etc"]);
```

Re-running a provisioning script? Clear a list first so entries do not
pile up — `removeContainerEnvList(c, "pihole-env")` returns how many it
deleted. Passing an empty list to `setContainerEnvLists` detaches all of
them.

## Example: Pi-hole on the router

```jennifer
# prerequisites (generic verbs, one-time): container package + enable,
# a bridge/veth for container networking, and storage
mt.add($c, "/interface/veth", {"name": "veth1", "address": "172.17.0.2/24",
    "gateway": "172.17.0.1"});
# (bridge the veth, NAT or route 172.17.0.0/24)

mt.addContainerEnv($c, "pihole-env", "TZ", "Europe/Vienna");
mt.addContainerMount($c, "pihole-etc", "usb1/pihole/etc", "/etc/pihole");

mt.addContainer($c, "pihole", "pihole/pihole:latest", "veth1", "usb1/pihole");
mt.setContainerEnvLists($c, "pihole", ["pihole-env"]);
mt.setContainerMountLists($c, "pihole", ["pihole-etc"]);
mt.startContainer($c, "pihole");

def cts as list of mt.Container init mt.containers($c);
for (def ct in $cts) { io.printf("%s (%s): %s\n", $ct.name, $ct.tag, $ct.status); }
```

## Pitfalls

- **Storage.** Containers extract onto the router's disk — a few hundred
  MB each. Small flash fills fast; point `rootDir` at USB/NVMe, and make
  sure that disk is actually formatted ([disk.md](disk.md)) — an unformatted
  one shows up much later as a container failing to extract for "no space".
- **Networking is yours.** The container talks through its veth; giving
  it internet and LAN access is ordinary [bridging](bridges.md) /
  [routing](routing.md) / [NAT](nat.md) work.
- **The list field names are not what you would guess.** On the router,
  entries group under `list` (not `name`), and a container references them
  through `envlists` / `mountlists` — *plural*. The helpers above spell
  it correctly; if you drop to the generic verbs, use those names, or
  RouterOS answers `!trap: unknown parameter`.
- **A container's `name` is not yours to set.** Identify your containers
  by the comment `addContainer` writes — which is exactly what
  `Container.name` and every `*Container(c, name)` call already match on.
- **Security surface.** A container is real software running on your
  router; treat its image and exposure like any other host.
- Enabling container support needs a reboot and a deliberate,
  console-side step — this library will not silently flip that gate.

## Related

- [bridges.md](bridges.md), [nat.md](nat.md), [dns.md](dns.md)
  (a Pi-hole/AdGuard container pairs with pointing DHCP clients at it),
  [disk.md](disk.md), [files.md](files.md) (storage).
