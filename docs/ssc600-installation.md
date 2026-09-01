# SSC600 Installation Guide

This document walks through installing ABB's **SSC600** software (the
virtual PAC this repository was originally built around) once the host has
already been prepared by the earlier setup phases (packages, RT tuning,
networking — see [architecture.md](architecture.md)).

## Prerequisites

- The host has completed `install_packages_deb.yml`, `start_timemaster.yml`,
  `setup_tuned.yml`, `assign_interfaces.yml`, and
  `switch_NM_to_systemd-networkd.yml` (in that order), and has been
  rebooted after the network switch.
- `libvirtd`/`qemu` are installed and running (from the package list).
- You have registered on ABB's website for SSC600 and obtained a
  **download link** for the "virtual products" `.cab` archive. Per the
  README: after registering with an email and receiving a download link,
  **right-click the link and copy the hyperlink** rather than clicking it
  — the direct link is what gets passed to Ansible.

## Step 1 — Download and extract (`download_ssc600.yml`)

```
ansible-playbook -l localhost download_ssc600.yml -e "ssc600_downloadlink=<your downloadlink>"
```

This playbook:

1. Downloads the archive from `ssc600_downloadlink` to
   `/root/virtual_products.cab`.
2. Extracts it in place with `cabextract` into `/root/virtual_products/`.
3. Verifies integrity with `sha256sum -c checksums.sha256` (fails the
   playbook if the download is corrupted or incomplete).
4. Decompresses `ssc600_disk.img.gz` (keeping the original `.gz`, `gunzip
   -k`) into `/root/virtual_products/ssc600_disk.img`.

## Step 2 — Install and start the VM (`install_ssc600.yml`)

```
ansible-playbook -l localhost install_ssc600.yml
```

This playbook:

1. Copies `ssc600_disk.img` from the extracted archive to
   `/var/lib/libvirt/images/ssc600.img` (the disk libvirt will actually
   boot from).
2. Copies the vendor-provided `ptp_status.sh` script to `/usr/sbin/` and
   its `ptp_status.service` unit to `/etc/systemd/system/`, then enables
   and starts it — this service reports/monitors PTP synchronization
   status for the guest.
3. Creates `/var/lib/libvirt/images/ptp` — this directory is shared
   **read-only** into the guest as a virtio-9p filesystem mount (see the
   `<filesystem>` device in `templates/ssc600-deb.xml`, mounted at `ptp`
   inside the guest), presumably so the guest can read host-side PTP
   status/state.
4. Defines the libvirt domain from `templates/ssc600-deb.xml` (rendered as
   a Jinja2 template via `lookup('template', ...)`, though the file
   currently contains no `{{ }}` placeholders) with `autostart: true`, then
   starts the `ssc600` VM.

## What the VM definition gives you

See `templates/ssc600-deb.xml` and [network-setup.md](network-setup.md) for
full detail. Summary:

- **8 GiB RAM**, backed by hugepages, locked (no swapping), `nosharepages`.
- **4 static vCPUs**, each pinned 1:1 to a physical RT core (`vcpupin`
  cpuset `7,6,5,4`), with the QEMU emulator thread pinned to core `3`
  (`emulatorpin`) — keeping the emulator/IO thread off the vCPU cores. All
  4 vCPUs use the `fifo` real-time scheduler at priority 50
  (`vcpusched`).
- **`host-passthrough` CPU mode** with cache passthrough — the guest sees
  (and can use) the actual host CPU features and the CAT/CMT-partitioned
  cache configured in [rt-tuning.md](rt-tuning.md).
- **KVM tuning**: `hint-dedicated` (tells the guest kernel it has dedicated
  physical CPUs, enabling more aggressive guest-side spinlock/scheduling
  choices), `poll-control` off (avoid extra host-side polling on top of
  the host's own `halt_poll_ns=0` tuning), `pv-ipi` on
  (paravirtual IPIs, cheaper VM exits for inter-vCPU signaling), `pmu` off
  (avoid vPMU virtualization overhead).
- **Clock**: UTC offset, RTC in catchup mode, PIT delay tick policy, HPET
  disabled — chosen for compatibility with the guest's own timing stack
  layered on top of the host's PTP-disciplined clock.
- **Watchdog** (`i6300esb`, action `reset`) — automatically resets the VM
  if the guest hangs, appropriate for an unattended protection device.
- **No memory balloon** (`memballoon model="none"`) — keeps the guest's
  locked/hugepage-backed memory allocation fixed, consistent with an RT
  workload that shouldn't have memory reclaimed at runtime.
- **Three network interfaces** — management bridge, PRP/process-bus direct
  attach, and a second direct-attached NIC (`lan5`). See
  [network-setup.md](network-setup.md#guest-vm-network-interfaces).
- **Disk**: `virtio`, raw format, `cache=none`/`io=threads` for direct,
  low-overhead disk I/O from `/var/lib/libvirt/images/ssc600.img`.

## Managing the VM afterwards

Because `cockpit` + `cockpit-machines` are installed as part of
`install_packages_deb.yml`, the VM can also be inspected/managed through
Cockpit's web UI (default HTTPS port 9090) in addition to `virsh`.

Common `virsh` operations:

```
virsh list --all           # check VM state
virsh console ssc600       # attach to the guest's virtio console
virsh dominfo ssc600
virsh dumpxml ssc600
```

## Troubleshooting notes

- If `download_ssc600.yml` fails at the checksum step, the download link
  may have expired (ABB's links are often session/time-limited) — obtain a
  fresh link.
- If the VM fails to start, check `journalctl -u libvirtd` and confirm
  hugepages are actually available (`grep Huge /proc/meminfo`) — the
  domain requires locked hugepage-backed memory, which depends on the
  `hugepages=16` (1GB each) kernel parameter from `templates/tuned.conf`
  having taken effect (requires a reboot after `setup_tuned.yml`).
- The guest's factory-default management IP is documented as
  `192.168.2.10/24`; the host's `mgmt-bridge` is configured with
  `192.168.2.230/24` specifically to be reachable on that subnet before any
  guest-side reconfiguration — see [network-setup.md](network-setup.md#management-bridge).
