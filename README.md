# homelab

Self-hosted stuff for the ThinkPad X1 Carbon Gen 7.

```
dockge/          the UI that runs everything (started by hand once)
stacks/          one folder per app, Dockge shows each as a stack
  caddy/         reverse proxy: pdf.<domain> -> Stirling PDF, etc.
  homepage/      dashboard
  uptime-kuma/   uptime monitoring
  stirling-pdf/  PDF tools
  transmute/     file converter
  searxng/       private search
  changedetection/  website change alerts
.env             your settings, shared by every stack (copy from .env.example)
```

Only two ports are open on the laptop: 80 (Caddy) and 5001 (Dockge). Everything
else is reached through Caddy by name.

## Setup on the ThinkPad

1. Install Docker and Tailscale, and log into Tailscale.

   ```
   sudo pacman -S docker docker-compose tailscale git
   sudo systemctl enable --now docker tailscaled
   sudo usermod -aG docker $USER      # then log out and back in
   sudo tailscale up
   ```

2. Put this repo at `/opt/homelab` (Dockge expects that path).

   ```
   sudo git clone <this repo> /opt/homelab
   sudo chown -R $USER:$USER /opt/homelab
   cd /opt/homelab
   ```

3. Make your `.env`.

   ```
   cp .env.example .env
   tailscale ip -4                   # e.g. 100.101.102.103
   ```

   Set `LAB_DOMAIN` to that IP with dashes plus `.sslip.io`, like
   `100-101-102-103.sslip.io`. sslip.io is a free DNS service that turns
   `anything.100-101-102-103.sslip.io` into `100.101.102.103`, so you get real
   names with no DNS setup. Set `SEARXNG_SECRET` to the output of `openssl rand -hex 32`.

4. Create the shared network and start Dockge.

   ```
   docker network create proxy
   cd dockge && docker compose up -d
   ```

5. Open `http://<tailscale ip>:5001`, make an account, and you'll see every
   folder in `stacks/`. Start **caddy** first, then the rest.

6. Open `http://home.<LAB_DOMAIN>`. That's the dashboard.

## Addresses

| name | app |
|---|---|
| `home.<LAB_DOMAIN>` | Homepage dashboard |
| `dockge.<LAB_DOMAIN>` | Dockge |
| `status.<LAB_DOMAIN>` | Uptime Kuma |
| `pdf.<LAB_DOMAIN>` | Stirling PDF |
| `convert.<LAB_DOMAIN>` | Transmute |
| `search.<LAB_DOMAIN>` | SearXNG |
| `changes.<LAB_DOMAIN>` | changedetection.io |

These only work from devices on your Tailscale.

## Adding a new app

1. Make `stacks/<name>/compose.yaml`. Copy any existing one. Give it a
   `container_name`, put it on the `proxy` network, and don't publish ports.
2. Add a block to `stacks/caddy/Caddyfile`:
   ```
   http://<name>.{$LAB_DOMAIN} {
   	reverse_proxy <container_name>:<port the app listens on>
   }
   ```
3. Add a tile to `stacks/homepage/config/services.yaml`.
4. In Dockge: start the new stack, then restart caddy.

## Laptop-as-server stuff

- **Keep it running with the lid shut:** in `/etc/systemd/logind.conf`, set
  `HandleLidSwitch=ignore` and `HandleLidSwitchExternalPower=ignore`, then
  `sudo systemctl restart systemd-logind`.
- **Don't cook the battery** by keeping it at 100% forever:
  `echo 80 | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold`
  (this resets on reboot; `tlp` can make it stick).
- **Backups:** all app data lives in `stacks/*/data/`. Back up that folder
  and `.env`, and you've got everything.
