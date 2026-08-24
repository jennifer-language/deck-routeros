# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - files and backups: the router's storage.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the file list. */
export def const FILE_PATH as string init "/file";

/**
 * One file on the router's storage.
 *
 * @field {string} name         file name (with extension, e.g. "nightly.backup")
 * @field {string} kind         file type as reported ("backup", ".txt file", "directory", ...)
 * @field {int}    size         size in bytes
 * @field {string} creationTime when it was created, as reported
 */
export def struct RouterFile {
    name as string,
    kind as string,
    size as int,
    creationTime as string
};

/**
 * List the files on the router.
 *
 * @param {Client} c an open client
 * @return {list of RouterFile} all files and directories
 */
export func files(c as Client) {
    def rows as list of map of string to string init getAll($c, FILE_PATH);
    def out as list of RouterFile init [];
    for (def row in $rows) {
        $out[] = fileFromRow($row);
    }
    return $out;
}

/**
 * Save a full configuration backup (unencrypted).
 *
 * The backup lands as `<name>.backup` on the router's storage and is
 * verified to exist before returning. It contains EVERYTHING including
 * password hashes and keys - prefer `saveBackupWith` for anything that
 * leaves the router. Restoring is a console/WinBox operation
 * (`/system backup load`), deliberately not wrapped: it reboots into a
 * different identity.
 *
 * @param {Client} c    an open client
 * @param {string} name backup name without extension (e.g. "nightly")
 * @throws {Error} kind "routeros" on a bad name or when the file did
 *                 not appear
 */
export func saveBackup(c as Client, name as string) {
    ensureName($name, "backup");
    apiRun($c, "/system/backup/save", {"name": $name});
    ensureBackupExists($c, $name);
}

/**
 * Save a configuration backup encrypted with a password.
 *
 * @param {Client} c        an open client
 * @param {string} name     backup name without extension
 * @param {string} password encryption password (needed again to restore)
 * @throws {Error} kind "routeros" on a bad name, an empty password, or
 *                 when the file did not appear
 */
export func saveBackupWith(c as Client, name as string, password as string) {
    ensureName($name, "backup");
    if (strings.trim($password) == "") {
        raiseError("the backup password must not be empty - use saveBackup for an unencrypted backup");
    }
    apiRun($c, "/system/backup/save", {"name": $name, "password": $password});
    ensureBackupExists($c, $name);
}

/**
 * Read a small text file's contents.
 *
 * RouterOS only exposes contents of small files (a few KB) through the
 * API - fine for scripts, notes, and PEMs; not a download mechanism.
 *
 * @param {Client} c    an open client
 * @param {string} name the file name (with extension)
 * @return {string} the contents ("" when the file is too large to expose)
 * @throws {Error} kind "routeros" when no such file exists
 */
export func readFileText(c as Client, name as string) {
    def rows as list of map of string to string init getAll($c, FILE_PATH);
    def row as map of string to string init findRowByField($rows, "name", $name);
    if (len($row) == 0) {
        raiseError("the file \"" + $name + "\" was not found on the router");
    }
    return rowValue($row, "contents");
}

/**
 * Create (or overwrite) a small text file on the router.
 *
 * What `importCertificatePem` uses under the hood; also handy for
 * dropping scripts or notes. RouterOS v7.
 *
 * @param {Client} c        an open client
 * @param {string} name     the file name (with extension)
 * @param {string} contents the text to write
 * @throws {Error} kind "routeros" on a bad name
 */
export func writeFileText(c as Client, name as string, contents as string) {
    ensureName($name, "file");
    def rows as list of map of string to string init getAll($c, FILE_PATH);
    def existing as map of string to string init findRowByField($rows, "name", $name);
    if (len($existing) > 0) {
        set($c, FILE_PATH, rowValue($existing, ".id"), {"contents": $contents});
    } else {
        add($c, FILE_PATH, {"name": $name, "contents": $contents});
    }
}

/**
 * Delete a file from the router's storage.
 *
 * @param {Client} c    an open client
 * @param {string} name the file name (with extension)
 * @throws {Error} kind "routeros" when no such file exists
 */
export func removeFile(c as Client, name as string) {
    def rows as list of map of string to string init getAll($c, FILE_PATH);
    def row as map of string to string init findRowByField($rows, "name", $name);
    if (len($row) == 0) {
        raiseError("the file \"" + $name + "\" was not found on the router");
    }
    remove($c, FILE_PATH, rowValue($row, ".id"));
}

/**
 * Verify a named backup file exists, or raise.
 *
 * @param {Client} c    an open client
 * @param {string} name the backup name without extension
 * @throws {Error} kind "routeros" when `<name>.backup` is missing
 * @internal
 */
func ensureBackupExists(c as Client, name as string) {
    def rows as list of map of string to string init getAll($c, FILE_PATH);
    def row as map of string to string init findRowByField($rows, "name", $name + ".backup");
    if (len($row) == 0) {
        raiseError("the backup \"" + $name + ".backup\" did not appear - check free storage");
    }
}

/**
 * Fold a reply row into a RouterFile.
 *
 * @param {map of string to string} row a "/file/print" row
 * @return {RouterFile} the typed file
 * @internal
 */
func fileFromRow(row as map of string to string) {
    return RouterFile{
        name: rowValue($row, "name"),
        kind: rowValue($row, "type"),
        size: rowInt($row, "size"),
        creationTime: rowValue($row, "creation-time")
    };
}
