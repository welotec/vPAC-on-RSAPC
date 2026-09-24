# Real-Time Tuning Deep Dive

The core value of this repository is turning a general-purpose x86 server
into a host that can meet the timing guarantees a protection & automation
workload (running inside a VM) needs. This is achieved through several
layered techniques, all deployed by `setup_tuned.yml` and
`start_timemaster.yml`.

## 1. RT kernel

`install_packages_deb.yml` installs `linux-image-rt-amd64` — the Debian
`PREEMPT_RT` real-time kernel — instead of (or alongside) the standard
kernel. This gives the kernel fully preemptible critical sections, which is
a prerequisite for low, bounded scheduling latency.

## 2. CPU core isolation

The host's cores are split into two pools (defaults, overridable via
Ansible vars):

- **`non_rt_cores` (default `[0, 1, 2]`)** — handle the host OS, IRQs,
  housekeeping, and any non-latency-critical work.
- **`rt_cores` (default `[3, 4, 5, 6, 7]`)** — dedicated to the latency
  critical workload (the VM's vCPUs / real-time threads).

This split shows up in multiple places:

- `templates/tuned.conf`'s `[bootloader]` section adds
  `isolcpus=${managed_irq}${isolated_cores}` (`isolated_cores=1-7`) to the
  kernel command line, removing those CPUs from the general scheduler's
  load-balancing target.
- `templates/cpu_setup.sh.j2` (rendered to `/usr/local/sbin/cpu_setup.sh`,
  run by `cpu_setup.service` at boot) pins CPU frequency scaling limits
  per pool:
  - Non-RT cores get `scaling_max_freq` capped at `non_rt_freq` (default
    1.5 GHz) — they can still clock down under light load.
  - RT cores get **both** `scaling_max_freq` and `scaling_min_freq` pinned
    to `rt_freq` (default 2.4 GHz), making their frequency effectively
    static/predictable (no P-state transitions to introduce jitter).
  - RT cores also get `pm_qos_resume_latency_us` set to `"n/a"`, which
    forces them into C0 (`idle.poll`), avoiding C-state exit latency.
- `templates/irqbalance_modifier.sh` (invoked from `tuned.conf`'s
  `[script]` section) and the root-level `irqbalance` example env file
  both work to keep IRQs off the RT cores, complementing `isolcpus`.
- Hyperthread sibling cores (`offline_cores`, default `[8..15]` — the
  siblings of cores `0..7` on a system with HT/SMT) are taken fully
  offline by `cpu_setup.sh.j2`, effectively disabling hyperthreading for
  determinism (SMT can introduce cross-thread scheduling jitter).

> **When changing core counts/topology:** update `rt_cores`/`non_rt_cores`
> (Ansible vars on `setup_tuned.yml`), `isolated_cores`/`non_isolated_cores`
> in `templates/tuned.conf`, and `offline_cores` in
> `templates/cpu_setup.sh.j2` consistently — they are not currently derived
> from a single source of truth.

## 3. Intel CAT/CMT cache & memory-bandwidth partitioning

`templates/cpu_setup.sh.j2` also configures **Intel RDT** (Resource
Director Technology) via direct `wrmsr` (model-specific register) writes,
using the `msr-tools`/`intel-cmt-cat` packages:

- **Cache Allocation Technology (CAT)**: `cos_masks` (default
  `["0xc00", "0x300", "0x0f0", "0x00f"]`) define four cache-way bitmasks,
  written to MSRs starting at `0xc90` — these are the Class-of-Service
  (COS) cache-way allocations.
- **COS assignments** (`cos_assignments`, default: COS 1 → core 1, COS 2 →
  cores 4-5, COS 3 → cores 2,3,6,7,10) are written per-core to MSR `0xc8f`
  via `wrmsr -p <core>`, binding specific cores to specific cache
  partitions so RT workloads don't suffer cache-eviction noise from
  non-RT/background work. Cores not explicitly assigned (0 and 8) remain
  on default COS 0.
- **GPU and WRC (write-cache) masks** (`gpu_mask`/`wrc_mask`, default
  `0xe00`) are written to MSRs starting at `0x18b0`/`0x18d0` respectively,
  restricting integrated-GPU and non-CPU-initiated write traffic to a
  cache region separate from the RT cores' partitions.

These masks are hardware/CPU-model specific (COS MSR layout depends on the
number of supported classes-of-service and cache ways) — verify mask
values against the target CPU's RDT capabilities (`intel-cmt-cat`'s
`pqos -d`) before reusing on different hardware.

