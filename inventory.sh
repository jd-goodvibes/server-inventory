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
PACKAGES=$(dpkg-query -W -f='${Package}\n' 2>/dev/null \
  | grep -Ev "$IGNORE_PKGS" \
  | sort \
  | jq -R -s -c 'split("\n") | map(select(length > 0))')

# Caddy domains (from Caddyfile)
CADDY_DOMAINS=$(grep -E '^[[:space:]]*[a-zA-Z0-9.-]+\.[a-zA-Z]+' /etc/caddy/Caddyfile 2>/dev/null \
  | sed 's/{.*//; s/,/ /g' \
  | awk '{for(i=1;i<=NF;i++) print $i}' \
  | sed 's/:.*//g' \
  | sort -u \
  | jq -R -s -c 'split("\n") | map(select(length > 0))')


# System stats (CPU, RAM, Disk)
SYSTEM_STATS=$(jq -n \
  --argjson cpu "$(nproc)" \
  --argjson mem_total "$(grep MemTotal /proc/meminfo | awk '{print $2}')" \
  --argjson mem_avail "$(grep MemAvailable /proc/meminfo | awk '{print $2}')" \
  --argjson disk_total "$(df -BG / | tail -1 | awk '{print $2}' | tr -d 'G')" \
  --argjson disk_avail "$(df -BG / | tail -1 | awk '{print $4}' | tr -d 'G')" \
  '{cpu_count: $cpu, mem_total_kb: $mem_total, mem_available_kb: $mem_avail, disk_total_gb: $disk_total, disk_available_gb: $disk_avail}')

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
  --argjson caddy "$CADDY_DOMAINS" \
  --argjson stats "$SYSTEM_STATS" \
  '{
    host: $host,
    generated: $date,
    enabled_services: $enabled,
    running_services: $running,
    user_cron: $usercron,
    system_cron: $syscron,
    docker_containers: $docker,
    installed_packages: $pkgs,
    caddy_domains: $caddy,
    system_stats: $stats
  }'
