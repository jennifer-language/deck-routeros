<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev> -->

# Disks

File: `src/topics/disk.j`. Path: `/disk` (`DISK_PATH`).

## Background

RouterOS v7 manages attached storage — USB sticks, NVMe, SATA — under
`/disk`. It matters more than it used to: container filesystems,
configuration backups, downloaded files, and disk logging all land on a
disk. This topic lists the devices, reports usage, formats, and ejects.
Empty on routers with no storage.

## Struct

```jennifer
mt.Disk { id, name, model, kind, fs, sizeBytes, freeBytes, slot }
```

`sizeBytes`/`freeBytes` are ints (bytes); `fs` is `""` on an
unformatted disk.

## Functions

| Function | Purpose |
|---|---|
| `disks(c)` → `list of Disk` | attached storage (empty if none) |
| `diskByName(c, name)` → `Disk` | one device |
| `formatDisk(c, name, filesystem, label)` | **erase + format (destructive)** |
| `ejectDisk(c, name)` | safe-remove a hot-pluggable disk |

## Examples

Inventory and free space:

```jennifer
def ds as list of mt.Disk init mt.disks($c);
for (def d in $ds) {
    io.printf("%s (%s) %s: %d of %d bytes free\n",
        $d.name, $d.model, $d.fs, $d.freeBytes, $d.sizeBytes);
}
```

Prepare a fresh disk for containers (ext4 is the router-native choice):

```jennifer
mt.formatDisk($c, "usb1", "ext4", "container-storage");
```

Then eject before unplugging:

```jennifer
mt.ejectDisk($c, "usb1");
```

## Pitfalls

- **`formatDisk` erases everything, with no undo and no prompt.** It is
  as destructive as it sounds — verify the device name against
  `disks(c)` first, and never run it on a disk with data you have not
  copied elsewhere. Treat it like `reboot`/`shutdown`: a deliberate,
  double-checked action.
- **Filesystem choice:** `ext4` for a router-only disk (containers,
  logs — POSIX permissions, robust); `exfat`/`fat32` if you also read
  the disk on a PC (but no permissions, and fat32 caps files at 4 GB).
- **Flash wear:** cheap USB sticks die under the constant small writes
  of disk logging or a busy container — use decent media, or NVMe where
  the board supports it.
- **Ejecting a disk in use** (a running container's root-dir, active
  disk logging) can fail or corrupt — stop the user first.

## Related

- [container.md](container.md) (root-dir storage),
  [files.md](files.md) (files and backups on the disk),
  [log.md](log.md) (disk logging).
