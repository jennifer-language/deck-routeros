# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# routeros - PPPoE client, and the PPP user database shared by the
# L2TP / SSTP / OpenVPN / PPTP remote-access servers.
# Spliced into routeros.j via include - not a standalone module.

/** RouterOS API path of the PPP secrets (the VPN/dial-in user database). */
export def const PPP_SECRET_PATH as string init "/ppp/secret";

/** RouterOS API path of the PPP profiles (address / DNS / limits per user). */
export def const PPP_PROFILE_PATH as string init "/ppp/profile";

/** RouterOS API path of the active PPP sessions across all servers. */
export def const PPP_ACTIVE_PATH as string init "/ppp/active";

def const PPP_SERVICES as list of string init ["any", "l2tp", "sstp", "ovpn", "pptp", "pppoe"];

/**
 * One PPP secret: a login the L2TP/SSTP/OpenVPN/PPTP servers share.
 *
 * @field {string} id            internal RouterOS id
 * @field {string} name          login name
 * @field {string} service       which server(s) may use it ("any", "l2tp",
 *                               "sstp", "ovpn", "pptp")
 * @field {string} profile       the PPP profile applied ("default" unless set)
 * @field {string} localAddress  the router's address on the tunnel, "" = from profile
 * @field {string} remoteAddress the client's assigned address, "" = from pool
 * @field {bool}   disabled      true when the login is switched off
 * @field {string} comment       free-text comment, "" when unset
 */
export def struct PppUser {
    id as string,
    name as string,
    service as string,
    profile as string,
    localAddress as string,
    remoteAddress as string,
    disabled as bool,
    comment as string
};

/**
 * One PPP profile: the address / DNS / limit template applied to a login.
 *
 * @field {string} id           internal RouterOS id
 * @field {string} name         profile name
 * @field {string} localAddress the router's tunnel address (or a pool name)
 * @field {string} remoteAddress the client address source (an address or pool)
 * @field {string} dnsServer    DNS handed to clients, "" when unset
 * @field {bool}   disabled     true when switched off
 */
export def struct PppProfile {
    id as string,
    name as string,
    localAddress as string,
    remoteAddress as string,
    dnsServer as string,
    disabled as bool
};

/**
 * One active PPP session (a connected VPN/dial-in client).
 *
 * @field {string} name    the login used
 * @field {string} service the server type ("l2tp", "sstp", "ovpn", "pppoe", ...)
 * @field {string} address the client's tunnel address
 * @field {string} uptime  session duration so far
 * @field {string} callerId where the client connected from
 */
export def struct PppSession {
    name as string,
    service as string,
    address as string,
    uptime as string,
    callerId as string
};

/**
 * List the PPP logins (the shared VPN/dial-in user database).
 *
 * @param {Client} c an open client
 * @return {list of PppUser} all logins
 */
export func vpnUsers(c as Client) {
    def rows as list of map of string to string init getAll($c, PPP_SECRET_PATH);
    def out as list of PppUser init [];
    for (def row in $rows) {
        $out[] = pppUserFromRow($row);
    }
    return $out;
}

/**
 * Create a remote-access VPN login.
 *
 * One login works for every PPP-based server (L2TP, SSTP, OpenVPN) -
 * `service` "any" lets any of them use it, or pin it to one. The
 * profile decides the client's address and DNS ("default" is fine to
 * start). Enable a server with `enableL2tpServer` / `enableSstpServer`
 * / `enableOvpnServer`; this is who may log in.
 *
 * @param {Client} c        an open client
 * @param {string} name     login name
 * @param {string} password its password
 * @param {string} service  "any", "l2tp", "sstp", "ovpn", "pptp", or "pppoe"
 * @param {string} comment  friendly note ("" for none)
 * @return {string} the RouterOS id of the login
 * @throws {Error} kind "routeros" on a bad name, empty password, bad
 *                 service, or a login that already exists
 * @example
 *   mt.enableL2tpServer($c, "a long ipsec secret");
 *   mt.addVpnUser($c, "alice", "her password", "any", "field laptop");
 */
export func addVpnUser(
    c as Client,
    name as string,
    password as string,
    service as string,
    comment as string) {
    ensureName($name, "VPN user");
    if (strings.trim($password) == "") {
        raiseError("the VPN user password must not be empty");
    }
    ensurePppService($service);
    if (idByName($c, PPP_SECRET_PATH, $name) != "") {
        raiseError("the VPN user \"" + $name + "\" already exists");
    }
    def attrs as map of string to string init {
        "name": $name,
        "password": $password,
        "service": $service
    };
    if ($comment != "") {
        $attrs["comment"] = $comment;
    }
    return add($c, PPP_SECRET_PATH, $attrs);
}

