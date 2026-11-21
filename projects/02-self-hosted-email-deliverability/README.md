# 02 · Self-hosted email: fixing DKIM and escaping the spam folder

**Goal:** run email for a business domain on a self-hosted **Mailcow** server, with mail that actually reaches recipients' inboxes.

**Result:** sending and receiving work, webmail has a valid certificate, **SPF, DKIM and DMARC all pass**, and Gmail delivers to the **Inbox**.

## Design

```
Incoming:  Internet ──25──▶ router NAT ──▶ Mailcow (Postfix, Dovecot, Rspamd, SOGo)
Webmail:   Internet ──443──▶ router NAT ──▶ Mailcow nginx on :8443
Outgoing:  Mailcow ──587/TLS──▶ SMTP relay (SMTP2GO) ──▶ Gmail / Outlook / …
```

## The troubleshooting path

### 1. Webmail returned `502 Bad Gateway`
- **Investigation:** the mail record was correctly DNS-only and resolved to the right public IP. The router's port list showed **443 forwarded to an old web server**, not the mail server.
- **Second finding:** `mailcow.conf` had `HTTP_PORT=8080` / `HTTPS_PORT=8443`, so even the LAN URL needed `:8443`.
- **Fix:** forwarded **external 443 → internal 8443** and **80 → 8080** (for ACME certificate renewal), plus 465/587/993 for mail clients. Retired the old web server's forwards, since the website now uses a tunnel ([project 01](../01-website-cloudflare-tunnel/)).

### 2. Gmail: `dkim=fail`
- **Evidence** (Gmail → Show original):
  ```
  dkim=fail header.s=dkim … spf=pass … dmarc=pass
  ```
- **Root cause:** the DKIM public key in DNS was stale and didn't match the key Mailcow signs with.
- **Fix:** copied the current key from Mailcow (Domains → DNS) into the `dkim._domainkey` TXT record. Next test: `dkim=pass`.

### 3. Everything passes, still in Spam
- **Root cause:** the server sends from a **residential IP**: no custom reverse DNS (PTR) and often listed on policy blocklists for consumer ranges. Big providers distrust that regardless of authentication.
- **Fix:** configured an **outbound SMTP relay**:
  1. Verified the sending domain with the relay provider (CNAMEs for return-path and DKIM).
  2. Created one SMTP credential for the server.
  3. Mailcow → Routing → *Sender-dependent transport* `relay-host:587`, assigned to the domain.
  4. Added the relay to SPF: `v=spf1 mx ip4:192.0.2.25 include:spf.smtp2go.com ~all`.
- **Result:** next message landed in the **Inbox** with all three checks passing.

### 4. DNS hygiene along the way
- Removed the `a` mechanism from SPF once the apex record pointed to a CDN (otherwise the CDN's IPs would be authorized senders).
- Pointed the DMARC `rua=` to my own mailbox; the registrar's default sent reports to a third party.
- Kept `mail`, `autoconfig`, `autodiscover` **DNS only**; a proxied mail host breaks SMTP/IMAP.
- Recovered a forgotten admin password with Mailcow's `helper-scripts/mailcow-reset-admin.sh`.

## Lessons

- Read the headers: `Authentication-Results` tells you exactly which check failed.
- Authentication (SPF/DKIM/DMARC) is necessary but **not sufficient**; sending-IP reputation decides inbox vs spam.
- A relay is the standard answer for self-hosted mail on residential connections. Inbound mail stays fully self-hosted.
