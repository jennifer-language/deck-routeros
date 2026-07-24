# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: 2026 mplx <jennifer@mplx.dev>

# routeros - router users: accounts, groups, sessions.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the router user list. */
export def const USER_PATH as string init "/user";

/** RouterOS API path of the user group list (permission bundles). */
export def const USER_GROUP_PATH as string init "/user/group";

/** RouterOS API path of the active login sessions (read-only). */
export def const USER_ACTIVE_PATH as string init "/user/active";

/** The built-in group with every permission. */
export def const GROUP_FULL as string init "full";

/** The built-in group that may look but not touch. */
export def const GROUP_READ as string init "read";

/** The built-in group that may configure but not manage users/packages. */
export def const GROUP_WRITE as string init "write";

/**
 * One router user account.
 *
 * The password is write-only: set on creation or via `setUserPassword`,
 * never read back.
 *
 * @field {string} id           internal RouterOS id
 * @field {string} name         login name
 * @field {string} group        permission group ("full", "read", "write", or custom)
 * @field {string} address      networks the user may log in from, "" for anywhere
 * @field {string} lastLoggedIn last login time as reported, "" for never
 * @field {bool}   disabled     true when the account is switched off
 * @field {string} comment      free-text comment, "" when unset
 */
export def struct User {
    id as string,
    name as string,
    group as string,
    address as string,
    lastLoggedIn as string,
    disabled as bool,
    comment as string
};

/**
 * One user group: a named bundle of permissions (policies).
 *
 * @field {string} id     internal RouterOS id
 * @field {string} name   group name
 * @field {string} policy comma-separated policies ("read,write,api,...")
 */
export def struct UserGroup {
    id as string,
    name as string,
    policy as string
};

/**
 * One active login session on the router.
 *
 * @field {string} name    the logged-in user
 * @field {string} address where the login came from, "" for console
 * @field {string} via     how ("api", "ssh", "winbox", "console", ...)
 * @field {string} when    when the session started, as reported
 */
export def struct UserSession {
    name as string,
    address as string,
    via as string,
    when as string
};

/**
 * List every user account on the router.
 *
 * @param {Client} c an open client
 * @return {list of User} all accounts
 */
export func users(c as Client) {
    def rows as list of map of string to string init getAll($c, USER_PATH);
    def out as list of User init [];
    for (def row in $rows) {
        $out[] = userFromRow($row);
    }
    return $out;
}

/**
 * List the user groups (permission bundles) on the router.
 *
 * @param {Client} c an open client
 * @return {list of UserGroup} built-in and custom groups
 */
export func userGroups(c as Client) {
    def rows as list of map of string to string init getAll($c, USER_GROUP_PATH);
    def out as list of UserGroup init [];
    for (def row in $rows) {
        $out[] = userGroupFromRow($row);
    }
    return $out;
}

/**
 * Who is logged in right now, from where, and how.
 *
 * @param {Client} c an open client
 * @return {list of UserSession} the active sessions (yours included)
 */
export func activeUsers(c as Client) {
    def rows as list of map of string to string init getAll($c, USER_ACTIVE_PATH);
    def out as list of UserSession init [];
    for (def row in $rows) {
        $out[] = userSessionFromRow($row);
    }
    return $out;
}

/**
 * Create a router user.
 *
 * The group decides what the account may do - use GROUP_READ for
 * monitoring accounts, GROUP_WRITE for configuration without user /
 * package management, GROUP_FULL only where truly needed. The group
 * must exist (built-in or custom), and a user of that name must not.
 * Pick a long password; consider `restrictUser` on top.
 *
 * @param {Client} c        an open client
 * @param {string} name     login name for the new account
 * @param {string} password its password (write-only from here on)
 * @param {string} group    permission group (e.g. GROUP_READ)
 * @return {string} the RouterOS id of the new user
 * @throws {Error} kind "routeros" on a bad name, empty password,
 *                 unknown group, or a user that already exists
 * @example
 *   mt.addUser($c, "monitoring", "a long random password", mt.GROUP_READ);
 */
export func addUser(c as Client, name as string, password as string, group as string) {
    ensureName($name, "user");
    ensureUserPassword($password);
    requiredId($c, USER_GROUP_PATH, $group, "user group");
    if (idByName($c, USER_PATH, $name) != "") {
        raiseError("the user \"" + $name + "\" already exists - use setUserPassword or setUserGroup to change it");
    }
    return add($c, USER_PATH, {"name": $name, "password": $password, "group": $group});
}

/**
 * Change a user's password.
 *
 * Existing sessions of that user stay alive; new logins need the new
 * password.
 *
 * @param {Client} c        an open client
 * @param {string} name     the account
 * @param {string} password the new password
 * @throws {Error} kind "routeros" on an empty password or unknown user
 */
export func setUserPassword(c as Client, name as string, password as string) {
    ensureUserPassword($password);
    set($c, USER_PATH, requiredId($c, USER_PATH, $name, "user"), {"password": $password});
}

/**
 * Move a user to another permission group.
 *
 * Refuses to change the group of the account this session is logged in
 * as - demoting yourself mid-session is a lockout.
 *
 * @param {Client} c     an open client
 * @param {string} name  the account
 * @param {string} group the new group (must exist)
 * @throws {Error} kind "routeros" on an unknown user or group, or on
 *                 your own account
 */
