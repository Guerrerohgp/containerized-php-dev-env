#!/usr/bin/env bash
# Retry only recognized web-port binding failures; the engine is the authority.
set -uo pipefail
export APP_PORT="${APP_PORT:-80}" SSL_PORT="${SSL_PORT:-443}"
original_http=$APP_PORT
original_https=$SSL_PORT
log=$(mktemp)
trap 'rm -f "$log"' EXIT
while :; do
    ${DOCKER_COMPOSE:?} up -d "$@" 2>&1 | tee "$log"
    status=${PIPESTATUS[0]}
    [ "$status" -ne 0 ] || break
    key=
    for candidate in APP_PORT SSL_PORT; do
        port=${!candidate}
        if grep -Ei 'bind|listen|expose privileged port|port is already allocated|ports are not available|access permissions' "$log" |
            sed 's/->.*//' | grep -Eq "(^|[^0-9])${port}([^0-9]|$)"; then
            key=$candidate
            break
        fi
    done
    if [ -z "$key" ]; then exit "$status"; fi
    if [ ! -t 0 ]; then
        echo "Cannot publish $key=${!key}. Set another port in .env and retry, or run ./dev up interactively." >&2
        exit "$status"
    fi
    suggested=8080
    [ "$key" != SSL_PORT ] || suggested=8443
    echo "Cannot publish $key=${!key}: the port is occupied or permission was denied."
    while :; do
        read -r -p "Replacement for $key [$suggested], or q to cancel: " answer || exit "$status"
        [ "$answer" != q ] || exit "$status"
        answer=${answer:-$suggested}
        if [[ "$answer" =~ ^[0-9]{1,5}$ ]] && (( 10#$answer >= 1 && 10#$answer <= 65535 )); then
            answer=$((10#$answer))
            other=$APP_PORT
            [ "$key" != APP_PORT ] || other=$SSL_PORT
            if [ "$answer" != "${!key}" ] && [ "$answer" != "$other" ]; then break; fi
        fi
        echo 'Choose a different port between 1 and 65535, distinct from the other web port.'
    done
    export "$key=$answer"
done
if [ "$APP_PORT" != "$original_http" ] || [ "$SSL_PORT" != "$original_https" ]; then
    # Preserve unrelated settings; save only ports the user actually changed.
    temp=$(mktemp .env.ports.XXXXXX) || exit 1
    awk -v http="$APP_PORT" -v https="$SSL_PORT" -v change_http="$([ "$APP_PORT" != "$original_http" ] && echo yes)" -v change_https="$([ "$SSL_PORT" != "$original_https" ] && echo yes)" '
        change_http=="yes" && /^APP_PORT=/ {print "APP_PORT=" http; h=1; next}
        change_https=="yes" && /^SSL_PORT=/ {print "SSL_PORT=" https; s=1; next}
        {print}
        END {if(change_http=="yes" && !h) print "APP_PORT=" http; if(change_https=="yes" && !s) print "SSL_PORT=" https}
    ' .env > "$temp" && cat "$temp" > .env || { rm -f "$temp"; exit 1; }
    rm -f "$temp"
    echo 'Saved accepted web ports to .env.'
fi
http_suffix=:$APP_PORT
https_suffix=:$SSL_PORT
[ "$APP_PORT" != 80 ] || http_suffix=
[ "$SSL_PORT" != 443 ] || https_suffix=
echo "Application: http://${PROJECT_DOMAIN:-localhost}$http_suffix (run ./dev hosts to register the domain)"
echo "HTTPS: https://${PROJECT_DOMAIN:-localhost}$https_suffix (requires a trusted certificate)"