/**
 * Delete a VPN login.
 *
 * @param {Client} c    an open client
 * @param {string} name the login name
 * @throws {Error} kind "routeros" when no such login exists
 */
export func removeVpnUser(c as Client, name as string) {
    remove($c, PPP_SECRET_PATH, requiredId($c, PPP_SECRET_PATH, $name, "VPN user"));
}

/**
 * Switch a VPN login on.
 *
 * @param {Client} c    an open client
 * @param {string} name the login name
 * @throws {Error} kind "routeros" when no such login exists
 */
export func enableVpnUser(c as Client, name as string) {
    enable($c, PPP_SECRET_PATH, requiredId($c, PPP_SECRET_PATH, $name, "VPN user"));
}

/**
 * Switch a VPN login off.
 *
 * @param {Client} c    an open client
 * @param {string} name the login name
 * @throws {Error} kind "routeros" when no such login exists
 */
export func disableVpnUser(c as Client, name as string) {
    disable($c, PPP_SECRET_PATH, requiredId($c, PPP_SECRET_PATH, $name, "VPN user"));
}

/**
 * List the PPP profiles.
 *
 * @param {Client} c an open client
 * @return {list of PppProfile} all profiles
 */
export func pppProfiles(c as Client) {
    def rows as list of map of string to string init getAll($c, PPP_PROFILE_PATH);
    def out as list of PppProfile init [];
    for (def row in $rows) {
        $out[] = pppProfileFromRow($row);
    }
    return $out;
}

/**
 * Who is connected through any PPP server right now.
 *
 * @param {Client} c an open client
 * @return {list of PppSession} the active sessions (all VPN types)
 */
export func pppActive(c as Client) {
    def rows as list of map of string to string init getAll($c, PPP_ACTIVE_PATH);
    def out as list of PppSession init [];
    for (def row in $rows) {
        $out[] = pppSessionFromRow($row);
    }
    return $out;
}

/**
 * Disconnect a connected VPN/dial-in client now.
 *
 * @param {Client} c    an open client
 * @param {string} name the login whose session to end
 * @throws {Error} kind "routeros" when that login has no active session
 */
export func kickPppUser(c as Client, name as string) {
    def rows as list of map of string to string init getAll($c, PPP_ACTIVE_PATH);
    def row as map of string to string init findRowByField($rows, "name", $name);
    if (len($row) == 0) {
        raiseError("\"" + $name + "\" has no active PPP session");
    }
    remove($c, PPP_ACTIVE_PATH, rowValue($row, ".id"));
}

/**
 * Validate a PPP secret service value.
 *
 * @param {string} service the candidate
 * @throws {Error} kind "routeros" on an unknown service
 * @internal
 */
func ensurePppService(service as string) {
    if (not lists.contains(PPP_SERVICES, $service)) {
        raiseError("unknown VPN service \"" + $service + "\" - use one of: " +
            strings.join(PPP_SERVICES, ", "));
    }
}

/**
 * Add a VPN CLIENT (dial OUT to a remote server), shared by the L2TP /
 * SSTP / OpenVPN client helpers. Idempotent by name.
 *
 * @param {Client} c             an open client
 * @param {string} path          the client list path
 * @param {string} kind          the VPN kind, for error messages
 * @param {string} name          name for the client interface
 * @param {string} serverAddress the server's address or DNS name
 * @param {string} user          the login on the server
 * @param {string} password      its password
 * @param {map of string to string} extra additional attributes
 * @return {string} the RouterOS id of the (new or existing) client
 * @throws {Error} kind "routeros" on bad input
 * @internal
 */
func vpnClientAdd(
    c as Client,
    path as string,
    kind as string,
    name as string,
    serverAddress as string,
    user as string,
    password as string,
    extra as map of string to string) {
    ensureName($name, $kind + " client");
    ensureName($user, $kind + " user");
    if (strings.trim($password) == "") {
        raiseError("the " + $kind + " password must not be empty");
    }
    def server as string init strings.trim($serverAddress);
    ensureHost($server);
    def existing as string init idByName($c, $path, $name);
    if ($existing != "") {
        return $existing;
    }
    def attrs as map of string to string init {
        "name": $name,
        "connect-to": $server,
        "user": $user,
        "password": $password
    };
    def keys as list of string init maps.keys($extra);
    for (def k in $keys) {
        $attrs[$k] = $extra[$k];
    }
    return add($c, $path, $attrs);
}

