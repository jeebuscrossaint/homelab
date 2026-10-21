# homelab

Self-hosted stuff for the ThinkPad X1 Carbon Gen 7.

```
dockge/          the UI that runs everything (started by hand once)
stacks/          one folder per app, Dockge shows each as a stack
  dns/           tiny DNS server so names like pdf.lab point at the ThinkPad
  caddy/         reverse proxy: pdf.lab -> Stirling PDF, etc.
  homepage/      dashboard
  uptime-kuma/   uptime monitoring
  stirling-pdf/  PDF tools
  transmute/     file converter
  searxng/       private search
  changedetection/  website change alerts
.env             your settings, shared by every stack (copy from .env.example)
```

Ports open on the laptop: 80 (Caddy), 5001 (Dockge), and 53 on the Tailscale IP
only (DNS). Everything else is reached through Caddy by name.

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
   tailscale ip -4                   # put this in TAILSCALE_IP
   openssl rand -hex 32              # put this in SEARXNG_SECRET
   ```

   `LAB_DOMAIN=lab` means your apps are `pdf.lab`, `home.lab`, etc.

4. Create the shared network and start Dockge.

   ```
   docker network create proxy
   cd dockge && docker compose up -d
   ```

5. Open `http://<tailscale ip>:5001`, make an account, and you'll see every
   folder in `stacks/`. Start **caddy** first, then the rest.

6. Make the `.lab` names work on all your Tailscale devices: in the Tailscale
   admin console go to **DNS**, **Add nameserver**, **Custom**, enter the
   ThinkPad's Tailscale IP, turn on **Restrict to domain**, and type `lab`.

7. Open `http://home.lab`. That's the dashboard.

## Addresses

| name | app |
|---|---|
| `home.lab` | Homepage dashboard |
| `dockge.lab` | Dockge |
| `status.lab` | Uptime Kuma |
| `pdf.lab` | Stirling PDF |
| `convert.lab` | Transmute |
| `search.lab` | SearXNG |
| `changes.lab` | changedetection.io |

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
