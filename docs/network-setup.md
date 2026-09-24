# Network Setup

The host's network layout is designed to give the SSC600 (or another) guest
VM direct, low-latency access to specific physical NICs while still
providing normal DHCP/management connectivity to the host itself. It is
built with **systemd-networkd** (NetworkManager is disabled) via
`assign_interfaces.yml` and `switch_NM_to_systemd-networkd.yml`.

## Interface naming

RSAPC MK2 boards expose multiple onboard NICs plus a dedicated **PRP**
(Parallel Redundancy Protocol, IEC 62439-3) card. Predictable naming is
critical because the libvirt VM definition
(`templates/ssc600-deb.xml`) and the PTP configuration
(`templates/timemaster.conf`) reference interfaces by name.

- **Onboard NICs → `lan1`..`lan7`**: `get_macs.sh` finds a contiguous block
  of onboard MAC addresses (see [playbooks.md](playbooks.md#get_macssh--get_macsyml)),
  and `assign_interfaces.yml` renders `templates/20-lanX.link.j2` once per
  detected MAC (matched by `Driver=igc` + `PermanentMACAddress`), producing
  `/etc/systemd/network/20-lan{1..7}.link` files that assign the name
  `lan{N}`.
- **PRP card → `lanPRP`**: `templates/20-prp-card.link` matches
  `Driver=igb` and a `PermanentMACAddress` OUI prefix `70:f8:e7*`, naming
  the interface `lanPRP` with alternative names `process_bus` and
  `lan_ptp`. This is the interface `timemaster.conf` uses for the PTP
  domain 0 source, and `templates/ssc600-deb.xml` attaches a `direct`
  (macvtap) interface to `process_bus` for the guest's redundant PRP link.
- Both link files clear `NamePolicy=`/`AlternativeNamesPolicy=` so udev
  relies purely on the explicit `Name=`/`AlternativeName=` fields rather
  than kernel/BIOS-provided predictable names.

## Management bridge

`templates/79-mgmtbridge.netdev` creates a Linux bridge device named
`mgmt-bridge` (alternative name `lan_mgmt`). `templates/80-mgmtbridge-interface.network`
enslaves `lan1` into that bridge. `templates/79-mgmtbridge.network`
configures the bridge itself:

- `Address` — the host's own management IP, either passed in via the
  `mgmt_bridge_address` extra var (as `setup.sh` does, using the detected
  IP of the machine's original default interface) or falling back to
  Ansible's `ansible_host` fact.
- A **second, fixed** address `192.168.2.230/24` is always added — this
  matches the SSC600 software's documented default IP (`192.168.2.10/24`),
  so the host can reach the guest's default management IP out of the box
  before any guest-side reconfiguration.
- `Gateway` — from the `gateway` extra var (again, supplied by `setup.sh`
  from the detected default route).
- `DNS` — from `dns_address` extra var, defaulting to `8.8.8.8`.

`templates/ssc600-deb.xml` attaches the guest's primary (management) NIC to
this same `mgmt-bridge`, so the VM's management interface lives on the same
L2 segment as the host's management IP and the SSC600 default IP.

## DHCP fallback

`templates/10-dhcp.network` matches `Name=lan1` and requests
`DHCP=ipv4`. It's deployed as `/etc/systemd/network/98-dhcp.network` — a
higher (later-sorting) filename than the bridge configs
(`79-`/`80-`), so systemd-networkd's file-based precedence lets the bridge
config "claim" `lan1` first and this file acts as a fallback/backup config.
Review interactions carefully if you change file numbering, since
systemd-networkd applies `.network` files in lexical filename order and
the first match for an interface wins.

## PTP-dedicated interface

The `lan_ptp` alternative name on the PRP card link file is what
`templates/timemaster.conf`'s `[ptp_domain 0]` section refers to
(`interfaces lan_ptp`) — keeping the timing traffic on the same physical
interface as the redundant PRP link to the (grandmaster-connected) network.

## Guest VM network interfaces

From `templates/ssc600-deb.xml`, the SSC600 guest gets three interfaces:

1. `type="bridge"`, `source bridge="mgmt-bridge"` — management interface,
   shared L2 with the host's management IP.
2. `type="direct"`, `source dev="process_bus"` (macvtap on top of the PRP
   `lanPRP`/`process_bus` interface) — the guest's process-bus/PRP
   connection, bypassing the host bridge for lower latency
   (`trustGuestRxFilters="yes"` lets the guest manage its own multicast/VLAN
   filtering, common for IEC 61850 GOOSE/SV traffic).
3. `type="direct"`, `source dev="lan5"` — a second direct-attached physical
   interface passed straight through to the guest via macvtap.

## Migration from NetworkManager

`switch_NM_to_systemd-networkd.yml` runs **after** `assign_interfaces.yml`
has already written the `systemd-networkd` config, so that once
NetworkManager is disabled there's already a complete configuration for
`systemd-networkd` to pick up. It also switches DNS resolution to
`systemd-resolved` by replacing `/etc/resolv.conf` with a symlink to
`/run/systemd/resolve/resolv.conf`. A **reboot** (the second `reboot.yml` in
`play_all.yml`, or the manual reboot instructed by `setup.sh`) is required
to cleanly apply the network stack switch.

## Things to check before changing network templates

- The PRP card's MAC OUI prefix (`70:f8:e7*`) and driver (`igb`) are
  hardware-specific — confirm against actual hardware before reusing on a
  different NIC model.
- The onboard NIC driver assumed by `20-lanX.link.j2` is `igc`; adjust if
  the target hardware uses a different onboard NIC family.
- The hardcoded `192.168.2.230/24` address exists purely to reach the
  SSC600 guest's factory-default IP — remove or adjust it if not deploying
  SSC600, or if the guest's IP has already been reconfigured.
