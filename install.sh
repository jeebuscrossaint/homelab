#!/bin/sh
# install.sh: turn a fresh Arch or Alpine machine into the homelab.
#   sudo ./install.sh          install everything and start every app
#   sudo ./install.sh --pull   same, but download newer app versions first
# Safe to run again any time. It only does what's missing.
set -eu

HOMELAB_DIR=$(cd "$(dirname "$0")" && pwd)
ENV_FILE="$HOMELAB_DIR/.env"
PULL=no

for arg in "$@"; do
	case $arg in
		--pull) PULL=yes ;;
		-h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "unknown option: $arg (try --help)"; exit 2 ;;
	esac
done

step() { printf '\n:: %s\n' "$*"; }
ok()   { printf ' ✓ %s\n' "$*"; }
die()  { printf ' ✗ %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "run it as root: sudo ./install.sh (or doas ./install.sh)"
. /etc/os-release
case $ID in
	arch|alpine) ;;
	*) die "only Arch and Alpine for now (this is $ID)" ;;
esac
# the person who ran sudo/doas, so they can use docker without sudo
ME=${SUDO_USER:-${DOAS_USER:-}}

step "packages"
if [ "$ID" = arch ]; then
	missing=""
	for p in docker docker-compose tailscale git openssl; do
		pacman -Q "$p" >/dev/null 2>&1 || missing="$missing $p"
	done
	# shellcheck disable=SC2086
	[ -z "$missing" ] || pacman -Syu --needed --noconfirm $missing
else
	# tailscale lives in Alpine's community repo, which is off by default
	sed -i 's|^#\(.*/community\)$|\1|' /etc/apk/repositories
	apk add --quiet docker docker-cli-compose tailscale git openssl
fi
ok "docker, tailscale, git"

step "services"
if [ "$ID" = arch ]; then
	systemctl enable --now docker.service tailscaled.service >/dev/null 2>&1
else
	for s in docker tailscale; do
		rc-update add "$s" default >/dev/null 2>&1 || true
		rc-service "$s" status >/dev/null 2>&1 || rc-service "$s" start
	done
fi
i=0
until docker info >/dev/null 2>&1; do
	i=$((i + 1)); [ $i -le 30 ] || die "docker didn't start"; sleep 1
done
if [ -n "$ME" ]; then
	if [ "$ID" = arch ]; then usermod -aG docker "$ME"; else addgroup "$ME" docker 2>/dev/null || true; fi
fi
ok "docker and tailscale start on boot"

step "tailscale"
i=0
until tailscale status --json >/dev/null 2>&1; do
	i=$((i + 1)); [ $i -le 30 ] || die "tailscaled isn't answering"; sleep 1
done
if ! tailscale status --json | grep -q '"BackendState": *"Running"'; then
	echo "   open the link below to add this machine to your Tailscale"
	tailscale up
fi
TS_IP=$(tailscale ip -4 | head -n 1)
ok "on Tailscale as $TS_IP"

step "settings (.env)"
[ -f "$ENV_FILE" ] || cp "$HOMELAB_DIR/.env.example" "$ENV_FILE"
set_env() {
	if grep -q "^$1=" "$ENV_FILE"; then
		sed -i "s|^$1=.*|$1=$2|" "$ENV_FILE"
	else
		printf '%s=%s\n' "$1" "$2" >> "$ENV_FILE"
	fi
}
grep -q '^LAB_DOMAIN=.' "$ENV_FILE" || set_env LAB_DOMAIN lab
set_env TAILSCALE_IP "$TS_IP"
set_env HOMELAB_DIR "$HOMELAB_DIR"
if grep -q '^SEARXNG_SECRET=change-me' "$ENV_FILE"; then
	set_env SEARXNG_SECRET "$(openssl rand -hex 32)"
fi
chown "$(stat -c %u:%g "$HOMELAB_DIR")" "$ENV_FILE"
LAB=$(sed -n 's/^LAB_DOMAIN=//p' "$ENV_FILE")
ok "apps will be at *.$LAB"

step "server settings"
if [ "$ID" = arch ]; then
	install -Dm644 "$HOMELAB_DIR/system/logind-server.conf" /etc/systemd/logind.conf.d/server.conf
	systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1
	systemctl set-default multi-user.target >/dev/null 2>&1
	install -Dm644 "$HOMELAB_DIR/system/screen-off.service" /etc/systemd/system/screen-off.service
	systemctl daemon-reload
	systemctl enable screen-off.service >/dev/null 2>&1
	ok "lid closed keeps running, never sleeps, boots to text, screen turns off when idle"
else
	install -D -m 755 "$HOMELAB_DIR/system/screen-off.start" /etc/local.d/screen-off.start
	rc-update add local default >/dev/null 2>&1 || true
	ok "screen turns off when idle"
fi

step "apps"
docker network inspect proxy >/dev/null 2>&1 || docker network create proxy >/dev/null
# downloads fail sometimes on flaky wifi, so each app gets 3 tries
up() {
	name=$(basename "$1")
	for try in 1 2 3; do
		if (
			cd "$1"
			if [ "$PULL" = yes ]; then docker compose pull --quiet; fi
			docker compose up -d --quiet-pull --remove-orphans >/dev/null 2>&1
		); then
			ok "$name"; return 0
		fi
		echo "   $name failed (try $try of 3), retrying..."; sleep 5
	done
	echo " ✗ $name didn't start. See why with: cd $1 && docker compose up"
}
up "$HOMELAB_DIR/dockge"
up "$HOMELAB_DIR/stacks/dns"
up "$HOMELAB_DIR/stacks/caddy"
for dir in "$HOMELAB_DIR"/stacks/*/; do
	dir=${dir%/}
	case $(basename "$dir") in dns|caddy) continue ;; esac
	if [ -f "$dir/compose.yaml" ]; then up "$dir"; fi
done

step "done"
cat <<MSG
   Dashboard: https://home.$LAB
   On each device, trust the certificate once: open http://ca.$LAB (see README)

   If this is a new server (or its Tailscale IP changed), point .$LAB at it once:
   Tailscale admin > DNS > Add nameserver > Custom > $TS_IP
   then turn on "Restrict to domain" and type: $LAB
MSG
