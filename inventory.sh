#!/bin/bash
# inventory.sh - Generate a JSON inventory report for this VPS

HOST=$(hostname)
DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Regex of "boring" system packages to exclude
IGNORE_PKGS='^(lib|linux|ubuntu|base|perl|python[0-9.]*|systemd|grub|tzdata|man|initramfs|openssh|ca-cert)'

# Enabled services
ENABLED_SERVICES=$(systemctl list-unit-files --type=service --state=enabled 2>/dev/null \
  | awk '{print $1}' \
  | grep -v '^UNIT' \
  | jq -R -s -c 'split("\n") | map(select(length > 0))')

# Running services
RUNNING_SERVICES=$(systemctl list-units --type=service --state=running 2>/dev/null \
  | awk '{print $1}' \
  | grep -v '^UNIT' \
  | jq -R -s -c 'split("\n") | map(select(length > 0))')

# User cron jobs
USER_CRON=$(crontab -l 2>/dev/null | jq -R -s -c 'split("\n") | map(select(length > 0))')

# System cron jobs
SYSTEM_CRON=$( (cat /etc/crontab 2>/dev/null; ls -1 /etc/cron.*/* 2>/dev/null) \
  | jq -R -s -c 'split("\n") | map(select(length > 0))')

# Docker containers
DOCKER_CONTAINERS=$(docker ps -a --format '{{.Names}}:{{.Status}}' 2>/dev/null \
  | jq -R -s -c 'split("\n") | map(select(length > 0))')

# Installed packages (filtered)
PACKAGES=$(dpkg-query -W -f='${Package}\n' \
  | grep -Ev "$IGNORE_PKGS" \
  | sort \
  | jq -R -s -c 'split("\n") | map(select(length > 0))')

# --- NEW: Extract Caddy subdomains ---
CADDY_DOMAINS=$(grep -E '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' /etc/caddy/Caddyfile 2>/dev/null \
  | awk '{print $1}' \
  | sort -u \
  | jq -R -s -c 'split("\n") | map(select(length > 0))')

# Combine everything into JSON
jq -n \
  --arg host "$HOST" \
  --arg date "$DATE" \
  --argjson enabled "$ENABLED_SERVICES" \
  --argjson running "$RUNNING_SERVICES" \
  --argjson usercron "$USER_CRON" \
  --argjson syscron "$SYSTEM_CRON" \
  --argjson docker "$DOCKER_CONTAINERS" \
  --argjson pkgs "$PACKAGES" \
  --argjson caddydom "$CADDY_DOMAINS" \
  '{
    host: $host,
    generated: $date,
    enabled_services: $enabled,
    running_services: $running,
    user_cron: $usercron,
    system_cron: $syscron,
    docker_containers: $docker,
    installed_packages: $pkgs,
    caddy_subdomains: $caddydom
  }'
