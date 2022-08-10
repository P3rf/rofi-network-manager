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
PASSWORD_ENTER="if connection is stored,hit enter/esc"
WIRELESS_INTERFACES=($(nmcli device | awk '$2=="wifi" {print $1}'))
WIRELESS_INTERFACES_PRODUCT=()
WLAN_INT=0
WIRED_INTERFACES="$(nmcli device | awk '$2=="ethernet" {print $1}' | head -1)"
WIRED_INTERFACES_PRODUCT=$(nmcli -f general.product device show "$WIRED_INTERFACES" | awk '{print $2}')

function initialization() {
	source "$DIR/rofi-network-manager.conf" || source "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/rofi-network-manager.conf" || exit
	{ [[ -f "$DIR/rofi-network-manager.rasi" ]] && RASI_DIR="$DIR/rofi-network-manager.rasi"; } || { [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/rofi-network-manager.rasi" ]] && RASI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/rofi-network-manager.rasi"; } || exit
	for i in "${WIRELESS_INTERFACES[@]}"; do WIRELESS_INTERFACES_PRODUCT+=("$(nmcli -f general.product device show "$i" | awk '{print $2}')"); done
	wireless_interface_state
	ethernet_interface_state
}
function notification() {
	[[ "$NOTIFICATIONS_INIT" == "on" && -x "$(command -v nm-connection-editor)" ]] && notify-send -r "5" -u "normal" $1 "$2"
}
function wireless_interface_state() {
	LINES=0
	WIDTH=0
	OPTIONS=""
	ACTIVE_SSID=$(nmcli device status | grep "^${WIRELESS_INTERFACES[WLAN_INT]}." | awk '{print $4}')
	WIFI_CON_STATE=$(nmcli device status | grep "^${WIRELESS_INTERFACES[WLAN_INT]}." | awk '{print $3}')
	if [[ "$WIFI_CON_STATE" =~ "unavailable" ]]; then
		WIFI_LIST="***Wi-Fi Disabled***"
		WIFI_SWITCH="~Wi-Fi On"
		OPTIONS="${OPTIONS}${WIFI_LIST}\n${WIFI_SWITCH}\n~Scan"
		((LINES += 3))
	elif [[ "$WIFI_CON_STATE" =~ "connected" ]]; then
		PROMPT=${WIRELESS_INTERFACES_PRODUCT[WLAN_INT]}[${WIRELESS_INTERFACES[WLAN_INT]}]
		WIFI_LIST=$(nmcli --fields IN-USE,SSID,SECURITY,BARS device wifi list ifname "${WIRELESS_INTERFACES[WLAN_INT]}" | awk -F'  +' '{ if (!seen[$2]++) print}' | sed "s/^IN-USE\s//g" | sed "/*/d" | sed "s/^ *//" | awk '$1!="--" {print}')
		LINES=$(echo -e "$WIFI_LIST" | wc -l)
		{ [[ "$ACTIVE_SSID" == "--" ]] && WIFI_SWITCH="~Scan\n~Manual/Hidden\n~Wi-Fi Off" && ((LINES += 3)); } || { WIFI_SWITCH="~Scan\n~Disconnect\n~Manual/Hidden\n~Wi-Fi Off" && ((LINES += 4)); }
		OPTIONS="${OPTIONS}${WIFI_LIST}\n${WIFI_SWITCH}"
	fi
	WIDTH=$(echo "$WIFI_LIST" | head -n 1 | awk '{print length($0);}')
}
function ethernet_interface_state() {
	WIRED_CON_STATE=$(nmcli device status | grep "ethernet" | head -1 | awk '{print $3}')
	{ [[ "$WIRED_CON_STATE" == "disconnected" ]] && WIRED_SWITCH="~Eth On"; } || { [[ "$WIRED_CON_STATE" == "connected" ]] && WIRED_SWITCH="~Eth Off"; } || { [[ "$WIRED_CON_STATE" == "unavailable" ]] && WIRED_SWITCH="***Wired Unavailable***"; } || { [[ "$WIRED_CON_STATE" == "connecting" ]] && WIRED_SWITCH="***Wired Initializing***"; }
	((LINES += 1))
	OPTIONS="${OPTIONS}\n${WIRED_SWITCH}"
}
function rofi_menu() {
	[[ $LINES -eq 0 ]] && notification "Initialization" "Some connections are being set up.Please try again later." && exit
	((WIDTH += WIDTH_FIX_MAIN))
	{ [[ ${#WIRELESS_INTERFACES[@]} -ne "1" ]] && OPTIONS="${OPTIONS}\n~Change Wifi Interface\n~More Options" && ((LINES += 2)); } || { OPTIONS="${OPTIONS}\n~More Options" && ((LINES += 1)); }
	{ [[ "$WIRED_CON_STATE" == "connected" ]] && PROMPT="${WIRED_INTERFACES_PRODUCT}[$WIRED_INTERFACES]"; } || PROMPT="${WIRELESS_INTERFACES_PRODUCT[WLAN_INT]}[${WIRELESS_INTERFACES[WLAN_INT]}]"
	SELECTION=$(echo -e "$OPTIONS" | rofi_cmd "-a 0")
	SSID=$(echo "$SELECTION" | sed "s/\s\{2,\}/\|/g" | awk -F "|" '{print $1}')
	selection_action
}
function rofi_cmd() {
	rofi -dmenu -i -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" $1 \
		-theme "$RASI_DIR" -theme-str '
		window{width: '"$((WIDTH / 2))"'em;}
		listview{lines: '"$LINES"';}
		textbox-prompt-colon{str:"'"$PROMPT"':";}'
}
function change_wireless_interface() {
	LINES=${#WIRELESS_INTERFACES[@]}
	WIDTH=35
	PROMPT=">_"
	if [[ ${#WIRELESS_INTERFACES[@]} -eq "2" ]]; then
		[[ $WLAN_INT -eq "0" ]] && WLAN_INT=1 || WLAN_INT=0
	else
		LIST_WLAN_INT=""
		for i in "${!WIRELESS_INTERFACES[@]}"; do
			ENTRY="${WIRELESS_INTERFACES_PRODUCT[$i]}[${WIRELESS_INTERFACES[$i]}]"
			WIDTH_TEMP=$(echo "$ENTRY" | awk '{print length($0);}')
			[[ $WIDTH_TEMP -gt $WIDTH ]] && WIDTH=$WIDTH_TEMP
			LIST_WLAN_INT=("${LIST_WLAN_INT[@]}${ENTRY}\n")
		done
		LIST_WLAN_INT[-1]=${LIST_WLAN_INT[-1]::-2}
		CHANGE_WLAN_INT=$(echo -e "${LIST_WLAN_INT[@]}" | rofi_cmd)
		for i in "${!WIRELESS_INTERFACES[@]}"; do [[ $CHANGE_WLAN_INT == "${WIRELESS_INTERFACES_PRODUCT[$i]}[${WIRELESS_INTERFACES[$i]}]" ]] && WLAN_INT=$i && break; done
	fi
	wireless_interface_state
	ethernet_interface_state
	rofi_menu
}
function scan() {
	[[ "$WIFI_CON_STATE" =~ "unavailable" ]] && change_wifi_state "Wi-Fi" "Enabling Wi-Fi connection" "on" && sleep 2
	notification "-t 0 Wifi" "Please Wait Scanning"
	WIFI_LIST=$(nmcli --fields IN-USE,SSID,SECURITY,BARS device wifi list ifname "${WIRELESS_INTERFACES[WLAN_INT]}" --rescan yes | awk -F'  +' '{ if (!seen[$2]++) print}' | sed "s/^IN-USE\s//g" | sed "/*/d" | sed "s/^ *//" | awk '$1!="--" {print}')
	wireless_interface_state
	ethernet_interface_state
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
	notification "-t 0 Wi-Fi" "Connecting to $1"
	{ [[ $(nmcli dev wifi con "$1" password "$2" ifname "${WIRELESS_INTERFACES[WLAN_INT]}" | grep -c "successfully activated") -eq "1" ]] && notification "Connection_Established" "You're now connected to Wi-Fi network '$1'"; } || notification "Connection_Error" "Connection can not be established"

}
function stored_connection() {
	check_wifi_connected
	notification "-t 0 Wi-Fi" "Connecting to $1"
	{ [[ $(nmcli dev wifi con "$1" ifname "${WIRELESS_INTERFACES[WLAN_INT]}" | grep -c "successfully activated") -eq "1" ]] && notification "Connection_Established" "You're now connected to Wi-Fi network '$1'"; } || notification "Connection_Error" "Connection can not be established"
}
function ssid_manual() {
	LINES=0
	WIDTH=35
	PROMPT="Enter_SSID"
	SSID=$(rofi_cmd)
	[[ -n $SSID ]] && {
		LINES=1
		WIDTH=$(echo "$PASSWORD_ENTER" | awk '{print length($0);}')
		((WIDTH += WIDTH_FIX_MAIN))
		PROMPT="Enter_Password"
		PASS=$(echo "$PASSWORD_ENTER" | rofi_cmd "-password")
		{ [[ -n "$PASS" ]] && [[ "$PASS" != "$PASSWORD_ENTER" ]] && connect "$SSID" "$PASS"; } || stored_connection "$SSID"
	}
}
function ssid_hidden() {
	LINES=0
	WIDTH=35
	PROMPT="Enter_SSID"
	SSID=$(rofi_cmd)
	[[ -n $SSID ]] && {
		LINES=1
		WIDTH=$(echo "$PASSWORD_ENTER" | awk '{print length($0);}')
		((WIDTH += WIDTH_FIX_MAIN))
		PROMPT="Enter_Password"
		PASS=$(echo "$PASSWORD_ENTER" | rofi_cmd "-password")
		check_wifi_connected
		if [[ -n "$PASS" ]] && [[ "$PASS" != "$PASSWORD_ENTER" ]]; then
			nmcli con add type wifi con-name "$SSID" ssid "$SSID" ifname "${WIRELESS_INTERFACES[WLAN_INT]}"
			nmcli con modify "$SSID" wifi-sec.key-mgmt wpa-psk
			nmcli con modify "$SSID" wifi-sec.psk "$PASS"
		else
			[[ $(nmcli -g NAME con show | grep -c "$SSID") -eq "0" ]] && nmcli con add type wifi con-name "$SSID" ssid "$SSID" ifname "${WIRELESS_INTERFACES[WLAN_INT]}"
		fi
		notification "-t 0 Wifi" "Connecting to $SSID"
		{ [[ $(nmcli con up id "$SSID" | grep -c "successfully activated") -eq "1" ]] && notification "Connection_Established" "You're now connected to Wi-Fi network '$SSID'"; } || notification "Connection_Error" "Connection can not be established"
	}
}
function status() {
	LINES=0
	WIDTH=0
	PROMPT="Status"
	OPTIONS=""
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
	WIRED_CON_STATE=$(nmcli device status | grep "ethernet" | head -1 | awk '{print $3}')
	WIRED_INT_NAME="${WIRED_INTERFACES_PRODUCT}[$WIRED_INTERFACES]"
	if [[ "$WIRED_CON_STATE" == "connected" ]]; then
		WIRED_CON_NAME=$(nmcli -t -f GENERAL.CONNECTION dev show "$WIRED_INTERFACES" | cut -d":" -f2)
		ETH_STATUS="$WIRED_INT_NAME:\n\t$WIRED_CON_NAME ~ "$(nmcli -t -f IP4.ADDRESS dev show "$(nmcli device | awk '$2=="ethernet" {print $1}' | head -1)" | awk -F '[:/]' '{print $2}')
		((LINES += 2))
	else
		ETH_STATUS="$WIRED_INT_NAME: ${WIRED_CON_STATE^}"
		((LINES += 1))
	fi
	WIDTH_TEMP=$(echo -e "$ETH_STATUS" | tail -n 1 | awk '{print length($0);}')
	[[ $WIDTH_TEMP -gt $WIDTH ]] && WIDTH=$WIDTH_TEMP
	((WIDTH += WIDTH_FIX_STATUS))
	[[ $WIDTH -le 25 ]] && WIDTH=35
	OPTIONS="$ETH_STATUS\n${WLAN_STATUS[*]}"
	ACTIVE_VPN=$(nmcli -g NAME,TYPE con show --active | awk '/:vpn/' | sed 's/:vpn.*//g')
	[[ -n $ACTIVE_VPN ]] && OPTIONS="${OPTIONS}\n${ACTIVE_VPN}[VPN]: $(nmcli -g ip4.address con show "${ACTIVE_VPN}" | awk -F '[:/]' '{print $1}')" && ((LINES += 1))
	echo -e "$OPTIONS" | rofi_cmd
}
function share_pass() {
	LINES=$(nmcli dev wifi show-password | grep -c -e SSID: -e Password:)
	[[ -x "$(command -v qrencode)" ]] && {
		QRCODE="\n~QrCode"
		((LINES += 1))
	} || QRCODE=""
	WIDTH=35
	SELECTION=$(echo -e "$(nmcli dev wifi show-password | grep -e SSID: -e Password:)$QRCODE" | rofi_cmd "-a "$((LINES - 1))"")
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
	SELECTION=$(echo -e "~Manual\n~Hidden" | rofi_cmd)
	selection_action
}
function vpn() {
	ACTIVE_VPN=$(nmcli -g NAME,TYPE con show --active | awk '/:vpn/' | sed 's/:vpn.*//g')
	WIDTH=35
	PROMPT="VPN"
	if [[ $ACTIVE_VPN ]]; then
		PROMPT="$ACTIVE_VPN"
		LINES=1
		VPN_ACTION=$(echo -e "~Deactive VPN" | rofi_cmd "-a 0")
		[[ "$VPN_ACTION" =~ "~Deactive VPN" ]] && nmcli connection down "$ACTIVE_VPN" && notification "VPN_Deactivated" "$ACTIVE_VPN"
	else
		VPN_LIST=$(nmcli -g NAME,TYPE connection | awk '/:vpn/' | sed 's/:vpn.*//g')
		LINES=$(nmcli -g NAME,TYPE connection | awk '/:vpn/' | sed 's/:vpn.*//g' | wc -l)
		VPN_ACTION=$(echo -e "$VPN_LIST" | rofi_cmd)
		[[ -n "$VPN_ACTION" ]] && {
			VPN_OUTPUT=$(nmcli connection up "$VPN_ACTION" 2>/dev/null)
			notification "-t 0 Activating_VPN" "$VPN_ACTION"
			{ [[ $(echo "$VPN_OUTPUT" | grep -c "Connection successfully activated") -eq "1" ]] && notification "VPN_Successfully_Activated" "$VPN_ACTION"; } || notification "Error_Activating_VPN" "Check your configuration for $VPN_ACTION"
		}
	fi
}
function more_options() {
	LINES=2
	WIDTH=35
	OPTIONS=""
	[[ "$WIFI_CON_STATE" == "connected" ]] && OPTIONS="~Share Wifi Password\n" && ((LINES += 1))
	OPTIONS="${OPTIONS}~Status\n~Restart Network"
	[[ $(nmcli -g NAME,TYPE connection | awk '/:vpn/' | sed 's/:vpn.*//g') ]] && OPTIONS="${OPTIONS}\n~VPN" && ((LINES += 1))
	[[ -x "$(command -v nm-connection-editor)" ]] && OPTIONS="${OPTIONS}\n~Open Connection Editor" && ((LINES += 1))
	SELECTION=$(echo -e "$OPTIONS" | rofi_cmd)
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
	"***Wi-Fi Disabled***") ;;
	"***Wired Unavailable***") ;;
	"***Wired Initializing***") ;;
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
			[[ "$SSID" == "*" ]] && SSID=$(echo "$SELECTION" | sed "s/\s\{2,\}/\|/g " | awk -F "|" '{print $3}')
			{ [[ "$ACTIVE_SSID" == "$SSID" ]] && nmcli con up "$SSID" ifname "${WIRELESS_INTERFACES[WLAN_INT]}"; } || {
				[[ "$SELECTION" =~ "WPA2" ]] || [[ "$SELECTION" =~ "WEP" ]] && PASS=$(echo "$PASSWORD_ENTER" | rofi_cmd "-password")
				{ [[ -n "$PASS" ]] && [[ "$PASS" != "$PASSWORD_ENTER" ]] && connect "$SSID" "$PASS"; } || stored_connection "$SSID"
			}
		}
		;;
	esac
}
function main() {
	initialization
	rofi_menu
}
main
