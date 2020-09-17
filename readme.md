# Rofi-NetWork-manager
A nework manager for Tiling Window Managers [i3/bspwm/awesome/etc] or not. 
Inspired from [rofi-wifi-menu](https://github.com/zbaylin/rofi-wifi-menu).


## Table of Contents
* [Requirements](#requirements)
* [Features](#features)
* [Screenshots](#screenshots)
* [Config](#config)
* [Download-Usage](#download-usage)
* [ToDo](#todo)

### Requirements
* nmcli
* [rofi](https://github.com/davatorium/rofi)
* [dunst](https://github.com/dunst-project/dunst) (_Optional_) (_For notifications_)
### Features
* Connect to an existing network
* Disconnect from the network
* Turn on/off wifi
* Support for Multiple wifi devices (_Up to two_)
	* Option to change between wifi devices when available
* Manual Connection to a hidden wifi
* Turn on/off ethernet
	* See when ethernet is unavailable
* Restart the network
* Status 
	* See devices Connection name and local IP
### Screenshots
<img src="https://raw.githubusercontent.com/P3rf/rofi-network-manager/master/desktop.png"/>
<img src="https://raw.githubusercontent.com/P3rf/rofi-network-manager/master/options.png"/>

### Config
````
	# Location  
	This sets the anchor point:
		+---------- +
		| 1 | 2 | 3 |
		| 8 | 0 | 4 |
		| 7 | 6 | 5 |
		+-----------+
	If you want the window to be in the upper right corner, set location to 3.
		LOCATION=0
	X, Y Offset
		Y_AXIS=0
		X_AXIS=0
	#Font to use
		FONT="DejaVu Sans Mono 8"
	#Use notifications or not
	# Values on / off
		NOTIFICATIONS_INIT="off"
````


### Download-Usage
```
git clone https://github.com/P3rf/rofi-network-manager.git
cd rofi-network-manager
bash "./rofi-network-manager.sh"
```


### ToDo
 * Tweak notifications
 * Add notifications icons
