# 04 · Datacenter build: Proxmox VE, Proxmox Backup Server, KVM-over-IP

> 🔧 **In progress.** Details are kept generic; no production addresses or layouts are published.

**Goal:** a small virtualization cluster on Dell PowerEdge hardware with centralized backups and out-of-band console access.

## Hardware & roles

| Server | Role |
| --- | --- |
| Dell PowerEdge R730 | Proxmox VE hypervisor |
| Dell PowerEdge R720xd | Proxmox VE hypervisor |
| Dell PowerEdge C2100 | Proxmox Backup Server (PBS) |
| Raritan Dominion KX II (8-port) | KVM-over-IP: remote console, BIOS and install access for every server |

## Done so far

- [x] Installed Proxmox VE on the R730 and R720xd
- [x] Installed Proxmox Backup Server on the C2100
- [x] Connected all servers to the KVM-over-IP switch for remote BIOS/console access
- [x] Hardware work: disks, RAM, BIOS configuration, racking and power

## Next steps

- [ ] Add PBS as a storage target on both PVE hosts and schedule nightly backups
- [ ] Set retention (e.g. keep daily/weekly/monthly) and enable verify jobs
- [ ] Test a full restore of a VM
- [ ] Document the VLAN design (management vs VM traffic) in generic form

## Why it matters

KVM-over-IP means a server can be reinstalled or recovered from BIOS level without anyone in the room. PBS gives deduplicated, incremental, verifiable backups, which is the piece RAIDZ alone can't provide.
