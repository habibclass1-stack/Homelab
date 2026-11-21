#!/usr/bin/env bash
# deploy-static-site.sh
# Sets up example.com on a fresh Debian 12 LXC:
#   Nginx static site, security headers, Let's Encrypt HTTPS, automatic security updates.
#
# Usage (as root inside the container, from the folder holding this script + the site files):
#   ./deploy-static-site.sh
#       Default: Cloudflare Tunnel mode. Nginx listens on localhost only; Cloudflare does HTTPS.
#   USE_CERTBOT=yes ADMIN_EMAIL=you@example.com ./deploy-static-site.sh
#       Direct mode: ports 80/443 forwarded to this container, Let's Encrypt certificate here.
#
# Safe to re-run: it updates the site files and config each time.

set -euo pipefail

DOMAIN="${DOMAIN:-example.com}"
ADMIN_EMAIL="${ADMIN_EMAIL:-}"
USE_CERTBOT="${USE_CERTBOT:-no}"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_ROOT="/var/www/${DOMAIN}"

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root."
[[ -f "${SRC_DIR}/index.html" ]] || die "index.html not found next to this script (${SRC_DIR})."
if [[ "$USE_CERTBOT" == "yes" && -z "$ADMIN_EMAIL" ]]; then
  die "Set ADMIN_EMAIL for Let's Encrypt notices, e.g. ADMIN_EMAIL=you@example.com $0"
fi

log "Installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q nginx unattended-upgrades curl
[[ "$USE_CERTBOT" == "yes" ]] && apt-get install -y -q certbot python3-certbot-nginx

log "Enabling automatic security updates"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

log "Copying site files to ${WEB_ROOT}"
mkdir -p "$WEB_ROOT"
# Copy everything except this script itself
find "$SRC_DIR" -maxdepth 1 -type f ! -name "$(basename "$0")" -exec cp -f {} "$WEB_ROOT"/ \;
chown -R www-data:www-data "$WEB_ROOT"
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
find "$WEB_ROOT" -type f -exec chmod 644 {} \;

log "Writing Nginx config"
# Hide the Nginx version in headers and error pages
sed -i 's/^\s*#\?\s*server_tokens.*/\tserver_tokens off;/' /etc/nginx/nginx.conf
grep -q 'server_tokens off' /etc/nginx/nginx.conf || sed -i '/http {/a \\tserver_tokens off;' /etc/nginx/nginx.conf

cat > /etc/nginx/snippets/site-security-headers.conf <<'EOF'
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
# The page uses inline CSS/JS and Google Fonts
add_header Content-Security-Policy "default-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; script-src 'self' 'unsafe-inline'; img-src 'self' data:; form-action 'self' mailto:; frame-ancestors 'none'; base-uri 'self'" always;
EOF

if [[ "$USE_CERTBOT" == "yes" ]]; then
  LISTEN_V4="listen 80;"; LISTEN_V6="listen [::]:80;"; REAL_IP=""
else
  # Tunnel mode: only cloudflared (on this container) can reach Nginx; log real visitor IPs
  LISTEN_V4="listen 127.0.0.1:80;"; LISTEN_V6=""
  REAL_IP="set_real_ip_from 127.0.0.1; real_ip_header CF-Connecting-IP;"
fi

cat > "/etc/nginx/sites-available/${DOMAIN}" <<EOF
# www -> apex redirect
server {
    ${LISTEN_V4}
    ${LISTEN_V6}
    server_name www.${DOMAIN};
    return 301 https://${DOMAIN}\$request_uri;
}

server {
    ${LISTEN_V4}
    ${LISTEN_V6}
    server_name ${DOMAIN};
    ${REAL_IP}

    root ${WEB_ROOT};
    index index.html;

    include snippets/site-security-headers.conf;

    gzip on;
    gzip_types text/css application/javascript image/svg+xml application/json;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Cache images for a week; HTML always fresh so updates show immediately
    location ~* \.(png|jpg|jpeg|svg|ico|webp)\$ {
        expires 7d;
        include snippets/site-security-headers.conf;
        add_header Cache-Control "public";
    }
    location ~* \.html\$ {
        expires -1;
        include snippets/site-security-headers.conf;
    }

    # Block hidden files (.git, .env, etc.)
    location ~ /\. { deny all; }
}
EOF

ln -sf "/etc/nginx/sites-available/${DOMAIN}" "/etc/nginx/sites-enabled/${DOMAIN}"
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx
systemctl reload nginx

if [[ "$USE_CERTBOT" == "yes" ]]; then
  log "Requesting Let's Encrypt certificate (DNS must already point here and port 80 must be open)"
  certbot --nginx --non-interactive --agree-tos -m "$ADMIN_EMAIL" \
    -d "$DOMAIN" -d "www.${DOMAIN}" --redirect
  # HSTS in the shared snippet, so every location block sends it
  grep -q Strict-Transport-Security /etc/nginx/snippets/site-security-headers.conf || \
    echo 'add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;' >> /etc/nginx/snippets/site-security-headers.conf
  nginx -t && systemctl reload nginx
  systemctl list-timers | grep -q certbot && log "Automatic certificate renewal is active (certbot.timer)"
  certbot renew --dry-run
fi

log "Checking the site"
if [[ "$USE_CERTBOT" == "yes" ]]; then
  curl -sSI "https://${DOMAIN}" | head -n 1 || true
else
  curl -sSI -H "Host: ${DOMAIN}" http://127.0.0.1 | head -n 1 || true
  systemctl is-active --quiet cloudflared && log "cloudflared tunnel is running" \
    || log "cloudflared not running yet: finish Step 3 of the runbook"
fi

log "Done. https://${DOMAIN} is live."
