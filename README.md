# Homelab & Infrastructure Projects

Hands-on infrastructure work: virtualization, storage, networking, self-hosting and email. Each project write-up covers **the goal, the design, the build steps, what broke and how I fixed it**.

> All IP addresses, hostnames and domains here are placeholders (`192.0.2.x`, `example.com`). No real credentials, tokens or network maps are published.

## Projects

| # | Project | Skills | Status |
| --- | --- | --- | --- |
| 01 | [Self-hosted website behind a Cloudflare Tunnel (no open ports)](projects/01-website-cloudflare-tunnel/) | Proxmox LXC, Nginx, Cloudflare DNS & Tunnel, security headers, Bash | ✅ In production |
| 02 | [Self-hosted email: fixing DKIM and escaping the spam folder](projects/02-self-hosted-email-deliverability/) | Mailcow, Docker, SPF/DKIM/DMARC, NAT/port forwarding, SMTP relay | ✅ In production |
| 03 | [Proxmox storage: ZFS RAIDZ2 pool and VM disk migration](projects/03-proxmox-zfs-raidz2/) | Proxmox VE, ZFS, RAIDZ2, Dell PowerEdge | ✅ Done |
| 04 | [Datacenter build: Proxmox VE, Proxmox Backup Server, KVM-over-IP](projects/04-datacenter-proxmox-pbs/) | Dell PowerEdge R730/R720xd/C2100, PBS, Raritan KVM | 🔧 In progress |
| 05 | [Browser-based remote desktop with Apache Guacamole](projects/05-guacamole-remote-access/) | Guacamole, xrdp, RDP, Linux VMs | 🔧 In progress |

## Lab at a glance

```
                     Internet
                        │
          ┌─────────────┴──────────────┐
          │                            │
   Cloudflare (DNS, Tunnel)     Router (NAT, mail ports only)
          │ outbound tunnel            │
┌─────────┴────────────────────────────┴───────────────┐
│ Dell PowerEdge R620 — Proxmox VE                      │
│   ZFS RAIDZ2 pool (7 disks) + separate OS disk         │
│   ├─ LXC: Nginx web server + cloudflared               │
│   └─ Mailcow mail server (Docker)                      │
└───────────────────────────────────────────────────────┘

Datacenter rack (separate environment)
  Proxmox VE: Dell R730, Dell R720xd
  Proxmox Backup Server: Dell C2100
  Raritan Dominion KX II KVM-over-IP for out-of-band console access
```

## Skills demonstrated

- **Virtualization:** Proxmox VE (VMs and unprivileged LXC containers), storage migration, Proxmox Backup Server
- **Storage:** ZFS, RAIDZ2 design, separating OS and data disks
- **Networking:** DNS, NAT/port forwarding, DHCP reservations, troubleshooting with `ping`, `dig`, `nslookup`, `curl`
- **Security:** zero-open-port publishing with Cloudflare Tunnel, HTTP security headers, secret rotation, least exposure
- **Email:** Mailcow, SPF/DKIM/DMARC, reverse DNS and residential IP reputation, SMTP relays
- **Hardware:** Dell PowerEdge servers, disks, BIOS, racking, KVM-over-IP
- **Scripting:** Bash deployment automation

Currently studying for **CompTIA Network+ (N10-009)**.
