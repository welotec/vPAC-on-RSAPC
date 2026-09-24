# Architecture Overview

## What this project builds

vPAC-on-RSAPC turns a bare-metal **RSAPC MK2** appliance into a
real-time-tuned host — a "vPAC" (virtual Protection & Automation Computer) —
capable of running a virtualized PAC application with the timing precision
that protection & automation workloads require. The concrete use case this
repo was built and tested against is **ABB's SSC600** software, distributed
as a KVM/libvirt virtual machine, but the host-tuning portions (CPU
isolation, cache partitioning, PTP timing, network layout) are intentionally
generic and reusable for other vPAC products.

There is no application code here — the repository is **infrastructure as
code**: Ansible playbooks, Jinja2 templates, and small Bash helper scripts
that configure a Debian 13 host from a stock installation into a running
vPAC platform.

## Layered view

```
┌───────────────────────────────────────────────────────────┐
│  Guest VM (e.g. ABB SSC600)                                │
│  - runs as a libvirt/KVM domain                            │
│  - disk image under /var/lib/libvirt/images/ssc600.img     │
│  - defined from templates/ssc600-deb.xml                   │
├───────────────────────────────────────────────────────────┤
│  Virtualization layer                                      │
│  - libvirt + QEMU/KVM                                      │
│  - Cockpit + cockpit-machines for a web management UI      │
├───────────────────────────────────────────────────────────┤
│  Real-time tuned host OS (Debian 13 + RT kernel)           │
│  - linux-image-rt-amd64                                    │
│  - tuned profile "welo-rt" (CPU isolation, C-state/        │
│    frequency pinning, Intel CAT/CMT cache partitioning)     │
│  - irqbalance restricted to non-RT cores                   │
│  - timemaster (chrony + linuxptp) for PTP/NTP time sync     │
│  - systemd-networkd based network configuration             │
├───────────────────────────────────────────────────────────┤
│  Bare-metal RSAPC MK2 hardware                              │
│  - multiple onboard NICs (incl. PRP card)                   │
│  - Intel CPU with RDT/CAT support                           │
└───────────────────────────────────────────────────────────┘
```

## Setup flow

The end-to-end setup is expressed twice, for two different execution
contexts:

- **`setup.sh`** — a Bash bootstrap script for a *local, single-host*
  install. It installs `ansible` itself, detects the current default route
  interface/IP/gateway/DNS with `ip`/`resolvectl`, and then invokes the
  playbooks below against `localhost` one at a time, pausing for two manual
  reboots and for the operator to supply an SSC600 download link.
- **`play_all.yml`** — the same sequence expressed as a single Ansible
  playbook using `import_playbook`, intended for driving one or more
  **remote** hosts via the `hosts/inventory.ini` inventory and
  `ansible.cfg` (remote user `ansible`, `su` privilege escalation).

Both paths execute the same logical phases, in this order:

1. **Package installation** — install the RT kernel and all required
   tooling (virtualization, timing, monitoring, hardening removals).
2. **Reboot** — activate the newly installed RT kernel.
3. **PTP/NTP time sync** — deploy and start `timemaster` (chrony + ptp4l +
   phc2sys) so the host (and downstream VM) can synchronize to IEC
   61850-9-3 grade time sources.
4. **RT tuning** — deploy the `welo-rt` tuned profile plus two custom
   systemd services (`cpu_setup`, `nic_setup`) that pin CPU frequencies,
   partition CPU cache via Intel CAT/CMT, offline hyperthread siblings, and
   tune NIC behavior; then activate the profile with `tuned-adm`.
5. **Network interface assignment** — detect onboard NIC MAC addresses and
   render stable `systemd-networkd` `.link`/`.network`/`.netdev` files:
   fixed `lan1..lan7` naming, a management bridge, DHCP fallback, and a PRP
   (Parallel Redundancy Protocol) card link file.
6. **Switch to systemd-networkd** — disable NetworkManager, enable
   `systemd-networkd`/`systemd-resolved`, and re-point `/etc/resolv.conf` at
   the resolved stub.
7. **Reboot** — activate the new network stack.
8. **SSC600 download & install** — download and verify the vendor disk
   image (manual step, requires a user-supplied download link), then define
   and start the libvirt VM plus its PTP status-reporting service.

See [playbooks.md](playbooks.md) for a per-playbook breakdown,
[rt-tuning.md](rt-tuning.md) for the real-time tuning internals, and
[network-setup.md](network-setup.md) for the networking details.

## Supported platforms

- **Primary/tested target:** Debian 13, using the `*_deb.yml` playbooks
  (`install_packages_deb.yml`) and `templates/ssc600-deb.xml`.
- **Secondary/legacy path:** RHEL-family hosts, using `install_packages.yml`
  / `install_epel.yml` (yum/dnf-based) and `templates/ssc600-rhel.xml`.
  These are not wired into `setup.sh` or `play_all.yml` and may not be kept
  fully in sync with the Debian path — verify before relying on them.
