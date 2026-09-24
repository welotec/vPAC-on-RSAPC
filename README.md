# vPAC on RSAPC 
## this is a repository showcasing fine tuning of the RSAPC MK2 platform for realtime applications.

> [!NOTE]
> This repository is still new and under construction - there might be errors
> ahead. Please reach out if you find any.

This repo was prepared to set up the SSC600 SW by ABB as it was the first
commercially available vPAC solution that we could get our hands on. Some of the
setup is specific to the SSC600 SW and was taken from their engineering manual.

This repo contains ansible scripts which will setup the system as well as the
SSC600 SW virtual machine. It is currently only tested against Debian 13 and
requires a working internet connection. For a simple local setup it is easiest
to run the setup.sh script as root once you've gone through a basic debian
installation. During the debian installation select regions and local settings
as you prefer, the extra non root user is assumed to be 'ansible'. When prompted
for basic packages to install, it is recommended to uncheck options for
'Desktop' and 'GNOME'. Stick with the recommended disk layout or make sure that
there is ~35G free space under /var for the VM image. After the setup.sh runs
through successfully, follow the instructions on screen, to reboot the machine
and run the two extra download and install scripts for the SSC600 SW. To do so it
is required that provide a downloadlink for the SSC600, which you can get from
the ABB website for the SSC600. You have to register with an E-Mail and when
there is a downloadlink, instead of klicking on it to download, right click to
copy the hyperlink. This is the link you will have to provide to the download
script.


## Project overview

- **What it is**: a set of Ansible playbooks, Jinja2 templates, and small
  Bash helper scripts (infrastructure-as-code, no application source) that
  configure a bare Debian 13 install into a real-time-tuned host running a
  virtualized PAC (protection & automation) application under
  libvirt/KVM.
- **What it does, at a high level**:
  1. Installs the required packages, including the Debian `PREEMPT_RT`
     kernel and the KVM/libvirt virtualization stack.
  2. Configures PTP/NTP time synchronization (`timemaster` = chrony +
     linuxptp) to an IEC 61850-9-3 timing profile.
  3. Applies a custom `tuned` profile (`welo-rt`) that isolates a pool of
     CPU cores for the real-time workload: pinned CPU frequencies, Intel
     CAT/CMT cache partitioning via `wrmsr`, disabled hyperthread siblings,
     and IRQ steering away from the isolated cores.
  4. Assigns stable network interface names (onboard NICs, a dedicated PRP
     card, and a management bridge) via `systemd-networkd`, replacing
     NetworkManager.
  5. Downloads, verifies, and installs the ABB SSC600 virtual PAC as a
     libvirt VM with vCPUs pinned 1:1 to the isolated RT cores.
- **Repository layout**: root-level `*.yml` files are Ansible playbooks
  (see `play_all.yml`/`setup.sh` for the overall execution order),
  `templates/` holds the config files and Jinja2 templates they deploy,
  and `hosts/` holds the Ansible inventory.

## Documentation

In-depth documentation lives in [`docs/`](docs/README.md):

- [docs/architecture.md](docs/architecture.md) — high-level system
  architecture and setup flow.
- [docs/playbooks.md](docs/playbooks.md) — reference for every playbook
  and helper script.
- [docs/network-setup.md](docs/network-setup.md) — network/interface
  configuration details.
- [docs/rt-tuning.md](docs/rt-tuning.md) — real-time tuning deep dive
  (CPU isolation, cache partitioning, PTP timing).
- [docs/ssc600-installation.md](docs/ssc600-installation.md) — step-by-step
  SSC600 download/install guide and VM configuration notes.
- [docs/templates.md](docs/templates.md) — reference for every file under
  `templates/`, including third-party origins.

## Thirdparty Copyrights, Trademarks, and Licenses acknowledgements

Parts of these files are taken from ABBs engineering Manuals or were part of
the SSW600 SW distribution
- templates/ssc600-deb.xml

Others were taken from the LF ENERGY SEAPATH project and modified.

- templates/timemaster.conf
- templates/tuned.conf


