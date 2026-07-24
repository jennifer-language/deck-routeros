# Files & backups

File: `src/topics/files.j`. Path: `/file` (`FILE_PATH`), plus the
`/system/backup/save` command.

## Background

The router's storage holds backups, certificates in transit, hotspot
pages, and whatever else lands there. Two jobs matter for operations:

1. **Backups**: `/system backup save` writes a full binary snapshot of
   the configuration - *including password hashes and keys*. An
   unencrypted backup that leaves the router is a credential leak, so
   there is an encrypted variant.
2. **Small text files**: v7 can create and read small files through the
   API (`contents` property) - the transport `importCertificatePem`
   rides on, and handy for dropping scripts.

Restoring a backup (`/system backup load`) is deliberately **not
wrapped**: it reboots the router into a possibly different identity
(addresses, users, keys) - too sharp an edge for an abstraction layer;
do it consciously via console/WinBox.

## Struct

```jennifer
mt.RouterFile { name, kind, size, creationTime }   # size is an int (bytes)
```

## Functions

| Function | Purpose |
|---|---|
| `files(c)` → `list of RouterFile` | what is on the storage |
| `saveBackup(c, name)` | unencrypted backup, verified to appear |
| `saveBackupWith(c, name, password)` | encrypted backup |
| `readFileText(c, name)` → string | small text files only |
| `writeFileText(c, name, contents)` | create/overwrite a small text file (v7) |
| `removeFile(c, name)` | delete |

## Examples

The nightly-backup pair - on-router schedule plus host-side pickup
check:

```jennifer
# on the router: a daily encrypted backup (scheduler topic)
mt.scheduleDaily($c, "nightly-backup", "03:00:00",
    "/system backup save name=nightly password=backupsecret");

# host-side audit: is it fresh, is it plausible?
def fs as list of mt.RouterFile init mt.files($c);
for (def f in $fs) {
    if ($f.name == "nightly.backup") {
        io.printf("backup: %d bytes, created %s\n", $f.size, $f.creationTime);
    }
}
```

One-off backup before risky changes:

```jennifer
mt.saveBackupWith($c, "before-fw-rework", "a strong password");
```

Storage housekeeping:

```jennifer
def fs as list of mt.RouterFile init mt.files($c);
for (def f in $fs) {
    io.printf("%s (%s) %d bytes\n", $f.name, $f.kind, $f.size);
}
mt.removeFile($c, "old-experiment.backup");
```

## Pitfalls

- **A `.backup` file is the whole router**, secrets included. Encrypt
  anything that leaves the device, and remember the password - an
  encrypted backup without it is noise.
- The API exposes `contents` only for small files (a few KB);
  `readFileText` returns `""` for bigger ones. Bulk download is FTP/
  SFTP territory, outside the binary API.
- Backups are version-and-model bound: restore on the same model and a
  close RouterOS version. For portable config, the console `/export`
  (rsc script) is the tool - it is console-only, not reachable through
  this API.
- Flash wears: don't schedule high-frequency writes to storage.

## Related

- [scheduler.md](scheduler.md) (the nightly save),
  [certificates.md](certificates.md) (PEM transport),
  [system.md](system.md) (backup before `installUpdates` is a habit).
