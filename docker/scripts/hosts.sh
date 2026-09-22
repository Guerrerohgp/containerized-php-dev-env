#!/usr/bin/env bash
set -euo pipefail

domain="${1:-${PROJECT_DOMAIN:-myapp.test}}"
port="${2:-${APP_PORT:-80}}"
hosts_file="${3:-/etc/hosts}"
if [ "$#" -gt 3 ] || [ "${#domain}" -gt 253 ] ||
   ! [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]] ||
   ! awk -v name="$domain" 'BEGIN { n=split(name,a,"."); for(i=1;i<=n;i++) if(length(a[i])<1 || length(a[i])>63 || a[i] ~ /^-/ || a[i] ~ /-$/) exit 1 }'; then
    echo 'Invalid domain: use a hostname such as myapp.test, without a URL or port.' >&2
    exit 1
fi
if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "${#port}" -gt 5 ] || (( 10#$port < 1 || 10#$port > 65535 )); then
    echo 'APP_PORT must be between 1 and 65535.' >&2
    exit 1
fi
domain=$(printf '%s' "$domain" | tr '[:upper:]' '[:lower:]')
[ -f "$hosts_file" ] || { echo "Hosts file not found: $hosts_file" >&2; exit 1; }
state=$(awk -v domain="$domain" '
    { sub(/#.*/, ""); for(i=2;i<=NF;i++) if(tolower($i)==domain) { found=1; if($1!="127.0.0.1") conflict=1 } }
    END { if(conflict) print "conflict"; else if(found) print "exists"; else print "missing" }
' "$hosts_file")
if [ "$state" = conflict ]; then
    echo "$domain already points to another address in $hosts_file. Resolve that entry first." >&2
    exit 1
fi
if [ "$state" = missing ]; then
    if [ ! -w "$hosts_file" ]; then
        # Elevate only the hosts helper, not the container engine or entire launcher.
        exec sudo bash "$0" "$domain" "$port" "$hosts_file"
    fi
    backup=$(mktemp "${hosts_file}.dev-backup.XXXXXX")
    cp -p "$hosts_file" "$backup"
    printf '\n127.0.0.1\t%s # Added by dev hosts\n' "$domain" >> "$hosts_file"
    echo "Added $domain. Backup: $backup"
else
    echo "$domain already points to 127.0.0.1."
fi
suffix=:$port
[ "$port" != 80 ] || suffix=
printf 'Open http://%s%s after starting the containers.\n' "$domain" "$suffix"
