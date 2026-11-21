# 05 · Browser-based remote desktop with Apache Guacamole

> 🔧 **In progress.**

**Goal:** give users desktop access to a set of Linux VMs from any web browser, without installing an RDP or VNC client, through one central gateway.

## Design

```
Browser ──HTTPS──▶ Apache Guacamole (web app + guacd) ──RDP──▶ xrdp on each Linux VM
```

- **Apache Guacamole**: clientless remote-desktop gateway; users only need a browser.
- **xrdp** on each Linux VM provides the RDP endpoint Guacamole connects to.

## Status

- [x] Guacamole gateway running
- [ ] xrdp installed and tested on all 7 Linux VMs
- [ ] Per-user connections and permissions in Guacamole
- [ ] HTTPS in front of Guacamole and MFA (TOTP extension)

Write-up with steps and lessons to follow once complete.
