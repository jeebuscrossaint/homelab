#!/usr/bin/env bash
# Turns the ThinkPad from a desktop into a server.
# Run it once on the ThinkPad:  sudo bash /opt/homelab/server-mode.sh
# Then reboot.
#
# Keeps: docker, tailscale, ssh, networkmanager, tlp/thermald, dev tools, CLI tools, tor, i2pd.
# Removes: the desktop (mango), GUI apps, audio, bluetooth, themes, extra fonts.
# Your files and app settings in ~/.config are NOT deleted.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "run it with sudo: sudo bash $0"
  exit 1
fi

GUI_APPS=(
  chromium claude-desktop discord firefox-developer-edition kitty slack-desktop-wayland-jetm
  tradingview visual-studio-code-bin torbrowser-launcher vencord-hook vencord-installer-bin
  qalculate-gtk zathura zathura-pdf-poppler imv mpv guvcview pwvucontrol overskride-bin
  wdisplays conky activitywatch-bin aw-awatcher
)
DESKTOP=(
  mangowm uwsm fuzzel dunst swaybg swayidle swaylock wlopm wlsunset wl-clip-persist
  wl-clipboard cliphist grim slurp satty wf-recorder xdg-desktop-portal-wlr xorg-xwayland
  polkit-gnome gnome-keyring udiskie libnotify playerctl xdg-user-dirs
)
AUDIO_BT=(
  pipewire pipewire-alsa pipewire-jack pipewire-pulse wireplumber gst-plugin-pipewire libpulse
  bluez bluez-utils
)
THEMES_FONTS=(
  adw-gtk-theme whitesur-cursor-theme-git whitesur-icon-theme
  cozette-otb maplemono-nf noto-fonts-emoji otb-scientifica otf-chomsky otf-font-awesome
  otf-intel-one-mono otf-server-mono otf-unscii-16-full ttf-fragment-mono ttf-geist-pixel-font-git
  ttf-ioskeley-mono-unhinted ttf-ms-fonts ttf-neospleen-nerd-font
)

echo "== keeping tor (it's a dependency of tor browser, which is being removed)"
pacman -D --asexplicit tor

echo "== turning off bluetooth"
systemctl disable --now bluetooth.service || true

echo "== removing desktop packages"
# only remove what's actually installed, so one missing name doesn't stop everything
ALL=("${GUI_APPS[@]}" "${DESKTOP[@]}" "${AUDIO_BT[@]}" "${THEMES_FONTS[@]}")
INSTALLED=()
for p in "${ALL[@]}"; do pacman -Q "$p" &>/dev/null && INSTALLED+=("$p"); done
pacman -Rns --noconfirm "${INSTALLED[@]}"

echo "== keep running with the lid closed"
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/server.conf <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF

echo "== never sleep or hibernate"
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

echo "== boot to a text login instead of a desktop"
systemctl set-default multi-user.target

echo "== stop auto-logging in on the built-in screen"
rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf

echo "== turn the screen off after 1 minute of no typing"
cat > /etc/systemd/system/screen-off.service <<'EOF'
[Unit]
Description=Turn the console screen off after 1 minute idle

[Service]
Type=oneshot
ExecStart=/usr/bin/setterm --blank 1 --powerdown 1
StandardOutput=tty
TTYPath=/dev/tty1

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable screen-off.service

echo
echo "done. reboot with: sudo reboot"
echo "after that, get in with: ssh freaknet-thinkpad-arch"
