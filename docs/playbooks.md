# Playbook & Script Reference

This document describes every Ansible playbook and helper script in the
repository root: purpose, key tasks, files it touches, and variables it
accepts.

## Orchestration

### `setup.sh`
Bash bootstrap for a **local** install (run as root on a freshly installed
Debian host, non-root user assumed to be `ansible`).

- Installs the `ansible` package.
- Detects the default route interface, its IPv4 address, gateway, and DNS
  servers (`ip route`, `ip -4 addr show`, `resolvectl dns`, falling back to
  `/etc/resolv.conf`).
- Runs, in order, against `-l localhost`:
  `install_packages_deb.yml` → `start_timemaster.yml` →
  `setup_tuned.yml` → `assign_interfaces.yml` (passing
  `mgmt_bridge_address` and `gateway` extra vars derived from the detected
  network config) → `switch_NM_to_systemd-networkd.yml`.
- Prints the two follow-up commands the operator must run manually after a
  reboot: `download_ssc600.yml` (needs `ssc600_downloadlink`) and
  `install_ssc600.yml`.

### `play_all.yml`
Same phase sequence as `setup.sh`, but expressed as Ansible
`import_playbook` entries against `hosts: all` for use with a remote
inventory (`ansible-playbook -i hosts/inventory.ini play_all.yml`). Order:
`install_packages_deb.yml` → `reboot.yml` → `download_ssc600.yml` →
`start_timemaster.yml` → `setup_tuned.yml` → `assign_interfaces.yml` →
`switch_NM_to_systemd-networkd.yml` → `reboot.yml` → `install_ssc600.yml`.

> Note the different ordering vs. `setup.sh` (SSC600 download happens
> earlier, and both reboots are automated instead of manual). Since
> `download_ssc600.yml` requires the `ssc600_downloadlink` extra var,
> running `play_all.yml` unmodified will fail at that step unless the var
> is supplied (e.g. `-e ssc600_downloadlink=...`).

### `ansible.cfg`
Default Ansible configuration: `remote_user=ansible`,
`become_method=su`, private key at `~/generic_seapath/generic_ansible_key`,
inventory at `./hosts/inventory.ini`, `remote_tmp=/tmp`.

### `hosts/inventory.ini`
Ansible inventory file for remote targets (placeholder/minimal by default —
populate with real hosts before using `play_all.yml` remotely).

## Package installation

### `install_packages_deb.yml` (Debian/apt — primary path)
- Installs the RT kernel (`linux-image-rt-amd64`), microcode
  (`intel-microcode`, `amd64-microcode`), virtualization stack
  (`qemu-system-x86`, `libvirt-daemon(-system)`, `virtinst`,
  `docker.io`/`docker-compose`), Cockpit + plugins for web management,
  timing tools (`chrony`, `linuxptp`), tuning tools (`tuned`, `irqbalance`,
  `linux-cpupower`, `rt-tests`, `rtirq-init`, `cpuset`, `intel-cmt-cat`),
  networking tools (`bridge-utils`, `net-tools`, `ethtool`,
  `systemd-resolved`), and various monitoring/diagnostics utilities
  (`htop`, `iotop`, `dstat`, `sysstat`, `tcpdump`, `tshark`, `iperf`/`iperf3`,
  `nmon`, `stress-ng`).
- Removes packages that would conflict with the desired setup:
  `isc-dhcp-client`/`isc-dhcp-common` (DHCP client, replaced by
  systemd-networkd), `nullmailer`, `linuxlogo`, `unattended-upgrades`
  (unwanted automatic reboots/updates on an RT host), `memtest86+`.

### `install_packages.yml` (RHEL/yum — secondary/legacy path)
Equivalent package list for RHEL-family systems (`kernel-rt`,
`kernel-rt-kvm`, `tuned-profiles-realtime`, `corosync`, `pcp-system-tools`,
etc.) using `ansible.builtin.yum`.

### `install_epel.yml` (RHEL — legacy path)
Enables RHEL RT/NFV subscription-manager repos and the CodeReady Builder
repo, then installs the EPEL release RPM from the Fedora project. Needed as
a prerequisite for some RHEL package installs.

## Time synchronization

