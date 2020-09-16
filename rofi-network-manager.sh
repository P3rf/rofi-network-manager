#!/bin/bash
POSITION=3
Y_AXIS=15
X_AXIS=0
FONT="DejaVu Sans Mono 9"
PASSWORD_ENTER="if connection is stored, hit enter/esc"
WIRELESS_INTERFACES=($(nmcli device | awk '$2=="wifi" {print $1}'))
WLAN_INT=0
function notification() {
	dunstify -r $1 -u $2 $3 "$4"
}
function initialization() {
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
			WIFI_SWITCH="~Disconnect\n~Wi-Fi Off"
			((LINES+=7))
		fi
	fi
	WIDTH=$(echo "$WIFI_LIST" | head -n 1 | awk '{print length($0); }')
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
	if [[ $(nmcli dev status | grep -ow ^wlan. | wc -l) -ne "1" ]]; then
		((LINES+=1))
		SELECTION=$(echo -e "$WIFI_LIST\n~Scan\n~Manual\n$WIFI_SWITCH\n$WIRE_SWITCH\n~Change Wifi Interface\n~Status\n~Restart Network" | uniq -u | rofi -dmenu -p "${WIRELESS_INTERFACES[WLAN_INT]} SSID" -lines "$LINES" -a "0" -location "$POSITION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" -width -"$WIDTH" -font "$FONT")
	else
		SELECTION=$(echo -e "$WIFI_LIST\n~Scan\n~Manual\n$WIFI_SWITCH\n$WIRE_SWITCH\n~Status\n~Restart Network" | uniq -u | rofi -dmenu -p "${WIRELESS_INTERFACES[WLAN_INT]} SSID" -lines "$LINES" -a "0" -location "$POSITION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" -width -"$WIDTH" -font "$FONT")
	fi
	SSID_SELECTION=$(echo "$SELECTION" | sed  "s/\s\{2,\}/\|/g" | awk -F "|" '{print $1}')
	selection_action
}
function change_wireless_interface() {
	if [[ $WLAN_INT -eq "0" ]]; then
		WLAN_INT=1
	else
		WLAN_INT=0
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
	if [ $(nmcli dev wifi con "$1" password "$2" ifname ${WIRELESS_INTERFACES[WLAN_INT]}| grep -c "successfully activated" ) = "1" ]; then
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
	
	SSID=$(echo "Enter SSID" | rofi -dmenu  -p ">_" -mesg -a "0" -lines 1 -location "$POSITION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" -width 18 -font "$FONT" )
	echo $SSID
	if [[ ! -z $SSID ]]; then
		PASS=$(echo "Enter Password" | rofi -dmenu  -p ">_" -a "0"  -password -lines 1 -location "$POSITION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" -width 18 -font "$FONT"  )
		if [ "$PASS" = "" ]; then
				check_wifi_connected
				nmcli dev wifi con "$SSID" ifname ${WIRELESS_INTERFACES[WLAN_INT]}
		else
		
				connect "$SSID" $PASS
		fi
	fi
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
			if [[ ! -z "$SELECTION" ]] && [[ "$WIFI_LIST" =~ .*"$SELECTION".*  ]]; then
				if [ "$SSID_SELECTION" = "*" ]; then
					SSID_SELECTION=$(echo "$SELECTION" | sed  "s/\s\{2,\}/\|/g "| awk -F "|" '{print $3}')
				fi
				if [[ "$ACTIVE_SSID" == "$SSID_SELECTION" ]]; then
					nmcli con up "$SSID_SELECTION" ifname ${WIRELESS_INTERFACES[WLAN_INT]}
				else
					if [[ "$SELECTION" =~ "WPA2" ]] || [[ "$SELECTION" =~ "WEP" ]]; then
						PASS=$(echo "$PASSWORD_ENTER" | rofi -dmenu -p ">_" -password -a "0" -location "$POSITION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" -width 16 -lines 1 -font "$FONT" )
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
function status() {
	WLAN_STATUS=("${WIRELESS_INTERFACES[0]}:\n\t"$(nmcli -t -f GENERAL.CONNECTION dev show ${WIRELESS_INTERFACES[0]} |  cut -d ':' -f2)" ~ "$(nmcli -t -f IP4.ADDRESS dev show ${WIRELESS_INTERFACES[0]} | cut -d / -f1 | cut -d ':' -f2) )
	STATUS_LINES=4
	if [[ $(nmcli dev status | grep -ow ^wlan. | wc -l) -ne "1" ]]; then
		WLAN_STATUS=(${WLAN_STATUS[@]}"\n${WIRELESS_INTERFACES[1]}:\n\t"$(nmcli -t -f GENERAL.CONNECTION dev show ${WIRELESS_INTERFACES[1]} |  cut -d ':' -f2)" ~ "$(nmcli -t -f IP4.ADDRESS dev show ${WIRELESS_INTERFACES[1]} | cut -d / -f1 | cut -d ':' -f2))
		((STATUS_LINES+=2))
	fi
	ETH_STATUS=("$(nmcli device | awk '$2=="ethernet" {print $1}'):\n\t"$(nmcli -t -f GENERAL.CONNECTION dev show eth0 |  cut -d ':' -f2)" ~ "$(nmcli -t -f IP4.ADDRESS dev show eth0 | cut -d / -f1 | cut -d ':' -f2) )
	echo -e "$ETH_STATUS\n${WLAN_STATUS[@]}\n"| rofi -dmenu -p "Status" -lines "$STATUS_LINES" -location "$POSITION" -yoffset "$Y_AXIS" -xoffset "$X_AXIS" -width -"$WIDTH" -font "$FONT"
}
function main() {
	initialization
	rofi_menu
}
main