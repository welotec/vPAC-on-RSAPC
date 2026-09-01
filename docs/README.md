# Documentation Index

This directory contains in-depth documentation for the vPAC-on-RSAPC
repository. Start here, then dive into the topic you need.

| Document | Description |
|---|---|
| [architecture.md](architecture.md) | High-level overview of the system: what gets built, how the pieces fit together, and the overall setup flow. |
| [playbooks.md](playbooks.md) | Reference for every Ansible playbook and helper script: what it does, what it touches, and the variables it accepts. |
| [network-setup.md](network-setup.md) | Details of the network configuration: NIC naming, systemd-networkd migration, management bridge, PRP card. |
| [rt-tuning.md](rt-tuning.md) | Real-time tuning deep dive: CPU isolation, Intel CAT/CMT cache partitioning, frequency pinning, IRQ affinity, the `tuned` profile. |
| [ssc600-installation.md](ssc600-installation.md) | Step-by-step guide for downloading and installing the ABB SSC600 virtual PAC on top of the tuned host. |
| [templates.md](templates.md) | Reference for the files under `templates/`, including third-party origins and licensing notes. |

## Quick start

For a fresh local installation, see the root [README.md](../README.md) and
run `setup.sh` as root after a base Debian 13 install. The
[architecture.md](architecture.md) document explains what that script does
step by step, and [playbooks.md](playbooks.md) documents each playbook it
invokes in detail.
