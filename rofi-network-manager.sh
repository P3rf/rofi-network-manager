#!/bin/bash
# Default Values
LOCATION=0
QRCODE_LOCATION=$LOCATION
Y_AXIS=0
X_AXIS=0
NOTIFICATIONS_INIT="off"
QRCODE_DIR="/tmp/"
WIDTH_FIX_MAIN=1
WIDTH_FIX_STATUS=10
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSWORD_ENTER="if connection is stored,hit enter/esc"
WIRELESS_INTERFACES=($(nmcli device | awk '$2=="wifi" {print $1}'))
WIRELESS_INTERFACES_PRODUCT=()
WLAN_INT=0
WIRED_INTERFACES="$(nmcli device | awk '$2=="ethernet" {print $1}' | head -1)"
WIRED_INTERFACES_PRODUCT=$(nmcli -f general.product device show "$WIRED_INTERFACES" | awk '{print $2}')
function initialization() {
	source "$DIR/rofi-network-manager.conf" || source "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/rofi-network-manager.conf"
	{ [[ -f "$DIR/rofi-network-manager.rasi" ]] && RASI_DIR="$DIR/rofi-network-manager.rasi"; } || { [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/rofi-network-manager.rasi" ]] && RASI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/rofi-network-manager.rasi"; } || exit
	for i in "${WIRELESS_INTERFACES[@]}"; do WIRELESS_INTERFACES_PRODUCT+=("$(nmcli -f general.product device show "$i" | awk '{print $2}')"); done
	wireless_interface_state
	ethernet_interface_state
}
function notification() {
	[[ "$NOTIFICATIONS_INIT" == "on" && -x "$(command -v notify-send)" ]] && notify-send -r "5" -u "normal" $1 "$2"
}
function wireless_interface_state() {
	ACTIVE_SSID=$(nmcli device status | grep "^${WIRELESS_INTERFACES[WLAN_INT]}." | awk '{print $4}')
	WIFI_CON_STATE=$(nmcli device status | grep "^${WIRELESS_INTERFACES[WLAN_INT]}." | awk '{print $3}')
	{ [[ "$WIFI_CON_STATE" == "unavailable" ]] && WIFI_LIST="***Wi-Fi Disabled***" && WIFI_SWITCH="~Wi-Fi On" && OPTIONS="${WIFI_LIST}\n${WIFI_SWITCH}\n~Scan"; } || { [[ "$WIFI_CON_STATE" =~ "connected" ]] && {
		PROMPT=${WIRELESS_INTERFACES_PRODUCT[WLAN_INT]}[${WIRELESS_INTERFACES[WLAN_INT]}]
		WIFI_LIST=$(nmcli --fields IN-USE,SSID,SECURITY,BARS device wifi list ifname "${WIRELESS_INTERFACES[WLAN_INT]}" | awk -F'  +' '{ if (!seen[$2]++) print}' | sed "s/^IN-USE\s//g" | sed "/*/d" | sed "s/^ *//" | awk '$1!="--" {print}')
		[[ "$ACTIVE_SSID" == "--" ]] && WIFI_SWITCH="~Scan\n~Manual/Hidden\n~Wi-Fi Off" || WIFI_SWITCH="~Scan\n~Disconnect\n~Manual/Hidden\n~Wi-Fi Off"
		OPTIONS="${WIFI_LIST}\n${WIFI_SWITCH}"
	}; }
}
function ethernet_interface_state() {
	WIRED_CON_STATE=$(nmcli device status | grep "ethernet" | head -1 | awk '{print $3}')
	{ [[ "$WIRED_CON_STATE" == "disconnected" ]] && WIRED_SWITCH="~Eth On"; } || { [[ "$WIRED_CON_STATE" == "connected" ]] && WIRED_SWITCH="~Eth Off"; } || { [[ "$WIRED_CON_STATE" == "unavailable" ]] && WIRED_SWITCH="***Wired Unavailable***"; } || { [[ "$WIRED_CON_STATE" == "connecting" ]] && WIRED_SWITCH="***Wired Initializing***"; }
	OPTIONS="${OPTIONS}\n${WIRED_SWITCH}"
}
function rofi_menu() {
	{ [[ ${#WIRELESS_INTERFACES[@]} -ne "1" ]] && OPTIONS="${OPTIONS}\n~Change Wifi Interface\n~More Options"; } || { OPTIONS="${OPTIONS}\n~More Options"; }
	{ [[ "$WIRED_CON_STATE" == "connected" ]] && PROMPT="${WIRED_INTERFACES_PRODUCT}[$WIRED_INTERFACES]"; } || PROMPT="${WIRELESS_INTERFACES_PRODUCT[WLAN_INT]}[${WIRELESS_INTERFACES[WLAN_INT]}]"
	dimensions "$OPTIONS" $WIDTH_FIX_MAIN
	SELECTION=$(echo -e "$OPTIONS" | rofi_cmd "-a 0")
	SSID=$(echo "$SELECTION" | sed "s/\s\{2,\}/\|/g" | awk -F "|" '{print $1}')
	selection_action
}
function dimensions() {
	WIDTH=$(echo -e "$1" | awk '{print length}' | sort -n | tail -1)
	LINES=$(echo -e "$1" | wc -l)
	((WIDTH += $2))
}
function rofi_cmd() {
	rofi -dmenu -i -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" $1 \
		-theme "$RASI_DIR" -theme-str '
		window{width: '"$((WIDTH / 2))"'em;}
		listview{lines: '"$LINES"';}
		textbox-prompt-colon{str:"'"$PROMPT"':";}
		'"$2"''
}
function change_wireless_interface() {
	{ [[ ${#WIRELESS_INTERFACES[@]} -eq "2" ]] && { [[ $WLAN_INT -eq "0" ]] && WLAN_INT=1 || WLAN_INT=0; }; } || {
		LIST_WLAN_INT=""
		for i in "${!WIRELESS_INTERFACES[@]}"; do
			ENTRY="${WIRELESS_INTERFACES_PRODUCT[$i]}[${WIRELESS_INTERFACES[$i]}]"
			WIDTH_TEMP=$(echo "$ENTRY" | awk '{print length($0);}')
			[[ $WIDTH_TEMP -gt $WIDTH ]] && WIDTH=$WIDTH_TEMP
			LIST_WLAN_INT=("${LIST_WLAN_INT[@]}${ENTRY}\n")
		done
		LIST_WLAN_INT[-1]=${LIST_WLAN_INT[-1]::-2}
		dimensions "${LIST_WLAN_INT[@]}" $WIDTH_FIX_STATUS
		CHANGE_WLAN_INT=$(echo -e "${LIST_WLAN_INT[@]}" | rofi_cmd)
		for i in "${!WIRELESS_INTERFACES[@]}"; do [[ $CHANGE_WLAN_INT == "${WIRELESS_INTERFACES_PRODUCT[$i]}[${WIRELESS_INTERFACES[$i]}]" ]] && WLAN_INT=$i && break; done
	}
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
	ACTIVE_SSID=$(nmcli -t -f GENERAL.CONNECTION dev show "${WIRELESS_INTERFACES[WLAN_INT]}" | cut -d ':' -f2)
	notification "$1" "You're now disconnected from Wi-Fi network '$ACTIVE_SSID'"
	nmcli con down id "$ACTIVE_SSID"
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
	WIDTH=40
	PROMPT="Enter_SSID"
	SSID=$(rofi_cmd)
	[[ -n $SSID ]] && {
		LINES=1
		PROMPT="Enter_Password"
		PASS=$(echo "$PASSWORD_ENTER" | rofi_cmd "-password")
		{ [[ -n "$PASS" ]] && [[ "$PASS" != "$PASSWORD_ENTER" ]] && connect "$SSID" "$PASS"; } || stored_connection "$SSID"
	}
}
function ssid_hidden() {
	LINES=0
	WIDTH=40
	PROMPT="Enter_SSID"
	SSID=$(rofi_cmd)
	[[ -n $SSID ]] && {
		LINES=1
		PROMPT="Enter_Password"
		PASS=$(echo "$PASSWORD_ENTER" | rofi_cmd "-password")
		check_wifi_connected
		[[ -n "$PASS" ]] && [[ "$PASS" != "$PASSWORD_ENTER" ]] && {
			nmcli con add type wifi con-name "$SSID" ssid "$SSID" ifname "${WIRELESS_INTERFACES[WLAN_INT]}"
			nmcli con modify "$SSID" wifi-sec.key-mgmt wpa-psk
			nmcli con modify "$SSID" wifi-sec.psk "$PASS"
		} || [[ $(nmcli -g NAME con show | grep -c "$SSID") -eq "0" ]] && nmcli con add type wifi con-name "$SSID" ssid "$SSID" ifname "${WIRELESS_INTERFACES[WLAN_INT]}"
		notification "-t 0 Wifi" "Connecting to $SSID"
		{ [[ $(nmcli con up id "$SSID" | grep -c "successfully activated") -eq "1" ]] && notification "Connection_Established" "You're now connected to Wi-Fi network '$SSID'"; } || notification "Connection_Error" "Connection can not be established"
	}
}
function status() {
	for i in "${!WIRELESS_INTERFACES[@]}"; do
		WIFI_CON_STATE=$(nmcli device status | grep "^${WIRELESS_INTERFACES[i]}." | awk '{print $3}')
		WIFI_INT_NAME=${WLAN_STATUS[*]}${WIRELESS_INTERFACES_PRODUCT[$i]}[${WIRELESS_INTERFACES[$i]}]
		[[ "$WIFI_CON_STATE" == "connected" ]] && WLAN_STATUS=("$WIFI_INT_NAME:\n\t$(nmcli -t -f GENERAL.CONNECTION dev show "${WIRELESS_INTERFACES[$i]}" | awk -F '[:]' '{print $2}') ~ $(nmcli -t -f IP4.ADDRESS dev show "${WIRELESS_INTERFACES[$i]}" | awk -F '[:/]' '{print $2}')\n") || WLAN_STATUS=("$WIFI_INT_NAME: ${WIFI_CON_STATE^}\n")
	done
	WLAN_STATUS[-1]=${WLAN_STATUS[-1]::-2}
	WIRED_CON_STATE=$(nmcli device status | grep "ethernet" | head -1 | awk '{print $3}')
	WIRED_INT_NAME="${WIRED_INTERFACES_PRODUCT}[$WIRED_INTERFACES]"
	[[ "$WIRED_CON_STATE" == "connected" ]] && {
		WIRED_CON_NAME=$(nmcli -t -f GENERAL.CONNECTION dev show "$WIRED_INTERFACES" | cut -d":" -f2)
		ETH_STATUS="$WIRED_INT_NAME:\n\t$WIRED_CON_NAME ~ "$(nmcli -t -f IP4.ADDRESS dev show "$(nmcli device | awk '$2=="ethernet" {print $1}' | head -1)" | awk -F '[:/]' '{print $2}')
	} || ETH_STATUS="$WIRED_INT_NAME: ${WIRED_CON_STATE^}"
	OPTIONS="$ETH_STATUS\n${WLAN_STATUS[*]}"
	ACTIVE_VPN=$(nmcli -g NAME,TYPE con show --active | awk '/:vpn/' | sed 's/:vpn.*//g')
	[[ -n $ACTIVE_VPN ]] && OPTIONS="${OPTIONS}\n${ACTIVE_VPN}[VPN]: $(nmcli -g ip4.address con show "${ACTIVE_VPN}" | awk -F '[:/]' '{print $1}')"
	dimensions "$OPTIONS" $WIDTH_FIX_STATUS
	echo -e "$OPTIONS" | rofi_cmd "" "mainbox {children:[listview];}"
}
function share_pass() {
	SSID=$(nmcli dev wifi show-password | grep -oP '(?<=SSID: ).*' | head -1)
	PASSWORD=$(nmcli dev wifi show-password | grep -oP '(?<=Password: ).*' | head -1)
	OPTIONS="SSID: ${SSID}\nPassword: ${PASSWORD}"
	[[ -x "$(command -v qrencode)" ]] && OPTIONS="${OPTIONS}\n~QrCode"
	dimensions "$OPTIONS" $WIDTH_FIX_STATUS
	SELECTION=$(echo -e "$OPTIONS" | rofi_cmd "-a "$((LINES - 1))"" "mainbox {children:[listview];}")
	selection_action
}
function gen_qrcode() {
	qrencode -t png -o /tmp/wifi_qr.png -s 10 -m 2 "WIFI:S:""$SSID"";T:""$(nmcli dev wifi show-password | grep -oP '(?<=Security: ).*' | head -1)"";P:""$PASSWORD"";;"
	rofi -dmenu -location "$QRCODE_LOCATION" \
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
	OPTIONS="~Manual\n~Hidden"
	dimensions "$OPTIONS" $WIDTH_FIX_STATUS
	SELECTION=$(echo -e "$OPTIONS" | rofi_cmd "" "mainbox {children:[listview];}")
	selection_action
}
function vpn() {
	ACTIVE_VPN=$(nmcli -g NAME,TYPE con show --active | awk '/:vpn/' | sed 's/:vpn.*//g')
	[[ $ACTIVE_VPN ]] && OPTIONS="~Deactive $ACTIVE_VPN" || OPTIONS=$(nmcli -g NAME,TYPE connection | awk '/:vpn/' | sed 's/:vpn.*//g')
	dimensions "$OPTIONS" "$WIDTH_FIX_STATUS"
	VPN_ACTION=$(echo -e "$OPTIONS" | rofi_cmd "" "mainbox {children:[listview];}")
	{ [[ "$VPN_ACTION" =~ "~Deactive" ]] && nmcli connection down "$ACTIVE_VPN" && notification "VPN_Deactivated" "$ACTIVE_VPN"; } || {
		VPN_OUTPUT=$(nmcli connection up "$VPN_ACTION" 2>/dev/null)
		notification "-t 0 Activating_VPN" "$VPN_ACTION"
		{ [[ $(echo "$VPN_OUTPUT" | grep -c "Connection successfully activated") -eq "1" ]] && notification "VPN_Successfully_Activated" "$VPN_ACTION"; } || notification "Error_Activating_VPN" "Check your configuration for $VPN_ACTION"
	}
}
function more_options() {
	OPTIONS=""
	[[ "$WIFI_CON_STATE" == "connected" ]] && OPTIONS="~Share Wifi Password\n"
	OPTIONS="${OPTIONS}~Status\n~Restart Network"
	[[ $(nmcli -g NAME,TYPE connection | awk '/:vpn/' | sed 's/:vpn.*//g') ]] && OPTIONS="${OPTIONS}\n~VPN"
	[[ -x "$(command -v nm-connection-editor)" ]] && OPTIONS="${OPTIONS}\n~Open Connection Editor"
	dimensions "$OPTIONS" "$WIDTH_FIX_STATUS"
	SELECTION=$(echo -e "$OPTIONS" | rofi_cmd "" "mainbox {children:[listview];}")
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
		WIDTH=40
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
