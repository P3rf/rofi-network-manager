#!/bin/bash
# Default Values
LOCATION=0
QRCODE_LOCATION=$LOCATION
Y_AXIS=0
X_AXIS=0
NOTIFICATIONS_INIT="off"
QRCODE_DIR="/tmp/"
WIDTH_FIX_MAIN=0
WIDTH_FIX_STATUS=0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSWORD_ENTER="if connection is stored, hit enter/esc"
WIRELESS_INTERFACES=($(nmcli device | awk '$2=="wifi" {print $1}'))
WIRELESS_INTERFACES_PRODUCT=()
WLAN_INT=0

function initialization() {
	source "$DIR/rofi-network-manager.conf" || source "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/rofi-network-manager.conf" || exit
	{ RASI_DIR="$DIR/rofi-network-manager.rasi" && [[ -f "$DIR/rofi-network-manager.rasi" ]]; } || { RASI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/rofi-network-manager.rasi" && [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/rofi-network-manager.rasi" ]]; } || exit
	for i in "${WIRELESS_INTERFACES[@]}"; do
		WIRELESS_INTERFACES_PRODUCT+=("$(nmcli -f general.product device show "$i" | awk '{print $2}')")
	done
	wireless_interface_state
	ethernet_interface_state
}
function notification() {
	[[ "$NOTIFICATIONS_INIT" == "on" ]] && dunstify -r "5" -u "normal" $1 "$2"
}
function wireless_interface_state() {
	ACTIVE_SSID=$(nmcli device status | grep "^${WIRELESS_INTERFACES[WLAN_INT]}." | awk '{print $4}')
	WIFI_CON_STATE=$(nmcli device status | grep "^${WIRELESS_INTERFACES[WLAN_INT]}." | awk '{print $3}')
	if [[ "$WIFI_CON_STATE" =~ "unavailable" ]]; then
		WIFI_LIST="   ***Wi-Fi Disabled***"
		WIFI_SWITCH="~Wi-Fi On"
		LINES=5
	elif [[ "$WIFI_CON_STATE" =~ "connected" ]]; then
		WIFI_LIST=$(nmcli --fields IN-USE,SSID,SECURITY,BARS device wifi list ifname "${WIRELESS_INTERFACES[WLAN_INT]}" | awk -F'  +' '{ if (!seen[$2]++) print}' | sed "s/^IN-USE\s//g" | sed "/--/d" | sed "/*/d" | sed "s/^ *//")
		LINES=$(echo -e "$WIFI_LIST" | wc -l)
		if [[ "$ACTIVE_SSID" == "--" ]]; then
			WIFI_SWITCH="~Manual/Hidden\n~Wi-Fi Off"
			((LINES += 5))
		else
			WIFI_SWITCH="~Disconnect\n~Manual/Hidden\n~Wi-Fi Off"
			((LINES += 6))
		fi
	fi
	WIDTH=$(echo "$WIFI_LIST" | head -n 1 | awk '{print length($0);}')
}
function ethernet_interface_state() {
	WIRE_CON_STATE=$(nmcli device status | grep "ethernet" | awk '{print $3}')
	if [[ "$WIRE_CON_STATE" == "disconnected" ]]; then
		WIRE_SWITCH="~Eth On"
	elif [[ "$WIRE_CON_STATE" == "connected" ]]; then
		WIRE_SWITCH="~Eth Off"
	elif [[ "$WIRE_CON_STATE" == "unavailable" ]]; then
		WIRE_SWITCH=" ***Wired Unavailable***"
	fi
}
function rofi_menu() {
	[[ $LINES -eq 0 ]] && notification "Initialization" "Some connections are being set up.Please try again later." && exit
	((WIDTH += WIDTH_FIX_MAIN))
	PROMPT=${WIRELESS_INTERFACES_PRODUCT[WLAN_INT]}[${WIRELESS_INTERFACES[WLAN_INT]}]
	if [[ $(nmcli device | awk '$2=="wifi" {print $1}' | wc -l) -ne "1" ]]; then
		((LINES += 1))
		SELECTION=$(echo -e "$WIFI_LIST\n~Scan\n$WIFI_SWITCH\n$WIRE_SWITCH\n~Change Wifi Interface\n~More Options" |
			rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" -a "0" \
				-theme "$RASI_DIR" -theme-str '
				window{width: '"$((WIDTH / 2))"'em;}
				listview{lines: '"$LINES"';}
				textbox-prompt-colon{str:"'"$PROMPT"':";}')
	else
		SELECTION=$(echo -e "$WIFI_LIST\n~Scan\n$WIFI_SWITCH\n$WIRE_SWITCH\n~More Options" |
			rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" -a "0" \
				-theme "$RASI_DIR" -theme-str '
				window{width: '"$((WIDTH / 2))"'em;}
				listview{lines: '"$LINES"';}
				textbox-prompt-colon{str:"'"$PROMPT"':";}')
	fi
	SSID_SELECTION=$(echo "$SELECTION" | sed "s/\s\{2,\}/\|/g" | awk -F "|" '{print $1}')
	selection_action
}
function change_wireless_interface() {
	PROMPT=">_"
	if [[ $(nmcli device | awk '$2=="wifi" {print $1}' | wc -l) -eq "2" ]]; then
		[[ $WLAN_INT -eq "0" ]] && WLAN_INT=1 || WLAN_INT=0
	else
		for i in "${!WIRELESS_INTERFACES[@]}"; do
			LIST_WLAN_INT=("${LIST_WLAN_INT[@]}${WIRELESS_INTERFACES_PRODUCT[$i]}[${WIRELESS_INTERFACES[$i]}]\n")
		done
		LINES=$(nmcli device | awk '$2=="wifi" {print $1}' | wc -l)
		CHANGE_WLAN_INT=$(echo -e "${LIST_WLAN_INT[@]}" |
			rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" \
				-theme "$RASI_DIR" -theme-str '
				window{width: '"$((WIDTH / 2))"'em;}
				listview{lines: '"$LINES"';}
				textbox-prompt-colon{str:"'"$PROMPT"':";}')
		for i in "${!WIRELESS_INTERFACES[@]}"; do
			[[ $CHANGE_WLAN_INT == "${WIRELESS_INTERFACES_PRODUCT[$i]}[${WIRELESS_INTERFACES[$i]}]" ]] && WLAN_INT=$i && break
		done
	fi
	wireless_interface_state
	rofi_menu
}
function scan() {
	[[ "$WIFI_CON_STATE" =~ "unavailable" ]] && change_wifi_state "Wi-Fi" "Enabling Wi-Fi connection" "on" && sleep 2
	notification "-t 0 Wifi" "Please Wait Scanning"
	WIFI_LIST=$(nmcli --fields IN-USE,SSID,SECURITY,BARS device wifi list ifname "${WIRELESS_INTERFACES[WLAN_INT]}" --rescan yes | awk -F'  +' '{ if (!seen[$2]++) print}' | sed "s/^IN-USE\s//g" | sed "/--/d" | sed "/*/d" | sed "s/^ *//")
	wireless_interface_state
	notification "-t 1 Wifi" "Please Wait Scanning"
	rofi_menu
}
function change_wifi_state() {
	notification "$1" "$2"
	nmcli radio wifi "$3"
}
function change_wire_state() {
	notification "$1" "$2"
	nmcli con "$3" "$(nmcli -t -f NAME,TYPE con | grep "ethernet" | cut -d":" -f1)"
}
function net_restart() {
	notification "$1" "$2"
	nmcli networking off
	sleep 3
	nmcli networking on
}
function disconnect() {
	TRUE_ACTIVE_SSID=$(nmcli -t -f GENERAL.CONNECTION dev show "${WIRELESS_INTERFACES[WLAN_INT]}" | cut -d ':' -f2)
	notification "$1" "You're now disconnected from Wi-Fi network '$TRUE_ACTIVE_SSID'"
	nmcli con down id "$TRUE_ACTIVE_SSID"
}
function check_wifi_connected() {
	[[ "$(nmcli device status | grep "^${WIRELESS_INTERFACES[WLAN_INT]}." | awk '{print $3}')" == "connected" ]] && disconnect "Connection_Terminated"
}
function connect() {
	check_wifi_connected
	notification "Wi-Fi" "Connecting to $1"
	if [[ $(nmcli dev wifi con "$1" password "$2" ifname "${WIRELESS_INTERFACES[WLAN_INT]}" | grep -c "successfully activated") == "1" ]]; then
		notification "Connection_Established" "You're now connected to Wi-Fi network '$1'"
	else
		notification "Connection_Error" "Connection can not be established"
	fi
}
function stored_connection() {
	check_wifi_connected
	notification "Wi-Fi" "Connecting to $1"
	if [[ $(nmcli dev wifi con "$1" ifname "${WIRELESS_INTERFACES[WLAN_INT]}" | grep -c "successfully activated") = "1" ]]; then
		notification "Connection_Established" "You're now connected to Wi-Fi network '$1'"
	else
		notification "Connection_Error" "Connection can not be established"
	fi
}
function ssid_manual() {
	LINES=0
	PROMPT="Enter_SSID"
	WIDTH=35
	SSID=$(rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" \
		-theme "$RASI_DIR" -theme-str '
		window{width: '"$((WIDTH / 2))"'em;}
		listview{lines: '"$LINES"';}
		textbox-prompt-colon{str:"'"$PROMPT"':";}')
	[[ -n $SSID ]] && {
		LINES=1
		WIDTH=$(echo "$PASSWORD_ENTER" | awk '{print length($0);}')
		((WIDTH += WIDTH_FIX_MAIN))
		PROMPT="Enter_Password"
		PASS=$(echo "$PASSWORD_ENTER" |
			rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" -password \
				-theme "$RASI_DIR" -theme-str '
				window{width: '"$((WIDTH / 2))"'em;}
				listview{lines: '"$LINES"';}
				textbox-prompt-colon{str:"'"$PROMPT"':";}')
		if [[ -n "$PASS" ]]; then
			if [[ "$PASS" =~ $PASSWORD_ENTER ]]; then
				stored_connection "$SSID"
			else
				connect "$SSID" "$PASS"
			fi
		else
			stored_connection "$SSID"
		fi
	}
}
function ssid_hidden() {
	LINES=0
	PROMPT="Enter_SSID"
	WIDTH=35
	SSID=$(rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" \
		-theme "$RASI_DIR" -theme-str '
		window{width: '"$((WIDTH / 2))"'em;}
		listview{lines: '"$LINES"';}
		textbox-prompt-colon{str:"'"$PROMPT"':";}')
	[[ -n $SSID ]] && {
		LINES=1
		WIDTH=$(echo "$PASSWORD_ENTER" | awk '{print length($0);}')
		((WIDTH += WIDTH_FIX_MAIN))
		PROMPT="Enter_Password"
		PASS=$(echo "$PASSWORD_ENTER" |
			rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" \
				-password -theme "$RASI_DIR" -theme-str '
				window{width: '"$((WIDTH / 2))"'em;}
				listview{lines: '"$LINES"';}
				textbox-prompt-colon{str:"'"$PROMPT"':";}
				')
		if [[ -n "$PASS" ]]; then
			if [[ "$PASS" =~ $PASSWORD_ENTER ]]; then
				check_wifi_connected
				notification "Wi-Fi" "Connecting to $SSID"
				if [[ $(nmcli dev wifi con "$SSID" ifname "${WIRELESS_INTERFACES[WLAN_INT]}" hidden yes | grep -c "successfully activated") = "1" ]]; then
					notification "Connection_Established" "You're now connected to Wi-Fi network '$SSID'"
				else
					notification "Connection_Error" "Connection can not be established"
				fi
			else
				check_wifi_connected
				notification "Wi-Fi" "Connecting to $SSID"
				if [[ $(nmcli dev wifi con "$SSID" password "$PASS" ifname "${WIRELESS_INTERFACES[WLAN_INT]}" | grep -c "successfully activated") == "1" ]]; then
					notification "Connection_Established" "You're now connected to Wi-Fi network '$SSID'"
				else
					notification "Connection_Error" "Connection can not be established"
				fi
			fi
		else
			check_wifi_connected
			notification "Wi-Fi" "Connecting to $SSID"
			if [[ $(nmcli dev wifi con "'$SSID'" ifname "${WIRELESS_INTERFACES[WLAN_INT]}" hidden yes | grep -c "successfully activated") = "1" ]]; then
				notification "Connection_Established" "You're now connected to Wi-Fi network '$SSID'"
			else
				notification "Connection_Error" "Connection can not be established"
			fi
		fi
	}
}
function status() {
	LINES=0
	WIDTH=0
	for i in "${!WIRELESS_INTERFACES[@]}"; do
		WIFI_CON_STATE=$(nmcli device status | grep "^${WIRELESS_INTERFACES[i]}." | awk '{print $3}')
		WIFI_INT_NAME=${WLAN_STATUS[*]}${WIRELESS_INTERFACES_PRODUCT[$i]}[${WIRELESS_INTERFACES[$i]}]
		if [[ "$WIFI_CON_STATE" == "connected" ]]; then
			WLAN_STATUS=("$WIFI_INT_NAME:\n\t$(nmcli -t -f GENERAL.CONNECTION dev show "${WIRELESS_INTERFACES[$i]}" | awk -F '[:]' '{print $2}') ~ $(nmcli -t -f IP4.ADDRESS dev show "${WIRELESS_INTERFACES[$i]}" | awk -F '[:/]' '{print $2}')\n")
			((LINES += 2))
		else
			WLAN_STATUS=("$WIFI_INT_NAME: ${WIFI_CON_STATE^}\n")
			((LINES += 1))
		fi
	done
	WLAN_STATUS[-1]=${WLAN_STATUS[-1]::-2}
	WIDTH_TEMP=$(echo -e "${WLAN_STATUS[*]}" | tail -n 2 | head -n 1 | awk '{print length($0);}')
	[[ $WIDTH_TEMP -gt $WIDTH ]] && WIDTH=$WIDTH_TEMP
	WIRE_CON_STATE=$(nmcli device status | grep "ethernet" | awk '{print $3}')
	WIRE_INT_NAME="$(nmcli device | awk '$2=="ethernet" {print $1}')"
	if [[ "$WIRE_CON_STATE" == "connected" ]]; then
		WIRE_CON_NAME=$(nmcli -g name,device con | awk '/:'"$WIRE_INT_NAME"'/' | sed 's/:'"$WIRE_INT_NAME"'.*//g')
		ETH_STATUS="$WIRE_INT_NAME:\n\t$WIRE_CON_NAME ~ "$(nmcli -t -f IP4.ADDRESS dev show "$(nmcli device | awk '$2=="ethernet" {print $1}')" | awk -F '[:/]' '{print $2}')
		((LINES += 2))
	else
		ETH_STATUS="$WIRE_INT_NAME: ${WIRE_CON_STATE^}"
		((LINES += 1))
	fi
	WIDTH_TEMP=$(echo -e "$ETH_STATUS" | tail -n 1 | awk '{print length($0);}')
	[[ $WIDTH_TEMP -gt $WIDTH ]] && WIDTH=$WIDTH_TEMP
	((WIDTH += WIDTH_FIX_STATUS))
	[[ $WIDTH -le 25 ]] && WIDTH=35
	OPTIONS="$ETH_STATUS\n${WLAN_STATUS[*]}"
	ACTIVE_VPN=$(nmcli -g NAME,TYPE con show --active | awk '/:vpn/' | sed 's/:vpn.*//g')
	[[ -n $ACTIVE_VPN ]] && OPTIONS="${OPTIONS}\n${ACTIVE_VPN}[VPN]:\t$(nmcli -g ip4.address con show "UTH Library" | awk -F '[:/]' '{print $1}')" && ((LINES += 1))
	echo -e "$OPTIONS" |
		rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" \
			-theme "$RASI_DIR" -theme-str '
			window{width: '"$((WIDTH / 2))"'em;
			children: [listview];}
			listview{lines: '"$LINES"';}'
}
function share_pass() {
	LINES=$(nmcli dev wifi show-password | grep -c -e SSID: -e Password:)
	((LINES += 1))
	WIDTH=35
	SELECTION=$(echo -e "$(nmcli dev wifi show-password | grep -e SSID: -e Password:)\n~QrCode" |
		rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" -a "$((LINES - 1))" \
			-theme "$RASI_DIR" -theme-str '
			window{width: '"$((WIDTH / 2))"'em;
			children: [listview];}
			listview{lines: '"$LINES"';}')
	selection_action
}
function gen_qrcode() {
	qrencode -t png -o /tmp/wifi_qr.png -s 10 -m 2 "WIFI:S:""$(nmcli dev wifi show-password | grep -oP '(?<=SSID: ).*' | head -1)"";T:""$(nmcli dev wifi show-password | grep -oP '(?<=Security: ).*' | head -1)"";P:""$(nmcli dev wifi show-password | grep -oP '(?<=Password: ).*' | head -1)"";;"
	rofi -dmenu -location "$QRCODE_LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" \
		-theme-str '
		* {
			background-color: transparent;
			text-color:       transparent;}
		window {
			border-radius: 6px;
			padding: 1em;
			background-color: transparent;
			background-image: url("'$QRCODE_DIR'wifi_qr.png",width);
			width: 20em;}
		textbox-prompt-colon {
			expand: false;
			margin: 0;
			str:"";}
		listview { lines: 15;}
		entry { enabled: false;}'
}
function manual_hidden() {
	LINES=2
	WIDTH=35
	SELECTION=$(echo -e "~Manual\n~Hidden" |
		rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" \
			-theme "$RASI_DIR" -theme-str '
			window{
				width: '"$((WIDTH / 2))"'em;
				children: [listview];}
			listview{lines: '"$LINES"';}')
	selection_action
}
function vpn() {
	ACTIVE_VPN=$(nmcli -g NAME,TYPE con show --active | awk '/:vpn/' | sed 's/:vpn.*//g')
	WIDTH=35
	if [[ $ACTIVE_VPN ]]; then
		PROMPT="$ACTIVE_VPN"
		LINES=1
		VPN_ACTION=$(echo -e "~Deactive VPN" |
			rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" \
				-theme "$RASI_DIR" -theme-str '
				window{width: '"$((WIDTH / 2))"'em;}
				listview{lines: '"$LINES"';}
				textbox-prompt-colon{str:"'"$PROMPT"':";}')
		[[ "$VPN_ACTION" =~ "~Deactive VPN" ]] && nmcli connection down "$ACTIVE_VPN" && notification "VPN_Deactivated" "$ACTIVE_VPN"
	else
		PROMPT="VPN"
		VPN_LIST=$(nmcli -g NAME,TYPE connection | awk '/:vpn/' | sed 's/:vpn.*//g')
		LINES=$(nmcli -g NAME,TYPE connection | awk '/:vpn/' | sed 's/:vpn.*//g' | wc -l)
		VPN_ACTION=$(echo -e "$VPN_LIST" |
			rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" \
				-theme "$RASI_DIR" -theme-str '
				window{width: '"$((WIDTH / 2))"'em;}
				listview{lines: '"$LINES"';}
				textbox-prompt-colon{str:"'"$PROMPT"':";}')
		[[ -n "$VPN_ACTION" ]] && {
			VPN_OUTPUT=$(nmcli connection up "$VPN_ACTION" 2>/dev/null)
			notification "-t 0 Activating_VPN" "$VPN_ACTION"
			if [[ $(echo "$VPN_OUTPUT" | grep -c "Connection successfully activated") -eq "1" ]]; then
				notification "VPN_Successfully_Activated" "$VPN_ACTION"
			else
				notification "Error_Activating_VPN" "Check your configuration for $VPN_ACTION"
			fi
		}
	fi
}
function more_options() {
	LINES=2
	WIDTH=35
	[[ "$WIFI_CON_STATE" == "connected" ]] && OPTIONS="~Share Wifi Password\n" && ((LINES += 1))
	OPTIONS="${OPTIONS}~Status\n~Restart Network"
	[[ $(nmcli -g NAME,TYPE connection | awk '/:vpn/' | sed 's/:vpn.*//g') ]] && OPTIONS="${OPTIONS}\n~VPN" && ((LINES += 1))
	[[ -x "$(command -v nm-connection-editor)" ]] && OPTIONS="${OPTIONS}\n~Open Connection Editor" && ((LINES += 1))
	SELECTION=$(echo -e "$OPTIONS" |
		rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" \
			-theme "$RASI_DIR" -theme-str '
			window{
				width: '"$((WIDTH / 2))"'em;
				children: [listview];}
			listview{lines: '"$LINES"';}')
	selection_action
}
function selection_action() {
	case "$SELECTION" in
	"~Disconnect") disconnect "Connection_Terminated" ;;
	"~Scan") scan ;;
	"~Status") status ;;
	"~Share Wifi Password") share_pass ;;
	"~Manual/Hidden") manual_hidden ;;
	"~Manual") ssid_manual ;;
	"~Hidden") ssid_hidden ;;
	"~Wi-Fi On") change_wifi_state "Wi-Fi" "Enabling Wi-Fi connection" "on" ;;
	"~Wi-Fi Off") change_wifi_state "Wi-Fi" "Disabling Wi-Fi connection" "off" ;;
	"~Eth Off") change_wire_state "Ethernet" "Disabling Wired connection" "down" ;;
	"~Eth On") change_wire_state "Ethernet" "Enabling Wired connection" "up" ;;
	"   ***Wi-Fi Disabled***   ") ;;
	" ***Wired Unavailable***") ;;
	"~Change Wifi Interface") change_wireless_interface ;;
	"~Restart Network") net_restart "Network" "Restarting Network" ;;
	"~QrCode") gen_qrcode ;;
	"~More Options") more_options ;;
	"~Open Connection Editor") nm-connection-editor ;;
	"~VPN") vpn ;;
	*)
		LINES=1
		WIDTH=$(echo "$PASSWORD_ENTER" | awk '{print length($0);}')
		((WIDTH += WIDTH_FIX_MAIN))
		PROMPT="Enter_Password"
		[[ -n "$SELECTION" ]] && [[ "$WIFI_LIST" =~ .*"$SELECTION".* ]] && {
			[[ "$SSID_SELECTION" = "*" ]] && SSID_SELECTION=$(echo "$SELECTION" | sed "s/\s\{2,\}/\|/g " | awk -F "|" '{print $3}')
			if [[ "$ACTIVE_SSID" == "$SSID_SELECTION" ]]; then
				nmcli con up "$SSID_SELECTION" ifname "${WIRELESS_INTERFACES[WLAN_INT]}"
			else
				[[ "$SELECTION" =~ "WPA2" ]] || [[ "$SELECTION" =~ "WEP" ]] && {
					PASS=$(echo "$PASSWORD_ENTER" | rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" -password \
						-theme "$RASI_DIR" -theme-str '
							window{width: '"$((WIDTH / 2))"'em;}
							listview{lines: '"$LINES"';}
							textbox-prompt-colon{str:"'"$PROMPT"':";}')
				}
				if [[ -n "$PASS" ]]; then
					if [[ "$PASS" =~ $PASSWORD_ENTER ]]; then
						stored_connection "$SSID_SELECTION"
					else
						connect "$SSID_SELECTION" "$PASS"
					fi
				else
					stored_connection "$SSID_SELECTION"
				fi
			fi
		}
		;;
	esac
}
function main() {
	initialization
	rofi_menu
}
main