## 4. `tuned` profile: `welo-rt`

`templates/tuned.conf` (installed to
`/etc/tuned/profiles/welo-rt/tuned.conf`) is a custom profile built on top
of the stock `realtime-virtual-host` profile (`include=`). Highlights:

- `[sysctl] kernel.printk=3 1 1 7` — reduces console log verbosity (avoids
  console I/O jitter from kernel logging).
- `[sysfs] /sys/module/kvm/parameters/halt_poll_ns = 0` — disables KVM's
  halt-polling, which is a latency/power tradeoff knob; setting to 0 stops
  vCPUs from busy-polling on halt (tune based on measured VM exit latency
  vs. host CPU usage).
- `[bootloader] cmdline_wrt=...` appends kernel parameters: fixed C-state
  (`processor.max_cstate=1 intel_idle.max_cstate=1`), performance governor
  by default, `rcu_nocb_poll`, 1GB hugepages (`hugepagesz=1GB hugepages=16`)
  for the VM's memory backing, IOMMU passthrough
  (`intel_iommu=on iommu=pt`), passive/no-HWP P-state control
  (`intel_pstate=passive intel_pstate.no_hwp=1`) so the explicit frequency
  pinning in `cpu_setup.sh` takes effect predictably, and `isolcpus=...`
  for the RT core range.
- `[systemd]` disables/stops `pmie*`/PCP-related timers not needed here,
  and enables/starts the custom `cpu_setup.service` and `nic_setup.service`
  units as part of activating the profile.
- `[script]` hooks in `irqbalance_modifier.sh` for additional IRQ steering
  logic beyond the static `IRQBALANCE_BANNED_CPULIST`.
- `[scheduler]` pins the RCU callback kthreads (`rcuc/*`) to non-isolated
  core 0 via a `group.rcuc=0:f:10:*:^\[rcuc` scheduler tuning rule, keeping
  RCU housekeeping off the RT cores.

Activated at the end of `setup_tuned.yml` with `tuned-adm profile welo-rt`.

## 5. NIC tuning

`templates/nic_setup.sh`, deployed and run via `nic_setup.service`,
performs NIC-level tuning (e.g. interrupt coalescing / queue affinity —
inspect the script directly for the current parameter set, as it is
hardware/driver dependent).

## 6. PTP / time synchronization

`templates/timemaster.conf` (see [playbooks.md](playbooks.md#time-synchronization))
configures the **IEC 61850-9-3** PTP profile: 1-second announce/sync/pdelay
intervals, `slaveOnly` mode, lowest possible priority (255/255) so any
purpose-built grandmaster clock is preferred, and a generous
`tx_timestamp_timeout` (10ms) to tolerate scheduling jitter on loaded
systems when acquiring hardware TX timestamps. `phc2sys`/`ptp4l` options
(`-s -H -2 -P --step_threshold 0.00001`) select software PHC stepping and a
tight step threshold appropriate for a slave-only deployment.

Accurate host time is a prerequisite for the guest VM's own PTP stack (via
the `lan_ptp` interface, see [network-setup.md](network-setup.md)) to
synchronize correctly.

## Practical guidance for agents modifying RT tuning

- Treat `rt_cores`/`non_rt_cores`/`offline_cores`/MSR masks as a cohesive,
  hardware-dependent unit — a change to one almost always requires
  updating the others.
- Don't casually add packages, services, or cron jobs that might run on RT
  cores; the whole point of the isolation is to keep non-deterministic
  work off them.
- Any change to `cmdline_wrt` in `tuned.conf` requires a **reboot** to take
  effect (kernel command-line change via bootloader).
- Validate wrmsr-based CAT/CMT changes against the actual CPU's RDT
  capability before assuming the mask layout applies (register offsets and
  number of supported COS classes vary by CPU generation).
