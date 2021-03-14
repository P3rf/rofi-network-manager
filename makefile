
PREFIX = /usr/local

install: rofi-network-manager.sh
	cp rofi-network-manager.sh "${PREFIX}/bin/rofi-network-manager"
	chmod +x "${PREFIX}/bin/rofi-network-manager"
	mkdir -p "$${XDG_CONFIG_HOME-$$HOME/.config}/rofi-network-manager"
	cp rofi-network-manager.conf "$${XDG_CONFIG_HOME-$$HOME/.config}/rofi-network-manager/"

