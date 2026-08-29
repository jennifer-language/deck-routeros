# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * White-box unit tests for the routeros module.
 *
 * Runs as the co-located test overlay: `jennifer test src/routeros_test.j`.
 * The tests are split into topic files under `topic/`, spliced together
 * here with `include` - one test file per implementation topic file.
 * Everything network-free is covered: path normalization, validation,
 * reply-row folding, builders, and normalization. Functions that need a
 * live router (connect, add, set, remove, ...) are thin compositions of
 * these tested helpers over `mikrotik.run`/`print` and are exercised
 * against real hardware, not here.
 */

use testing;

include "topics/core_test.j";
include "topics/interfaces_test.j";
include "topics/interfacelist_test.j";
include "topics/ethernet_test.j";
include "topics/lte_test.j";
include "topics/bonding_test.j";
include "topics/bridges_test.j";
include "topics/switch_test.j";
include "topics/vlans_test.j";
include "topics/firewall_test.j";
include "topics/nat_test.j";
include "topics/raw_test.j";
include "topics/addresslist_test.j";
include "topics/mangle_test.j";
include "topics/contrack_test.j";
include "topics/ip_test.j";
include "topics/ipv6_test.j";
include "topics/arp_test.j";
include "topics/neighbor_test.j";
include "topics/dhcp_test.j";
include "topics/ppp_test.j";
include "topics/l2tp_test.j";
include "topics/sstp_test.j";
include "topics/ovpn_test.j";
include "topics/hotspot_test.j";
include "topics/dns_test.j";
include "topics/routing_test.j";
include "topics/upnp_test.j";
include "topics/trafficflow_test.j";
include "topics/queues_test.j";
include "topics/wireless_test.j";
include "topics/wifi_test.j";
include "topics/capsman_test.j";
include "topics/wireguard_test.j";
include "topics/eoip_test.j";
include "topics/gre_test.j";
include "topics/ipsec_test.j";
include "topics/vrrp_test.j";
include "topics/tools_test.j";
include "topics/sms_test.j";
include "topics/netwatch_test.j";
include "topics/scheduler_test.j";
include "topics/script_test.j";
include "topics/users_test.j";
include "topics/services_test.j";
include "topics/certificates_test.j";
include "topics/clock_test.j";
include "topics/files_test.j";
include "topics/disk_test.j";
include "topics/cloud_test.j";
include "topics/snmp_test.j";
include "topics/radius_test.j";
include "topics/health_test.j";
include "topics/container_test.j";
include "topics/log_test.j";
include "topics/system_test.j";
