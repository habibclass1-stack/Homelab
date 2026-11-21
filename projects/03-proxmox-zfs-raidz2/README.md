# 03 · Proxmox storage: ZFS RAIDZ2 pool and VM disk migration

**Goal:** give a Dell PowerEdge R620 running Proxmox VE redundant storage for VMs and containers.

**Result:** 8 disks total. Proxmox stays on its own disk, and a **ZFS RAIDZ2 pool (`Tank`) on the other 7** holds all VM and container disks. The pool survives any **two** simultaneous disk failures.

## Design

| Disk(s) | Role |
| --- | --- |
| 1 | Proxmox VE OS (`local`, `local-lvm`) |
| 7 | ZFS RAIDZ2 pool `Tank`: VM disks and container root filesystems |

Why RAIDZ2 over RAIDZ1: with 7 disks, a rebuild after one failure takes long enough that a second failure during resilver is a real risk. RAIDZ2 covers it.

## Steps

1. Added 5 disks to the existing 3 (8 total).
2. Created the RAIDZ2 pool on 7 disks and added it as Proxmox storage (content: *Disk image*, *Container*).
3. **Migrated existing VMs off the single OS disk:**
   ```bash
   qm disk move <VMID> scsi0 Tank --delete 1        # repeat for every disk incl. efidisk0/tpmstate0
   pct move-volume <CTID> rootfs Tank --delete 1   # containers (stopped)
   ```
4. Verified: `qm config` / `pct config` show only `Tank:` volumes, no leftover "Unused disk" entries, and `zpool status Tank` is `ONLINE`.
5. New workloads are created directly on `Tank` (e.g. `--rootfs Tank:8`).

## Lessons

- Workloads left on the OS disk are a single point of failure, so move everything.
- Keep a ZFS pool **below ~80% full**; performance drops sharply beyond that.
- **RAIDZ2 is redundancy, not backup.** It doesn't protect against deletion, ransomware or a dead server, so off-box backups are still required ([project 04](../04-datacenter-proxmox-pbs/)).