/**
 * Fold a reply row into a PppUser.
 *
 * @param {map of string to string} row a "/ppp/secret/print" row
 * @return {PppUser} the typed login
 * @internal
 */
func pppUserFromRow(row as map of string to string) {
    return PppUser{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        service: rowValue($row, "service"),
        profile: rowValue($row, "profile"),
        localAddress: rowValue($row, "local-address"),
        remoteAddress: rowValue($row, "remote-address"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}

/**
 * Fold a reply row into a PppProfile.
 *
 * @param {map of string to string} row a "/ppp/profile/print" row
 * @return {PppProfile} the typed profile
 * @internal
 */
func pppProfileFromRow(row as map of string to string) {
    return PppProfile{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        localAddress: rowValue($row, "local-address"),
        remoteAddress: rowValue($row, "remote-address"),
        dnsServer: rowValue($row, "dns-server"),
        disabled: rowBool($row, "disabled")
    };
}

/**
 * Fold a reply row into a PppSession.
 *
 * @param {map of string to string} row a "/ppp/active/print" row
 * @return {PppSession} the typed session
 * @internal
 */
func pppSessionFromRow(row as map of string to string) {
    return PppSession{
        name: rowValue($row, "name"),
        service: rowValue($row, "service"),
        address: rowValue($row, "address"),
        uptime: rowValue($row, "uptime"),
        callerId: rowValue($row, "caller-id")
    };
}

/**
 * RouterOS API path of the PPPoE client list (dial-in WAN).
 *
 * The client lives under "/interface/pppoe-client"; RouterOS's "/ppp"
 * menu holds the server-side pieces (secrets, profiles) - drive those
 * with the generic verbs if you run the router as a PPPoE server.
 */
export def const PPPOE_CLIENT_PATH as string init "/interface/pppoe-client";

/** RouterOS API path of the PPPoE server service list. */
export def const PPPOE_SERVER_PATH as string init "/interface/pppoe-server/server";

/**
 * One PPPoE client: a dial-in uplink over user name and password.
 *
 * The password is deliberately not part of this struct - it is written
 * on setup and never read back.
 *
 * @field {string} id              internal RouterOS id
 * @field {string} name            the PPPoE interface name (e.g. "pppoewan")
 * @field {string} interfaceName   physical interface the session dials over
 * @field {string} user            the ISP dial-in user name
 * @field {bool}   usePeerDns      true when the router adopts the ISP's DNS servers
 * @field {bool}   addDefaultRoute true when the session installs the default route
 * @field {bool}   running         true when the session is up (connected)
 * @field {bool}   disabled        true when the client is switched off
 * @field {string} comment         free-text comment, "" when unset
 */
export def struct PppoeClient {
    id as string,
    name as string,
    interfaceName as string,
    user as string,
    usePeerDns as bool,
    addDefaultRoute as bool,
    running as bool,
    disabled as bool,
    comment as string
};

/**
 * List every PPPoE client on the router.
 *
 * @param {Client} c an open client
 * @return {list of PppoeClient} all PPPoE clients with their session state
 */
export func pppoeClients(c as Client) {
    def rows as list of map of string to string init getAll($c, PPPOE_CLIENT_PATH);
    def out as list of PppoeClient init [];
    for (def row in $rows) {
        $out[] = pppoeFromRow($row);
    }
    return $out;
}

/**
 * Configure a PPPoE dial-in uplink: the DSL/fiber way to the internet.
 *
 * Creates a PPPoE client on the physical WAN port with the defaults a
 * dial-in uplink wants - the ISP's default route is installed and its
 * DNS servers adopted (use the generic `set` on PPPOE_CLIENT_PATH to
 * change that). The user name and password come from your ISP.
 * Idempotent by name: if a PPPoE client of that name already exists,
 * its id is returned untouched.
 *
 * Once the session is up, `name` is a routable interface: masquerade it
 * for the LAN (`addMasquerade(c, name, ...)`), exactly as with a DHCP
 * WAN.
 *
 * @param {Client} c             an open client
 * @param {string} name          name for the PPPoE interface (e.g. "pppoewan");
 *                               also the handle for the other calls
 * @param {string} interfaceName physical interface the ISP line is plugged
 *                               into (e.g. "ether1")
 * @param {string} user          dial-in user name from the ISP
 *                               (e.g. "user@provider.example")
 * @param {string} password      dial-in password from the ISP
 * @return {string} the RouterOS id of the (new or existing) PPPoE client
 * @throws {Error} kind "routeros" on a bad name, unknown interface, or
 *                 empty credentials
 * @example
 *   mt.setupPppoe($c, "pppoewan", "ether1", "user@provider.example", "secret");
 *   mt.addMasquerade($c, "pppoewan", "lan to internet");
 */
export func setupPppoe(
    c as Client,
    name as string,
    interfaceName as string,
    user as string,
    password as string) {
    ensureName($name, "PPPoE client");
    ensureName($user, "PPPoE user");
    if (strings.trim($password) == "") {
        raiseError("the PPPoE password must not be empty - it comes from your ISP");
    }
    requiredId($c, INTERFACE_PATH, $interfaceName, "interface");
    def existing as string init idByName($c, PPPOE_CLIENT_PATH, $name);
    if ($existing != "") {
        return $existing;
    }
    return add(
        $c,
        PPPOE_CLIENT_PATH,
        {
            "name": $name,
            "interface": $interfaceName,
            "user": $user,
            "password": $password,
            "add-default-route": "yes",
            "use-peer-dns": "yes",
            "disabled": "no"
        });
}

/**
 * Read the state of a PPPoE uplink: is the session up?
 *
 * @param {Client} c    an open client
 * @param {string} name the PPPoE interface name
 * @return {PppoeClient} the client state; check `running`
 * @throws {Error} kind "routeros" when no PPPoE client has that name
 * @example
 *   def dsl as mt.PppoeClient init mt.pppoeStatus($c, "pppoewan");
 *   if (not $dsl.running) { io.printf("dial-in is down\n"); }
 */
export func pppoeStatus(c as Client, name as string) {
    def row as map of string to string init findByName($c, PPPOE_CLIENT_PATH, $name);
    if (len($row) == 0) {
        raiseError("no PPPoE client named \"" + $name + "\" was found - set one up with setupPppoe");
    }
    return pppoeFromRow($row);
}

/**
 * Change the dial-in credentials of a PPPoE uplink.
 *
 * The session reconnects with the new user name and password.
 *
 * @param {Client} c        an open client
 * @param {string} name     the PPPoE interface name
 * @param {string} user     the new dial-in user name
 * @param {string} password the new dial-in password
 * @throws {Error} kind "routeros" on empty credentials or an unknown client
 */
export func setPppoeCredentials(c as Client, name as string, user as string, password as string) {
    ensureName($user, "PPPoE user");
    if (strings.trim($password) == "") {
        raiseError("the PPPoE password must not be empty - it comes from your ISP");
    }
    set(
        $c,
        PPPOE_CLIENT_PATH,
        requiredId($c, PPPOE_CLIENT_PATH, $name, "PPPoE client"),
        {"user": $user, "password": $password});
}

/**
 * Remove a PPPoE client; the dial-in uplink goes away.
 *
 * @param {Client} c    an open client
 * @param {string} name the PPPoE interface name
 * @throws {Error} kind "routeros" when no PPPoE client has that name
 */
export func removePppoeClient(c as Client, name as string) {
    remove($c, PPPOE_CLIENT_PATH, requiredId($c, PPPOE_CLIENT_PATH, $name, "PPPoE client"));
}

/**
 * Switch a PPPoE client on; it starts dialing immediately.
 *
 * @param {Client} c    an open client
 * @param {string} name the PPPoE interface name
 * @throws {Error} kind "routeros" when no PPPoE client has that name
 */
export func enablePppoeClient(c as Client, name as string) {
    enable($c, PPPOE_CLIENT_PATH, requiredId($c, PPPOE_CLIENT_PATH, $name, "PPPoE client"));
}

/**
 * Switch a PPPoE client off; the session disconnects.
 *
 * @param {Client} c    an open client
 * @param {string} name the PPPoE interface name
 * @throws {Error} kind "routeros" when no PPPoE client has that name
 */
export func disablePppoeClient(c as Client, name as string) {
    disable($c, PPPOE_CLIENT_PATH, requiredId($c, PPPOE_CLIENT_PATH, $name, "PPPoE client"));
}

/**
 * Fold a reply row into a PppoeClient.
 *
 * @param {map of string to string} row an "/interface/pppoe-client/print" row
 * @return {PppoeClient} the typed client state
 * @internal
 */
func pppoeFromRow(row as map of string to string) {
    return PppoeClient{
        id: rowValue($row, ".id"),
        name: rowValue($row, "name"),
        interfaceName: rowValue($row, "interface"),
        user: rowValue($row, "user"),
        usePeerDns: rowBool($row, "use-peer-dns"),
        addDefaultRoute: rowBool($row, "add-default-route"),
        running: rowBool($row, "running"),
        disabled: rowBool($row, "disabled"),
        comment: rowValue($row, "comment")
    };
}

/**
 * One PPPoE server service: the router accepting PPPoE dial-ins on an
 * interface.
 *
 * @field {string} id             internal RouterOS id
 * @field {string} serviceName    the PPPoE service name clients may target
 * @field {string} interfaceName  the interface it serves on (the LAN side)
 * @field {string} defaultProfile the PPP profile applied to sessions
 * @field {bool}   disabled       true when switched off
 */
export def struct PppoeServer {
    id as string,
    serviceName as string,
    interfaceName as string,
    defaultProfile as string,
    disabled as bool
};

/**
 * List the PPPoE server services.
 *
 * @param {Client} c an open client
 * @return {list of PppoeServer} all PPPoE server services
 */
export func pppoeServers(c as Client) {
    def rows as list of map of string to string init getAll($c, PPPOE_SERVER_PATH);
    def out as list of PppoeServer init [];
    for (def row in $rows) {
        $out[] = pppoeServerFromRow($row);
    }
    return $out;
}

/**
 * Run a PPPoE server on an interface (accept dial-in clients).
 *
 * The other side of `setupPppoe`: instead of dialing an ISP, the router
 * IS the concentrator - clients (an office switch, downstream routers)
 * dial it. Authenticates against the shared PPP user database, so add
 * logins with `addVpnUser` (service "pppoe" or "any"). Bind it to the
 * LAN-facing interface. Idempotent by service name on that interface.
 *
 * @param {Client} c             an open client
 * @param {string} serviceName   the PPPoE service name (clients see it)
 * @param {string} interfaceName the interface to serve on
 * @return {string} the RouterOS id of the (new or existing) service
 * @throws {Error} kind "routeros" on a bad name or unknown interface
 * @example
 *   mt.addPppoeServer($c, "office", "ether2");
 *   mt.addVpnUser($c, "branch", "a password", "pppoe", "downstream router");
 */
export func addPppoeServer(c as Client, serviceName as string, interfaceName as string) {
    ensureName($serviceName, "PPPoE service");
    requiredId($c, INTERFACE_PATH, $interfaceName, "interface");
    def rows as list of map of string to string init getAll($c, PPPOE_SERVER_PATH);
    for (def row in $rows) {
        if (rowValue($row, "service-name") == $serviceName and
            rowValue($row, "interface") == $interfaceName) {
            return rowValue($row, ".id");
        }
    }
    return add(
        $c,
        PPPOE_SERVER_PATH,
        {"service-name": $serviceName, "interface": $interfaceName, "one-session-per-host": "yes"});
}

/**
 * Remove a PPPoE server service by its service name.
 *
 * @param {Client} c           an open client
 * @param {string} serviceName the service name
 * @throws {Error} kind "routeros" when no such service exists
 */
export func removePppoeServer(c as Client, serviceName as string) {
    def rows as list of map of string to string init getAll($c, PPPOE_SERVER_PATH);
    def row as map of string to string init findRowByField($rows, "service-name", $serviceName);
    if (len($row) == 0) {
        raiseError("no PPPoE server service named \"" + $serviceName + "\" was found");
    }
    remove($c, PPPOE_SERVER_PATH, rowValue($row, ".id"));
}

/**
 * Fold a reply row into a PppoeServer.
 *
 * @param {map of string to string} row an "/interface/pppoe-server/server/print" row
 * @return {PppoeServer} the typed service
 * @internal
 */
func pppoeServerFromRow(row as map of string to string) {
    return PppoeServer{
        id: rowValue($row, ".id"),
        serviceName: rowValue($row, "service-name"),
        interfaceName: rowValue($row, "interface"),
        defaultProfile: rowValue($row, "default-profile"),
        disabled: rowBool($row, "disabled")
    };
}
