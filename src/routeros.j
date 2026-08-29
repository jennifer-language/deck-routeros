# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * routeros - a thick, friendly layer over the MikroTik RouterOS API.
 *
 * The `mikrotik` module speaks the raw RouterOS binary API: you send
 * command paths and `=key=value` attribute words and get reply rows back.
 * routeros wraps that wire-level surface in plain verbs (add / remove /
 * set / update / get) and in typed helpers for the everyday objects -
 * interfaces, ethernet ports (speed, duplex, MTU, PoE, link state),
 * bonding (link aggregation), bridges, bridge ports, VLANs, firewall
 * filter, mangle (packet marking), and NAT
 * rules (masquerade, port forwarding), IP addressing (addresses, the
 * ARP table, DHCP server and WAN client, PPPoE dial-in, DNS, hotspot
 * guest portal), static
 * routes, simple
 * queues (bandwidth limits), wireless (SSID, password, guest networks),
 * WireGuard VPN tunnels, EoIP and GRE tunnels (layer-2 and routed
 * links between sites), IPsec site-to-site tunnels, VRRP gateway
 * redundancy,
 * diagnostics (ping, bandwidth test), netwatch host monitoring,
 * scheduled scripts, router user
 * accounts, management services (hardening the ways in), certificates
 * (self-signed, Let's Encrypt, PEM import), clock and NTP, files and
 * backups, cloud DDNS, SNMP, the router
 * log (reading and routing it), and system
 * maintenance (package updates, routerboard firmware, reboot) - so a
 * user without RouterOS knowledge can configure a router safely.
 * Inputs are validated before they touch the wire, replies are folded
 * into value-semantic structs, and every failure throws an
 * `Error{kind: "routeros"}` with a message written for humans.
 *
 * The implementation is split into topic files, spliced together here
 * with `include` - the module boundary (and every `export`) is this
 * file. The co-located white-box tests live in `routeros_test.j`.
 *
 * @module routeros
 * @see https://jennifer-lang.dev/modules/mikrotik.html
 * @example
 *   import "./routeros.j" as mt;
 *
 *   def c as mt.Client init mt.connect("192.168.88.1", "admin", "secret");
 *   mt.addBridge($c, "brlan");
 *   mt.addBridgePort($c, "brlan", "ether2");
 *   mt.allowService($c, "tcp", 22, "ssh management");
 *   mt.disconnect($c);
 */

use strings;
use lists;
use maps;
use convert;
use io;
use os;

import "mikrotik.j";
import "ipnet.j";

include "topics/core.j";
include "topics/interfaces.j";
include "topics/interfacelist.j";
include "topics/ethernet.j";
include "topics/lte.j";
include "topics/bonding.j";
include "topics/bridges.j";
include "topics/switch.j";
include "topics/vlans.j";
include "topics/firewall.j";
include "topics/nat.j";
include "topics/raw.j";
include "topics/addresslist.j";
include "topics/mangle.j";
include "topics/contrack.j";
include "topics/ip.j";
include "topics/ipv6.j";
include "topics/arp.j";
include "topics/neighbor.j";
include "topics/dhcp.j";
include "topics/ppp.j";
include "topics/l2tp.j";
include "topics/sstp.j";
include "topics/ovpn.j";
include "topics/hotspot.j";
include "topics/dns.j";
include "topics/routing.j";
include "topics/upnp.j";
include "topics/trafficflow.j";
include "topics/queues.j";
include "topics/wireless.j";
include "topics/wifi.j";
include "topics/capsman.j";
include "topics/wireguard.j";
include "topics/eoip.j";
include "topics/gre.j";
include "topics/ipsec.j";
include "topics/vrrp.j";
include "topics/tools.j";
include "topics/sms.j";
include "topics/netwatch.j";
include "topics/scheduler.j";
include "topics/script.j";
include "topics/users.j";
include "topics/services.j";
include "topics/certificates.j";
include "topics/clock.j";
include "topics/files.j";
include "topics/disk.j";
include "topics/cloud.j";
include "topics/snmp.j";
include "topics/radius.j";
include "topics/health.j";
include "topics/container.j";
include "topics/log.j";
include "topics/system.j";