### `start_timemaster.yml`
Copies `templates/timemaster.conf` to `/etc/timemaster.conf` and starts +
enables the `timemaster` service. `timemaster.conf` wires together
`chronyd`, `ntpd`, `ptp4l`, and `phc2sys` for a PTP domain 0 source on
interface `lan_ptp`, configured to the **IEC 61850-9-3** timing profile
(1s announce/sync/pdelay intervals, `slaveOnly`, `priority1`/`priority2`
255 so any dedicated grandmaster clock wins). See
[rt-tuning.md](rt-tuning.md) for more on the timing configuration.

## Real-time tuning

### `setup_tuned.yml`
Deploys and activates the `welo-rt` custom `tuned` profile. Key tasks:

- Creates `/etc/tuned/profiles/welo-rt/` and deploys `templates/tuned.conf`
  and `templates/irqbalance_modifier.sh` into it.
- Renders `templates/cpu_setup.sh.j2` to `/usr/local/sbin/cpu_setup.sh`
  (mode `0755`) using the vars `rt_cores` (default `[3,4,5,6,7]`) and
  `non_rt_cores` (default `[0,1,2]`), and deploys
  `templates/cpu_setup.service` as a systemd unit.
- Deploys `templates/nic_setup.sh` to `/usr/local/sbin/nic_setup.sh` and
  `templates/nic_setup.service`.
- Enables and starts the `tuned` service, then runs
  `tuned-adm profile welo-rt` to activate it (which in turn enables/starts
  `cpu_setup.service` and `nic_setup.service` per `tuned.conf`'s
  `[systemd]` section).
- Playbook variables: `rt_cores: [3, 4, 5, 6, 7]`, `non_rt_cores: [0, 1, 2]`
  (override with `-e` to match different core counts/layouts).

Full technical detail in [rt-tuning.md](rt-tuning.md).

## Networking

### `assign_interfaces.yml`
- Runs `get_macs.sh` remotely to detect onboard NIC MAC addresses.
- Looks for existing interfaces already named `lan_mgmt` / `lan_ptp` (e.g.
  from a previous run) and records whether they exist.
- Renders `templates/20-lanX.link.j2` once per interface index `0..6` to
  `/etc/systemd/network/20-lan{N+1}.link`, matching by
  `PermanentMACAddress` and assigning names `lan1..lan7`.
- Deploys the management bridge network/netdev files
  (`79-mgmtbridge.network`, `79-mgmtbridge.netdev`,
  `80-mgmtbridge-interface.network`), a DHCP fallback network file
  (`10-dhcp.network` → deployed as `98-dhcp.network`), and the PRP card
  link file (`20-prp-card.link`).
- Variables: `mgmt_bridge_address`, `gateway` (used inside the bridge
  network template — see [network-setup.md](network-setup.md)).

### `switch_NM_to_systemd-networkd.yml`
Disables and stops `NetworkManager`, enables `systemd-networkd`, enables
and starts `systemd-resolved`, then replaces `/etc/resolv.conf` with a
symlink to `/run/systemd/resolve/resolv.conf` so DNS resolution goes
through `systemd-resolved`.

### `get_macs.sh` / `get_macs.yml`
`get_macs.sh` inspects `/sys/class/net/*/address`, finds a contiguous run
of up to 7 MAC addresses (onboard NICs are typically allocated sequential
MACs from the vendor, distinguishing them from add-in PCIe cards), maps
each to its PCI bus address via `/sys/class/net/$iface/device`, and prints
the MACs sorted by PCI address — giving a stable enumeration order for the
`lan1..lan7` assignment in `assign_interfaces.yml`. `get_macs.yml` is a
standalone debug playbook that just runs the script and prints the
resulting array.

## Miscellaneous

### `set_hostname.yml`
Standalone playbook that sets the host's hostname to `vPAC-host`. **Not**
included in `setup.sh` or `play_all.yml` — run manually if desired.

### `reboot.yml`
Trivial wrapper around `ansible.builtin.reboot`, used between phases that
require a kernel or network stack change to take effect.

### `irqbalance` (file, not a playbook)
Example `/etc/default/irqbalance`-style environment file with
`IRQBALANCE_BANNED_CPULIST=1-7` — keeps IRQ rebalancing off the RT-ish
cores. (Note: the actual IRQ steering used in the working setup is done via
`templates/irqbalance_modifier.sh`, referenced by `tuned.conf`'s
`[script]` section; this root-level file appears to be an earlier/example
config — check before assuming it's deployed anywhere.)

## SSC600 (ABB virtual PAC)

See [ssc600-installation.md](ssc600-installation.md) for the full
`download_ssc600.yml` / `install_ssc600.yml` walkthrough.
