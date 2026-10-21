#!/bin/sh
# Starts ttyd for term.lab. Colors and font come from coat when it has sent them:
# coat's ttyd module writes /theme/ttyd.conf (one `ttyd -t` option per line) and
# restarts this container. Until then, plain VGA colors.
set --
if [ -s /theme/ttyd.conf ]; then
	while IFS= read -r opt; do
		case $opt in '' | '#'*) continue ;; esac
		set -- "$@" -t "$opt"
	done < /theme/ttyd.conf
else
	set -- -t fontFamily=monospace \
		-t 'theme={"background":"#000000","foreground":"#aaaaaa","cursor":"#aaaaaa","black":"#000000","red":"#aa0000","green":"#00aa00","yellow":"#aa5500","blue":"#0000aa","magenta":"#aa00aa","cyan":"#00aaaa","white":"#aaaaaa","brightBlack":"#555555","brightRed":"#ff5555","brightGreen":"#55ff55","brightYellow":"#ffff55","brightBlue":"#5555ff","brightMagenta":"#ff55ff","brightCyan":"#55ffff","brightWhite":"#ffffff"}'
fi
exec ttyd --writable -t titleFixed=server -t fontSize=16 -t cursorStyle=block "$@" \
	ssh -i /data/id_ed25519 -o UserKnownHostsFile=/data/known_hosts -o StrictHostKeyChecking=accept-new \
	"$SERVER_USER@host.docker.internal"
