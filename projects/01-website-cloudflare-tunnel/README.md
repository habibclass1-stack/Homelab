# 01 · Self-hosted website behind a Cloudflare Tunnel (no open ports)

**Goal:** host a business website on my own Proxmox server at home, without opening any inbound ports on the home router or exposing the home IP address.

**Result:** the site is live over HTTPS, served from an unprivileged LXC container. The router has no website port forwards; visitors only ever see Cloudflare's IPs.

## Design

```
Visitor ──HTTPS──▶ Cloudflare edge ◀──outbound tunnel── cloudflared ──▶ Nginx (127.0.0.1:80)
                   (DNS, TLS, DDoS)                       └──────── LXC container on Proxmox ───────┘
```

| Decision | Why |
| --- | --- |
| Cloudflare Tunnel instead of port forwarding | Residential ISP: changing IP, ports 80/443 may be blocked, and no inbound exposure at all |
| Nginx bound to `127.0.0.1` only | Only the local tunnel connector can reach the web server, not even the LAN |
| Unprivileged LXC, 1 vCPU / 512 MB / 8 GB | A static site needs very little; unprivileged limits blast radius |
| Container disk on the ZFS RAIDZ2 pool | Survives two disk failures (see [project 03](../03-proxmox-zfs-raidz2/)) |
| Moved DNS from the registrar to Cloudflare | Required for the tunnel; registrar keeps the domain registration |

## Build steps

1. **Create the container** on the Proxmox host:
   ```bash
   pveam update
   TEMPLATE=$(pveam available --section system | awk '/debian-12-standard/ {print $2}' | sort -V | tail -1)
   pveam download local $TEMPLATE
   pct create 210 local:vztmpl/$TEMPLATE --hostname web \
     --unprivileged 1 --features nesting=1 --cores 1 --memory 512 --swap 512 \
     --rootfs Tank:8 --net0 name=eth0,bridge=vmbr0,ip=192.168.10.50/24,gw=192.168.10.1 \
     --onboot 1 --start 1 --password
   ```
2. **Deploy the site** with [`deploy-static-site.sh`](deploy-static-site.sh). It installs Nginx, publishes the files, adds security headers (CSP, X-Frame-Options, nosniff, Referrer-Policy), hides the Nginx version, logs real visitor IPs from `CF-Connecting-IP` and enables unattended security upgrades.
3. **Move DNS to Cloudflare:** add the domain (Free plan), review imported records, then switch the registrar's nameservers.
4. **Create the tunnel:** Zero Trust → Networks → Tunnels → cloudflared; install the connector in the container as a systemd service.
5. **Publish routes:** `example.com` and `www.example.com` → `http://localhost:80`.

## What broke and how I fixed it

| Problem | Root cause | Fix |
| --- | --- | --- |
| `Could not resolve host` inside the container | Consumer router's DNS forwarder answered unreliably | `pct set 210 --nameserver "1.1.1.1 8.8.8.8"` + container reboot (editing `/etc/resolv.conf` alone gets overwritten by Proxmox) |
| Packet loss pinging the router, none to the internet | Router rate-limits ICMP to itself / slow ARP learning for a new MAC | Verified with a second target (`1.1.1.1`) before chasing a false IP conflict |
| Imported DNS records were all proxied (orange cloud) | Cloudflare's import proxies A records by default | Set mail-related records to **DNS only**; proxying breaks SMTP/IMAP |
| Tunnel token was exposed in a chat log during setup | Human error | **Rotated the token** in Cloudflare and reinstalled the connector with the new one |
| `systemctl start cloudflared` timed out after rotation | Service installed with a stale token | `cloudflared service uninstall`, then reinstalled with the current token |

## Lessons

- A tunnel removes a whole class of exposure: no NAT rules, no dynamic DNS, no open 443 on a home IP.
- Treat tunnel tokens like passwords: rotate the moment one leaks.
- When a ping test looks bad, test a second target before concluding anything.
