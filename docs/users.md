# Router users

File: `src/topics/users.j`. Paths: `/user` (`USER_PATH`),
`/user/group` (`USER_GROUP_PATH`), `/user/active` (`USER_ACTIVE_PATH`).

## Background

Router accounts decide who may log in (WinBox, SSH, API - including
routeros itself) and what they may do. Permissions come from the
account's **group**: the built-ins are `full` (everything), `write`
(configure, but no user/package management), and `read` (look, don't
touch); custom groups combine individual policies. Two habits keep a
router healthy: give every human and every tool its *own* account with
the *smallest* group that works, and restrict where admin accounts may
log in from.

routeros encodes one more safety property: because the `Client`
remembers which account it is logged in as, the destructive operations
(**remove**, **disable**, **change group**) refuse to target *your own
account* - the classic mid-session lockout.

## Structs

```jennifer
mt.User        { id, name, group, address, lastLoggedIn, disabled, comment }
mt.UserGroup   { id, name, policy }
mt.UserSession { name, address, via, when }
```

Passwords are write-only: set on creation or change, never read back
into a struct.

## Functions

| Function | Purpose |
|---|---|
| `users(c)` → `list of User` | all accounts |
| `userGroups(c)` → `list of UserGroup` | permission bundles (built-in + custom) |
| `activeUsers(c)` → `list of UserSession` | who is logged in right now |
| `addUser(c, name, password, group)` → id | create an account (group must exist, name must not) |
| `setUserPassword(c, name, password)` | change a password |
| `setUserGroup(c, name, group)` | move to another group (refuses your own account) |
| `restrictUser(c, name, addresses)` | limit login sources to IPs/CIDRs; `""` lifts it |
| `removeUser(c, name)` | delete (refuses your own account) |
| `enableUser(c, name)` / `disableUser(c, name)` | switch on / off (disable refuses your own) |

Group name constants: `GROUP_FULL`, `GROUP_READ`, `GROUP_WRITE`.

## Examples

A read-only account for monitoring, locked to the management network:

```jennifer
mt.addUser($c, "monitoring", "a long random password", mt.GROUP_READ);
mt.restrictUser($c, "monitoring", "10.0.9.0/24");
```

An admin colleague, and cleaning up after they leave:

```jennifer
mt.addUser($c, "kim", "another long password", mt.GROUP_FULL);
mt.restrictUser($c, "kim", "10.0.9.0/24,192.168.88.10");
# ... later ...
mt.disableUser($c, "kim");     # keeps the account and its history
mt.removeUser($c, "kim");      # or gone for good
```

Audit - accounts, their reach, and live sessions:

```jennifer
def accounts as list of mt.User init mt.users($c);
for (def u in $accounts) {
    io.printf("%s (%s) from %s, last login %s\n",
        $u.name, $u.group, $u.address, $u.lastLoggedIn);
}

def sessions as list of mt.UserSession init mt.activeUsers($c);
for (def s in $sessions) {
    io.printf("active: %s via %s from %s since %s\n",
        $s.name, $s.via, $s.address, $s.when);
}
```

The self-protection in action:

```jennifer
# logged in as "admin":
try {
    mt.removeUser($c, "admin");
} catch (e) {
    io.printf("%s\n", $e.message);
    # -> refusing to remove "admin" - it is the account this session is logged in as
}
```

## Pitfalls

- **The self-guard is per-session, not global.** It stops *this
  session* from sawing off its own branch; a second admin account can
  still remove the first. It also cannot know about the last `full`
  user - do not demote or disable your only admin from another account.
- `restrictUser` applies to **new logins**. Restricting your own
  account does not drop your current session, but the *next* login must
  come from the listed networks - make sure yours is in there.
- `setUserPassword` leaves existing sessions of that user alive; kick
  them by disabling the account (or via `/user/active` with the generic
  verbs on a RouterOS that supports removing sessions).
- routeros requires a non-empty password even though RouterOS itself
  allows empty ones. Length policy beyond that is yours - the `password`
  module that ships with Jennifer generates strong ones.
- The API user routeros logs in with needs the `api` policy; a `read`
  group account is enough for all the listing functions.

## Related

- [core.md](core.md) (the `Client` carries the logged-in user),
  [system.md](system.md) (reboot needs the `reboot` policy),
  [scheduler.md](scheduler.md) (tasks run with their creator's
  policies).
