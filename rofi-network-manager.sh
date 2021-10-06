#!/bin/bash
# Default Values
LOCATION=0
Y_AXIS=0
X_AXIS=0
NOTIFICATIONS_INIT="off"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [[ -f "$DIR/rofi-network-manager.conf" ]]; then
	source "$DIR/rofi-network-manager.conf"
fi
PASSWORD_ENTER="if connection is stored, hit enter/esc"
WIRELESS_INTERFACES=($(nmcli device | awk '$2=="wifi" {print $1}'))
WIRELESS_INTERFACES_PRODUCT=()
WLAN_INT=0
function notification() {
	if [[ "$NOTIFICATIONS_INIT" == "on" ]]; then
		dunstify -r $1 -u $2 $3 "$4" -i "$5"
	fi
}
function initialization() {
	for i in "${WIRELESS_INTERFACES[@]}"
	do
		WIRELESS_INTERFACES_PRODUCT+=($(nmcli -f general.product device show $i | awk '{print $2}'))
	done
	wireless_interface_state
	ethernet_interface_state
}
function wireless_interface_state() {
	ACTIVE_SSID=$(nmcli device status | grep ${WIRELESS_INTERFACES[WLAN_INT]} |  awk '{print $4}')
	WIFI_CON_STATE=$(nmcli device status | grep ${WIRELESS_INTERFACES[WLAN_INT]} |  awk '{print $3}')
	if [[ "$WIFI_CON_STATE" =~ "unavailable" ]]; then
		WIFI_LIST="   ***Wi-Fi Disabled***   "
		WIFI_SWITCH="~Wi-Fi On"
		LINES=7
	elif [[ "$WIFI_CON_STATE" =~ "connected" ]]; then
		WIFI_LIST=$(nmcli --fields IN-USE,SSID,SECURITY,BARS device wifi list ifname ${WIRELESS_INTERFACES[WLAN_INT]} | sed "s/^IN-USE\s//g" | sed "/*/d" | sed "s/^ *//")
		LINES=$(echo "$WIFI_LIST" | wc -l)
		if [[ "$ACTIVE_SSID" == "--" ]]; then
			WIFI_SWITCH="~Wi-Fi Off"
			((LINES+=6))
		else
			WIFI_SWITCH="~Disconnect\n~Share Wifi Password\n~Wi-Fi Off"
			((LINES+=8))
		fi
	fi
	WIDTH=$(echo "$WIFI_LIST" | head -n 1 | awk '{print length($0); }')
	((WIDTH+=0))
}
function ethernet_interface_state() {
	WIRE_CON_STATE=$(nmcli device status | grep "ethernet"  |  awk '{print $3}')
	if [[ "$WIRE_CON_STATE" == "disconnected" ]]; then
		WIRE_SWITCH="~Eth On"
	elif [[ "$WIRE_CON_STATE" == "connected" ]]; then
		WIRE_SWITCH="~Eth Off"
	elif [[ "$WIRE_CON_STATE" == "unavailable" ]]; then
		WIRE_SWITCH=" ***Wired Unavailable***"
	fi
}
function rofi_menu() {
	PROMPT=${WIRELESS_INTERFACES_PRODUCT[WLAN_INT]}[${WIRELESS_INTERFACES[WLAN_INT]}]
	if [[ $(nmcli device | awk '$2=="wifi" {print $1}' | wc -l) -ne "1" ]]; then
		((LINES+=1))
		SELECTION=$(echo -e "$WIFI_LIST\n~Scan\n~Manual\n$WIFI_SWITCH\n$WIRE_SWITCH\n~Change Wifi Interface\n~Status\n~Restart Network" | uniq -u | \
		rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS"  \
		-a "0" -theme-str 'window {width: '"$((($WIDTH/2)+2))"'em;}listview{lines: '"$LINES"';}textbox-prompt-colon{expand:true;str:"'$PROMPT'";}')
	else
		SELECTION=$(echo -e "$WIFI_LIST\n~Scan\n~Manual\n$WIFI_SWITCH\n$WIRE_SWITCH\n~Status\n~Restart Network" | uniq -u | \
		rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS"  \
		-a "0"-theme-str 'window {width: '"$((($WIDTH/2)+2))"'em;}listview{lines: '"$LINES"';}textbox-prompt-colon{expand:true;str:"'$PROMPT'";}')

	fi
	SSID_SELECTION=$(echo "$SELECTION" | sed  "s/\s\{2,\}/\|/g" | awk -F "|" '{print $1}')
	selection_action
}
function change_wireless_interface() {
	PROMPT=">_"
	if [[ $(nmcli device | awk '$2=="wifi" {print $1}' | wc -l) -eq "2" ]]; then
		if [[ $WLAN_INT -eq "0" ]]; then
			WLAN_INT=1
		else
			WLAN_INT=0
		fi
	else
		for i in "${!WIRELESS_INTERFACES[@]}"
		do
			LIST_WLAN_INT=(${LIST_WLAN_INT[@]}"${WIRELESS_INTERFACES_PRODUCT[$i]}[${WIRELESS_INTERFACES[$i]}]\n")
		done
		LINES=$(nmcli device | awk '$2=="wifi" {print $1}' | wc -l)
		CHANGE_WLAN_INT=$(echo -e  ${LIST_WLAN_INT[@]}| \
		rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" \
		-a "0" -theme-str 'window {width: '"$((($WIDTH/2)+2))"'em;}listview{lines: '"$LINES"';}textbox-prompt-colon{expand:true;str:"'$PROMPT'";}'\
		)
		for i in "${!WIRELESS_INTERFACES[@]}"
		do
			if [[ $CHANGE_WLAN_INT == "${WIRELESS_INTERFACES_PRODUCT[$i]}[${WIRELESS_INTERFACES[$i]}]" ]];then
				WLAN_INT=$i
				break
			fi
		done
	fi
	wireless_interface_state
	rofi_menu
}
function scan() {
	if [[ "$WIFI_CON_STATE" =~ "disabled" ]]; then
		change_wifi_state "4" "low" "Wi-Fi" "Enabling Wi-Fi connection" "on"
	fi
	notification "5" "normal" "Wifi" "Please Wait Scanning"
	WIFI_LIST=$(nmcli --fields IN-USE,SSID,SECURITY,BARS device wifi list ifname ${WIRELESS_INTERFACES[WLAN_INT]} --rescan yes | sed "s/^IN-USE\s//g" | sed "/*/d" | sed "s/^ *//")
	wireless_interface_state
	rofi_menu
}
function change_wifi_state() {
	notification $1 $2 $3 "$4"
	nmcli radio wifi $5
}
function change_wire_state() {
	notification $1 $2 $3 "$4"
	nmcli con $5 Ethernet
}
function net_restart() {
	notification $1 $2 $3 "$4"
	nmcli networking off
	sleep 3
	nmcli networking on
}
function disconnect() {
	TRUE_ACTIVE_SSID=$(nmcli -t -f GENERAL.CONNECTION dev show ${WIRELESS_INTERFACES[WLAN_INT]} |  cut -d ':' -f2)
	notification $1 $2 $3 "You're now disconnected from Wi-Fi network '$TRUE_ACTIVE_SSID'"
	nmcli con down id  "$TRUE_ACTIVE_SSID"
}
function check_wifi_connected(){
	if [[ "$(nmcli device status | grep ${WIRELESS_INTERFACES[WLAN_INT]} | awk '{print $3}')" == "connected" ]]; then
		disconnect "5" "low" "Connection_Terminated"
	fi
}
function connect() {
	check_wifi_connected
	notification "5" "critical" "Wi-Fi" "Connecting to $1"
	if [ $(nmcli dev wifi con "$1" password "$2" ifname ${WIRELESS_INTERFACES[WLAN_INT]}| grep -c "successfully activated" ) == "1" ]; then
		notification "5" "normal" "Connection_Established" "You're now connected to Wi-Fi network '$1' "
	else
		notification "5" "normal" "Connection_Error" "Connection can not be established"
	fi
}
function stored_connection() {
	check_wifi_connected
	notification "5" "critical" "Wi-Fi" "Connecting to $1"
	if [ $(nmcli dev wifi con "$1" ifname ${WIRELESS_INTERFACES[WLAN_INT]}| grep -c "successfully activated" ) = "1" ]; then
		notification "5" "normal" "Connection_Established" "You're now connected to Wi-Fi network '$1' "
	else
		notification "5" "normal" "Connection_Error" "Connection can not be established"
	fi
}
function ssid_manual() {
	LINES=0
	PROMPT="Enter_SSID:"
	WIDTH=$(echo $PROMPT | awk '{print length}' )
	SSID=$(	rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS"  \
	-a "0" \
	-theme-str 'window {width: '"$((($WIDTH/2)+15))"'em;}listview{lines: '"$LINES"';}textbox-prompt-colon{expand:true;str:"'$PROMPT'";}')
	echo $SSID
	if [[ ! -z $SSID ]]; then
		PROMPT="Enter_Password:"
		WIDTH=$(echo $PROMPT | awk '{print length}' )
		PASS=$(rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS"  \
		-a "0" -password \
		-theme-str 'window {width: '"$((($WIDTH/2)+15))"'em;}listview{lines: '"$LINES"';}textbox-prompt-colon{expand:true;str:"'$PROMPT'";}')
		if [ "$PASS" = "" ]; then
				check_wifi_connected
				nmcli dev wifi con "$SSID" ifname ${WIRELESS_INTERFACES[WLAN_INT]}

		else

				connect "$SSID" $PASS
		fi
	fi
}
function status() {
	LINES=2
	WIDTH=38
	PROMPT="Status"
	for i in "${!WIRELESS_INTERFACES[@]}"
	do
		WLAN_STATUS=(${WLAN_STATUS[@]}"${WIRELESS_INTERFACES_PRODUCT[$i]}[${WIRELESS_INTERFACES[$i]}]:\n\t$(nmcli -t -f GENERAL.CONNECTION dev show ${WIRELESS_INTERFACES[$i]} | awk -F '[:]' '{print $2}') ~ $(nmcli -t -f IP4.ADDRESS dev show ${WIRELESS_INTERFACES[$i]} | awk -F '[:/]' '{print $2}')\n")
		((LINES+=2))
	done
	ETH_STATUS=("$(nmcli device | awk '$2=="ethernet" {print $1}'):\n\t"$(nmcli -t -f GENERAL.CONNECTION dev show eth0 | awk -F '[:]' '{print $2}')" ~ "$(nmcli -t -f IP4.ADDRESS dev show eth0 | awk -F '[:/]' '{print $2}') )
	echo -e "$ETH_STATUS\n${WLAN_STATUS[@]}\n"| \
	rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS"  \
	-theme-str 'window {width: '"$((($WIDTH/2)+2))"'em;}listview{lines: '"$LINES"';}textbox-prompt-colon{expand:true;str:"'$PROMPT'";}'
}
function share_pass() {
	LINES=1
	PROMPT=">_"
	NOW_SSID=$(nmcli -t -f active,ssid dev wifi | grep ^yes | cut -d: -f2- | sort -u)
	PASSWORD=$(nmcli -s -g 802-11-wireless-security.psk connection show "$NOW_SSID")
	WIDTH=$(echo $NOW_SSID" : "$PASSWORD | awk '{print length}' )
	echo -e "$NOW_SSID" : "$PASSWORD\n"| \
	rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS"  \
	-theme-str 'window {width: '"$((($WIDTH/2)+2))"'em;}listview{lines: '"$LINES"';}textbox-prompt-colon{expand:true;str:"'$PROMPT'";}'
}
function selection_action () {
	case "$SELECTION" in
		"~Disconnect")
			disconnect "5" "low" "Connection_Terminated"
			;;
		"~Scan")
			scan
			;;
		"~Status")
			status
			;;
		"~Share Wifi Password")
			share_pass
			;;
		"~Manual")
			ssid_manual
				;;
		"~Wi-Fi On")
			change_wifi_state "4" "low" "Wi-Fi" "Enabling Wi-Fi connection" "on"
			;;
		"~Wi-Fi Off")
			change_wifi_state "4" "low" "Wi-Fi" "Disabling Wi-Fi connection" "off"
			;;
		"~Eth Off")
			change_wire_state "6" "low" "Ethernet" "Disabling Wired connection" "down"
			;;
		"~Eth On")
			change_wire_state "6" "low" "Ethernet" "Enabling Wired connection" "up"
			;;
		"   ***Wi-Fi Disabled***   ")
			;;
		" ***Wired Unavailable***")
			;;
		"~Change Wifi Interface")
			change_wireless_interface
			;;
		"~Restart Network")
			net_restart "7" "critical" "Network" "Restarting Network"
			;;
		*)
			LINES=1
			WIDTH=$(echo $PASSWORD_ENTER | awk '{print length}' )
			PROMPT="Enter_SSID:"
			if [[ ! -z "$SELECTION" ]] && [[ "$WIFI_LIST" =~ .*"$SELECTION".*  ]]; then
				if [ "$SSID_SELECTION" = "*" ]; then
					SSID_SELECTION=$(echo "$SELECTION" | sed  "s/\s\{2,\}/\|/g "| awk -F "|" '{print $3}')
				fi
				if [[ "$ACTIVE_SSID" == "$SSID_SELECTION" ]]; then
					nmcli con up "$SSID_SELECTION" ifname ${WIRELESS_INTERFACES[WLAN_INT]}
				else
					if [[ "$SELECTION" =~ "WPA2" ]] || [[ "$SELECTION" =~ "WEP" ]]; then
						PASS=$(echo "$PASSWORD_ENTER" | \
						rofi -dmenu -location "$LOCATION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS"  \
						-a "0" -password -theme-str 'window {width: '"$((($WIDTH/2)+2))"'em;}listview{lines: '"$LINES"';}textbox-prompt-colon{expand:true;str:"'$PROMPT'";}')
					fi
					if [[ ! -z "$PASS" ]] ; then
						if [[ "$PASS" =~ "$PASSWORD_ENTER" ]]; then
							stored_connection "$SSID_SELECTION"
						else
							connect "$SSID_SELECTION" $PASS
						fi
					fi
				fi
			fi
		;;
	esac
}
function main() {
	initialization
	rofi_menu
}
main