# Templates Reference

All files deployed by the playbooks live under `templates/`, mixing plain
config files (`ansible.builtin.copy`) and Jinja2 templates
(`ansible.builtin.template` / `lookup('template', ...)`). This reference
lists each file, what deploys it, where it ends up, and its purpose.

| File | Deployed by | Destination | Purpose |
|---|---|---|---|
| `10-dhcp.network` | `assign_interfaces.yml` | `/etc/systemd/network/98-dhcp.network` | DHCP fallback config for `lan1`. |
| `20-lanX.link.j2` | `assign_interfaces.yml` (Jinja, looped 0-6) | `/etc/systemd/network/20-lan{1..7}.link` | Stable naming of onboard NICs by MAC address. |
| `20-lanX.link.j2.bak` | *(none — not referenced by any playbook)* | — | Appears to be a stray backup of the above; verify before deleting. |
| `20-prp-card.link` | `assign_interfaces.yml` | `/etc/systemd/network/20-prp-card.link` | Names the PRP card `lanPRP` (alt names `process_bus`, `lan_ptp`). |
| `79-mgmtbridge.netdev` | `assign_interfaces.yml` | `/etc/systemd/network/79-mgmtbridge.netdev` | Defines the `mgmt-bridge` Linux bridge device. |
| `79-mgmtbridge.network` | `assign_interfaces.yml` (Jinja) | `/etc/systemd/network/79-mgmtbridge.network` | Assigns addresses/gateway/DNS to the bridge. |
| `80-mgmtbridge-interface.network` | `assign_interfaces.yml` | `/etc/systemd/network/80-mgmtbridge-interface.network` | Enslaves `lan1` into `mgmt-bridge`. |
| `cpu_setup.service` | `setup_tuned.yml` | `/etc/systemd/system/cpu_setup.service` | Runs `cpu_setup.sh` once at boot, before libvirt guests start. |
| `cpu_setup.sh.j2` | `setup_tuned.yml` (Jinja) | `/usr/local/sbin/cpu_setup.sh` | CPU frequency pinning, CAT/CMT MSR setup, HT sibling offlining. |
| `irqbalance_modifier.sh` | `setup_tuned.yml` | `/etc/tuned/profiles/welo-rt/irqbalance_modifier.sh` | `tuned` profile hook script; bans the `igb` driver's IRQs from irqbalance while the profile is active, restores on deactivation. |
| `nic_setup.service` | `setup_tuned.yml` | `/etc/systemd/system/nic_setup.service` | Runs `nic_setup.sh` (after a 60s delay) once network is online. |
| `nic_setup.sh` | `setup_tuned.yml` | `/usr/local/sbin/nic_setup.sh` | Pins the PRP interface's (`lanPRP`) IRQs and kernel threads to CPU 3. |
| `ssc600-deb.xml` | `install_ssc600.yml` (Jinja lookup) | libvirt domain XML (`virsh define`) | SSC600 guest definition for Debian hosts: 8GiB hugepage RAM, 4 pinned/FIFO-scheduled vCPUs, host-passthrough CPU, 3 NICs, 9p PTP mount, watchdog. |
| `ssc600-rhel.xml` | *(not currently used by any playbook)* | — | RHEL-host equivalent of `ssc600-deb.xml`; part of the legacy/secondary RHEL path. |
| `timemaster.conf` | `start_timemaster.yml` | `/etc/timemaster.conf` | chrony/ptp4l/phc2sys glue for PTP domain 0 on `lan_ptp`, IEC 61850-9-3 profile. |
| `timemaster_new.conf` | *(not currently used by any playbook)* | — | Looks like a work-in-progress replacement for `timemaster.conf`; confirm intent before using. |
| `tuned.conf` | `setup_tuned.yml` | `/etc/tuned/profiles/welo-rt/tuned.conf` | The `welo-rt` tuned profile: kernel cmdline, sysctl/sysfs tweaks, service enablement, IRQ script hook, RCU scheduler pinning. |

## Third-party origins & licensing

Per the root [README.md](../README.md#thirdparty-copyrights-trademarks-and-licenses-acknowledgements),
some template files are derived from other projects and should retain their
attribution/comments when modified:

- **`ssc600-deb.xml`** — derived from ABB's SSC600 engineering manual /
  SSC600 SW distribution. This is ABB IP; treat the structure (device
  layout, tuning flags) as vendor-recommended configuration and avoid
  redistributing outside the scope already covered by the README's
  acknowledgement.
- **`timemaster.conf`** and **`tuned.conf`** — adapted from the
  [LF Energy SEAPATH project](https://github.com/seapath) (see the
  attribution comment at the top of `timemaster.conf`, and SEAPATH's
  `realtime-virtual-host` tuned profile that `tuned.conf` extends via
  `include=`). Keep the attribution comments intact; if pulling further
  updates from SEAPATH, diff against their current version rather than
  editing blind.

When adding **new** third-party-derived files to `templates/`, update the
"Thirdparty Copyrights" section of the root README to keep the
acknowledgement list accurate.

## Jinja2 templates vs. static files

Files with a `.j2` extension (`20-lanX.link.j2`, `cpu_setup.sh.j2`) are
deployed with `ansible.builtin.template` and support Jinja2 variables
(`{{ }}`) and control structures (`{% %}`). `templates/79-mgmtbridge.network`
and `templates/ssc600-deb.xml` are also rendered through Jinja (via
`ansible.builtin.template` and `lookup('template', ...)` respectively)
**despite not having a `.j2` extension** — the `.j2` suffix is a
convention, not a requirement, in this repo. When editing any file deployed
via `template`/`lookup('template', ...)`, check whether it contains Jinja
expressions before assuming it's static.

Every other file in `templates/` is deployed verbatim via
`ansible.builtin.copy` and contains no Ansible variable substitution.