export func setUserGroup(c as Client, name as string, group as string) {
    ensureNotSelf($c.user, $name, "change the group of");
    requiredId($c, USER_GROUP_PATH, $group, "user group");
    set($c, USER_PATH, requiredId($c, USER_PATH, $name, "user"), {"group": $group});
}

/**
 * Limit where a user may log in from.
 *
 * With an address restriction, logins from anywhere else are refused -
 * a strong second line for admin accounts. Pass "" to lift the
 * restriction. Careful with your own account: the restriction applies
 * to NEW logins, so make sure your management network is in the list.
 *
 * @param {Client} c         an open client
 * @param {string} name      the account
 * @param {string} addresses allowed sources: IPs and/or CIDR networks,
 *                           comma-separated (e.g. "10.0.9.0/24"); "" = anywhere
 * @throws {Error} kind "routeros" on a malformed address or unknown user
 */
export func restrictUser(c as Client, name as string, addresses as string) {
    def allowed as string init "";
    if (strings.trim($addresses) != "") {
        $allowed = normalizedUserAddress($addresses);
    }
    set($c, USER_PATH, requiredId($c, USER_PATH, $name, "user"), {"address": $allowed});
}

/**
 * Delete a user account.
 *
 * Refuses the account this session is logged in as - removing the
 * branch you sit on ends badly.
 *
 * @param {Client} c    an open client
 * @param {string} name the account to delete
 * @throws {Error} kind "routeros" on an unknown user or your own account
 */
export func removeUser(c as Client, name as string) {
    ensureNotSelf($c.user, $name, "remove");
    remove($c, USER_PATH, requiredId($c, USER_PATH, $name, "user"));
}

/**
 * Switch a user account on.
 *
 * @param {Client} c    an open client
 * @param {string} name the account
 * @throws {Error} kind "routeros" when no user has that name
 */
export func enableUser(c as Client, name as string) {
    enable($c, USER_PATH, requiredId($c, USER_PATH, $name, "user"));
}

/**
 * Switch a user account off; logins are refused until enabled again.
 *
 * Refuses the account this session is logged in as.
 *
 * @param {Client} c    an open client
 * @param {string} name the account
 * @throws {Error} kind "routeros" on an unknown user or your own account
 */
export func disableUser(c as Client, name as string) {
    ensureNotSelf($c.user, $name, "disable");
    disable($c, USER_PATH, requiredId($c, USER_PATH, $name, "user"));
}

/**
 * Refuse an operation on the account this session runs as.
 *
 * @param {string} loggedIn the session's own user name
 * @param {string} name     the account the operation targets
 * @param {string} action   verb for the error message
 * @throws {Error} kind "routeros" when both are the same account
 * @internal
 */
func ensureNotSelf(loggedIn as string, name as string, action as string) {
    if ($loggedIn == $name) {
        raiseError("refusing to " + $action + " \"" + $name + "\" - it is the account this session is logged in as");
    }
}

/**
 * Validate a user password: must not be empty.
 *
 * RouterOS itself allows empty passwords; routeros does not.
 *
 * @param {string} password the candidate
 * @throws {Error} kind "routeros" when empty
 * @internal
 */
func ensureUserPassword(password as string) {
    if (strings.trim($password) == "") {
        raiseError("the user password must not be empty");
    }
}

/**
 * Validate and normalize a login-source list: IPs and CIDR networks,
 * comma-separated.
 *
 * @param {string} csv the candidate list (non-empty)
 * @return {string} the normalized list
 * @throws {Error} kind "routeros" on an empty entry or malformed address
 * @internal
 */
func normalizedUserAddress(csv as string) {
    def parts as list of string init strings.split($csv, ",");
    def out as list of string init [];
    for (def part in $parts) {
        def p as string init strings.trim($part);
        if ($p == "") {
            raiseError("the address list \"" + $csv + "\" must not contain empty entries");
        }
        if (strings.contains($p, "/")) {
            ensureCidr($p);
        } else {
            ensureIpAddress($p);
        }
        $out[] = $p;
    }
    return strings.join($out, ",");
}

/**
 * Fold a reply row into a User.
 *
 * @param {map of string to string} row a "/user/print" row
 * @return {User} the typed account
 * @internal
 */
func userFromRow(row as map of string to string) {
    return User{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        group: rowValue($row, "group"),
        address: rowValue($row, "address"),
        lastLoggedIn: rowValue($row, "last-logged-in"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}

/**
 * Fold a reply row into a UserGroup.
 *
 * @param {map of string to string} row a "/user/group/print" row
 * @return {UserGroup} the typed group
 * @internal
 */
func userGroupFromRow(row as map of string to string) {
    return UserGroup{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        policy: rowValue($row, "policy")
    };
}

/**
 * Fold a reply row into a UserSession.
 *
 * @param {map of string to string} row a "/user/active/print" row
 * @return {UserSession} the typed session
 * @internal
 */
func userSessionFromRow(row as map of string to string) {
    return UserSession{
        name: rowValue($row, "name"),
        address: rowValue($row, "address"),
        via: rowValue($row, "via"),
        when: rowValue($row, "when")
    };
}
